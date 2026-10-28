import 'dart:async';

import 'package:flutter/material.dart';

import '../models/passenger_models.dart';
import '../models/trip_filter.dart';
import '../services/location_sharer.dart';
import '../services/uway_data_source.dart';
import '../widgets/live_location_map.dart';
import 'driver_home_screen.dart' show DriverStatusPill;
import 'passenger_reports_screen.dart';

/// One trip, in focus: the route map with the bus, big buttons for what the
/// driver can do right now, and the list of stops.
class DriverTripScreen extends StatefulWidget {
  const DriverTripScreen({
    required this.apiClient,
    required this.trip,
    required this.sharer,
    super.key,
  });

  final UwayDataSource apiClient;
  final UwayTrip trip;
  final LocationSharer sharer;

  @override
  State<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends State<DriverTripScreen> {
  late UwayTrip _trip = widget.trip;
  UwayRoute? _route;
  String? _busy;
  String? _error;
  Timer? _poll;

  LocationSharer get _sharer => widget.sharer;

  @override
  void initState() {
    super.initState();
    _sharer.addListener(_onSharer);
    _loadRoute();
    // Pick up changes the admin makes (cancel, new time) without reopening.
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _refreshTrip());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _sharer.removeListener(_onSharer);
    super.dispose();
  }

