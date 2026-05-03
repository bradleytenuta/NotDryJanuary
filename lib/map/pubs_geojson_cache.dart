import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class PubsGeoJsonCache {
  PubsGeoJsonCache._();

  static final PubsGeoJsonCache instance = PubsGeoJsonCache._();

  static const String _assetPath = 'assets/geojson/london-pubs.geojson';

  List<_PubPolygonFeature>? _cachedFeatures;

  Future<void> warmUp() async {
    await _loadFeatures();
  }

  Future<NearbyPubMapData> buildNearbyMapData({
    required double userLatitude,
    required double userLongitude,
    required double radiusMeters,
  }) async {
    final List<_PubPolygonFeature> features = await _loadFeatures();

    final List<_PubPolygonFeature> nearbyFeatures = features
        .where(
          (_PubPolygonFeature feature) => feature.hasPointWithin(
            userLatitude: userLatitude,
            userLongitude: userLongitude,
            radiusMeters: radiusMeters,
          ),
        )
        .toList(growable: false);

    final List<Map<String, dynamic>> nearbyAreaFeatures = nearbyFeatures
        .map((feature) => feature.toGeoJsonFeature())
        .toList(growable: false);

    return NearbyPubMapData(
      areaFeatureCollection: jsonEncode(<String, dynamic>{
        'type': 'FeatureCollection',
        'features': nearbyAreaFeatures,
      }),
      nearbyFeatureIds: nearbyFeatures.map((feature) => feature.id).toList(growable: false),
    );
  }

  Future<List<_PubPolygonFeature>> _loadFeatures() async {
    final List<_PubPolygonFeature>? cached = _cachedFeatures;
    if (cached != null) {
      return cached;
    }

    final String raw = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
    final List<dynamic> featuresRaw =
        decoded['features'] as List<dynamic>? ?? const <dynamic>[];

    final List<_PubPolygonFeature> parsed = <_PubPolygonFeature>[];

    for (final dynamic featureRaw in featuresRaw) {
      final Map<String, dynamic>? feature = featureRaw as Map<String, dynamic>?;
      if (feature == null) {
        continue;
      }

      final Map<String, dynamic>? geometry =
          feature['geometry'] as Map<String, dynamic>?;
      if (geometry == null) {
        continue;
      }

      final String geometryType = (geometry['type'] as String?) ?? '';
      if (geometryType != 'Polygon') {
        continue;
      }

      final List<List<List<double>>>? coordinates =
          _parsePolygonCoordinates(geometry['coordinates']);
      if (coordinates == null || coordinates.isEmpty) {
        continue;
      }

      final String id =
          (feature['id'] as String?) ??
          (feature['properties'] as Map<String, dynamic>?)?['@id'] as String? ??
          '';

      parsed.add(
        _PubPolygonFeature(
          id: id,
          brand: _stringOrNull((feature['properties'] as Map<String, dynamic>?)?['brand']),
          name: _stringOrNull((feature['properties'] as Map<String, dynamic>?)?['name']) ?? 'Unknown',
          city: _stringOrNull((feature['properties'] as Map<String, dynamic>?)?['addr:city']) ?? 'Unknown',
          street: _stringOrNull((feature['properties'] as Map<String, dynamic>?)?['addr:street']) ?? 'Unknown',
          houseNumber: _stringOrNull((feature['properties'] as Map<String, dynamic>?)?['addr:housenumber']) ?? 'Unknown',
          postcode: _stringOrNull((feature['properties'] as Map<String, dynamic>?)?['addr:postcode']) ?? 'Unknown',
          wheelchair: _stringOrNull((feature['properties'] as Map<String, dynamic>?)?['wheelchair']) ?? 'Unknown',
          coordinates: coordinates,
        ),
      );
    }

    _cachedFeatures = parsed;
    return parsed;
  }

  List<List<List<double>>>? _parsePolygonCoordinates(dynamic raw) {
    if (raw is! List) {
      return null;
    }

    final List<List<List<double>>> rings = <List<List<double>>>[];

    for (final dynamic ringRaw in raw) {
      if (ringRaw is! List) {
        continue;
      }

      final List<List<double>> ring = <List<double>>[];
      for (final dynamic pointRaw in ringRaw) {
        final List<double>? point = _parsePointList(pointRaw);
        if (point != null) {
          ring.add(point);
        }
      }

      if (ring.length >= 3) {
        rings.add(ring);
      }
    }

    return rings;
  }

  List<double>? _parsePointList(dynamic pointRaw) {
    if (pointRaw is! List || pointRaw.length < 2) {
      return null;
    }

    final num? longitudeRaw = pointRaw[0] as num?;
    final num? latitudeRaw = pointRaw[1] as num?;
    if (longitudeRaw == null || latitudeRaw == null) {
      return null;
    }

    return <double>[longitudeRaw.toDouble(), latitudeRaw.toDouble()];
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    final String output = value.toString().trim();
    if (output.isEmpty) {
      return null;
    }
    return output;
  }
}

class NearbyPubMapData {
  const NearbyPubMapData({
    required this.areaFeatureCollection,
    required this.nearbyFeatureIds,
  });

  final String areaFeatureCollection;
  final List<String> nearbyFeatureIds;
}

class _PubPolygonFeature {
  static const double _polygonExpansionMeters = 1.0;
  static const double _metersPerDegreeLatitude = 111320.0;

  const _PubPolygonFeature({
    required this.id,
    required this.brand,
    required this.name,
    required this.city,
    required this.street,
    required this.houseNumber,
    required this.postcode,
    required this.wheelchair,
    required this.coordinates,
  });

  final String id;
  final String? brand;
  final String name;
  final String city;
  final String street;
  final String houseNumber;
  final String postcode;
  final String wheelchair;
  final List<List<List<double>>> coordinates;

  bool hasPointWithin({
    required double userLatitude,
    required double userLongitude,
    required double radiusMeters,
  }) {
    for (final List<double> coordinate in _allCoordinatePairs()) {
      final double distance = Geolocator.distanceBetween(
        userLatitude,
        userLongitude,
        coordinate[1],
        coordinate[0],
      );
      if (distance <= radiusMeters) {
        return true;
      }
    }

    return false;
  }

  Iterable<List<double>> _allCoordinatePairs() sync* {
    for (final List<List<double>> ring in coordinates) {
      yield* ring;
    }
  }

  Map<String, dynamic> toGeoJsonFeature() {
    return <String, dynamic>{
      'type': 'Feature',
      'id': id,
      'properties': <String, dynamic>{
        'sourceId': id,
        'brand': brand,
        'name': name,
        'city': city,
        'street': street,
        'housenumber': houseNumber,
        'postcode': postcode,
        'wheelchair': wheelchair,
      },
      'geometry': <String, dynamic>{
        'type': 'Polygon',
        'coordinates': _expandedCoordinates(),
      },
    };
  }

  List<List<List<double>>> _expandedCoordinates() {
    return coordinates
        .map((List<List<double>> ring) => _expandRing(ring))
        .toList(growable: false);
  }

  List<List<double>> _expandRing(List<List<double>> ring) {
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

      final double scale =
          (distanceMeters + _polygonExpansionMeters) / distanceMeters;
      final double expandedDxMeters = dxMeters * scale;
      final double expandedDyMeters = dyMeters * scale;

      return <double>[
        centroid.longitude + (expandedDxMeters / metersPerDegreeLongitude),
        centroid.latitude + (expandedDyMeters / _metersPerDegreeLatitude),
      ];
    }).toList(growable: false);
  }

  ({double latitude, double longitude}) _centroidOfRing(List<List<double>> ring) {
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
