import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/driver_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/passenger_home_screen.dart';
import 'services/api_configuration.dart';
import 'services/auth_service.dart';
import 'services/demo_uway_data_source.dart';
import 'services/uway_api_client.dart';
import 'services/uway_data_source.dart';
import 'theme/uway_theme.dart';

void main() => runApp(const UwayApp());

class UwayApp extends StatefulWidget {
  const UwayApp({this.authService, super.key});

  /// Injected in tests; the app creates its own otherwise.
  final UwayAuthService? authService;

  @override
  State<UwayApp> createState() => _UwayAppState();
}

class _UwayAppState extends State<UwayApp> {
  UwayDataSource? _dataSource;
  UwaySession? _session;
  bool _developerEntry = false;
  late final UwayAuthService _authService =
      widget.authService ?? UwayAuthService();

  void _signedIn(UwaySession session) => setState(() {
        _session = session;
        _dataSource = UwayApiClient(configuration: session.configuration);
      });

  void _signOut() {
    _dataSource?.close();
    setState(() {
      _dataSource = null;
      _session = null;
      _developerEntry = false;
    });
  }

  String? get _accountLabel => _session == null
      ? null
      : '${_session!.fullName}\n${_session!.email}';

  void _launch({
    required String role,
    required bool demoData,
    required int driverId,
    required String gender,
  }) {
    final source = demoData
        ? DemoUwayDataSource(
            role: role,
            driverId: driverId,
            passengerGender: gender,
          )
        : UwayApiClient(
            configuration: ApiConfiguration.forDevelopment(
              role: role,
              driverId: driverId,
              // Local test profiles created by the gender migration.
              passengerId: gender == 'F' ? 'test-female-1' : 'test-male-1',
            ),
          );
    setState(() => _dataSource = source);
  }

  @override
  void dispose() {
    _dataSource?.close();
    super.dispose();
  }

  ThemeData _defaultTheme() => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF176B67),
      surface: const Color(0xFFF6F8F7),
    ),
    scaffoldBackgroundColor: const Color(0xFFF6F8F7),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF6F8F7),
      foregroundColor: Color(0xFF173A40),
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1E8E5)),
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: Color(0xFFE1E8E5)),
      ),
    ),
  );

  Widget _home() {
    final source = _dataSource;
    if (source == null) {
      if (kDebugMode && _developerEntry) {
        return _DevelopmentEntryScreen(
          onContinue: _launch,
          onBack: () => setState(() => _developerEntry = false),
        );
      }
      return LoginScreen(
        authService: _authService,
        onSignedIn: _signedIn,
        onDevelopmentMode:
            kDebugMode ? () => setState(() => _developerEntry = true) : null,
      );
    }
    final onSignOut = _signOut;
    if (source.role == 'Driver') {
      return DriverHomeScreen(
        apiClient: source,
        accountLabel: _accountLabel,
        onSignOut: onSignOut,
      );
    }
    if (source.role == 'Admin') {
      return _AdminUsesWebDashboard(onSignOut: onSignOut);
    }
    return PassengerHomeScreen(
      apiClient: source,
      accountLabel: _accountLabel,
      onSignOut: onSignOut,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([uwayPurpleMode, uwayDriverInverted]),
        builder: (context, _) =>
            _app(uwayPurpleMode.value, uwayDriverInverted.value),
      );

  // The key rebuilds the app when the look changes. Updating the theme in
  // place made Flutter reuse Material ink layers in a new position, which
  // threw a duplicate GlobalKey error.
  Widget _app(bool purpleMode, bool driverInverted) => MaterialApp(
        key: ValueKey<String>('$purpleMode-$driverInverted'),
        // No theme animation: lerping between the default and the Passenger
        // theme throws "different inherit values" for the button text style.
        themeAnimationDuration: Duration.zero,
        title: 'UWAY',
        theme: switch (_dataSource?.role) {
          'Passenger' => UwayTheme.passenger(purpleMode: purpleMode),
          'Driver' => UwayTheme.driver(inverted: driverInverted),
          _ => _defaultTheme(),
        },
        builder: (context, child) {
          final current = _dataSource;
          if (current?.isDemoData != true) return child ?? const SizedBox();
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFF3D98A),
                child: const SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      'DEMO DATA · Sample only · Not connected to the API',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B2F00),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: child ?? const SizedBox(),
                ),
              ),
            ],
          );
        },
        home: _home(),
      );
}

