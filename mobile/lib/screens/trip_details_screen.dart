import 'package:flutter/material.dart';

import '../models/passenger_models.dart';
import '../models/trip_filter.dart';
import '../services/uway_data_source.dart';
import '../widgets/passenger_state_panel.dart';
import '../theme/uway_theme.dart';
import '../widgets/trip_card.dart';
import 'drop_off_picker_screen.dart';
import 'trip_tracking_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({
    required this.apiClient,
    required this.tripId,
    super.key,
  });

  final UwayDataSource apiClient;
  final String tripId;

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  late Future<_TripDetails> _details;

  @override
  void initState() {
    super.initState();
    _details = _loadDetails();
  }

  Future<_TripDetails> _loadDetails() async {
    final trip = await widget.apiClient.getTrip(widget.tripId);
    final route = (await widget.apiClient.getRoute(trip.routeId))
        .forAudience(trip.audience);
    return _TripDetails(trip, route);
  }

  void _reload() {
    final next = _loadDetails();
    setState(() {
      _details = next;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Trip details')),
        body: FutureBuilder<_TripDetails>(
          future: _details,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingPanel();
            }
            if (snapshot.hasError) {
              final denied = snapshot.error is UwayApiException &&
                  (snapshot.error! as UwayApiException).statusCode == 403;
              return PassengerStatePanel(
                title: denied
                    ? 'Trip details are unavailable'
                    : 'Trip could not load',
                message: denied
                    ? 'This account is not allowed to view these trip details. Check the local Passenger access configuration and try again.'
                    : snapshot.error.toString(),
                icon: denied ? Icons.lock_outline : Icons.cloud_off_outlined,
                action: OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              );
            }

            final details = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Text(
                  details.route.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatusPill(trip: details.trip),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _formatDate(details.trip.departureAtUtc),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                if (details.trip.isCancelled || details.trip.isDelayed) ...[
                  const SizedBox(height: 12),
                  _AlertBanner(trip: details.trip),
                ],
                const SizedBox(height: 18),
                _TripSummaryCard(trip: details.trip),
                const SizedBox(height: 18),
                _TripIntentPanel(
                  apiClient: widget.apiClient,
                  trip: details.trip,
                  route: details.route,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: details.trip.isStarted && !details.trip.isTerminal
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TripTrackingScreen(
                                apiClient: widget.apiClient,
                                trip: details.trip,
                                route: details.route,
                              ),
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.my_location_outlined),
                  label: const Text('View bus location'),
                ),
                const SizedBox(height: 8),
                Text(
                  details.trip.isStarted && !details.trip.isTerminal
                      ? 'The bus is on its way. Open the map to follow it.'
                      : details.trip.isFinished
                          ? 'This trip has finished, so live location is no longer available.'
                          : details.trip.isCancelled
                              ? 'This trip was cancelled.'
                              : 'Available once the driver starts the trip.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      );
}

class _TripDetails {
  const _TripDetails(this.trip, this.route);
  final UwayTrip trip;
  final UwayRoute route;
}

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({required this.trip});
  final UwayTrip trip;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailLine(
                label: 'Departure',
                value: _formatDate(trip.departureAtUtc),
              ),
              if (trip.busNumber != null)
                _DetailLine(label: 'Bus', value: trip.busNumber!),
              if (trip.driverName != null)
                _DetailLine(label: 'Driver', value: trip.driverName!),
            ],
          ),
        ),
      );
}

class _TripIntentPanel extends StatefulWidget {
  const _TripIntentPanel({
    required this.apiClient,
    required this.trip,
    required this.route,
  });

  final UwayDataSource apiClient;
  final UwayTrip trip;
  final UwayRoute route;

  @override
  State<_TripIntentPanel> createState() => _TripIntentPanelState();
}

class _TripIntentPanelState extends State<_TripIntentPanel> {
  late Future<PassengerTripIntent?> _intent;
  int? _selectedStopId;
  bool _saving = false;
  bool _intentConflictUnresolved = false;
  String? _message;

  bool get _canCreate =>
      (widget.trip.status == 'Scheduled' || widget.trip.isInProgress) &&
      !widget.trip.isCancelled;
  bool get _canChange => _canCreate;

  @override
  void initState() {
    super.initState();
    _intent = widget.apiClient.getMyIntent(widget.trip.id);
  }

  Future<PassengerTripIntent?> _reloadIntent(
      {bool clearSelection = false}) async {
    if (!mounted) return null;
    final next = widget.apiClient.getMyIntent(widget.trip.id);
    setState(() {
      _intent = next;
      _message = null;
      if (clearSelection) _selectedStopId = null;
    });
    return next;
  }

