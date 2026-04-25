import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapCameraLogic {
  MapCameraLogic({
    this.minCameraUpdateInterval = const Duration(milliseconds: 80),
  });

  final Duration minCameraUpdateInterval;
  DateTime _lastCameraUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  double _cameraBearingDegrees = 0;

  double get cameraBearingDegrees => _cameraBearingDegrees;

  void setInitialBearingIfUnset(double heading) {
    if (_cameraBearingDegrees == 0 && heading != 0) {
      _cameraBearingDegrees = heading;
    }
  }

  double sanitizeHeading(double heading) {
    if (heading.isNaN || heading.isInfinite || heading < 0) {
      return _cameraBearingDegrees;
    }

    return heading % 360;
  }

  bool canProcessCompassUpdate(DateTime now) {
    if (now.difference(_lastCameraUpdate) < minCameraUpdateInterval) {
      return false;
    }
    _lastCameraUpdate = now;
    return true;
  }

  void updateBearingFromCompass(double heading) {
    final double normalizedHeading = heading % 360;
    _cameraBearingDegrees = _smoothBearing(
      current: _cameraBearingDegrees,
      target: normalizedHeading,
    );
  }

  Future<void> updateCamera({
    required GoogleMapController? controller,
    required LatLng target,
    required double tilt,
    required double zoom,
  }) async {
    if (controller == null) return;

    await controller.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          tilt: tilt,
          zoom: zoom,
          bearing: _cameraBearingDegrees,
        ),
      ),
    );
  }

  double _smoothBearing({required double current, required double target}) {
    if (current == 0) return target;

    final double delta = ((target - current + 540) % 360) - 180;
    if (delta.abs() <= 1.0) {
      return target;
    }

    final double step = delta * 0.35;
    return (current + step + 360) % 360;
  }
}
