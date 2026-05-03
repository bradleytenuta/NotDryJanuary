import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/pub_feature.dart';
import 'feature_service.dart';

class PubsGeoJsonCache {
  PubsGeoJsonCache._();

  static final PubsGeoJsonCache instance = PubsGeoJsonCache._();

  static const String _assetPath = 'assets/geojson/london-pubs.geojson';

  List<PubFeature>? _cachedFeatures;

  Future<void> warmUp() async {
    await loadFeatures();
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