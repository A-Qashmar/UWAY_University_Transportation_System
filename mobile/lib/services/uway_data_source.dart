import '../models/passenger_models.dart';

abstract interface class UwayDataSource {
  String get role;
  int get driverId;
  String get baseUrl;
  bool get isDemoData;
  bool get supportsRealtimeLocation;
  bool get supportsGps;

  Future<List<UwayTrip>> getTrips();
  Future<List<UwayTrip>> getAssignedTrips();
  Future<UwayTrip> getTrip(String tripId);
  Future<UwayRoute> getRoute(int routeId);

  /// Every route the university has registered, whether or not it has trips.
  Future<List<UwayRoute>> getRoutes();
  Future<UwayTrip> startTrip(String tripId);
  Future<UwayTrip> endTrip(String tripId);
  Future<UwayTrip> delayTrip(String tripId, int delayMinutes, String reason);
  Future<void> reportNearlyFull(String tripId);
  Future<TripLocation> updateTripLocation(
      String tripId, double latitude, double longitude);
  Future<TripLocation?> getLatestLocation(String tripId);
  Future<PassengerTripIntent?> getMyIntent(String tripId);
  /// [dropOffStopId] is optional; the passenger can choose it later.
  Future<PassengerTripIntent> createIntent(String tripId, [int? dropOffStopId]);
  Future<PassengerTripIntent> changeDropOff(String tripId, int dropOffStopId);
  Future<void> cancelIntent(String tripId);
  Future<List<PassengerNotification>> getNotifications({int take = 50});
  Future<void> markNotificationRead(String notificationId);

  /// Sends a report. [tripId] is optional and links it to a trip.
  Future<PassengerReport> createReport({
    required String category,
    required String description,
    String? tripId,
    List<ReportFile> files = const [],
  });
  Future<List<PassengerReport>> getMyReports();

  /// Download address and headers for a report attachment ("" when there is none).
  String attachmentUrl(String attachmentId);
  Map<String, String> get authHeaders;
  void close();
}

class UwayApiException implements Exception {
  const UwayApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}