  void _onSharer() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRoute() async {
    try {
      final route = (await widget.apiClient.getRoute(_trip.routeId))
          .forAudience(_trip.audience);
      if (mounted) setState(() => _route = route);
    } on Object catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _refreshTrip() async {
    try {
      final trips = await widget.apiClient.getAssignedTrips();
      final fresh = trips.where((t) => t.id == _trip.id).firstOrNull;
      if (fresh != null && mounted) {
        setState(() => _trip = fresh);
        if (!fresh.isStarted) _sharer.stop();
      }
    } on Object {
      // Keep showing the last known state.
    }
  }

  Future<void> _run(String key, Future<UwayTrip?> Function() action,
      {String? done}) async {
    setState(() {
      _busy = key;
      _error = null;
    });
    try {
      final updated = await action();
      if (updated != null && mounted) setState(() => _trip = updated);
      await _refreshTrip();
      if (mounted && done != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(done)));
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _start() => _run('start', () async {
        final started = await widget.apiClient.startTrip(_trip.id);
        // Share the bus location automatically so the driver has one thing less to do.
        if (widget.apiClient.supportsGps) await _sharer.start(started.id);
        return started;
      }, done: 'Trip started. Passengers can now see the bus.');

  Future<void> _end() async {
    final ok = await _confirm(
      title: 'End this trip?',
      text: 'Passengers will stop seeing the bus on the map.',
      action: 'End trip',
      color: const Color(0xFFC0392B),
    );
    if (ok != true) return;
    await _run('end', () async {
      _sharer.stop();
      return widget.apiClient.endTrip(_trip.id);
    }, done: 'Trip ended. Thank you!');
  }

  Future<void> _nearlyFull() async {
    final ok = await _confirm(
      title: 'Tell operations the bus is nearly full?',
      text: 'The admin will get an alert right away.',
      action: 'Send alert',
      color: const Color(0xFFB4741A),
    );
    if (ok != true) return;
    await _run('full', () async {
      await widget.apiClient.reportNearlyFull(_trip.id);
      return null;
    }, done: 'Alert sent to operations.');
  }

  Future<void> _delay() async {
    final result = await showDialog<({int minutes, String reason})>(
      context: context,
      builder: (_) => const _DelayDialog(),
    );
    if (result == null) return;
    await _run('delay', () => widget.apiClient.delayTrip(_trip.id, result.minutes, result.reason),
        done: 'Delay reported. Passengers were told.');
  }

  Future<bool?> _confirm({
    required String title,
    required String text,
    required String action,
    required Color color,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      );

  Future<void> _report() async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => ReportFormScreen(
        apiClient: widget.apiClient,
        initialCategory: 'TripProblem',
        initialTripId: _trip.id,
      ),
    ));
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent. You can follow it under My reports.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canStart = _trip.status == 'Scheduled' && !_trip.isCancelled;
    final canDelay = canStart;
    final running = _trip.isStarted && !_trip.isCancelled;
    final sharing = _sharer.isSharing(_trip.id);
    final loc = _sharer.lastLocation;
    final stops = _route?.stops ?? const <UwayRouteStop>[];

    return Scaffold(
      appBar: AppBar(title: Text(_trip.displayName, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          // The map stays in view while the buttons below scroll.
          if (stops.any((s) => s.hasLocation))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: LiveLocationMap(
                latitude: sharing || running ? loc?.latitude : null,
                longitude: sharing || running ? loc?.longitude : null,
                stops: stops,
                height: 260,
              ),
            )
          else if (_route == null)
            const SizedBox(
                height: 120, child: Center(child: CircularProgressIndicator())),
          Expanded(
            child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(
            children: [
              Text(
                _hhmm(_trip.departureAtUtc),
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_dayText(_trip.departureAtUtc),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              DriverStatusPill(trip: _trip),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 14, runSpacing: 4, children: [
            if (_trip.busNumber != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.directions_bus_outlined, size: 18),
                const SizedBox(width: 5),
                Text('Bus ${_trip.busNumber}'),
              ]),
            if (_trip.joinedCount != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.groups_2_outlined, size: 18),
                const SizedBox(width: 5),
                Text('${_trip.joinedCount} passenger${_trip.joinedCount == 1 ? '' : 's'} joined'),
              ]),
            if (_trip.audience != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_trip.audience == 'F' ? Icons.woman : Icons.man, size: 18),
                const SizedBox(width: 5),
                Text(_trip.audience == 'F' ? "Women's trip" : "Men's trip"),
              ]),
          ]),
          if (_trip.isDelayed && !_trip.isTerminal) ...[
            const SizedBox(height: 10),
            _Notice(
              icon: Icons.schedule,
              color: const Color(0xFFB4741A),
              text: 'Delayed ${_trip.delayMinutes} min · ${_trip.delayReason ?? ''}',
            ),
          ],
          if (_trip.isCancelled) ...[
            const SizedBox(height: 10),
            _Notice(
              icon: Icons.event_busy_outlined,
              color: const Color(0xFFC0392B),
              text: 'This trip was cancelled. ${_trip.cancellationReason ?? ''}',
            ),
          ],
          const SizedBox(height: 14),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _Notice(
                icon: Icons.error_outline,
                color: scheme.error,
                text: _error!),
          ],
          const SizedBox(height: 18),

          // ---- the big buttons
          if (canStart)
            _BigAction(
              icon: Icons.play_arrow_rounded,
              label: 'Start trip',
              hint: 'Passengers will see the bus on the map',
              color: const Color(0xFF1E8E6A),
              busy: _busy == 'start',
              onPressed: _busy != null ? null : _start,
            ),
          if (canDelay) ...[
            const SizedBox(height: 10),
            _BigAction(
              icon: Icons.schedule,
              label: 'Report delay',
              hint: 'Tell passengers you will be late',
              color: const Color(0xFFB4741A),
              busy: _busy == 'delay',
              onPressed: _busy != null ? null : _delay,
            ),
          ],
          if (running) ...[
            _SharingCard(
              sharing: sharing,
              supported: widget.apiClient.supportsGps,
              error: _sharer.error,
              lastSentAt: _sharer.lastSentAt,
              onToggle: _busy != null
                  ? null
                  : () => sharing ? _sharer.stop() : _sharer.start(_trip.id),
            ),
            const SizedBox(height: 10),
            _BigAction(
              icon: Icons.groups_2_rounded,
              label: 'Bus nearly full',
              hint: 'Alert operations',
              color: const Color(0xFFB4741A),
              busy: _busy == 'full',
              onPressed: _busy != null ? null : _nearlyFull,
            ),
            const SizedBox(height: 10),
            _BigAction(
              icon: Icons.stop_rounded,
              label: 'End trip',
              hint: 'Finish when everyone has got off',
              color: const Color(0xFFC0392B),
              busy: _busy == 'end',
              onPressed: _busy != null ? null : _end,
            ),
          ],
          if (_trip.isTerminal)
            _Notice(
              icon: _trip.isCancelled ? Icons.event_busy_outlined : Icons.check_circle_outline,
              color: scheme.primary,
              text: _trip.isCancelled
                  ? 'Nothing to do for this trip.'
                  : 'This trip is finished. Well done!',
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _report,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Report a problem'),
          ),

          // ---- stops
          if (stops.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Stops', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (var i = 0; i < stops.length; i++)
              _StopRow(
                stop: stops[i],
                first: i == 0,
                last: i == stops.length - 1,
              ),
          ],
        ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(66),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Row(
          children: [
            busy
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: Colors.white))
                : Icon(icon, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(hint,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SharingCard extends StatelessWidget {
  const _SharingCard({
    required this.sharing,
    required this.supported,
    required this.error,
    required this.lastSentAt,
    required this.onToggle,
  });

  final bool sharing;
  final bool supported;
  final String? error;
  final DateTime? lastSentAt;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    const good = Color(0xFF1E8E6A);
    const warn = Color(0xFFB4741A);
    final color = !supported ? Colors.grey : (sharing && error == null ? good : warn);
    final title = !supported
        ? 'Live location needs real data'
        : sharing
            ? (error == null ? 'Sharing bus location' : 'Location problem')
            : 'Location is not being shared';
    final detail = !supported
        ? 'Sample data does not send GPS.'
        : sharing
            ? (error ??
                (lastSentAt == null
                    ? 'Getting the first position…'
                    : 'Updated every 5 seconds · last at ${_hhmmss(lastSentAt!)}'))
            : (error ?? 'Passengers cannot see where the bus is.');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(sharing ? Icons.my_location : Icons.location_disabled_outlined,
              color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w800, fontSize: 15.5)),
                Text(detail, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
          if (supported)
            TextButton(
              onPressed: onToggle,
              child: Text(sharing ? 'Stop' : 'Share'),
            ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.first, required this.last});

  final UwayRouteStop stop;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final campus = isCampusStopName(stop.name);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Expanded(
                    child: Container(
                        width: 3,
                        color: first ? Colors.transparent : color.withValues(alpha: 0.35))),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: campus ? color : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(campus ? Icons.school_rounded : Icons.hail_rounded,
                      size: 17, color: campus ? Colors.white : color),
                ),
                Expanded(
                    child: Container(
                        width: 3,
                        color: last ? Colors.transparent : color.withValues(alpha: 0.35))),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                stop.name,
                style: TextStyle(
                    fontWeight: campus ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: color))),
          ],
        ),
      );
}

