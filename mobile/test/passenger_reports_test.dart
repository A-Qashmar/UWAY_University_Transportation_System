import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uway_mobile/screens/passenger_reports_screen.dart';
import 'package:uway_mobile/services/demo_uway_data_source.dart';

void main() {
  testWidgets('a report needs a description and then appears in My reports',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final source = DemoUwayDataSource(role: 'Passenger');

    await tester.pumpWidget(MaterialApp(
      home: MyReportsScreen(apiClient: source),
    ));
    await tester.pumpAndSettle();
    // The demo has one resolved sample report with a reply.
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('Reply from the team'), findsOneWidget);

    await tester.tap(find.text('New report'));
    await tester.pumpAndSettle();
    final send = find.widgetWithText(FilledButton, 'Send report');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'I left my laptop bag on the bus.');
    await tester.pump();
    expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(find.text('Thank you. Your report was sent.'), findsOneWidget);
    expect(find.text('I left my laptop bag on the bus.'), findsOneWidget);
    expect((await source.getMyReports()).length, 2);
  });
}
