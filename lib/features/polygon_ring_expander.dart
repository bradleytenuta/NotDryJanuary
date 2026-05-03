import 'dart:math' as math;

class PolygonRingExpander {
  const PolygonRingExpander._();

  static const double _metersPerDegreeLatitude = 111320.0;

  static List<List<List<double>>> expandPolygonCoordinates({
    required List<List<List<double>>> coordinates,
    required double expansionMeters,
  }) {
    return coordinates
        .map(
          (List<List<double>> ring) => _expandRing(
            ring: ring,
            expansionMeters: expansionMeters,
          ),
        )
        .toList(growable: false);
  }

  static List<List<double>> _expandRing({
    required List<List<double>> ring,
    required double expansionMeters,
  }) {
    if (ring.length < 3) {
      return ring;
    }

    final ({double latitude, double longitude}) centroid = _centroidOfRing(ring);
    final double metersPerDegreeLongitude =
        _metersPerDegreeLatitude * math.cos(centroid.latitude * math.pi / 180.0);

    if (metersPerDegreeLongitude.abs() < 0.000001) {
      return ring;
    }

    return ring.map((List<double> point) {
      final double longitude = point[0];
      final double latitude = point[1];

      final double dxMeters =
          (longitude - centroid.longitude) * metersPerDegreeLongitude;
      final double dyMeters =
          (latitude - centroid.latitude) * _metersPerDegreeLatitude;

      final double distanceMeters = math.sqrt(
        (dxMeters * dxMeters) + (dyMeters * dyMeters),
      );

      if (distanceMeters == 0) {
        return point;
      }

      final double scale = (distanceMeters + expansionMeters) / distanceMeters;
      final double expandedDxMeters = dxMeters * scale;
      final double expandedDyMeters = dyMeters * scale;

      return <double>[
        centroid.longitude + (expandedDxMeters / metersPerDegreeLongitude),
        centroid.latitude + (expandedDyMeters / _metersPerDegreeLatitude),
      ];
    }).toList(growable: false);
  }

  static ({double latitude, double longitude}) _centroidOfRing(
    List<List<double>> ring,
  ) {
    double longitudeSum = 0;
    double latitudeSum = 0;

    for (final List<double> point in ring) {
      longitudeSum += point[0];
      latitudeSum += point[1];
    }

    final double count = ring.length.toDouble();
    return (
      latitude: latitudeSum / count,
      longitude: longitudeSum / count,
    );
  }
}