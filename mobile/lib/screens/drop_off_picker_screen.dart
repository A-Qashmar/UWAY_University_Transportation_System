import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/passenger_models.dart';
import '../theme/uway_theme.dart';
import '../widgets/uway_tile_layer.dart';

/// Lets the rider pick a drop-off point on a map. [options] are the only
/// points that can be chosen; [routeStops] are drawn as a faint line so the
/// rider can see where the bus goes. Points without coordinates stay
/// selectable from the list below the map. Pops with the chosen stop id.
class DropOffPickerScreen extends StatefulWidget {
  const DropOffPickerScreen({
    required this.title,
    required this.options,
    required this.routeStops,
    this.selectedId,
    super.key,
  });

  final String title;
  final List<UwayRouteStop> options;
  final List<UwayRouteStop> routeStops;
  final int? selectedId;

  @override
  State<DropOffPickerScreen> createState() => _DropOffPickerScreenState();
}

class _DropOffPickerScreenState extends State<DropOffPickerScreen> {
  int? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.options.any((s) => s.id == widget.selectedId)
        ? widget.selectedId
        : null;
  }

  LatLng _point(UwayRouteStop stop) =>
      LatLng(stop.latitude!, stop.longitude!);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mapped = widget.options.where((s) => s.hasLocation).toList();
    final line = widget.routeStops
        .where((s) => s.hasLocation)
        .map(_point)
        .toList(growable: false);
    final fitPoints = [
      ...mapped.map(_point),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          if (fitPoints.isNotEmpty)
            SizedBox(
              height: 300,
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: fitPoints.length > 1
                      ? CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(fitPoints),
                          padding: const EdgeInsets.all(48),
                          maxZoom: 16,
                        )
                      : null,
                  initialCenter: fitPoints.first,
                  initialZoom: 15,
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
                        color: scheme.primary.withValues(alpha: 0.35),
                      ),
                    ]),
                  MarkerLayer(markers: [
                    for (final stop in mapped)
                      Marker(
                        point: _point(stop),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = stop.id),
                          child: Icon(
                            Icons.location_on,
                            size: stop.id == _selected ? 44 : 34,
                            color: stop.id == _selected
                                ? scheme.primary
                                : UwayColors.gold,
                          ),
                        ),
                      ),
                  ]),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Map locations are not available for these points. Choose from the list.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                for (final stop in widget.options)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        stop.id == _selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: stop.id == _selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      title: Text(stop.name),
                      onTap: () => setState(() => _selected = stop.id),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  child: const Text('Confirm drop-off'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
