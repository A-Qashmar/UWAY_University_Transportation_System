import '../data/demo_fixtures.dart';
import '../models/passenger_models.dart';
import '../models/trip_filter.dart';
import 'uway_data_source.dart';

class DemoUwayDataSource implements UwayDataSource {
  DemoUwayDataSource({
    required this.role,
    this.driverId = 1,
    this.passengerGender = 'M',
  })
      : _trips = DemoFixtures.trips(),
        _notifications = DemoFixtures.notifications() {
    const tripId = DemoFixtures.activeIntentTripId;
    _activeIntents[tripId] = PassengerTripIntent(
      id: DemoFixtures.activeIntentId,
      tripId: tripId,
      dropOffStopId: 107,
      dropOffStopName: 'UOS - M3',
      createdAtUtc: DateTime.now().subtract(const Duration(minutes: 12)),
      expectedRiderCount: 2,
    );
    _activeIntents[DemoFixtures.secondIntentTripId] = PassengerTripIntent(
      id: '30000000-0000-4000-8000-000000000002',
      tripId: DemoFixtures.secondIntentTripId,
      dropOffStopId: 110,
      dropOffStopName: 'UOS - Medical College',
      createdAtUtc: DateTime.now().subtract(const Duration(minutes: 7)),
      expectedRiderCount: 1,
    );
    _expectedRiderCounts[tripId] = 2;
    _expectedRiderCounts[DemoFixtures.secondIntentTripId] = 1;
  }

  @override
  final String role;

  @override
  final int driverId;

  /// 'F' or 'M'. A demo passenger only sees trips for their own gender.
  final String passengerGender;

  bool _visible(UwayTrip trip) =>
      role != 'Passenger' || trip.audience == passengerGender;

