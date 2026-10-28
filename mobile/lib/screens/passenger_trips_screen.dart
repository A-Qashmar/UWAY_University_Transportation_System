import 'dart:async';

import 'package:flutter/material.dart';

import '../models/passenger_models.dart';
import '../models/trip_filter.dart';
import '../services/uway_data_source.dart';
import '../theme/uway_theme.dart';
import '../widgets/passenger_state_panel.dart';
import '../widgets/trip_card.dart';
import 'trip_details_screen.dart';

/// Trips: a search-first screen. The passenger picks a direction, a route and
/// optionally a departure time, then presses Search. Results are filtered
/// locally from the trips the data source returned; the API is never asked for
/// anything new and no sample data is substituted when it fails. The route
/// list is every registered route from `GET /api/routes`.
class PassengerTripsScreen extends StatefulWidget {
  const PassengerTripsScreen({required this.apiClient, super.key});

  final UwayDataSource apiClient;

  @override
  State<PassengerTripsScreen> createState() => _PassengerTripsScreenState();
}

class _BrowseData {
  const _BrowseData(this.trips, this.routes, this.failedRoutes);
  final List<UwayTrip> trips;
  final Map<int, UwayRoute> routes;
  final int failedRoutes;
}

class _PassengerTripsScreenState extends State<PassengerTripsScreen> {
  late Future<_BrowseData> _data;
  TripDirectionFilter _direction = TripDirectionFilter.any;
  int? _routeId;
  int? _timeMinutes;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 20), (_) => _silentRefresh());
  }

  Timer? _autoRefresh;

  /// Reloads quietly in the background so new trips and changes appear by themselves.
  Future<void> _silentRefresh() async {
    try {
      final next = _load();
      await next;
      if (mounted) setState(() => _data = next);
    } on Object {
      // Keep showing what we have; the next check tries again.
    }
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<_BrowseData> _load() async {
    // All registered routes are offered, not only the ones that already have
    // trips. Trips are matched to the chosen route after the passenger searches.
    final results = await Future.wait([
      widget.apiClient.getTrips(),
      widget.apiClient.getRoutes(),
    ]);
    final trips = results[0] as List<UwayTrip>;
    final routes = {
      for (final route in results[1] as List<UwayRoute>) route.id: route,
    };
    return _BrowseData(trips, routes, 0);
  }

  Future<void> _refresh() async {
    final result = _load();
    setState(() {
      _data = result;
    });
    try {
      await result;
    } catch (_) {
      // The error state is shown by the FutureBuilder.
    }
  }

  List<UwayRoute> _routesFor(_BrowseData data) {
    final routes = data.routes.values
        .where((route) => directionMatches(_direction, route))
        .toList();
    routes.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return routes;
  }

  void _setDirection(TripDirectionFilter direction, _BrowseData data) {
    setState(() {
      _direction = direction;
      final route = _routeId == null ? null : data.routes[_routeId];
      if (_routeId != null && !directionMatches(direction, route)) {
        _routeId = null;
        _timeMinutes = null;
      }
      _searched = false;
    });
  }

  Future<void> _pickRoute(_BrowseData data) async {
    final routes = _routesFor(data);
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Choose a route',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            if (routes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No routes match this direction.'),
              ),
            for (final route in routes)
              ListTile(
                leading: Icon(
                  route.id == _routeId
                      ? Icons.radio_button_checked
                      : Icons.alt_route,
                  color: route.id == _routeId
                      ? Theme.of(sheetContext).colorScheme.primary
                      : null,
                ),
                title: Text(route.name.isEmpty ? 'Route ${route.id}' : route.name),
                onTap: () => Navigator.of(sheetContext).pop(route.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _routeId = picked;
      _timeMinutes = null;
      _searched = false;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_BrowseData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const LoadingPanel(message: 'Loading trips…');
          }
          if (snapshot.hasError) return _errorPanel(snapshot.error!);
          final data = snapshot.data!;
          if (data.trips.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 100),
                  PassengerStatePanel(
                    title: 'No trips are available',
                    message:
                        'Check again later for scheduled university bus trips.',
                    icon: Icons.route_outlined,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'Find your trip',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  formatLongDate(DateTime.now()),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                _searchCard(context, data),
                if (data.failedRoutes > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Details could not be loaded for ${data.failedRoutes} route${data.failedRoutes == 1 ? '' : 's'}, so they cannot be searched. Pull down to retry.',
                    style: TextStyle(color: context.uwayWarning),
                  ),
                ],
                const SizedBox(height: 18),
                if (!_searched)
                  const PassengerStatePanel(
                    title: 'Where are you headed?',
                    message:
                        'Choose a route, then press Search to see its upcoming trips.',
                    icon: Icons.search,
                  )
                else
                  ..._results(context, data),
              ],
            ),
          );
        },
      );

  List<Widget> _results(BuildContext context, _BrowseData data) {
    final matching = data.trips.where((trip) {
      if (trip.routeId != _routeId) return false;
      return _timeMinutes == null || tripMinutes(trip) == _timeMinutes;
    }).toList();
    final results = rankTrips(matching);
    final routeName = data.routes[_routeId]?.name;
    if (results.isEmpty) {
      return [
        PassengerStatePanel(
          title: 'No upcoming trips found',
          message: _timeMinutes == null
              ? 'There are no upcoming trips on this route right now. Try another route or check again later.'
              : 'Nothing departs at ${formatMinutes(_timeMinutes!)} on this route. Try another time or clear it.',
          icon: Icons.search_off_outlined,
        ),
      ];
    }
    return [
      Text(
        '${results.length} trip${results.length == 1 ? '' : 's'}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 10),
      for (final trip in results) ...[
        TripCard(
          trip: trip,
          routeName: routeName,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TripDetailsScreen(
                apiClient: widget.apiClient,
                tripId: trip.id,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _searchCard(BuildContext context, _BrowseData data) {
    final routeName = _routeId == null ? null : data.routes[_routeId]?.name;
    final upcomingOnRoute = _routeId == null
        ? const <UwayTrip>[]
        : rankTrips(
            data.trips.where((trip) => trip.routeId == _routeId).toList(),
          );
    final times = departureTimesOfDay(upcomingOnRoute);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Direction',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: muted,
                    )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final option in const [
                  (TripDirectionFilter.any, 'Any'),
                  (TripDirectionFilter.toCampus, 'To campus'),
                  (TripDirectionFilter.fromCampus, 'From campus'),
                ])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: _direction == option.$1,
                    onSelected: (_) => _setDirection(option.$1, data),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Route',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: muted,
                    )),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _pickRoute(data),
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.alt_route, color: UwayColors.gold),
                  suffixIcon: Icon(Icons.keyboard_arrow_down),
                ),
                child: Text(
                  _routeId == null
                      ? 'Choose a route'
                      : (routeName == null || routeName.isEmpty
                          ? 'Route $_routeId'
                          : routeName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _routeId == null ? muted : null),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Departure time',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: muted,
                    )),
            const SizedBox(height: 8),
            if (_routeId == null)
              Text('Choose a route to see its departure times.',
                  style: TextStyle(color: muted))
            else if (times.isEmpty)
              Text('No upcoming departures on this route.',
                  style: TextStyle(color: muted))
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('Any time'),
                    selected: _timeMinutes == null,
                    onSelected: (_) {
                      setState(() {
                        _timeMinutes = null;
                        _searched = false;
                      });
                    },
                  ),
                  for (final minutes in times)
                    ChoiceChip(
                      label: Text(formatMinutes(minutes)),
                      selected: _timeMinutes == minutes,
                      onSelected: (_) {
                        setState(() {
                          _timeMinutes = _timeMinutes == minutes ? null : minutes;
                          _searched = false;
                        });
                      },
                    ),
                ],
              ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _routeId == null
                  ? null
                  : () {
                      setState(() {
                        _searched = true;
                      });
                    },
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
            if (_routeId == null) ...[
              const SizedBox(height: 8),
              Text('Pick a route first to enable Search.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: muted)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorPanel(Object error) {
    final message = error is UwayApiException && error.statusCode == 403
        ? 'This account is not allowed to browse trips. Check the local Passenger access configuration and try again.'
        : error.toString();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        children: [
          const SizedBox(height: 100),
          PassengerStatePanel(
            title: error is UwayApiException && error.statusCode == 403
                ? 'Trip browsing is restricted'
                : 'Trips could not load',
            message: message,
            icon: error is UwayApiException && error.statusCode == 401
                ? Icons.lock_outline
                : Icons.cloud_off_outlined,
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
}
