import 'dart:math' as math;

class MapCameraLogic {
  MapCameraLogic({
    this.minCameraUpdateInterval = const Duration(milliseconds: 80),
  });

  final Duration minCameraUpdateInterval;
  DateTime _lastCameraUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  double _cameraBearingDegrees = 0;
  double? _smoothedLatitude;
  double? _smoothedLongitude;

  static const double _maxStepMeters = 6.0;

  double get cameraBearingDegrees => _cameraBearingDegrees;

  ({double latitude, double longitude}) smoothPlayerPosition({
    required double latitude,
    required double longitude,
    required double horizontalAccuracyMeters,
  }) {
    final double? previousLat = _smoothedLatitude;
    final double? previousLng = _smoothedLongitude;

    if (previousLat == null || previousLng == null) {
      _smoothedLatitude = latitude;
      _smoothedLongitude = longitude;
      return (latitude: latitude, longitude: longitude);
    }

    final double distanceMeters = _distanceMeters(
      previousLat,
      previousLng,
      latitude,
      longitude,
    );

    final double accuracy = horizontalAccuracyMeters.isNaN ||
            horizontalAccuracyMeters.isInfinite
        ? 30
        : horizontalAccuracyMeters.clamp(1, 100).toDouble();

    final double baseAlpha = accuracy <= 8
        ? 0.32
        : accuracy <= 18
            ? 0.24
            : 0.16;

    // Clamp very large single-frame jumps to reduce visible teleports.
    final double jumpClamp = distanceMeters <= _maxStepMeters
        ? 1
        : (_maxStepMeters / distanceMeters).clamp(0.05, 1.0);
    final double alpha = (baseAlpha * jumpClamp).clamp(0.06, 0.38);

    _smoothedLatitude = previousLat + ((latitude - previousLat) * alpha);
    _smoothedLongitude = previousLng + ((longitude - previousLng) * alpha);

    return (
      latitude: _smoothedLatitude!,
      longitude: _smoothedLongitude!,
    );
  }

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

  double _distanceMeters(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const double earthRadiusMeters = 6371000;
    final double dLat = _toRadians(endLat - startLat);
    final double dLng = _toRadians(endLng - startLng);
    final double lat1 = _toRadians(startLat);
    final double lat2 = _toRadians(endLat);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180.0);

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
