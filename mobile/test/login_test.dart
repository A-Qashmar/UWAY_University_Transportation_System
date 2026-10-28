import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uway_mobile/main.dart';
import 'package:uway_mobile/services/auth_service.dart';

http.Client _server({required bool accept}) => MockClient((request) async {
      if (request.url.path == '/api/auth/login') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (accept && body['password'] == 'Uway@2026') {
          return http.Response(
            jsonEncode({
              'token': 't.t',
              'expiresAtUtc': '2030-01-01T00:00:00Z',
              'userId': 'u1',
              'email': body['email'],
              'fullName': 'Mariam Ali',
              'role': 'Passenger',
              'gender': 'F',
              'driverId': null,
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'detail': 'The email or password is not correct.'}),
          401,
        );
      }
      // Any trips/routes/notification call after sign-in.
      return http.Response('[]', 200);
    });

void main() {
  testWidgets('the app starts on the sign-in screen', (tester) async {
    await tester.pumpWidget(const UwayApp());
    expect(find.text('Welcome to UWAY'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    final button = find.widgetWithText(FilledButton, 'Sign in');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets('a wrong password shows the server message', (tester) async {
    final service = UwayAuthService(
      httpClient: _server(accept: true),
      baseUrl: 'http://test',
    );
    await tester.pumpWidget(UwayApp(authService: service));
    await tester.enterText(find.byType(TextField).first, 'mariam.ali@uway.test');
    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('The email or password is not correct.'), findsOneWidget);
    expect(find.text('Welcome to UWAY'), findsOneWidget);
  });

  test('a good password returns the session with the passenger gender',
      () async {
    final service = UwayAuthService(
      httpClient: _server(accept: true),
      baseUrl: 'http://test',
    );
    final session = await service.signIn(' Mariam.Ali@uway.test ', 'Uway@2026');
    expect(session.role, 'Passenger');
    expect(session.gender, 'F');
    expect(session.configuration.developmentHeaders,
        {'Authorization': 'Bearer t.t'});
  });
}
