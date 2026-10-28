import 'package:flutter_test/flutter_test.dart';
import 'package:uway_mobile/main.dart';

Future<void> openDeveloperEntry(WidgetTester tester) async {
  await tester.pumpWidget(const UwayApp());
  await tester.tap(find.text('Developer mode (sample data)'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts in explicit development data-mode selection',
      (tester) async {
    await openDeveloperEntry(tester);

    expect(find.text('UWAY development entry'), findsOneWidget);
    expect(find.text('Demo Data'), findsOneWidget);
    expect(find.text('API Data'), findsOneWidget);
    expect(
        find.text(
            'This selector is for local project testing. It is not an account sign-in.'),
        findsOneWidget);
  });

  testWidgets('Demo Data opens the sample Passenger app', (tester) async {
    await openDeveloperEntry(tester);
    await tester.tap(find.text('Continue to mobile app'));
    await tester.pumpAndSettle();

    expect(find.text('DEMO DATA · Sample only · Not connected to the API'),
        findsOneWidget);
    // The trip in progress on Home carries the real route name.
    expect(find.text('King Faisal Line → University City'), findsWidgets);
  });

  testWidgets('a Passenger session can be started as a man or a woman',
      (tester) async {
    await openDeveloperEntry(tester);
    expect(find.text('Passenger is'), findsOneWidget);
    expect(find.text('Man'), findsOneWidget);
    expect(find.text('Woman'), findsOneWidget);

    await tester.tap(find.text('Driver'));
    await tester.pump();
    expect(find.text('Passenger is'), findsNothing);

    await tester.tap(find.text('Passenger'));
    await tester.pump();
    await tester.tap(find.text('Woman'));
    await tester.pump();
    await tester.tap(find.text('Continue to mobile app'));
    await tester.pumpAndSettle();
    // The women's demo trips include a Heerah morning trip but no in-progress
    // trip, so Home has no ongoing-trip card.
    expect(find.text('Your trip in progress'), findsNothing);
  });
}
