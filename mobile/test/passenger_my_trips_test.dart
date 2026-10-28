import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uway_mobile/data/demo_fixtures.dart';
import 'package:uway_mobile/screens/passenger_home_screen.dart';
import 'package:uway_mobile/screens/passenger_my_trips_screen.dart';
import 'package:uway_mobile/services/demo_uway_data_source.dart';

void main() {
  testWidgets('Your Trips lists only trips with an active Trip Intent',
      (tester) async {
    final source = DemoUwayDataSource(role: 'Passenger');
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PassengerMyTripsScreen(apiClient: source))),
    );
    await tester.pumpAndSettle();

    // Demo fixtures: two trips carry an active intent.
    expect(find.text('King Faisal Line → University City'), findsNWidgets(2));
    expect(find.text('Drop-off: UOS - M3'), findsOneWidget);
    expect(find.text('Drop-off: UOS - Medical College'), findsOneWidget);
  });

  testWidgets('Your Trips shows an empty state after the intents are cancelled',
      (tester) async {
    final source = DemoUwayDataSource(role: 'Passenger');
    await source.cancelIntent(DemoFixtures.activeIntentTripId);
    await source.cancelIntent(DemoFixtures.secondIntentTripId);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PassengerMyTripsScreen(apiClient: source))),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active trip intents'), findsOneWidget);
    expect(find.text('King Faisal Line → University City'), findsNothing);
  });

  testWidgets('Passenger home separates Trips from My Trips',
      (tester) async {
    final source = DemoUwayDataSource(role: 'Passenger');
    await tester.pumpWidget(
      MaterialApp(home: PassengerHomeScreen(apiClient: source)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('My Trips'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    // Home is the first tab and offers the way into the search.
    expect(find.text('Find a trip'), findsOneWidget);
  });
}
