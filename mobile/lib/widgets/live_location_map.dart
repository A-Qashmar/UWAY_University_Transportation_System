import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/passenger_models.dart';
import '../models/trip_filter.dart';
import '../theme/uway_theme.dart';
import 'uway_tile_layer.dart';

/// Map for trip tracking: the route line and stops, the rider's drop-off
/// point and, when known, the bus. Either [latitude]/[longitude] or at least
/// one stop with coordinates is needed to draw anything.
///
/// Like a delivery app, the camera follows the bus: it starts zoomed in on the
/// bus and moves with it. When the rider pans or zooms, following pauses and a
/// "Follow bus" button brings it back.
class LiveLocationMap extends StatefulWidget {
  const LiveLocationMap({
    this.latitude,
    this.longitude,
    this.stops = const [],
    this.dropOffStopId,
    this.height = 320,
    this.showLegend = true,
    this.onStopTap,
    this.selectableStopIds,
    super.key,
  });

  /// When set, only these stops are drawn at full strength; the others are
  /// dimmed (they cannot be chosen as a drop-off on this trip).
  final Set<int>? selectableStopIds;

  /// Called when a stop pin is tapped (for choosing a drop-off stop).
  final ValueChanged<UwayRouteStop>? onStopTap;

  final double? latitude;
  final double? longitude;
  final List<UwayRouteStop> stops;
  final int? dropOffStopId;
  /// Fixed height, or null to fill the space the parent gives.
  final double? height;
  final bool showLegend;

  @override
  State<LiveLocationMap> createState() => _LiveLocationMapState();
}

class _LiveLocationMapState extends State<LiveLocationMap> {
  static const _followZoom = 17.5;

  final _controller = MapController();
  bool _following = true;
  bool _ready = false;

  bool get _hasBus => widget.latitude != null && widget.longitude != null;
  LatLng? get _bus => _hasBus ? LatLng(widget.latitude!, widget.longitude!) : null;

  @override
  void didUpdateWidget(LiveLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved = oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    if (!_ready || !_following || !moved) return;
    final bus = _bus;
    if (bus == null) return;
    // The first position zooms in on the bus; after that the rider's own zoom
    // level is kept while the bus moves.
    final firstFix = oldWidget.latitude == null || oldWidget.longitude == null;
    _controller.move(bus, firstFix ? _followZoom : _controller.camera.zoom);
  }

  /// Stops that sit almost on top of each other would paint as a pile of pins
  /// (slow and unreadable); one marker is kept per spot. The rider's drop-off
  /// stop is always kept.
  static List<UwayRouteStop> _spreadOut(List<UwayRouteStop> stops, int? keepId) {
    const distance = Distance();
    final kept = <UwayRouteStop>[];
    for (final stop in stops) {
      final point = LatLng(stop.latitude!, stop.longitude!);
      final crowded = kept.any((other) =>
          distance(point, LatLng(other.latitude!, other.longitude!)) < 30);
      if (!crowded || stop.id == keepId) kept.add(stop);
    }
    return kept;
  }

