import 'dart:async';

import 'package:flutter/material.dart';

import '../models/passenger_models.dart';
import '../services/location_sharer.dart';
import '../theme/uway_theme.dart';
import '../services/uway_data_source.dart';
import '../widgets/notification_bell.dart';
import 'driver_trip_screen.dart';
import 'passenger_notifications_screen.dart';
import 'passenger_reports_screen.dart';

/// The driver's app: My trips, My reports and Account. Everything a driver
/// needs on a trip is one tap away, with large buttons and plain wording.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    required this.apiClient,
    this.accountLabel,
    this.onSignOut,
    super.key,
  });

  final UwayDataSource apiClient;
  final String? accountLabel;
  final VoidCallback? onSignOut;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

/// Keeps the open tab when the app rebuilds to change the look.
int _driverResumeTab = 0;

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  List<UwayTrip> _trips = const [];
  bool _loading = true;
  String? _error;
  int _selectedIndex = _driverResumeTab;
  bool _showHistory = false;
  Timer? _autoRefresh;
  late final LocationSharer _sharer = LocationSharer(apiClient: widget.apiClient);

  String? get _name => widget.accountLabel?.split('\n').first;

  @override
  void initState() {
    super.initState();
    _driverResumeTab = 0;
    _load();
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _sharer.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final trips = await widget.apiClient.getAssignedTrips();
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _error = null;
      });
      // A trip that ended or was cancelled elsewhere must not keep sending GPS.
      final sharing = _sharer.sharingTripId;
      if (sharing != null &&
          !trips.any((trip) => trip.id == sharing && trip.isStarted)) {
        _sharer.stop();
      }
    } on Object catch (error) {
      if (!mounted || silent) return;
      setState(() => _error = _message(error));
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _openTrip(UwayTrip trip) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DriverTripScreen(
          apiClient: widget.apiClient,
          trip: trip,
          sharer: _sharer,
        ),
      ),
    );
    if (mounted) await _load(silent: true);
  }

  void _openNotifications() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Notifications')),
          body: PassengerNotificationsScreen(apiClient: widget.apiClient),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/uway-mark.png', height: 32),
              const SizedBox(width: 10),
              const Text(
                'UWAY',
                style: TextStyle(
                  color: UwayColors.gold,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          actions: [
            NotificationBell(
              apiClient: widget.apiClient,
              onPressed: _openNotifications,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _tripsTab(),
            MyReportsScreen(apiClient: widget.apiClient, embedded: true),
            _accountTab(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route),
              label: 'My trips',
            ),
            NavigationDestination(
              icon: Icon(Icons.support_agent_outlined),
              selectedIcon: Icon(Icons.support_agent),
              label: 'My reports',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Account',
            ),
          ],
        ),
      );

  // ---------------------------------------------------------------- trips

  Widget _tripsTab() {
    final active = _trips.where((t) => t.isStarted && !t.isCancelled).toList();
    final upcoming = _trips
        .where((t) => t.status == 'Scheduled' && !t.isCancelled)
        .toList()
      ..sort((a, b) => a.departureAtUtc.compareTo(b.departureAtUtc));
    final history = _trips
        .where((t) => t.isTerminal)
        .toList()
      ..sort((a, b) => b.departureAtUtc.compareTo(a.departureAtUtc));
    final first = _name?.trim().split(RegExp(r'\s+')).first;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            first == null || first.isEmpty
                ? _greeting()
                : '${_greeting()}, $first',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            active.isNotEmpty
                ? 'You have a trip in progress.'
                : upcoming.isEmpty
                    ? 'No trips are waiting for you right now.'
                    : 'Tap a trip to open it.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (_error != null)
            _InfoPanel(
              icon: Icons.cloud_off_outlined,
              message: _error!,
              actionLabel: 'Try again',
              onAction: _load,
            ),
          if (_loading && _trips.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (active.isNotEmpty) ...[
            const _SectionLabel('In progress'),
            for (final trip in active) _tripCard(trip, highlight: true),
          ],
          if (upcoming.isNotEmpty) ...[
            const _SectionLabel('Upcoming'),
            for (final trip in upcoming) _tripCard(trip),
          ],
          if (!_loading &&
              _error == null &&
              active.isEmpty &&
              upcoming.isEmpty)
            const _InfoPanel(
              icon: Icons.directions_bus_outlined,
              message:
                  'No trips yet. When the admin assigns you a trip it appears here by itself.',
            ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _showHistory = !_showHistory),
              icon: Icon(_showHistory ? Icons.expand_less : Icons.history),
              label: Text(_showHistory
                  ? 'Hide past trips'
                  : 'Past trips (${history.length})'),
            ),
            if (_showHistory)
              for (final trip in history) _tripCard(trip, compact: true),
          ],
        ],
      ),
    );
  }

  Widget _tripCard(UwayTrip trip,
      {bool highlight = false, bool compact = false}) {
    final scheme = Theme.of(context).colorScheme;
    final time = _hhmm(trip.departureAtUtc);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        // A calm white card; the status is carried by the coloured outline and pill.
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: driverStatusStyle(trip).color.withValues(alpha: highlight ? 0.9 : 0.35),
            width: highlight ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openTrip(trip),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      time,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 10),
                    Text(_dayText(trip.departureAtUtc),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const Spacer(),
                    DriverStatusPill(trip: trip),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  trip.displayName,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (trip.busNumber != null)
                      _Tag(Icons.directions_bus_outlined, trip.busNumber!),
                    if (trip.joinedCount != null && !trip.isTerminal)
                      _Tag(Icons.groups_2_outlined,
                          '${trip.joinedCount} joined'),
                    if (trip.audience != null)
                      _Tag(
                        trip.audience == 'F' ? Icons.woman : Icons.man,
                        trip.audience == 'F' ? 'Women' : 'Men',
                      ),
                  ],
                ),
                if (trip.isDelayed && !trip.isTerminal) ...[
                  const SizedBox(height: 8),
                  _Banner(
                    icon: Icons.schedule,
                    color: const Color(0xFFB4741A),
                    text: 'Delayed ${trip.delayMinutes} min · ${trip.delayReason ?? ''}',
                  ),
                ],
                if (trip.isCancelled) ...[
                  const SizedBox(height: 8),
                  _Banner(
                    icon: Icons.event_busy_outlined,
                    color: const Color(0xFFC0392B),
                    text: 'Cancelled · ${trip.cancellationReason ?? ''}',
                  ),
                ],
                if (!compact && !trip.isTerminal) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.touch_app_outlined,
                          size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        trip.isStarted ? 'Open to manage the trip' : 'Open trip',
                        style: TextStyle(
                            color: scheme.primary, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: scheme.primary),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- account

  Widget _accountTab() {
    final label = widget.accountLabel?.split('\n') ?? const <String>[];
    final done = _trips.where((t) => t.isFinished).length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.badge_outlined, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.isNotEmpty
                            ? label.first
                            : (widget.apiClient.isDemoData
                                ? 'Sample driver'
                                : 'Driver'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (label.length > 1) Text(label[1]),
                      const SizedBox(height: 2),
                      const Text('Driver account'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ValueListenableBuilder<bool>(
            valueListenable: uwayDriverInverted,
            builder: (context, inverted, _) {
              final tripRunning = _sharer.sharingTripId != null ||
                  _trips.any((t) => t.isStarted && !t.isCancelled);
              return SwitchListTile(
                secondary: const Icon(Icons.contrast),
                title: const Text('Invert colours'),
                subtitle: Text(tripRunning
                    ? 'Finish your running trip first, then you can change the look.'
                    : 'Dark green with cream, easier on the eyes at night.'),
                value: inverted,
                onChanged: tripRunning
                    ? null
                    : (value) {
                        _driverResumeTab = 2;
                        uwayDriverInverted.value = value;
                      },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Trips completed'),
                trailing: Text('$done',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Server'),
                subtitle: Text(widget.apiClient.baseUrl),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(
                    widget.apiClient.isDemoData ? 'Sample session' : 'Signed in'),
                subtitle: Text(widget.apiClient.isDemoData
                    ? 'Sample data only. Nothing is sent to the server.'
                    : 'Your account is protected with your password.'),
              ),
            ],
          ),
        ),
        if (widget.onSignOut != null) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: widget.onSignOut,
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ pieces

/// The trip status as a coloured pill: Scheduled (blue), Started (green),
/// Finished (grey), Cancelled (red); a delay is added in amber.
/// Label, colour and icon for a trip's status: scheduled blue, in progress
/// green, finished grey, cancelled red.
({String label, Color color, IconData icon}) driverStatusStyle(UwayTrip trip) =>
    trip.isCancelled
        ? (label: 'Cancelled', color: const Color(0xFFC0392B), icon: Icons.cancel_outlined)
        : switch (trip.status) {
            'Started' => (label: 'In progress', color: const Color(0xFF1E8E6A), icon: Icons.play_circle_outline),
            'Finished' => (label: 'Finished', color: const Color(0xFF5D6B6C), icon: Icons.check_circle_outline),
            _ => (label: 'Scheduled', color: const Color(0xFF2F5DA8), icon: Icons.schedule),
          };

class DriverStatusPill extends StatelessWidget {
  const DriverStatusPill({required this.trip, super.key});

  final UwayTrip trip;

  @override
  Widget build(BuildContext context) {
    final (:label, :color, :icon) = driverStatusStyle(trip);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color, width: 1.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(color: color))),
          ],
        ),
      );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _dayText(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _message(Object error) => error is UwayApiException
    ? error.message
    : 'Could not reach the UWAY server. Check the connection and try again.';
