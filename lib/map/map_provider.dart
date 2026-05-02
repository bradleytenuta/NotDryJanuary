import 'package:flutter/material.dart';

abstract class MapProviderController {
  Future<void> moveCamera({
    required double latitude,
    required double longitude,
    required double tilt,
    required double zoom,
    required double bearing,
  });
}

typedef MapProviderBuilder = Widget Function({
  required ValueChanged<MapProviderController> onControllerCreated,
  required VoidCallback onMapReady,
  required double initialLatitude,
  required double initialLongitude,
  required double initialZoom,
  required double initialTilt,
});
