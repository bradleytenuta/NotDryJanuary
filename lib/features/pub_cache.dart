import 'dart:convert';

import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter/services.dart';

import '../domain/pub_feature.dart';
import 'feature_service.dart';

class PubsGeoJsonCache {
  PubsGeoJsonCache._();

  static final PubsGeoJsonCache instance = PubsGeoJsonCache._();

  static const String _assetPath = 'assets/geojson/london-pubs.geojson';
  static const double nearbyRenderRadiusMeters = 1000;
  static const double nearbyRenderRefreshDistanceMeters = 500;
  static const double visitedCheckRadiusMeters = 100;
  static const double visitedCheckRefreshDistanceMeters = 5;

  List<PubFeature>? _cachedFeatures;
  final Map<String, _NearbyFeaturesWindow> _cachedNearbyFeaturesByRadius =
      <String, _NearbyFeaturesWindow>{};

  Future<void> warmUp() async {
    // Rebuild caches from disk on each app start for deterministic startup state.
    _cachedFeatures = null;
    _cachedNearbyFeaturesByRadius.clear();
    await loadFeatures();
  }

  Future<void> buildStartupNearbyCaches({
    required double userLatitude,
    required double userLongitude,
  }) async {
    await loadNearbyFeatures(
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      radiusMeters: nearbyRenderRadiusMeters,
      refreshDistanceMeters: nearbyRenderRefreshDistanceMeters,
      forceRefresh: true,
    );

    await loadNearbyFeatures(
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      radiusMeters: visitedCheckRadiusMeters,
      refreshDistanceMeters: visitedCheckRefreshDistanceMeters,
      forceRefresh: true,
    );
  }

  Future<List<PubFeature>> loadFeatures() async {
    final List<PubFeature>? cached = _cachedFeatures;
    if (cached != null) {
      return cached;
    }

    final String raw = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
    final List<dynamic> featuresRaw =
        decoded['features'] as List<dynamic>? ?? const <dynamic>[];

    final List<PubFeature> parsed = <PubFeature>[];

    for (final dynamic featureRaw in featuresRaw) {
      final Map<String, dynamic>? feature = featureRaw as Map<String, dynamic>?;
      final Map<String, dynamic>? geometry =
          feature?['geometry'] as Map<String, dynamic>?;

      final List<List<List<double>>>? coordinates =
          FeatureService.parsePolygonCoordinates(geometry?['coordinates']);

      if (_skipFeature(
        feature: feature,
        geometry: geometry,
        coordinates: coordinates,
      )) {
        continue;
      }

      final Map<String, dynamic> safeFeature = feature!;
      final List<List<List<double>>> safeCoordinates = coordinates!;
      final Map<String, dynamic>? properties =
          safeFeature['properties'] as Map<String, dynamic>?;

      final String id =
          (safeFeature['id'] as String?) ??
          properties?['@id'] as String? ??
          '';

      parsed.add(
        PubFeature(
          id: id,
          brand: FeatureService.stringOrNull(
            properties?['brand'],
          ),
          name: FeatureService.stringOrNull(
                properties?['name'],
              ) ??
              'Unknown',
          city: FeatureService.stringOrNull(
                properties?['addr:city'],
              ) ??
              'Unknown',
          street: FeatureService.stringOrNull(
                properties?['addr:street'],
              ) ??
              'Unknown',
          houseNumber: FeatureService.stringOrNull(
                properties?['addr:housenumber'],
              ) ??
              'Unknown',
          postcode: FeatureService.stringOrNull(
                properties?['addr:postcode'],
              ) ??
              'Unknown',
          wheelchair: FeatureService.stringOrNull(
                properties?['wheelchair'],
              ) ??
              'Unknown',
          coordinates: safeCoordinates,
        ),
      );
    }

    _cachedFeatures = parsed;
    return parsed;
  }

  Future<List<PubFeature>> loadNearbyFeatures({
    required double userLatitude,
    required double userLongitude,
    required double radiusMeters,
    required double refreshDistanceMeters,
    bool forceRefresh = false,
  }) async {
    final String radiusKey = _radiusToCacheKey(radiusMeters);
    final _NearbyFeaturesWindow? existingWindow =
        _cachedNearbyFeaturesByRadius[radiusKey];

    if (!forceRefresh && existingWindow != null) {
      final double distanceFromWindowOrigin = geo.Geolocator.distanceBetween(
        existingWindow.originLatitude,
        existingWindow.originLongitude,
        userLatitude,
        userLongitude,
      );

      if (distanceFromWindowOrigin < refreshDistanceMeters) {
        return existingWindow.features;
      }
    }

    final List<PubFeature> allFeatures = await loadFeatures();
    final List<PubFeature> nearbyFeatures = allFeatures
        .where(
          (PubFeature feature) => FeatureService.hasPointWithin(
            coordinates: feature.coordinates,
            userLatitude: userLatitude,
            userLongitude: userLongitude,
            radiusMeters: radiusMeters,
          ),
        )
        .toList(growable: false);

    _cachedNearbyFeaturesByRadius[radiusKey] = _NearbyFeaturesWindow(
      originLatitude: userLatitude,
      originLongitude: userLongitude,
      features: nearbyFeatures,
    );

    return nearbyFeatures;
  }

  String _radiusToCacheKey(double radiusMeters) {
    return radiusMeters.toStringAsFixed(3);
  }

  bool _skipFeature({
    required Map<String, dynamic>? feature,
    required Map<String, dynamic>? geometry,
    required List<List<List<double>>>? coordinates,
  }) {
    if (feature == null) {
      return true;
    }

    if (geometry == null) {
      return true;
    }

    final String geometryType = (geometry['type'] as String?) ?? '';
    if (geometryType != 'Polygon') {
      return true;
    }

    if (coordinates == null || coordinates.isEmpty) {
      return true;
    }

    return false;
  }
}

class _NearbyFeaturesWindow {
  _NearbyFeaturesWindow({
    required this.originLatitude,
    required this.originLongitude,
    required this.features,
  });

  final double originLatitude;
  final double originLongitude;
  final List<PubFeature> features;
}