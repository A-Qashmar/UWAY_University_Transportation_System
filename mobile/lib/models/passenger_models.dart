class UwayTrip {
  const UwayTrip({
    required this.id,
    required this.routeId,
    required this.routeCode,
    this.routeName,
    required this.departureAtUtc,
    required this.status,
    this.audience,
    this.busNumber,
    this.driverName,
    this.delayMinutes = 0,
    this.delayReason,
    this.startedAtUtc,
    this.endedAtUtc,
    this.cancelledAtUtc,
    this.cancellationReason,
    this.joinedCount,
  });

  /// How many passengers joined (known to drivers and admins only).
  final int? joinedCount;

  final String id;
  final int routeId;
  final String routeCode;

  /// Readable line name, for example "King Faisal Line → University City".
  final String? routeName;

  /// What riders and staff see. The short code is only a fallback.
  String get displayName => (routeName != null && routeName!.isNotEmpty)
      ? routeName!
      : (routeCode.isEmpty ? 'Trip' : routeCode);
  final DateTime departureAtUtc;
  final String status;

  /// 'F' for a women's trip, 'M' for a men's trip (null if the server did not say).
  final String? audience;
  final String? busNumber;
  final String? driverName;
  final int delayMinutes;
  final String? delayReason;
  final DateTime? startedAtUtc;
  final DateTime? endedAtUtc;
  final DateTime? cancelledAtUtc;
  final String? cancellationReason;

  /// The primary lifecycle is Scheduled, Started or Finished. A delay or a
  /// cancellation is only an alert on top of it.
  bool get isStarted => status == 'Started';
  bool get isFinished => status == 'Finished';
  bool get isCancelled => cancelledAtUtc != null;
  bool get isDelayed => delayMinutes > 0;

  /// Kept for existing call sites: a trip that is running right now.
  bool get isInProgress => isStarted;

  /// No further action is possible: finished or cancelled.
  bool get isTerminal => isFinished || isCancelled;

  factory UwayTrip.fromJson(Map<String, dynamic> json) => UwayTrip(
        id: json['id'] as String,
        routeId: json['routeId'] as int,
        routeCode: json['routeCode'] as String? ?? '',
        routeName: json['routeName'] as String?,
        departureAtUtc:
            DateTime.parse(json['departureAtUtc'] as String).toLocal(),
        status: json['status'] as String? ?? 'Unknown',
        audience: json['audience'] as String?,
        busNumber: json['fleetNumber'] as String?,
        driverName: json['driverName'] as String?,
        delayMinutes: json['delayMinutes'] as int? ?? 0,
        delayReason: json['delayReason'] as String?,
        startedAtUtc: _date(json['startedAtUtc']),
        endedAtUtc: _date(json['endedAtUtc']),
        cancelledAtUtc: _date(json['cancelledAtUtc']),
        cancellationReason: json['cancellationReason'] as String?,
        joinedCount: json['joinedCount'] as int?,
      );
}

class UwayRouteStop {
  const UwayRouteStop({
    required this.id,
    required this.name,
    required this.order,
    this.latitude,
    this.longitude,
    this.audience,
  });

  final int id;
  final String name;
  final int order;

  /// "M" (men only), "F" (women only) or null (everyone).
  final String? audience;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  factory UwayRouteStop.fromJson(Map<String, dynamic> json) => UwayRouteStop(
        id: json['id'] as int,
        name: json['name'] as String? ?? 'Stop',
        order: json['order'] as int? ?? 0,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        audience: json['audience'] as String?,
      );
}

class UwayRoute {
  const UwayRoute({
    required this.id,
    required this.name,
    required this.stops,
    this.isActive = true,
  });

  final int id;
  final String name;
  final List<UwayRouteStop> stops;
  final bool isActive;

  /// The route as a trip for [audience] ("M" or "F") runs it: stops reserved
  /// for the other gender (UOS - M3 / UOS - W3) are left out.
  UwayRoute forAudience(String? audience) => audience == null
      ? this
      : UwayRoute(
          id: id,
          name: name,
          isActive: isActive,
          stops: [
            for (final stop in stops)
              if (stop.audience == null || stop.audience == audience) stop,
          ],
        );