  void _followBus() {
    final bus = _bus;
    if (bus == null) return;
    setState(() => _following = true);
    _controller.move(bus, _followZoom);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final located = widget.stops.where((s) => s.hasLocation).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final line =
        located.map((s) => LatLng(s.latitude!, s.longitude!)).toList();
    final drawn = _spreadOut(located, widget.dropOffStopId);
    final bus = _bus;
    final fit = [...line, if (bus != null) bus];
    if (fit.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                // With a bus: start close to it. Without: show the whole route.
                initialCenter: bus ?? fit.first,
                initialZoom: bus != null ? _followZoom : 14,
                initialCameraFit: bus == null && fit.length > 1
                    ? CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(fit),
                        padding: const EdgeInsets.all(40),
                        maxZoom: 16,
                      )
                    : null,
                onMapReady: () => _ready = true,
                onPositionChanged: (camera, hasGesture) {
                  if (!hasGesture || !_following || bus == null) return;
                  // The map reports this while it lays itself out: change our
                  // state after the frame, never during it.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _following) setState(() => _following = false);
                  });
                },
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                uwayTileLayer(context),
                if (line.length > 1)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: line,
                      strokeWidth: 3,
                      color: scheme.primary.withValues(alpha: 0.4),
                    ),
                  ]),
                MarkerLayer(markers: [
                  for (final stop in drawn)
                    Marker(
                      point: LatLng(stop.latitude!, stop.longitude!),
                      width: 46,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onStopTap == null
                            ? null
                            : () => widget.onStopTap!(stop),
                        child: Opacity(
                          opacity: widget.selectableStopIds == null ||
                                  widget.selectableStopIds!.contains(stop.id)
                              ? 1
                              : 0.45,
                          child: RepaintBoundary(
                            child: isCampusStopName(stop.name)
                                ? const CampusMarker()
                                : StopMarker(
                                    highlighted:
                                        stop.id == widget.dropOffStopId,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  if (bus != null)
                    Marker(
                      point: bus,
                      width: 64,
                      height: 64,
                      child: const RepaintBoundary(child: BusMarker()),
                    ),
                ]),
              ],
            ),
            if (widget.showLegend)
              const Positioned(
                left: 8,
                top: 8,
                child: _MapLegend(),
              ),
            if (bus != null && !_following)
              Positioned(
                right: 8,
                top: 8,
                child: FilledButton.icon(
                  onPressed: _followBus,
                  // A positioned child has no width limit, and the app theme asks
                  // buttons for full width: give this one its own small size.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    visualDensity: VisualDensity.compact,
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Follow bus'),
                ),
              ),
            const Positioned(
              left: 8,
              bottom: 7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  child: Text('© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 10, color: Colors.black87)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bus: a large rounded badge with a bus icon and a soft halo, so it is
/// the first thing the eye finds on the map.
class BusMarker extends StatelessWidget {
  const BusMarker({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.18),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: const Icon(Icons.directions_bus_rounded,
              color: Colors.white, size: 26),
        ),
      ],
    );
  }
}

/// A pick-up / drop-off stop: a pin with a waiting-passenger symbol. The
/// passenger's chosen drop-off stop is drawn larger, in gold.
class StopMarker extends StatelessWidget {
  const StopMarker({this.highlighted = false, super.key});

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted
        ? UwayColors.gold
        : Theme.of(context).colorScheme.primary;
    final size = highlighted ? 46.0 : 36.0;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(Icons.location_on_rounded,
            size: size,
            color: color,
            shadows: const [Shadow(color: Colors.black38, blurRadius: 4)]),
        Positioned(
          top: size * 0.17,
          child: Container(
            width: size * 0.42,
            height: size * 0.42,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(highlighted ? Icons.flag_rounded : Icons.hail_rounded,
                size: size * 0.3, color: color),
          ),
        ),
      ],
    );
  }
}

/// A University City stop. It shows the University of Sharjah logo when the
/// file `assets/uos-logo.png` exists, and a school icon until then.
class CampusMarker extends StatelessWidget {
  const CampusMarker({super.key});

  // Checked once, so a missing logo file is not retried by every marker.
  static final Future<bool> _hasLogo = rootBundle
      .load('assets/uos-logo.png')
      .then((_) => true, onError: (_) => false);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: FutureBuilder<bool>(
        future: _hasLogo,
        builder: (context, snapshot) => snapshot.data == true
            ? ClipOval(
                child: Image.asset('assets/uos-logo.png', fit: BoxFit.contain),
              )
            : Icon(Icons.school_rounded, color: color, size: 24),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    Widget item(IconData icon, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.black87)),
          ],
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            item(Icons.directions_bus_rounded, 'Bus'),
            const SizedBox(height: 3),
            item(Icons.location_on_rounded, 'Stop'),
            const SizedBox(height: 3),
            item(Icons.school_rounded, 'University'),
          ],
        ),
      ),
    );
  }
}
