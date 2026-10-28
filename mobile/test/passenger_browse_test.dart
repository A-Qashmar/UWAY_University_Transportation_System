import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uway_mobile/models/trip_filter.dart';
import 'package:uway_mobile/screens/passenger_home_screen.dart';
import 'package:uway_mobile/screens/passenger_trips_screen.dart';
import 'package:uway_mobile/services/demo_uway_data_source.dart';
import 'package:uway_mobile/theme/uway_theme.dart';
import 'package:uway_mobile/widgets/trip_card.dart';

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpTrips(WidgetTester tester, DemoUwayDataSource source) async {
  await tester.pumpWidget(MaterialApp(
    theme: UwayTheme.passenger(),
    home: Scaffold(body: PassengerTripsScreen(apiClient: source)),
  ));
  await tester.pumpAndSettle();
}

bool _searchEnabled(WidgetTester tester) {
  final button = tester.widget<ButtonStyleButton>(
    find.byWidgetPredicate((widget) => widget is FilledButton),
  );
  return button.onPressed != null;
}

void main() {
  testWidgets('Trips is search-first: choose a route, then press Search',
      (tester) async {
    _tallScreen(tester);
    final source = DemoUwayDataSource(role: 'Passenger');
    await _pumpTrips(tester, source);

    // Nothing is listed and Search is disabled until a route is chosen.
    expect(find.text('Where are you headed?'), findsOneWidget);
    expect(find.byType(TripCard), findsNothing);
    expect(_searchEnabled(tester), isFalse);

    await tester.tap(find.text('Choose a route'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('King Faisal Line → University City'));
    await tester.pumpAndSettle();
    expect(_searchEnabled(tester), isTrue);
    expect(find.byType(TripCard), findsNothing);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(TripCard), findsNWidgets(3));
    expect(find.text('3 trips'), findsOneWidget);
    expect(find.text('Bus DEMO-BUS-01'), findsOneWidget);
  });

  testWidgets('departure time narrows the search and must be searched again',
      (tester) async {
    _tallScreen(tester);
    final source = DemoUwayDataSource(role: 'Passenger');
    final trips = await source.getTrips();
    final delayed = trips.firstWhere((trip) => trip.delayMinutes > 0);
    await _pumpTrips(tester, source);

    await tester.tap(find.text('Choose a route'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('King Faisal Line → University City'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(TripCard), findsNWidgets(3));

    await tester.tap(find.text(formatMinutes(tripMinutes(delayed))));
    await tester.pumpAndSettle();
    // Changing a criterion clears the results until Search is pressed again.
    expect(find.byType(TripCard), findsNothing);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(TripCard), findsOneWidget);
    expect(find.text('1 trip'), findsOneWidget);
    // A delay is an alert on the card, not a status.
    expect(find.text('Delayed 8 mins'), findsOneWidget);
  });

  testWidgets('direction limits the routes that can be chosen',
      (tester) async {
    _tallScreen(tester);
    final source = DemoUwayDataSource(role: 'Passenger');
    await _pumpTrips(tester, source);

    await tester.tap(find.text('From campus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a route'));
    await tester.pumpAndSettle();
    expect(find.text('University City → King Faisal Line'), findsOneWidget);
    expect(find.text('King Faisal Line → University City'), findsNothing);
    expect(find.text('Al Heera Line → University City'), findsNothing);
    await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
    await tester.pumpAndSettle();

    await tester.tap(find.text('To campus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a route'));
    await tester.pumpAndSettle();
    expect(find.text('King Faisal Line → University City'), findsOneWidget);
    expect(find.text('Al Heera Line → University City'), findsOneWidget);
    expect(find.text('University City → King Faisal Line'), findsNothing);
  });

  testWidgets('switching tabs and returning from details does not throw',
      (tester) async {
    _tallScreen(tester);
    final source = DemoUwayDataSource(role: 'Passenger');
    await tester.pumpWidget(MaterialApp(
      theme: UwayTheme.passenger(),
      home: PassengerHomeScreen(apiClient: source),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Trips'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Drop-off: UOS - Medical College'), findsOneWidget);

    await tester.tap(find.text('Drop-off: UOS - Medical College'));
    await tester.pumpAndSettle();
    expect(find.text('Trip details'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Drop-off: UOS - Medical College'), findsOneWidget);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
