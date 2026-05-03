import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../debug/location_override.dart';
import '../domain/pub_feature.dart';
import '../domain/nearby_pub_map_data.dart';
import '../features/feature_service.dart';
import '../features/pub_cache.dart';
import '../user_session_store.dart';

const String visitedNearbyPubsSourceId = 'nearby-pubs-visited-source';
const String unvisitedNearbyPubsSourceId = 'nearby-pubs-unvisited-source';
const String visitedNearbyPubsLayerId = 'nearby-pubs-visited-3d-layer';
const String unvisitedNearbyPubsLayerId = 'nearby-pubs-unvisited-3d-layer';
const List<String> nearbyPubsLayerIds = <String>[
  visitedNearbyPubsLayerId,
  unvisitedNearbyPubsLayerId,
];

const double nearbyPubsRefreshDistanceMeters = 500;
const double _nearbyPubsRadiusMeters = 1000;
const String _debugTargetFeatureId = 'way/263674306';
const double _debugExtrusionHeightMeters = 150;
const int _visitedExtrusionColor = 0xFF2E7D32;
const int _unvisitedExtrusionColor = 0xFFD32F2F;

Future<bool> addNearbyPubFeatures(
  mbx.MapboxMap mapboxMap, {
  double? latitude,
  double? longitude,
  bool forceRefresh = false,
}) async {
  try {
    final ({double latitude, double longitude}) filterOrigin;
    if (latitude != null && longitude != null) {
      filterOrigin = resolveTrackingLocation(
        latitude: latitude,
        longitude: longitude,
      );
    } else {
      final geo.Position position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );

      filterOrigin = resolveTrackingLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }

    final List<PubFeature> nearbyFeatures =
        await PubsGeoJsonCache.instance.loadNearbyFeatures(
      userLatitude: filterOrigin.latitude,
      userLongitude: filterOrigin.longitude,
      radiusMeters: _nearbyPubsRadiusMeters,
      refreshDistanceMeters: nearbyPubsRefreshDistanceMeters,
      forceRefresh: forceRefresh,
    );
    final UserSessionData userSession =
        await UserSessionStore.instance.loadOrCreate();

    final NearbyPubMapData nearbyMapData =
        FeatureService.buildNearbyMapDataFromNearbyFeatures(
      nearbyFeatures: nearbyFeatures,
      visitedPubIds: userSession.visitedPubs,
    );

    debugPrint(
      'Mapbox pubs debug: nearbyCount=${nearbyMapData.nearbyFeatureIds.length}, '
      'nearbyVisitedCount=${nearbyMapData.visitedNearbyFeatureIds.length}, '
      'nearbyUnvisitedCount=${nearbyMapData.unvisitedNearbyFeatureIds.length}, '
      'sessionVisitedCount=${userSession.visitedPubs.length}, '
      'target($_debugTargetFeatureId)Present=${nearbyMapData.nearbyFeatureIds.contains(_debugTargetFeatureId)}, '
      'origin=(${filterOrigin.latitude}, ${filterOrigin.longitude}), '
      'radius=$_nearbyPubsRadiusMeters',
    );

    final mbx.StyleManager style = mapboxMap.style;

    final mbx.Source? existingVisitedSource = await _tryGetSource(
      style: style,
      sourceId: visitedNearbyPubsSourceId,
    );
    if (existingVisitedSource case final mbx.GeoJsonSource source) {
      await source.updateGeoJSON(nearbyMapData.visitedAreaFeatureCollection);
    } else {
      await style.addSource(
        mbx.GeoJsonSource(
          id: visitedNearbyPubsSourceId,
          data: nearbyMapData.visitedAreaFeatureCollection,
        ),
      );
    }

    final mbx.Source? existingUnvisitedSource = await _tryGetSource(
      style: style,
      sourceId: unvisitedNearbyPubsSourceId,
    );
    if (existingUnvisitedSource case final mbx.GeoJsonSource source) {
      await source.updateGeoJSON(nearbyMapData.unvisitedAreaFeatureCollection);
    } else {
      await style.addSource(
        mbx.GeoJsonSource(
          id: unvisitedNearbyPubsSourceId,
          data: nearbyMapData.unvisitedAreaFeatureCollection,
        ),
      );
    }

    final mbx.FillExtrusionLayer visitedLayer = mbx.FillExtrusionLayer(
      id: visitedNearbyPubsLayerId,
      sourceId: visitedNearbyPubsSourceId,
      fillExtrusionColor: _visitedExtrusionColor,
      fillExtrusionHeight: _debugExtrusionHeightMeters,
      fillExtrusionBase: 0,
      fillExtrusionOpacity: 0.85,
      fillExtrusionVerticalGradient: true,
    );

    final mbx.FillExtrusionLayer unvisitedLayer = mbx.FillExtrusionLayer(
      id: unvisitedNearbyPubsLayerId,
      sourceId: unvisitedNearbyPubsSourceId,
      fillExtrusionColor: _unvisitedExtrusionColor,
      fillExtrusionHeight: _debugExtrusionHeightMeters,
      fillExtrusionBase: 0,
      fillExtrusionOpacity: 0.85,
      fillExtrusionVerticalGradient: true,
    );

    final mbx.Layer? existingVisitedLayer = await _tryGetLayer(
      style: style,
      layerId: visitedNearbyPubsLayerId,
    );
    if (existingVisitedLayer == null) {
      await style.addLayer(visitedLayer);
    } else {
      await style.updateLayer(visitedLayer);
    }

    final mbx.Layer? existingUnvisitedLayer = await _tryGetLayer(
      style: style,
      layerId: unvisitedNearbyPubsLayerId,
    );
    if (existingUnvisitedLayer == null) {
      await style.addLayer(unvisitedLayer);
    } else {
      await style.updateLayer(unvisitedLayer);
    }

    return true;
  } catch (error, stackTrace) {
    debugPrint('Mapbox pubs debug error: $error');
    debugPrint('Mapbox pubs debug stackTrace: $stackTrace');
    return false;
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