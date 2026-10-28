import 'dart:async';

import 'package:flutter/material.dart';

import '../models/passenger_models.dart';
import '../services/route_names.dart';
import '../services/uway_data_source.dart';
import '../widgets/passenger_state_panel.dart';
import '../widgets/trip_card.dart';
import 'trip_details_screen.dart';

/// Your Trips: only trips for which this passenger has an active Trip Intent.
///
/// The API has no endpoint that lists a passenger's intents, so the list is
/// built by reading the browsable trips and asking for this passenger's intent
/// on each one. History (completed/cancelled trips) is intentionally excluded.
class PassengerMyTripsScreen extends StatefulWidget {
  const PassengerMyTripsScreen({
    required this.apiClient,
    this.refreshToken = 0,
    super.key,
  });

  final UwayDataSource apiClient;

  /// Changing this value reloads the list (used when the tab is selected).
  final int refreshToken;

  @override
  State<PassengerMyTripsScreen> createState() => _PassengerMyTripsScreenState();
}

class _MyTrip {
  const _MyTrip(this.trip, this.intent, this.routeName);
  final UwayTrip trip;
  final PassengerTripIntent intent;
  final String? routeName;
}

class _PassengerMyTripsScreenState extends State<PassengerMyTripsScreen> {
  late Future<List<_MyTrip>> _items;

  @override
  void initState() {
    super.initState();
    _items = _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 20), (_) => _silentRefresh());
  }

  Timer? _autoRefresh;

  /// Reloads quietly in the background so new trips and changes appear by themselves.
  Future<void> _silentRefresh() async {
    try {
      final next = _load();
      await next;
      if (mounted) setState(() => _items = next);
    } on Object {
      // Keep showing what we have; the next check tries again.
    }
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PassengerMyTripsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _items = _load();
  }

  Future<List<_MyTrip>> _load() async {
    final trips = await widget.apiClient.getTrips();
    final candidates =
        trips.where((trip) => !trip.isTerminal).toList(growable: false);
    final intents = await Future.wait(
      candidates.map((trip) => widget.apiClient.getMyIntent(trip.id)),
    );
    final withIntent = <int>[
      for (var i = 0; i < candidates.length; i++)
        if (intents[i] != null) i,
    ];
    final names = await loadRouteNames(
      widget.apiClient,
      withIntent.map((i) => candidates[i].routeId),
    );
    final result = <_MyTrip>[
      for (final i in withIntent)
        _MyTrip(candidates[i], intents[i]!, names[candidates[i].routeId]),
    ]..sort((a, b) =>
        a.trip.departureAtUtc.compareTo(b.trip.departureAtUtc));
    return result;
  }

  void _reload() {
    if (!mounted) return;
    final next = _load();
    setState(() {
      _items = next;
    });
  }

  Future<void> _refresh() async {
    final result = _load();
    setState(() {
      _items = result;
    });
    try {
      await result;
    } catch (_) {
      // The error is shown by the FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<_MyTrip>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const LoadingPanel(message: 'Loading your trips…');
          }
          if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  const SizedBox(height: 100),
                  PassengerStatePanel(
                    title: 'Your trips could not load',
                    message: snapshot.error.toString(),
                    icon: Icons.cloud_off_outlined,
                    action: OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ),
                ],
              ),
            );
          }
          final items = snapshot.data ?? const <_MyTrip>[];
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 100),
                  PassengerStatePanel(
                    title: 'No active trip intents',
                    message:
                        'Open Trips, choose a trip and select "I\'m Taking This Trip". It will appear here. A Trip Intent is not a reservation.',
                    icon: Icons.event_available_outlined,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  'Your trips',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Trips where you selected "I\'m Taking This Trip". This is not a seat reservation.',
                ),
                const SizedBox(height: 18),
                for (final item in items) ...[
                  TripCard(
                    trip: item.trip,
                    routeName: item.routeName,
                    dropOffName: item.intent.dropOffStopName,
                    onTap: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute<void>(
                            builder: (_) => TripDetailsScreen(
                              apiClient: widget.apiClient,
                              tripId: item.trip.id,
                            ),
                          ),
                        )
                        .then((_) => _reload()),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      );
}