class _DevelopmentEntryScreen extends StatefulWidget {
  const _DevelopmentEntryScreen({required this.onContinue, this.onBack});

  final VoidCallback? onBack;

  final void Function({
    required String role,
    required bool demoData,
    required int driverId,
    required String gender,
  }) onContinue;

  @override
  State<_DevelopmentEntryScreen> createState() =>
      _DevelopmentEntryScreenState();
}

class _DevelopmentEntryScreenState extends State<_DevelopmentEntryScreen> {
  String _role = 'Passenger';
  bool _demoData = true;
  String _gender = 'M';
  late final TextEditingController _driverIdController;

  @override
  void initState() {
    super.initState();
    final configured = ApiConfiguration.forDevelopment(
      role: 'Driver',
      driverId: 0,
    );
    _driverIdController = TextEditingController(text: '${configured.driverId}');
  }

  @override
  void dispose() {
    _driverIdController.dispose();
    super.dispose();
  }

  void _continue() {
    final parsedDriverId = int.tryParse(_driverIdController.text.trim()) ?? 0;
    widget.onContinue(
      role: _role,
      demoData: _demoData,
      driverId: parsedDriverId,
      gender: _gender,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('UWAY development entry'),
          leading: widget.onBack == null
              ? null
              : BackButton(onPressed: widget.onBack),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Choose a development session',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'This selector is for local project testing. It is not an account sign-in.',
            ),
            const SizedBox(height: 22),
            Text('Mobile role', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Passenger',
                  label: Text('Passenger'),
                  icon: Icon(Icons.person_outline),
                ),
                ButtonSegment(
                  value: 'Driver',
                  label: Text('Driver'),
                  icon: Icon(Icons.directions_bus_outlined),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (selection) =>
                  setState(() => _role = selection.first),
            ),
            if (_role == 'Passenger') ...[
              const SizedBox(height: 18),
              Text('Passenger is',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'M',
                    label: Text('Man'),
                    icon: Icon(Icons.man),
                  ),
                  ButtonSegment(
                    value: 'F',
                    label: Text('Woman'),
                    icon: Icon(Icons.woman),
                  ),
                ],
                selected: {_gender},
                onSelectionChanged: (selection) =>
                    setState(() => _gender = selection.first),
              ),
              const SizedBox(height: 6),
              const Text(
                'Passengers only see trips for their own gender. Real sign-in will read this from the passenger profile.',
              ),
            ],
            if (_role == 'Driver') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _driverIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Driver ID for API Data mode',
                  helperText: 'Demo Data uses the sample driver identity.',
                ),
              ),
            ],
            const SizedBox(height: 22),
            Text('Data source', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Demo Data')),
                ButtonSegment(value: false, label: Text('API Data')),
              ],
              selected: {_demoData},
              onSelectionChanged: (selection) =>
                  setState(() => _demoData = selection.first),
            ),
            const SizedBox(height: 8),
            Text(
              _demoData
                  ? 'Uses local sample fixtures; no API or database is contacted.'
                  : 'Uses ${ApiConfiguration.forDevelopment(role: _role, driverId: 0).baseUrl} and the local Development header mechanism.',
            ),
            if (!_demoData)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'API Data mode requires the Development API and its local header authentication. Requests will show API errors; the app will not substitute sample data.',
                  ),
                ),
              ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _continue,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continue to mobile app'),
            ),
            const SizedBox(height: 14),
            const Card(
              child: ListTile(
                leading: Icon(Icons.admin_panel_settings_outlined),
                title: Text('Admin dashboard'),
                subtitle: Text(
                  'Admin is a separate React web app and is not part of this Flutter mobile entry.',
                ),
              ),
            ),
          ],
        ),
      );
}

class _AdminUsesWebDashboard extends StatelessWidget {
  const _AdminUsesWebDashboard({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Administrators use the web dashboard.\nPlease sign in there.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: onSignOut,
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      );
}
