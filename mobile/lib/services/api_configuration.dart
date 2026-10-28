import 'package:flutter/foundation.dart';

class ApiConfiguration {
  const ApiConfiguration({
    required this.role,
    required this.passengerId,
    required this.driverId,
    required this.baseUrl,
    this.bearerToken,
  });

  final String role;
  final String passengerId;
  final int driverId;
  final String baseUrl;

  /// Session token from sign-in. When set it replaces the development headers.
  final String? bearerToken;

  static const _configuredUrl = String.fromEnvironment(
    'UWAY_API_URL',
    defaultValue: 'http://localhost:5251',
  );
  static const _configuredPassengerId = String.fromEnvironment(
    'UWAY_DEV_PASSENGER_ID',
    defaultValue: 'test-male-1',
  );

  static const _configuredDriverId =
      int.fromEnvironment('UWAY_DEV_DRIVER_ID', defaultValue: 1);

  static String defaultBaseUrl() {
    var url = _configuredUrl;
    if (url == 'http://localhost:5251' &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator access uses adb reverse for the local API.
      url = 'http://127.0.0.1:5251';
    }
    return url;
  }

  static ApiConfiguration forDevelopment({
    required String role,
    required int driverId,
    String? passengerId,
  }) {
    var url = _configuredUrl;
    if (url == 'http://localhost:5251' &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator access uses adb reverse for the local API.
      url = 'http://127.0.0.1:5251';
    }
    return ApiConfiguration(
      role: role,
      passengerId: passengerId ?? _configuredPassengerId,
      driverId: driverId == 0 ? _configuredDriverId : driverId,
      baseUrl: url,
    );
  }

  Map<String, String> get developmentHeaders {
    if (bearerToken != null) return {'Authorization': 'Bearer $bearerToken'};
    if (!kDebugMode) return const {};
    final headers = <String, String>{'X-Uway-Dev-Role': role};
    if (role == 'Passenger') {
      headers['X-Uway-Dev-UserId'] = passengerId;
    } else if (role == 'Driver') {
      headers['X-Uway-Dev-DriverId'] = '$driverId';
    } else if (role == 'Admin') {
      headers['X-Uway-Dev-UserId'] = 'admin-local';
    }
    return headers;
  }
}