  final List<UwayTrip> _trips;
  final List<PassengerNotification> _notifications;
  final Map<String, PassengerTripIntent> _activeIntents = {};
  final Map<String, int> _expectedRiderCounts = {};
  final Set<String> _nearlyFullTrips = {};
  late final List<PassengerReport> _reports = [
    PassengerReport(
      id: '50000000-0000-4000-8000-000000000001',
      category: 'LostItem',
      description: 'I left a blue water bottle on the 08:00 bus.',
      status: 'Resolved',
      adminResponse:
          'We found the bottle. Please collect it from the transport office.',
      createdAtUtc: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
  int _nextIntentNumber = 3;
  bool _closed = false;

  @override
  String get baseUrl => 'Local sample data';

  @override
  bool get isDemoData => true;

  @override
  bool get supportsRealtimeLocation => false;

  @override
  bool get supportsGps => false;

  bool wasReportedNearlyFull(String tripId) =>
      _nearlyFullTrips.contains(tripId);

  @override
  Future<List<UwayTrip>> getTrips() async =>
      List.unmodifiable(_trips.where(_visible));

  @override
  Future<List<UwayTrip>> getAssignedTrips() async {
    _requireRole('Driver');
    return List.unmodifiable(_trips);
  }

  @override
  Future<UwayTrip> getTrip(String tripId) async {
    final trip = _trip(tripId);
    if (!_visible(trip)) {
      throw const UwayApiException(404, 'Sample trip was not found.');
    }
    return trip;
  }

  @override
  Future<List<UwayRoute>> getRoutes() async =>
      List.unmodifiable(DemoFixtures.routes);

  @override
  Future<UwayRoute> getRoute(int routeId) async {
    for (final route in DemoFixtures.routes) {
      if (route.id == routeId) return route;
    }
    throw const UwayApiException(404, 'Sample route was not found.');
  }

  @override
  Future<UwayTrip> startTrip(String tripId) async {
    _requireRole('Driver');
    final trip = _trip(tripId);
    if (trip.status != 'Scheduled' || trip.isCancelled) {
      throw const UwayApiException(409, 'Only a scheduled trip can start.');
    }
    return _replaceTrip(trip, status: 'Started', startedAtUtc: DateTime.now());
  }

  @override
  Future<UwayTrip> endTrip(String tripId) async {
    _requireRole('Driver');
    final trip = _trip(tripId);
    if (!trip.isStarted) {
      throw const UwayApiException(409, 'Only an active trip can end.');
    }
    return _replaceTrip(trip, status: 'Finished', endedAtUtc: DateTime.now());
  }

  @override
  Future<UwayTrip> delayTrip(
      String tripId, int delayMinutes, String reason) async {
    _requireRole('Driver');
    final trip = _trip(tripId);
    if (trip.status != 'Scheduled' || trip.isCancelled) {
      throw const UwayApiException(409, 'This sample trip cannot be delayed.');
    }
    final delayed = UwayTrip(
      id: trip.id,
      routeId: trip.routeId,
      routeCode: trip.routeCode,
      routeName: trip.routeName,
      audience: trip.audience,
      departureAtUtc: trip.departureAtUtc,
      status: trip.status,
      busNumber: trip.busNumber,
      driverName: trip.driverName,
      delayMinutes: delayMinutes,
      delayReason: reason,
      startedAtUtc: trip.startedAtUtc,
      endedAtUtc: trip.endedAtUtc,
    );
    _trips[_trips.indexWhere((item) => item.id == trip.id)] = delayed;
    return delayed;
  }

  @override
  Future<void> reportNearlyFull(String tripId) async {
    _requireRole('Driver');
    final trip = _trip(tripId);
    if (!trip.isStarted) {
      throw const UwayApiException(409, 'Only an active trip can be reported.');
    }
    _nearlyFullTrips.add(tripId);
  }

  @override
  Future<TripLocation> updateTripLocation(
      String tripId, double latitude, double longitude) async {
    throw const UwayApiException(
      501,
      'GPS updates require API Data mode. Demo mode does not simulate bus movement.',
    );
  }

  @override
  Future<TripLocation?> getLatestLocation(String tripId) async {
    _trip(tripId);
    return null;
  }

  @override
  Future<PassengerTripIntent?> getMyIntent(String tripId) async =>
      _activeIntents[tripId];

  @override
  Future<PassengerTripIntent> createIntent(String tripId,
      [int? dropOffStopId]) async {
    _requireRole('Passenger');
    final trip = _trip(tripId);
    if (!_visible(trip)) {
      throw const UwayApiException(404, 'Sample trip was not found.');
    }
    if (!(trip.status == 'Scheduled' || trip.isInProgress) ||
        trip.isCancelled) {
      throw const UwayApiException(
          409, 'This sample trip cannot accept intent.');
    }
    if (dropOffStopId != null) _validateDropOff(trip, dropOffStopId);
    if (_activeIntents.containsKey(tripId)) {
      throw const UwayApiException(
        409,
        'An active Trip Intent already exists for this sample trip.',
      );
    }
    final intent = PassengerTripIntent(
      id: '30000000-0000-4000-8000-${_nextIntentNumber.toString().padLeft(12, '0')}',
      tripId: tripId,
      dropOffStopId: dropOffStopId,
      dropOffStopName: dropOffStopId == null ? null : _stopName(dropOffStopId),
      createdAtUtc: DateTime.now(),
      expectedRiderCount: _expectedRiderCounts.update(
        tripId,
        (count) => count + 1,
        ifAbsent: () => 1,
      ),
    );
    _activeIntents[tripId] = intent;
    _nextIntentNumber++;
    return intent;
  }

  @override
  Future<PassengerTripIntent> changeDropOff(
      String tripId, int dropOffStopId) async {
    _requireRole('Passenger');
    final trip = _trip(tripId);
    if (!_visible(trip)) {
      throw const UwayApiException(404, 'Sample trip was not found.');
    }
    if (trip.isFinished || trip.isCancelled) {
      throw const UwayApiException(409, 'This sample trip cannot be changed.');
    }
    final current = _activeIntents[tripId];
    if (current == null) {
      throw const UwayApiException(404, 'No active sample Trip Intent exists.');
    }
    _validateDropOff(trip, dropOffStopId);
    final updated = PassengerTripIntent(
      id: current.id,
      tripId: current.tripId,
      dropOffStopId: dropOffStopId,
      dropOffStopName: _stopName(dropOffStopId),
      createdAtUtc: current.createdAtUtc,
      expectedRiderCount: _expectedRiderCounts[tripId] ?? 1,
    );
    _activeIntents[tripId] = updated;
    return updated;
  }

  @override
  Future<void> cancelIntent(String tripId) async {
    _requireRole('Passenger');
    if (_activeIntents.remove(tripId) == null) {
      throw const UwayApiException(404, 'No active sample Trip Intent exists.');
    }
    _expectedRiderCounts.update(
      tripId,
      (count) => count > 0 ? count - 1 : 0,
      ifAbsent: () => 0,
    );
  }

  @override
  Future<List<PassengerNotification>> getNotifications({int take = 50}) async {
    if (role != 'Passenger') return const [];
    return _notifications.take(take).toList(growable: false);
  }

  @override
  String attachmentUrl(String attachmentId) => '';

  @override
  Map<String, String> get authHeaders => const {};

  @override
  Future<PassengerReport> createReport({
    required String category,
    required String description,
    String? tripId,
    List<ReportFile> files = const [],
  }) async {
    _requireReporter();
    String? label;
    if (tripId != null) {
      final trip = _trip(tripId);
      if (!_visible(trip)) {
        throw const UwayApiException(400, 'That trip could not be found.');
      }
      label = trip.displayName;
    }
    final report = PassengerReport(
      id: '50000000-0000-4000-8000-${(_reports.length + 1).toString().padLeft(12, '0')}',
      category: category,
      description: description,
      status: 'Open',
      tripLabel: label,
      createdAtUtc: DateTime.now(),
    );
    _reports.insert(0, report);
    return report;
  }

  @override
  Future<List<PassengerReport>> getMyReports() async {
    _requireReporter();
    return List.unmodifiable(_reports);
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    if (role != 'Passenger') return;
    final index =
        _notifications.indexWhere((item) => item.id == notificationId);
    if (index < 0) {
      throw const UwayApiException(404, 'Sample notification was not found.');
    }
    final item = _notifications[index];
    if (item.isRead) return;
    _notifications[index] = PassengerNotification(
      id: item.id,
      tripId: item.tripId,
      type: item.type,
      title: item.title,
      message: item.message,
      createdAtUtc: item.createdAtUtc,
      readAtUtc: DateTime.now(),
    );
  }

  @override
  void close() => _closed = true;

  UwayTrip _trip(String id) {
    if (_closed) throw const UwayApiException(410, 'Sample session is closed.');
    for (final trip in _trips) {
      if (trip.id == id) return trip;
    }
    throw const UwayApiException(404, 'Sample trip was not found.');
  }

  UwayTrip _replaceTrip(
    UwayTrip current, {
    required String status,
    DateTime? startedAtUtc,
    DateTime? endedAtUtc,
  }) {
    final updated = UwayTrip(
      id: current.id,
      routeId: current.routeId,
      routeCode: current.routeCode,
      routeName: current.routeName,
      audience: current.audience,
      departureAtUtc: current.departureAtUtc,
      status: status,
      busNumber: current.busNumber,
      driverName: current.driverName,
      delayMinutes: current.delayMinutes,
      delayReason: current.delayReason,
      startedAtUtc: startedAtUtc ?? current.startedAtUtc,
      endedAtUtc: endedAtUtc ?? current.endedAtUtc,
    );
    _trips[_trips.indexWhere((item) => item.id == current.id)] = updated;
    return updated;
  }

  void _validateDropOff(UwayTrip trip, int stopId) {
    final route =
        DemoFixtures.routes.firstWhere((item) => item.id == trip.routeId);
    if (!dropOffOptions(route).any((stop) => stop.id == stopId)) {
      // Trips to campus: campus points only; trips from campus: other points.
      throw const UwayApiException(
          400, 'Choose one of the drop-off points offered for this trip.');
    }
  }

  String _stopName(int id) => DemoFixtures.routes
      .expand((route) => route.stops)
      .firstWhere((stop) => stop.id == id)
      .name;

  void _requireReporter() {
    if (role != 'Passenger' && role != 'Driver') {
      throw const UwayApiException(
          403, 'This action is unavailable for the selected demo role.');
    }
  }

  void _requireRole(String expected) {
    if (role != expected) {
      throw const UwayApiException(
          403, 'This action is unavailable for the selected demo role.');
    }
  }
}
