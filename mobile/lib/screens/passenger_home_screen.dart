import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/passenger_models.dart';
import '../services/route_names.dart';
import '../services/uway_data_source.dart';
import '../theme/uway_theme.dart';
import '../widgets/trip_card.dart';
import 'passenger_my_trips_screen.dart';
import '../widgets/notification_bell.dart';
import 'passenger_notifications_screen.dart';
import 'passenger_reports_screen.dart';
import 'passenger_trips_screen.dart';
import 'trip_details_screen.dart';

/// Tab to open the next time the Passenger home is created. Changing the look
/// rebuilds the app, and this keeps the passenger on the Account tab.
int _resumeTab = 0;

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({
    required this.apiClient,
    this.accountLabel,
    this.onSignOut,
    super.key,
  });

  final UwayDataSource apiClient;

  /// Name and email of the signed-in person, shown under Account.
  final String? accountLabel;
  final VoidCallback? onSignOut;

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = _resumeTab;
  int _homeRefresh = 0;
  int _myTripsRefresh = 0;

  @override
  void initState() {
    super.initState();
    _resumeTab = 0;
  }

  void _select(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) _homeRefresh++;
      if (index == 2) _myTripsRefresh++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _PassengerHomePage(
        apiClient: widget.apiClient,
        refreshToken: _homeRefresh,
        onFindTrip: () => _select(1),
        userName: widget.accountLabel?.split('\n').first,
      ),
      PassengerTripsScreen(apiClient: widget.apiClient),
      PassengerMyTripsScreen(
        apiClient: widget.apiClient,
        refreshToken: _myTripsRefresh,
      ),
      _PassengerAccountPage(
        apiClient: widget.apiClient,
        accountLabel: widget.accountLabel,
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/uway-mark.png', height: 32),
            const SizedBox(width: 10),
            Text(
              'UWAY',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: UwayColors.gold),
            ),
            child: Text(
              widget.apiClient.isDemoData ? 'DEMO DATA' : 'LOCAL API',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: UwayColors.gold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
            ),
          ),
          NotificationBell(
            apiClient: widget.apiClient,
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      endDrawerEnableOpenDragGesture: false,
      endDrawer: Drawer(
        width: math.min(MediaQuery.sizeOf(context).width * 0.92, 400),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close notifications',
                      icon: const Icon(Icons.close),
                      onPressed: () => _scaffoldKey.currentState?.closeEndDrawer(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: PassengerNotificationsScreen(apiClient: widget.apiClient),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number),
            label: 'My Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class _OngoingTrip {
  const _OngoingTrip(this.trip, this.intent, this.routeName);
  final UwayTrip trip;
  final PassengerTripIntent intent;
  final String? routeName;
}

/// Home: the passenger's trip in progress first (when there is one), a short
/// introduction, and the main actions.
class _PassengerHomePage extends StatefulWidget {
  const _PassengerHomePage({
    required this.apiClient,
    required this.refreshToken,
    required this.onFindTrip,
    this.userName,
  });

  final UwayDataSource apiClient;
  final int refreshToken;
  final VoidCallback onFindTrip;
  final String? userName;

  @override
  State<_PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<_PassengerHomePage> {
  late Future<List<_OngoingTrip>> _ongoing;

  @override
  void initState() {
    super.initState();
    _ongoing = _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 20), (_) => _silentRefresh());
  }

  Timer? _autoRefresh;

  /// Reloads quietly in the background so new trips and changes appear by themselves.
  Future<void> _silentRefresh() async {
    try {
      final next = _load();
      await next;
      if (mounted) setState(() => _ongoing = next);
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
  void didUpdateWidget(covariant _PassengerHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _ongoing = _load();
    }
  }

  Future<List<_OngoingTrip>> _load() async {
    final trips = await widget.apiClient.getTrips();
    final active = trips.where((trip) => trip.isInProgress).toList();
    final withIntent = <(UwayTrip, PassengerTripIntent)>[];
    for (final trip in active) {
      final intent = await widget.apiClient.getMyIntent(trip.id);
      if (intent != null) withIntent.add((trip, intent));
    }
    final names = await loadRouteNames(
      widget.apiClient,
      withIntent.map((item) => item.$1.routeId),
    );
    return [
      for (final item in withIntent)
        _OngoingTrip(item.$1, item.$2, names[item.$1.routeId]),
    ];
  }

  void _retry() {
    final next = _load();
    setState(() {
      _ongoing = next;
    });
  }

  Future<void> _openReport() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReportFormScreen(apiClient: widget.apiClient),
      ),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Thank you. Your report was sent. You can follow it under Account, My reports.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Greeting(userName: widget.userName),
        FutureBuilder<List<_OngoingTrip>>(
          future: _ongoing,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const SizedBox.shrink();
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your trip in progress could not be checked.',
                        style: TextStyle(color: muted),
                      ),
                    ),
                    TextButton(onPressed: _retry, child: const Text('Retry')),
                  ],
                ),
              );
            }
            final items = snapshot.data ?? const <_OngoingTrip>[];
            if (items.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your trip in progress',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
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
                          .then((_) {
                        if (mounted) _retry();
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            );
          },
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [UwayColors.purple, UwayColors.purpleDark],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your university ride, made simple',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Find a university bus trip, tell the driver where you will get off, and follow the bus on the map.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: widget.onFindTrip,
                style: FilledButton.styleFrom(
                  backgroundColor: UwayColors.gold,
                  foregroundColor: UwayColors.onGold,
                ),
                icon: const Icon(Icons.search),
                label: const Text('Find a trip'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: const Icon(Icons.search_off_outlined,
                color: UwayColors.gold),
            title: const Text('Lost something?'),
            subtitle: const Text('Submit a report'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openReport,
          ),
        ),
      ],
    );
  }
}

