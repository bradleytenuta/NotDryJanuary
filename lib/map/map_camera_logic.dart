class MapCameraLogic {
  MapCameraLogic();

  double _cameraBearingDegrees = 0;

  double get cameraBearingDegrees => _cameraBearingDegrees;

  void setInitialBearingIfUnset(double heading) {
    if (_cameraBearingDegrees == 0 && heading != 0) {
      _cameraBearingDegrees = heading;
    }
  }

  double sanitizeHeading(double heading) {
    if (heading.isNaN || heading.isInfinite) {
      return _cameraBearingDegrees;
    }

    // Some sensors report headings in [-180, 180]. Normalize to [0, 360).
    final double normalizedHeading = ((heading % 360) + 360) % 360;

    // Geolocator uses -1 when heading is unavailable.
    if (heading == -1) {
      return _cameraBearingDegrees;
    }

    return normalizedHeading;
  }

  void updateBearingFromCompass(double heading) {
    _cameraBearingDegrees = sanitizeHeading(heading);
  }
}
