import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_configuration.dart';
import 'uway_data_source.dart';

/// The signed-in person, as returned by `POST /api/auth/login`.
class UwaySession {
  const UwaySession({
    required this.token,
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.baseUrl,
    this.gender,
    this.driverId,
  });

  final String token;
  final String userId;
  final String email;
  final String fullName;
  final String role;
  final String baseUrl;
  final String? gender;
  final int? driverId;

  factory UwaySession.fromJson(Map<String, dynamic> json, String baseUrl) =>
      UwaySession(
        token: json['token'] as String,
        userId: json['userId'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        role: json['role'] as String,
        gender: json['gender'] as String?,
        driverId: json['driverId'] as int?,
        baseUrl: baseUrl,
      );

  ApiConfiguration get configuration => ApiConfiguration(
        role: role,
        passengerId: userId,
        driverId: driverId ?? 0,
        baseUrl: baseUrl,
        bearerToken: token,
      );
}

class UwayAuthService {
  UwayAuthService({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfiguration.defaultBaseUrl();

  final http.Client _http;
  final String baseUrl;

  Future<UwaySession> signIn(String email, String password) async {
    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } on Object {
      throw const UwayApiException(
        0,
        'The server could not be reached. Check your connection and try again.',
      );
    }
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode == 200) {
      return UwaySession.fromJson(body as Map<String, dynamic>, baseUrl);
    }
    final detail = body is Map<String, dynamic> ? body['detail'] as String? : null;
    throw UwayApiException(
      response.statusCode,
      detail ?? 'Sign-in failed. Please try again.',
    );
  }
}