class _PassengerAccountPage extends StatelessWidget {
  const _PassengerAccountPage({
    required this.apiClient,
    this.accountLabel,
    this.onSignOut,
  });

  final UwayDataSource apiClient;
  final String? accountLabel;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Account and settings',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (accountLabel != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined, size: 36),
                title: Text(accountLabel!.split('\n').first),
                subtitle: Text(accountLabel!.split('\n').skip(1).join('\n')),
              ),
            ),
          const SizedBox(height: 18),
          Card(
            child: ValueListenableBuilder<bool>(
              valueListenable: uwayPurpleMode,
              builder: (context, purpleMode, _) => SwitchListTile(
                secondary: const Icon(Icons.palette_outlined),
                title: const Text('Purple mode'),
                subtitle: const Text(
                    'Purple becomes the main colour and cream the accent. Resets when the app restarts.'),
                value: purpleMode,
                onChanged: (value) {
                  _resumeTab = 3;
                  uwayPurpleMode.value = value;
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Role'),
                    subtitle: Text(apiClient.role)),
                const Divider(height: 1),
                ListTile(
                    leading: const Icon(Icons.dns_outlined),
                    title: const Text('API address'),
                    subtitle: Text(apiClient.baseUrl)),
                const Divider(height: 1),
                ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(apiClient.isDemoData
                        ? 'Sample session'
                        : 'Signed in'),
                    subtitle: Text(apiClient.isDemoData
                        ? 'This session uses in-memory sample data and does not sign in.'
                        : 'Your session is protected with your UWAY account.')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: const Text('Report a problem'),
                  subtitle: const Text('Lost items, trip or driver issues'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => ReportFormScreen(
                        apiClient: apiClient,
                        initialCategory: 'TripProblem',
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.inbox_outlined),
                  title: const Text('My reports'),
                  subtitle: const Text('Status and replies from the team'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => MyReportsScreen(apiClient: apiClient),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onSignOut != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ],
      );
}

String apiClientLabel(UwayDataSource source) =>
    source.isDemoData ? 'PASSENGER · DEMO DATA' : 'PASSENGER · LOCAL API';


/// "Good morning, Mariam" - the greeting follows the time of day.
class _Greeting extends StatelessWidget {
  const _Greeting({this.userName});

  final String? userName;

  static String greetingFor(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final first = userName?.trim().split(RegExp(r'\s+')).first;
    final text = first == null || first.isEmpty
        ? greetingFor(DateTime.now())
        : '${greetingFor(DateTime.now())}, $first';
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 16),
      child: Row(
        children: [
          Icon(
            DateTime.now().hour < 18
                ? Icons.wb_sunny_outlined
                : Icons.nights_stay_outlined,
            color: UwayColors.gold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
