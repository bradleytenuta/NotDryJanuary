import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../debug/location_override.dart';
import '../domain/pub_feature.dart';
import '../domain/nearby_pub_map_data.dart';
import '../features/feature_service.dart';
import '../features/pub_cache.dart';

const String nearbyPubsSourceId = 'nearby-pubs-source';
const String nearbyPubsLayerId = 'nearby-pubs-3d-layer';

const double _nearbyPubsRadiusMeters = 1000;
const String _debugTargetFeatureId = 'way/263674306';
const double _debugExtrusionHeightMeters = 250;

Future<void> addNearbyPubFeatures(mbx.MapboxMap mapboxMap) async {
  try {
    final geo.Position position = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
      ),
    );

    final ({double latitude, double longitude}) filterOrigin =
        resolveTrackingLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    final List<PubFeature> features =
        await PubsGeoJsonCache.instance.loadFeatures();

    final NearbyPubMapData nearbyMapData = FeatureService.buildNearbyMapData(
      features: features,
      userLatitude: filterOrigin.latitude,
      userLongitude: filterOrigin.longitude,
      radiusMeters: _nearbyPubsRadiusMeters,
    );

    debugPrint(
      'Mapbox pubs debug: nearbyCount=${nearbyMapData.nearbyFeatureIds.length}, '
      'target($_debugTargetFeatureId)Present=${nearbyMapData.nearbyFeatureIds.contains(_debugTargetFeatureId)}, '
      'origin=(${filterOrigin.latitude}, ${filterOrigin.longitude}), '
      'radius=$_nearbyPubsRadiusMeters',
    );

    final mbx.StyleManager style = mapboxMap.style;

    final mbx.Source? existingSource = await _tryGetSource(
      style: style,
      sourceId: nearbyPubsSourceId,
    );
    if (existingSource case final mbx.GeoJsonSource source) {
      await source.updateGeoJSON(nearbyMapData.areaFeatureCollection);
    } else {
      await style.addSource(
        mbx.GeoJsonSource(
          id: nearbyPubsSourceId,
          data: nearbyMapData.areaFeatureCollection,
        ),
      );
    }

    final mbx.FillExtrusionLayer debugLayer = mbx.FillExtrusionLayer(
      id: nearbyPubsLayerId,
      sourceId: nearbyPubsSourceId,
      fillExtrusionColor: 0xFFD32F2F,
      fillExtrusionHeight: _debugExtrusionHeightMeters,
      fillExtrusionBase: 0,
      fillExtrusionOpacity: 0.85,
      fillExtrusionVerticalGradient: true,
    );

    final mbx.Layer? existingLayer = await _tryGetLayer(
      style: style,
      layerId: nearbyPubsLayerId,
    );
    if (existingLayer == null) {
      await style.addLayer(debugLayer);
    } else {
      await style.updateLayer(debugLayer);
    }
  } catch (error, stackTrace) {
    debugPrint('Mapbox pubs debug error: $error');
    debugPrint('Mapbox pubs debug stackTrace: $stackTrace');
  }
}

Future<mbx.Source?> _tryGetSource({
  required mbx.StyleManager style,
  required String sourceId,
}) async {
  try {
    return await style.getSource(sourceId);
  } catch (error) {
    if (_isStyleObjectMissingError(error)) {
      return null;
    }
    rethrow;
  }
}

Future<mbx.Layer?> _tryGetLayer({
  required mbx.StyleManager style,
  required String layerId,
}) async {
  try {
    return await style.getLayer(layerId);
  } catch (error) {
    if (_isStyleObjectMissingError(error)) {
      return null;
    }
    rethrow;
  }
}

bool _isStyleObjectMissingError(Object error) {
  final String message = error.toString();
  return message.contains('is not in style');
}