  Future<void> _retryIntentLoad() async {
    if (!mounted || _saving) return;
    final conflictUnresolved = _intentConflictUnresolved;
    final previousMessage = _message;
    setState(() => _saving = true);
    try {
      final intent = await _reloadIntent(clearSelection: conflictUnresolved);
      if (!mounted) return;
      setState(() {
        if (conflictUnresolved && intent != null) {
          _intentConflictUnresolved = false;
        }
        _message = conflictUnresolved ? previousMessage : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = conflictUnresolved ? previousMessage : error.toString();
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _create() async {
    final stopId = _selectedStopId;
    await _perform(
      () => widget.apiClient.createIntent(widget.trip.id, stopId),
      reloadOnConflict: true,
    );
  }

  Future<void> _change() async {
    final stopId = _selectedStopId;
    if (stopId == null) return;
    await _perform(
      () => widget.apiClient.changeDropOff(widget.trip.id, stopId),
    );
  }

  Future<void> _cancel() async {
    await _perform(() => widget.apiClient.cancelIntent(widget.trip.id));
    if (mounted) setState(() => _selectedStopId = null);
  }

  Future<void> _perform<T>(
    Future<T> Function() action, {
    bool reloadOnConflict = false,
  }) async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) await _reloadIntent();
    } catch (error) {
      final originalMessage = error.toString();
      if (mounted &&
          reloadOnConflict &&
          error is UwayApiException &&
          error.statusCode == 409) {
        setState(() => _intentConflictUnresolved = true);
        try {
          final existingIntent = await _reloadIntent(clearSelection: true);
          if (mounted && existingIntent != null) {
            setState(() => _intentConflictUnresolved = false);
          }
        } catch (_) {
          // Keep the original conflict message if the refresh also fails.
        }
      }
      if (mounted) setState(() => _message = originalMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _pickerTitle => routeDirection(widget.route) ==
          RouteDirection.toCampus
      ? 'Where on campus will you get off?'
      : 'Where will you get off?';

  Future<void> _pick(List<UwayRouteStop> options, int? current) async {
    final chosen = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => DropOffPickerScreen(
          title: _pickerTitle,
          options: options,
          routeStops: widget.route.stops,
          selectedId: current,
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _selectedStopId = chosen);
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trip Intent',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'This tells the university you plan to take the trip. It is not a reservation and does not hold a seat.',
              ),
              const SizedBox(height: 14),
              FutureBuilder<PassengerTripIntent?>(
                future: _intent,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: LinearProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trip Intent could not load: ${snapshot.error}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _message!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        TextButton.icon(
                          onPressed: _saving ? null : _retryIntentLoad,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry loading'),
                        ),
                      ],
                    );
                  }

                  final intent = snapshot.data;
                  final stopId = _selectedStopId ?? intent?.dropOffStopId;
                  final options = dropOffOptions(widget.route);
                  final stopExists = options.any(
                    (stop) => stop.id == stopId,
                  );
                  final awaitingConflictRefresh =
                      intent == null && _intentConflictUnresolved;
                  final canSelect = intent == null ? _canCreate : _canChange;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (intent != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'You have an active Trip Intent for this trip.',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          intent.dropOffStopId == null
                              ? 'Drop-off stop: not chosen yet (optional)'
                              : 'Selected drop-off: ${intent.dropOffStopName ?? _stopName(intent.dropOffStopId)}',
                        ),
                        Text(
                            'Expected rider count: ${intent.expectedRiderCount}'),
                        const SizedBox(height: 12),
                      ] else if (awaitingConflictRefresh) ...[
                        const Text(
                          'The server reported an existing Trip Intent, but its current details could not be confirmed. Check the status before trying again.',
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        const Text(
                          'You have not indicated that you plan to take this trip.',
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (awaitingConflictRefresh)
                        const SizedBox.shrink()
                      else if (options.isNotEmpty)
                        _DropOffTile(
                          title: intent == null
                              ? '$_pickerTitle (optional)'
                              : _pickerTitle,
                          selectedName: stopExists ? _stopName(stopId) : null,
                          enabled: canSelect && !_saving,
                          onTap: () => _pick(options, stopId),
                        )
                      else
                        const Text(
                          'No route stops are available for drop-off selection.',
                        ),
                      const SizedBox(height: 12),
                      if (awaitingConflictRefresh)
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _retryIntentLoad,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Check Trip Intent status'),
                        )
                      else if (intent == null)
                        FilledButton.icon(
                          onPressed: _canCreate && !_saving ? _create : null,
                          icon: _saving
                              ? const _SmallProgress()
                              : const Icon(Icons.directions_bus_outlined),
                          label: const Text("I'm Taking This Trip"),
                        )
                      else ...[
                        OutlinedButton(
                          onPressed: _canChange &&
                                  stopExists &&
                                  stopId != intent.dropOffStopId &&
                                  !_saving
                              ? _change
                              : null,
                          child: Text(intent.dropOffStopId == null
                              ? 'Save drop-off stop'
                              : 'Update drop-off stop'),
                        ),
                        TextButton.icon(
                          onPressed: _saving ? null : _cancel,
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel Trip Intent'),
                        ),
                      ],
                      if (!_canChange) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Trip Intent changes are unavailable in this trip state.',
                        ),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _message!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );

  String _stopName(int? id) {
    for (final stop in widget.route.stops) {
      if (stop.id == id) return stop.name;
    }
    return 'Unknown stop';
  }
}

class _SmallProgress extends StatelessWidget {
  const _SmallProgress();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 94,
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';


class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.trip});
  final UwayTrip trip;

  @override
  Widget build(BuildContext context) {
    final color = tripStatusColor(context, trip.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        humanTripStatus(trip.status),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.trip});
  final UwayTrip trip;

  @override
  Widget build(BuildContext context) {
    final cancelled = trip.isCancelled;
    final color = cancelled ? context.uwayDanger : context.uwayWarning;
    final reason = cancelled ? trip.cancellationReason : trip.delayReason;
    final text = cancelled
        ? 'This trip was cancelled${reason == null ? '' : ' · $reason'}'
        : 'Delayed ${trip.delayMinutes} min${trip.delayMinutes == 1 ? '' : 's'}${reason == null ? '' : ' · $reason'}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(cancelled ? Icons.cancel_outlined : Icons.schedule, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _DropOffTile extends StatelessWidget {
  const _DropOffTile({
    required this.title,
    required this.selectedName,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String? selectedName;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        child: Row(
          children: [
            const Icon(Icons.place_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedName == null ? title : 'Drop-off point',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    selectedName ?? 'Choose on the map',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.map_outlined),
          ],
        ),
      );
}
