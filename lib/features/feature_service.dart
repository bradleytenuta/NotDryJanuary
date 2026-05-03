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

    final List<Map<String, dynamic>> nearbyAreaFeatures = nearbyFeatures
        .map((PubFeature feature) => toGeoJsonFeature(feature))
        .toList(growable: false);

    return NearbyPubMapData(
      areaFeatureCollection: jsonEncode(<String, dynamic>{
        'type': 'FeatureCollection',
        'features': nearbyAreaFeatures,
      }),
      nearbyFeatureIds:
          nearbyFeatures.map((PubFeature feature) => feature.id).toList(growable: false),
    );
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