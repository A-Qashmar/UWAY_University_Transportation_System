import 'dart:async';

import 'package:flutter/material.dart';

import '../models/passenger_models.dart';
import '../models/trip_filter.dart';
import '../services/trip_location_connection.dart';
import '../services/uway_api_client.dart';
import '../services/uway_data_source.dart';
import '../widgets/passenger_state_panel.dart';
import '../widgets/live_location_map.dart';

class TripTrackingScreen extends StatefulWidget {
  const TripTrackingScreen({
    required this.apiClient,
    required this.trip,
    this.route,
    super.key,
  });

  final UwayDataSource apiClient;
  final UwayTrip trip;
  final UwayRoute? route;

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen> {
  TripLocationConnection? _connection;
  StreamSubscription<TripLocation>? _locationSubscription;
  StreamSubscription<TrackingConnectionStatus>? _statusSubscription;
  Timer? _activeTripCheck;

  UwayRoute? get _tripRoute => widget.route?.forAudience(widget.trip.audience);
  List<UwayRouteStop> get _stops => _tripRoute?.stops ?? const [];

  /// Stops a rider may choose to get off at: on a trip to the university only
  /// the campus stops (such as M3 or W3), on a trip from it the other stops.
  Set<int> get _dropOffIds =>
      dropOffOptions(_tripRoute).map((stop) => stop.id).toSet();
  bool _hasIntent = false;
  TripLocation? _location;
  TrackingConnectionStatus _status = TrackingConnectionStatus.connecting;
  Object? _error;
  bool _tripUnavailable = false;
  bool _loadingLocation = true;
  int? _dropOffStopId;

  @override
  void initState() {
    super.initState();
    if (!widget.trip.isTerminal && widget.trip.isInProgress) {
      if (widget.apiClient.supportsRealtimeLocation &&
          widget.apiClient is UwayApiClient) {
        final connection = TripLocationConnection(
          apiClient: widget.apiClient as UwayApiClient,
        );
        _connection = connection;
        _locationSubscription = connection.locations.listen(_onLocation);
        _statusSubscription = connection.statuses.listen((status) {
          if (mounted) setState(() => _status = status);
        });
      } else {
        _status = TrackingConnectionStatus.disconnected;
      }
      _startTracking();
      if (widget.apiClient.supportsRealtimeLocation) {
        _activeTripCheck = Timer.periodic(
          const Duration(seconds: 10),
          (_) => _checkTripState(),
        );
      }
    } else {
      _loadingLocation = false;
      _tripUnavailable = true;
    }
  }

  Future<void> _startTracking() async {
    try {
      try {
        final intent = await widget.apiClient.getMyIntent(widget.trip.id);
        _dropOffStopId = intent?.dropOffStopId;
        _hasIntent = intent != null;
      } catch (_) {
        // The drop-off flag is optional; tracking works without it.
      }
      await _refreshLatestLocation();
      await _connection?.connect(widget.trip.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loadingLocation = false;
        if (error is UwayApiException && error.statusCode == 409) {
          _tripUnavailable = true;
        }
      });
    }
  }

