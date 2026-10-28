import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uway_mobile/main.dart';
import 'package:uway_mobile/theme/uway_theme.dart';

void main() {
  testWidgets('Passenger session uses the UWAY cream, purple and gold theme',
      (tester) async {
    await tester.pumpWidget(const UwayApp());
    await tester.tap(find.text('Developer mode (sample data)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to mobile app'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(NavigationBar));
    final scheme = Theme.of(context).colorScheme;
    expect(scheme.brightness, Brightness.light);
    expect(scheme.primary, UwayColors.purple);
    expect(scheme.secondary, UwayColors.gold);
    expect(Theme.of(context).scaffoldBackgroundColor, UwayColors.background);
  });

  testWidgets('development entry keeps the existing light theme',
      (tester) async {
    await tester.pumpWidget(const UwayApp());
    await tester.tap(find.text('Developer mode (sample data)'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).colorScheme.brightness, Brightness.light);
    expect(Theme.of(context).scaffoldBackgroundColor,
        isNot(UwayColors.background));
  });

  test('purple mode makes purple dominant and cream the accent', () {
    final theme = UwayTheme.passenger(purpleMode: true);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, UwayColors.cream);
    expect(theme.scaffoldBackgroundColor, UwayColors.purpleModeBackground);
  });

  testWidgets('Account has a Purple mode switch that changes the theme',
      (tester) async {
    addTearDown(() => uwayPurpleMode.value = false);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const UwayApp());
    await tester.tap(find.text('Developer mode (sample data)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to mobile app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.byType(NavigationBar))).brightness,
        Brightness.light);
    await tester.tap(find.text('Purple mode'));
    await tester.pumpAndSettle();
    final scheme = Theme.of(tester.element(find.byType(NavigationBar)))
        .colorScheme;
    expect(scheme.brightness, Brightness.dark);
    expect(scheme.primary, UwayColors.cream);
    // The passenger stays on the Account tab after the look changes.
    expect(find.text('Account and settings'), findsOneWidget);
  });
}
