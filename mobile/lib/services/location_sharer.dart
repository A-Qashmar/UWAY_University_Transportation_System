import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/passenger_models.dart';
import 'uway_data_source.dart';

/// Sends the driver's GPS position to the server every few seconds while a
/// trip is running, so passengers and the admin see an accurate bus location.
class LocationSharer extends ChangeNotifier {
  LocationSharer({
    required this.apiClient,
    this.interval = const Duration(seconds: 5),
    Future<Position> Function()? positionProvider,
  }) : _positionProvider = positionProvider ?? _devicePosition;

  final UwayDataSource apiClient;
  final Duration interval;
  final Future<Position> Function() _positionProvider;

  Timer? _timer;
  bool _sending = false;
  String? _tripId;
  String? error;
  TripLocation? lastLocation;
  DateTime? lastSentAt;

  String? get sharingTripId => _tripId;
  bool isSharing(String tripId) => _tripId == tripId;

  static Future<Position> _devicePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Turn on location (GPS) on this phone.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Allow location for UWAY so passengers can see the bus.');
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 4),
    );
  }

  /// Starts sharing for [tripId]. Returns false when sharing is not possible
  /// (for example sample data); [error] then explains why.
  Future<bool> start(String tripId) async {
    if (!apiClient.supportsGps) {
      error = 'Live location works with real data only.';
      notifyListeners();
      return false;
    }
    stop();
    _tripId = tripId;
    error = null;
    notifyListeners();
    await _send();
    if (_tripId == null) return false; // the first send failed and stopped us
    _timer = Timer.periodic(interval, (_) => _send());
    return true;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_tripId != null) {
      _tripId = null;
      notifyListeners();
    }
  }

  Future<void> _send() async {
    final tripId = _tripId;
    if (tripId == null || _sending) return;
    _sending = true;
    try {
      final position = await _positionProvider();
      final location = await apiClient.updateTripLocation(
        tripId,
        position.latitude,
        position.longitude,
      );
      lastLocation = location;
      lastSentAt = DateTime.now();
      error = null;
    } on UwayApiException catch (e) {
      error = e.message;
      // Another request touching the same trip at the same moment is a
      // temporary clash ("Retry the location update"): the next tick retries.
      // Anything else (trip ended, not your trip, signed out) stops sharing.
      final temporary = e.statusCode >= 500 ||
          e.statusCode == 0 ||
          (e.statusCode == 409 && e.message.toLowerCase().contains('retry'));
      if (!temporary) stop();
    } on Object catch (e) {
      // GPS hiccups are temporary: keep trying, but tell the driver.
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
