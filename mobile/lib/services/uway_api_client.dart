import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../models/passenger_models.dart';
import 'api_configuration.dart';
import 'uway_data_source.dart';

export 'uway_data_source.dart' show UwayApiException;

class UwayApiClient implements UwayDataSource {
  UwayApiClient({required this.configuration, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;
  final ApiConfiguration configuration;

  @override
  String get role => configuration.role;

  @override
  int get driverId => configuration.driverId;

  @override
  String get baseUrl => configuration.baseUrl;

  @override
  bool get isDemoData => false;

  @override
  bool get supportsRealtimeLocation => true;

  @override
  bool get supportsGps => true;

  @override
  Future<List<UwayTrip>> getTrips() async {
    final json = await _get('/api/trips');
    return (json as List<dynamic>)
        .map((item) => UwayTrip.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<UwayTrip>> getAssignedTrips() async {
    final json = await _get('/api/trips/assigned');
    return (json as List<dynamic>)
        .map((item) => UwayTrip.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<UwayTrip> startTrip(String tripId) async => UwayTrip.fromJson(
        await _send('POST', '/api/trips/$tripId/start') as Map<String, dynamic>,
      );

  @override
  Future<UwayTrip> endTrip(String tripId) async => UwayTrip.fromJson(
        await _send('POST', '/api/trips/$tripId/end') as Map<String, dynamic>,
      );

  @override
  Future<UwayTrip> delayTrip(
    String tripId,
    int delayMinutes,
    String reason,
  ) async =>
      UwayTrip.fromJson(
        await _send(
          'POST',
          '/api/trips/$tripId/delay',
          body: {'delayMinutes': delayMinutes, 'reason': reason},
        ) as Map<String, dynamic>,
      );

  @override
  Future<void> reportNearlyFull(String tripId) async {
    await _send('POST', '/api/trips/$tripId/nearly-full');
  }

  @override
  Future<TripLocation> updateTripLocation(
    String tripId,
    double latitude,
    double longitude,
  ) async =>
      TripLocation.fromJson(
        await _send(
          'POST',
          '/api/trips/$tripId/location',
          body: {'latitude': latitude, 'longitude': longitude},
        ) as Map<String, dynamic>,
      );

  @override
  Future<UwayTrip> getTrip(String tripId) async => UwayTrip.fromJson(
        await _get('/api/trips/$tripId') as Map<String, dynamic>,
      );

  @override
  Future<List<UwayRoute>> getRoutes() async {
    final body = await _get('/api/routes') as List<dynamic>;
    return body
        .map((item) => UwayRoute.fromJson(item as Map<String, dynamic>))
        .where((route) => route.isActive && route.stops.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<UwayRoute> getRoute(int routeId) async => UwayRoute.fromJson(
        await _get('/api/routes/$routeId') as Map<String, dynamic>,
      );

  @override
  Future<PassengerTripIntent?> getMyIntent(String tripId) async {
    try {
      return PassengerTripIntent.fromJson(
        await _get('/api/trips/$tripId/intent') as Map<String, dynamic>,
      );
    } on UwayApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<PassengerTripIntent> createIntent(
    String tripId, [
    int? dropOffStopId,
  ]) async =>
      PassengerTripIntent.fromJson(
        await _send(
          'POST',
          '/api/trips/$tripId/intent',
          body: {if (dropOffStopId != null) 'dropOffStopId': dropOffStopId},
        ) as Map<String, dynamic>,
      );

  @override
  Future<PassengerTripIntent> changeDropOff(
    String tripId,
    int dropOffStopId,
  ) async =>
      PassengerTripIntent.fromJson(
        await _send(
          'PUT',
          '/api/trips/$tripId/intent/drop-off',
          body: {'dropOffStopId': dropOffStopId},
        ) as Map<String, dynamic>,
      );

  @override
  Future<void> cancelIntent(String tripId) async {
    await _send('DELETE', '/api/trips/$tripId/intent');
  }

  @override
  Future<TripLocation?> getLatestLocation(String tripId) async {
    final response = await _http.get(
      _uri('/api/trips/$tripId/location'),
      headers: configuration.developmentHeaders,
    );
    if (response.statusCode == 204) return null;
    final json = _decodeResponse(response);
    return TripLocation.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<List<PassengerNotification>> getNotifications({int take = 50}) async {
    final json = await _get('/api/notifications?take=$take');
    return (json as List<dynamic>)
        .map(
          (item) =>
              PassengerNotification.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  @override
  Future<PassengerReport> createReport({
    required String category,
    required String description,
    String? tripId,
    List<ReportFile> files = const [],
  }) async {
    final created = await _send('POST', '/api/reports', body: {
      'category': category,
      'description': description,
      if (tripId != null) 'tripId': tripId,
    }) as Map<String, dynamic>;
    final report = PassengerReport.fromJson(created);
    var failed = 0;
    for (final file in files) {
      try {
        await _upload(report.id, file);
      } on Object {
        failed++;
      }
    }
    if (failed > 0) {
      throw UwayApiException(
        0,
        'Your report was sent, but $failed file${failed == 1 ? '' : 's'} could not be uploaded. '
        'Check My reports.',
      );
    }
    return report;
  }

  Future<void> _upload(String reportId, ReportFile file) async {
    final lower = file.name.toLowerCase();
    final subtype = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.mp4')
            ? 'mp4'
            : lower.endsWith('.mov')
                ? 'quicktime'
                : lower.endsWith('.webp')
                    ? 'webp'
                    : file.isVideo
                        ? 'mp4'
                        : 'jpeg';
    final request = http.MultipartRequest('POST', _uri('/api/reports/$reportId/attachments'))
      ..headers.addAll(configuration.developmentHeaders)
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: file.name,
        contentType: MediaType(file.isVideo ? 'video' : 'image', subtype),
      ));
    final response = await http.Response.fromStream(
      await _http.send(request).timeout(const Duration(minutes: 3)),
    );
    _decodeResponse(response);
  }

  /// Headers for downloading an attachment (photos are shown with these).
  @override
  Map<String, String> get authHeaders => configuration.developmentHeaders;

  @override
  String attachmentUrl(String attachmentId) =>
      _uri('/api/reports/attachments/$attachmentId').toString();

  @override
  Future<List<PassengerReport>> getMyReports() async {
    final json = await _get('/api/reports/mine');
    return (json as List<dynamic>)
        .map((item) => PassengerReport.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _send('PUT', '/api/notifications/$notificationId/read');
  }

  Future<dynamic> _get(String path) async {
    final response = await _http.get(
      _uri(path),
      headers: configuration.developmentHeaders,
    );
    return _decodeResponse(response);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, _uri(path))
      ..headers.addAll(configuration.developmentHeaders)
      ..headers['Content-Type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _http.send(request);
    return _decodeResponse(await http.Response.fromStream(streamed));
  }

  Uri _uri(String path) => Uri.parse('${configuration.baseUrl}$path');

  dynamic _decodeResponse(http.Response response) {
    if (response.statusCode == 204) return null;
    dynamic json;
    try {
      json = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      json = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body =
          json is Map<String, dynamic> ? json : const <String, dynamic>{};
      final detail = body['detail'] ?? body['title'];
      final defaultMessage = switch (response.statusCode) {
        401 => 'Sign-in is required to access this service.',
        403 => 'This action is not available to the current passenger account.',
        404 => 'The requested trip or item could not be found.',
        409 =>
          'This request conflicts with the current server state. Refresh and try again.',
        _ => 'The service could not complete the request. Try again later.',
      };
      throw UwayApiException(
        response.statusCode,
        detail as String? ?? defaultMessage,
      );
    }
    return json;
  }

  @override
  void close() => _http.close();
}
