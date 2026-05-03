const bool useDebugLocationOverride = true;
const double debugOverrideLatitude = 51.497819;
const double debugOverrideLongitude = -0.142396;

({double latitude, double longitude}) resolveTrackingLocation({
  required double latitude,
  required double longitude,
}) {
  if (useDebugLocationOverride) {
    return (
      latitude: debugOverrideLatitude,
      longitude: debugOverrideLongitude,
    );
  }

  return (
    latitude: latitude,
    longitude: longitude,
  );
}
