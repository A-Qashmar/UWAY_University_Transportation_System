import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uway_mobile/screens/passenger_home_screen.dart';
import 'package:uway_mobile/services/demo_uway_data_source.dart';
import 'package:uway_mobile/theme/uway_theme.dart';

void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: UwayTheme.passenger(),
      home: PassengerHomeScreen(
        apiClient: DemoUwayDataSource(role: 'Passenger'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Home lists the trip in progress first, with the actions',
      (tester) async {
    await pumpHome(tester);

    expect(find.text('Your trip in progress'), findsOneWidget);
    // Demo fixtures: the started trip carries a Medical College drop-off.
    expect(find.text('Drop-off: UOS - Medical College'), findsOneWidget);
    expect(find.text('Find a trip'), findsOneWidget);
    expect(find.text('Lost something?'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsOneWidget);
  });

  testWidgets('Find a trip opens the Trips tab', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Find a trip'));
    await tester.pumpAndSettle();
    expect(find.text('Find your trip'), findsOneWidget);
  });

  testWidgets('the bell opens the notifications panel', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byWidgetPredicate((widget) =>
        widget is IconButton &&
        (widget.tooltip ?? '').startsWith('Notifications')));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Trip delayed'), findsOneWidget);

    await tester.tap(find.byTooltip('Close notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Trip delayed'), findsNothing);
  });

  testWidgets('Lost something opens the report form', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Lost something?'));
    await tester.pumpAndSettle();
    expect(find.text('Send a report'), findsOneWidget);
    expect(find.text('Lost item'), findsOneWidget);
  });
}