class _DelayDialog extends StatefulWidget {
  const _DelayDialog();

  @override
  State<_DelayDialog> createState() => _DelayDialogState();
}

class _DelayDialogState extends State<_DelayDialog> {
  static const _minutes = [5, 10, 15, 30];
  static const _reasons = ['Traffic', 'Bus problem', 'Waiting for passengers', 'Road closed'];
  int _selected = 10;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Report a delay'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How late will you be?'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final m in _minutes)
                  ChoiceChip(
                    label: Text('$m min'),
                    selected: _selected == m,
                    onSelected: (_) => setState(() => _selected = m),
                  ),
              ]),
              const SizedBox(height: 16),
              const Text('Why?'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final r in _reasons)
                  ActionChip(label: Text(r), onPressed: () => setState(() => _reason.text = r)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                maxLength: 240,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: _reason.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, (minutes: _selected, reason: _reason.text.trim())),
            child: const Text('Send'),
          ),
        ],
      );
}

String _hhmm(DateTime utc) => _hm(utc.toLocal());

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _hhmmss(DateTime d) => '${_hm(d.toLocal())}:${d.second.toString().padLeft(2, '0')}';

String _dayText(DateTime utc) {
  final d = utc.toLocal();
  final now = DateTime.now();
  final diff = DateTime(d.year, d.month, d.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _message(Object error) => error is UwayApiException
    ? error.message
    : 'Could not reach the UWAY server. Check the connection and try again.';
