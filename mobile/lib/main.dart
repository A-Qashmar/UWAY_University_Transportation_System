import 'package:flutter/material.dart';

void main() => runApp(const UwayApp());

class UwayApp extends StatelessWidget {
  const UwayApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'UWAY',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF166B68), useMaterial3: true),
        home: const RoleLandingPage(),
      );
}

class RoleLandingPage extends StatelessWidget {
  const RoleLandingPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('UWAY')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('University Transportation System', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  const Text('Choose an app area to continue.'),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: () => _showArea(context, 'Passenger'), child: const Text('Passenger')),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () => _showArea(context, 'Driver'), child: const Text('Driver')),
                ],
              ),
            ),
          ),
        ),
      );

  void _showArea(BuildContext context, String area) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AreaPlaceholder(area: area)));
  }
}

class AreaPlaceholder extends StatelessWidget {
  const AreaPlaceholder({required this.area, super.key});
  final String area;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('$area area')),
        body: Center(child: Text('$area app structure is ready for Phase 3.')),
      );
}