  factory UwayRoute.fromJson(Map<String, dynamic> json) => UwayRoute(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
        stops: (json['stops'] as List<dynamic>? ?? const [])
            .map((item) => UwayRouteStop.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class PassengerTripIntent {
  const PassengerTripIntent({
    required this.id,
    required this.tripId,
    required this.dropOffStopId,
    required this.createdAtUtc,
    required this.expectedRiderCount,
    this.dropOffStopName,
  });

  final String id;
  final String tripId;
  final int? dropOffStopId;
  final String? dropOffStopName;
  final DateTime createdAtUtc;
  final int expectedRiderCount;

  factory PassengerTripIntent.fromJson(Map<String, dynamic> json) =>
      PassengerTripIntent(
        id: json['id'] as String,
        tripId: json['tripId'] as String,
        dropOffStopId: json['dropOffStopId'] as int?,
        dropOffStopName: json['dropOffStopName'] as String?,
        createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toLocal(),
        expectedRiderCount: json['expectedRiderCount'] as int? ?? 0,
      );
}

class TripLocation {
  const TripLocation({
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.timestampUtc,
  });

  final String tripId;
  final double latitude;
  final double longitude;
  final DateTime timestampUtc;

  factory TripLocation.fromJson(Map<String, dynamic> json) => TripLocation(
        tripId: json['tripId'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timestampUtc: DateTime.parse(json['timestampUtc'] as String).toLocal(),
      );
}

class PassengerNotification {
  const PassengerNotification({
    required this.id,
    this.tripId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAtUtc,
    this.readAtUtc,
  });

  final String id;
  final String? tripId;
  final String type;
  final String title;
  final String message;
  final DateTime createdAtUtc;
  final DateTime? readAtUtc;

  bool get isRead => readAtUtc != null;

  factory PassengerNotification.fromJson(Map<String, dynamic> json) =>
      PassengerNotification(
        id: json['id'] as String,
        tripId: json['tripId'] as String?,
        type: json['type'] as String? ?? 'OperationalUpdate',
        title: json['title'] as String? ?? 'Trip update',
        message: json['message'] as String? ?? '',
        createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toLocal(),
        readAtUtc: _date(json['readAtUtc']),
      );
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();


/// Report types a passenger can choose, in display order.
const reportCategories = <String, String>{
  'LostItem': 'Lost item',
  'TripProblem': 'Problem with a trip',
  'DriverOrBus': 'Driver or bus',
  'Other': 'Something else',
};

String reportCategoryLabel(String category) =>
    reportCategories[category] ?? category;

/// Passenger-friendly wording for the Admin's status.
String reportStatusLabel(String status) => switch (status) {
      'InReview' => 'Under review',
      'Resolved' => 'Resolved',
      _ => 'Received',
    };

/// A file that was attached to a report (a photo or a video).
class ReportAttachmentInfo {
  const ReportAttachmentInfo({
    required this.id,
    required this.fileName,
    required this.contentType,
  });

  final String id;
  final String fileName;
  final String contentType;

  bool get isVideo => contentType.startsWith('video/');

  factory ReportAttachmentInfo.fromJson(Map<String, dynamic> json) =>
      ReportAttachmentInfo(
        id: json['id'] as String,
        fileName: json['fileName'] as String? ?? 'file',
        contentType: json['contentType'] as String? ?? '',
      );
}

/// A photo or video picked on the phone, waiting to be sent with a report.
class ReportFile {
  const ReportFile({
    required this.path,
    required this.name,
    required this.isVideo,
  });

  final String path;
  final String name;
  final bool isVideo;
}

class PassengerReport {
  const PassengerReport({
    required this.id,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAtUtc,
    this.adminResponse,
    this.tripLabel,
    this.attachments = const [],
  });

  final List<ReportAttachmentInfo> attachments;
  final String id;
  final String category;
  final String description;
  final String status;
  final String? adminResponse;
  final String? tripLabel;
  final DateTime createdAtUtc;

  factory PassengerReport.fromJson(Map<String, dynamic> json) {
    final route = json['tripRouteName'] as String?;
    final departure = json['tripDepartureAtUtc'] as String?;
    String? label;
    if (route != null) {
      final time = departure == null ? null : DateTime.parse(departure).toLocal();
      label = time == null
          ? route
          : '$route · ${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return PassengerReport(
      id: json['id'] as String,
      category: json['category'] as String? ?? 'Other',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'Open',
      adminResponse: json['adminResponse'] as String?,
      tripLabel: label,
      attachments: [
        for (final item in (json['attachments'] as List<dynamic>? ?? const []))
          ReportAttachmentInfo.fromJson(item as Map<String, dynamic>),
      ],
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toLocal(),
    );
  }
}