  Future<void> _refreshLatestLocation() async {
    setState(() {
      _loadingLocation = true;
      _error = null;
    });
    try {
      final latest = await widget.apiClient.getLatestLocation(widget.trip.id);
      if (mounted) setState(() => _location = latest);
    } catch (error) {
      if (error is UwayApiException && error.statusCode == 409 && mounted) {
        setState(() => _tripUnavailable = true);
        await _connection?.close();
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _checkTripState() async {
    if (_tripUnavailable) return;
    try {
      // Also the fallback when the live connection is down: the map stays current.
      final latest = await widget.apiClient.getLatestLocation(widget.trip.id);
      if (mounted && latest != null) {
        setState(() {
          _location = latest;
          _error = null;
        });
      }
    } on UwayApiException catch (error) {
      if (error.statusCode == 409 && mounted) {
        setState(() => _tripUnavailable = true);
        await _connection?.close();
      }
    } catch (_) {
      // A temporary network failure should not end the current subscription.
    }
  }

  void _onLocation(TripLocation location) {
    if (!mounted ||
        location.tripId.toLowerCase() != widget.trip.id.toLowerCase()) {
      return;
    }
    setState(() {
      _location = location;
      _error = null;
      _loadingLocation = false;
    });
  }

  /// Tapping a stop pin offers it as the rider's drop-off, after a confirmation.
  Future<void> _onStopTap(UwayRouteStop stop) async {
    if (widget.apiClient.role != 'Passenger') return;
    if (!_dropOffIds.contains(stop.id)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(routeDirection(_tripRoute) == RouteDirection.toCampus
            ? 'On a trip to the university you get off at a campus stop.'
            : 'On a trip from the university you get off at one of the stops along the route.'),
      ));
      return;
    }
    if (_dropOffStopId == stop.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is already your drop-off stop.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Get off here?'),
        content: Text(_hasIntent
            ? 'Set "${stop.name}" as your drop-off stop.'
            : 'Set "${stop.name}" as your drop-off stop. You will also be added to this trip.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (_hasIntent) {
        await widget.apiClient.changeDropOff(widget.trip.id, stop.id);
      } else {
        await widget.apiClient.createIntent(widget.trip.id, stop.id);
      }
      if (!mounted) return;
      setState(() {
        _dropOffStopId = stop.id;
        _hasIntent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Drop-off set: ${stop.name}')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is UwayApiException
            ? error.message
            : 'The drop-off could not be saved. Try again.'),
      ));
    }
  }

  @override
  void dispose() {
    _activeTripCheck?.cancel();
    _locationSubscription?.cancel();
    _statusSubscription?.cancel();
    unawaited(_connection?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.route?.name ?? widget.trip.displayName),
        ),
        body: widget.trip.isTerminal || _tripUnavailable
            ? PassengerStatePanel(
                title: widget.trip.isCancelled
                    ? 'Trip cancelled'
                    : 'Trip tracking ended',
                message:
                    'Live location is available only while this trip is in progress.',
                icon: Icons.location_off_outlined,
              )
            : Column(
                children: [
                  // The map takes the screen; the details sit under it.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: _loadingLocation && _location == null
                          ? const Center(child: CircularProgressIndicator())
                          : LiveLocationMap(
                              latitude: _location?.latitude,
                              longitude: _location?.longitude,
                              stops: _stops,
                              dropOffStopId: _dropOffStopId,
                              height: null,
                              onStopTap: _onStopTap,
                              selectableStopIds: _dropOffIds,
                            ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.apiClient.supportsRealtimeLocation)
                            _ConnectionLine(status: _status)
                          else
                            Text('Demo sample data · GPS movement is not simulated.',
                                style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          if (_error != null)
                            Text('Live tracking could not connect: $_error',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error)),
                          Text(
                            _location == null
                                ? 'No bus location yet. The driver has not sent one.'
                                : 'Bus updated ${_formatTimestamp(_location!.timestampUtc.toLocal())}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tip: tap a bright stop on the map to choose it as your drop-off.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      );
}

class _ConnectionLine extends StatelessWidget {
  const _ConnectionLine({required this.status});
  final TrackingConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      TrackingConnectionStatus.connecting => 'Connecting to live updates…',
      TrackingConnectionStatus.connected => 'Live updates connected',
      TrackingConnectionStatus.reconnecting => 'Connection lost · reconnecting…',
      TrackingConnectionStatus.disconnected => 'Live updates disconnected',
    };
    final icon = switch (status) {
      TrackingConnectionStatus.connected => Icons.wifi,
      TrackingConnectionStatus.reconnecting => Icons.sync,
      TrackingConnectionStatus.disconnected => Icons.wifi_off,
      TrackingConnectionStatus.connecting => Icons.wifi_find,
    };
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String _formatTimestamp(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
