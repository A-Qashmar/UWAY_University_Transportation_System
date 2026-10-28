import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// The one map background used by every UWAY map.
///
/// Map tiles are 256-pixel images. On a phone with a dense screen they are
/// stretched, which looks blurry. [RetinaMode] asks for tiles one zoom level
/// deeper and draws them at half size, so they stay sharp. If the background
/// ever changes (another tile provider, satellite imagery), change it here.
TileLayer uwayTileLayer(BuildContext context) => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'edu.uway.uway_mobile',
      retinaMode: RetinaMode.isHighDensity(context),
      maxNativeZoom: 19,
      // Keep the previous tiles on screen while new ones load, instead of grey.
      keepBuffer: 3,
      panBuffer: 1,
    );
