import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uway_mobile/models/passenger_models.dart';
import 'package:uway_mobile/screens/drop_off_picker_screen.dart';

void main() {
  testWidgets('picker returns the chosen point and needs a choice first',
      (tester) async {
    const options = [
      UwayRouteStop(id: 1, name: 'UOS - M3', order: 1),
      UwayRouteStop(id: 2, name: 'UOS - W3', order: 2),
    ];
    int? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<int>(
                MaterialPageRoute<int>(
                  builder: (_) => const DropOffPickerScreen(
                    title: 'Where on campus will you get off?',
                    options: options,
                    routeStops: options,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Map locations are not available'),
        findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, 'Confirm drop-off');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.text('UOS - W3'));
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(result, 2);
  });
}
