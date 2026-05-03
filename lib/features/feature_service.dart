import 'dart:convert';

import 'package:geolocator/geolocator.dart';

import '../domain/nearby_pub_map_data.dart';
import '../domain/pub_feature.dart';
import 'polygon_ring_expander.dart';

class FeatureService {
  const FeatureService._();

  static const double _polygonExpansionMeters = 1.0;

  static String? stringOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    final String output = value.toString().trim();
    if (output.isEmpty) {
      return null;
    }
    return output;
  }

  static List<List<List<double>>>? parsePolygonCoordinates(dynamic raw) {
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

  static NearbyPubMapData buildNearbyMapData({
    required List<PubFeature> features,
    required double userLatitude,
    required double userLongitude,
    required double radiusMeters,
    required Iterable<String> visitedPubIds,
  }) {
    final List<PubFeature> nearbyFeatures = features
        .where(
          (PubFeature feature) => hasPointWithin(
            coordinates: feature.coordinates,
            userLatitude: userLatitude,
            userLongitude: userLongitude,
            radiusMeters: radiusMeters,
          ),
        )
        .toList(growable: false);

    return buildNearbyMapDataFromNearbyFeatures(
      nearbyFeatures: nearbyFeatures,
      visitedPubIds: visitedPubIds,
    );
  }

  static NearbyPubMapData buildNearbyMapDataFromNearbyFeatures({
    required List<PubFeature> nearbyFeatures,
    required Iterable<String> visitedPubIds,
  }) {
    final Set<String> visitedIds = visitedPubIds.toSet();

    final List<Map<String, dynamic>> visitedAreaFeatures = nearbyFeatures
        .where((PubFeature feature) => visitedIds.contains(feature.id))
        .map((PubFeature feature) => toGeoJsonFeature(feature))
        .toList(growable: false);

    final List<Map<String, dynamic>> unvisitedAreaFeatures = nearbyFeatures
        .where((PubFeature feature) => !visitedIds.contains(feature.id))
        .map((PubFeature feature) => toGeoJsonFeature(feature))
        .toList(growable: false);

    return NearbyPubMapData(
      visitedAreaFeatureCollection:
          _toFeatureCollectionJson(visitedAreaFeatures),
      unvisitedAreaFeatureCollection:
          _toFeatureCollectionJson(unvisitedAreaFeatures),
      nearbyFeatureIds:
          nearbyFeatures.map((PubFeature feature) => feature.id).toList(growable: false),
      visitedNearbyFeatureIds: nearbyFeatures
        .where((PubFeature feature) => visitedIds.contains(feature.id))
        .map((PubFeature feature) => feature.id)
        .toList(growable: false),
      unvisitedNearbyFeatureIds: nearbyFeatures
        .where((PubFeature feature) => !visitedIds.contains(feature.id))
        .map((PubFeature feature) => feature.id)
        .toList(growable: false),
    );
  }

  static String _toFeatureCollectionJson(List<Map<String, dynamic>> features) {
    return jsonEncode(<String, dynamic>{
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  static Map<String, dynamic> toGeoJsonFeature(PubFeature feature) {
    return <String, dynamic>{
      'type': 'Feature',
      'id': feature.id,
      'properties': <String, dynamic>{
        'sourceId': feature.id,
        'brand': feature.brand,
        'name': feature.name,
        'city': feature.city,
        'street': feature.street,
        'housenumber': feature.houseNumber,
        'postcode': feature.postcode,
        'wheelchair': feature.wheelchair,
      },
      'geometry': <String, dynamic>{
        'type': 'Polygon',
        'coordinates': PolygonRingExpander.expandPolygonCoordinates(
          coordinates: feature.coordinates,
          expansionMeters: _polygonExpansionMeters,
        ),
      },
    };
  }

  static List<String> findContainingFeatureIds({
    required List<PubFeature> features,
    required double userLatitude,
    required double userLongitude,
  }) {
    return features
        .where(
          (PubFeature feature) => isPointInsideFeature(
            coordinates: feature.coordinates,
            userLatitude: userLatitude,
            userLongitude: userLongitude,
          ),
        )
        .map((PubFeature feature) => feature.id)
        .toList(growable: false);
  }

  static bool isPointInsideFeature({
    required List<List<List<double>>> coordinates,
    required double userLatitude,
    required double userLongitude,
  }) {
    if (coordinates.isEmpty) {
      return false;
    }

    final List<List<double>> outerRing = coordinates.first;
    if (!_isPointInRing(
      ring: outerRing,
      latitude: userLatitude,
      longitude: userLongitude,
    )) {
      return false;
    }

    for (final List<List<double>> hole in coordinates.skip(1)) {
      if (_isPointInRing(
        ring: hole,
        latitude: userLatitude,
        longitude: userLongitude,
      )) {
        return false;
      }
    }

    return true;
  }

  static bool hasPointWithin({
    required List<List<List<double>>> coordinates,
    required double userLatitude,
    required double userLongitude,
    required double radiusMeters,
  }) {
    for (final List<double> coordinate in _allCoordinatePairs(coordinates)) {
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

  static Iterable<List<double>> _allCoordinatePairs(
    List<List<List<double>>> coordinates,
  ) sync* {
    for (final List<List<double>> ring in coordinates) {
      yield* ring;
    }
  }

  static bool _isPointInRing({
    required List<List<double>> ring,
    required double latitude,
    required double longitude,
  }) {
    if (ring.length < 3) {
      return false;
    }

    bool isInside = false;
    for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final List<double> current = ring[i];
      final List<double> previous = ring[j];

      final double x1 = previous[0];
      final double y1 = previous[1];
      final double x2 = current[0];
      final double y2 = current[1];

      if (_isPointOnSegment(
        pointLongitude: longitude,
        pointLatitude: latitude,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
      )) {
        return true;
      }

      final bool crossesLatitude = (y1 > latitude) != (y2 > latitude);
      if (!crossesLatitude) {
        continue;
      }

      final double intersectionLongitude =
          ((x2 - x1) * (latitude - y1) / (y2 - y1)) + x1;
      if (longitude < intersectionLongitude) {
        isInside = !isInside;
      }
    }

    return isInside;
  }

  static bool _isPointOnSegment({
    required double pointLongitude,
    required double pointLatitude,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
  }) {
    const double epsilon = 1e-10;

    final double cross =
        ((pointLatitude - y1) * (x2 - x1)) - ((pointLongitude - x1) * (y2 - y1));
    if (cross.abs() > epsilon) {
      return false;
    }

    final double dot =
        ((pointLongitude - x1) * (x2 - x1)) + ((pointLatitude - y1) * (y2 - y1));
    if (dot < -epsilon) {
      return false;
    }

    final double squaredLength =
        ((x2 - x1) * (x2 - x1)) + ((y2 - y1) * (y2 - y1));
    if (dot - squaredLength > epsilon) {
      return false;
    }

    return true;
  }

  static List<double>? _parsePointList(dynamic pointRaw) {
    if (pointRaw is! List || pointRaw.length < 2) {
      return null;
    }

    final dynamic longitudeValue = pointRaw[0];
    final dynamic latitudeValue = pointRaw[1];
    final num? longitudeRaw = longitudeValue is num ? longitudeValue : null;
    final num? latitudeRaw = latitudeValue is num ? latitudeValue : null;
    if (longitudeRaw == null || latitudeRaw == null) {
      return null;
    }

    return <double>[longitudeRaw.toDouble(), latitudeRaw.toDouble()];
  }
}