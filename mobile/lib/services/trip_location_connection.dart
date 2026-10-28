import 'dart:async';

import 'package:signalr_core/signalr_core.dart';

import '../models/passenger_models.dart';
import 'uway_api_client.dart';

enum TrackingConnectionStatus {
  connecting,
  connected,
  reconnecting,
  disconnected,
}

class TripLocationConnection {
  TripLocationConnection({required UwayApiClient apiClient})
      : _apiClient = apiClient;

  final UwayApiClient _apiClient;
  final _locations = StreamController<TripLocation>.broadcast();
  final _statuses = StreamController<TrackingConnectionStatus>.broadcast();
  HubConnection? _connection;
  String? _tripId;
  bool _closed = false;

  Stream<TripLocation> get locations => _locations.stream;
  Stream<TrackingConnectionStatus> get statuses => _statuses.stream;

  Future<void> connect(String tripId) async {
    _tripId = tripId;
    _statuses.add(TrackingConnectionStatus.connecting);
    final token = _apiClient.configuration.bearerToken;
    final connection = HubConnectionBuilder()
        .withUrl(
      '${_apiClient.baseUrl}/hubs/trip-locations',
      token != null
          ? HttpConnectionOptions(accessTokenFactory: () async => token)
          : HttpConnectionOptions(
              customHeaders: _apiClient.configuration.developmentHeaders,
            ),
    )
        .withAutomaticReconnect([0, 2000, 5000, 10000, 20000]).build();
    _connection = connection;

    connection.on('LocationUpdated', (arguments) {
      if (arguments == null || arguments.isEmpty || arguments.first is! Map) {
        return;
      }
      try {
        final location = TripLocation.fromJson(
          Map<String, dynamic>.from(arguments.first as Map),
        );
        _locations.add(location);
      } on Object {
        // Ignore malformed events; the next REST read remains authoritative.
      }
    });
    connection.onreconnecting((_) {
      if (!_closed) _statuses.add(TrackingConnectionStatus.reconnecting);
    });
    connection.onreconnected((_) async {
      if (_closed) return;
      try {
        await _joinTrip();
        await _reloadLatestLocation();
        _statuses.add(TrackingConnectionStatus.connected);
      } on Object {
        _statuses.add(TrackingConnectionStatus.disconnected);
      }
    });
    connection.onclose((_) {
      if (!_closed) _statuses.add(TrackingConnectionStatus.disconnected);
    });

    await connection.start();
    await _joinTrip();
    _statuses.add(TrackingConnectionStatus.connected);
  }

  Future<void> _joinTrip() async {
    final connection = _connection;
    final tripId = _tripId;
    if (connection == null || tripId == null) return;
    await connection.invoke('JoinTrip', args: [tripId]);
  }

  Future<void> _reloadLatestLocation() async {
    final tripId = _tripId;
    if (tripId == null) return;
    final latest = await _apiClient.getLatestLocation(tripId);
    if (latest != null) _locations.add(latest);
  }

  Future<void> close() async {
    _closed = true;
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      try {
        await connection.invoke('LeaveTrip', args: [_tripId]);
      } on Object {
        // Stopping the connection also removes it from the server-side group.
      }
      await connection.stop();
    }
    await _locations.close();
    await _statuses.close();
  }
}
