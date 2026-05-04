import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../../debug/location_override.dart';
import '../../domain/pub_feature.dart';
import '../../domain/nearby_pub_map_data.dart';
import '../../features/feature_service.dart';
import '../../features/pub_cache.dart';
import '../../user_session_store.dart';

const String visitedNearbyPubsSourceId = 'nearby-pubs-visited-source';
const String unvisitedNearbyPubsSourceId = 'nearby-pubs-unvisited-source';
const String visitedNearbyPubsBottomLayerId =
  'nearby-pubs-visited-3d-bottom-layer';
const String visitedNearbyPubsMiddleLayerId =
  'nearby-pubs-visited-3d-middle-layer';
const String visitedNearbyPubsTopLayerId = 'nearby-pubs-visited-3d-top-layer';
const String unvisitedNearbyPubsBottomLayerId =
  'nearby-pubs-unvisited-3d-bottom-layer';
const String unvisitedNearbyPubsMiddleLayerId =
  'nearby-pubs-unvisited-3d-middle-layer';
const String unvisitedNearbyPubsTopLayerId =
  'nearby-pubs-unvisited-3d-top-layer';
const String _greeneKingBrandValue = 'Greene King';
const String _greeneKingBrandAssetPath = 'assets/icons/branding/greene-king.png';
const List<String> nearbyPubsLayerIds = <String>[
  visitedNearbyPubsBottomLayerId,
  visitedNearbyPubsMiddleLayerId,
  visitedNearbyPubsTopLayerId,
  unvisitedNearbyPubsBottomLayerId,
  unvisitedNearbyPubsMiddleLayerId,
  unvisitedNearbyPubsTopLayerId,
];

const double nearbyPubsRefreshDistanceMeters = 500;
const double _nearbyPubsRadiusMeters = 1000;
const String _debugTargetFeatureId = 'way/263674306';
const double _debugExtrusionHeightMeters = 150;
const int _visitedExtrusionColor = 0xFF2E7D32;
const int _unvisitedExtrusionColor = 0xFFD32F2F;
const double _greeneKingSymbolZOffsetMeters = 175;
const double _greeneKingIconSize = 0.2;

final Expando<mbx.PointAnnotationManager> _greeneKingAnnotationManagers =
  Expando<mbx.PointAnnotationManager>('greeneKingAnnotationManagers');
Uint8List? _cachedGreeneKingAnnotationImage;

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
      'greeneKingCount=${nearbyFeatures.where((PubFeature feature) => _isGreeneKing(feature.brand)).length}, '
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

    await _upsertExtrusionLayer(
      style: style,
      layerId: visitedNearbyPubsBottomLayerId,
      sourceId: visitedNearbyPubsSourceId,
      color: _visitedExtrusionColor,
      base: 0,
      height: _debugExtrusionHeightMeters * 0.4,
      opacity: 0.60,
    );
    await _upsertExtrusionLayer(
      style: style,
      layerId: visitedNearbyPubsMiddleLayerId,
      sourceId: visitedNearbyPubsSourceId,
      color: _visitedExtrusionColor,
      base: _debugExtrusionHeightMeters * 0.4,
      height: _debugExtrusionHeightMeters * 0.75,
      opacity: 0.42,
    );
    await _upsertExtrusionLayer(
      style: style,
      layerId: visitedNearbyPubsTopLayerId,
      sourceId: visitedNearbyPubsSourceId,
      color: _visitedExtrusionColor,
      base: _debugExtrusionHeightMeters * 0.75,
      height: _debugExtrusionHeightMeters,
      opacity: 0.16,
    );

    await _upsertExtrusionLayer(
      style: style,
      layerId: unvisitedNearbyPubsBottomLayerId,
      sourceId: unvisitedNearbyPubsSourceId,
      color: _unvisitedExtrusionColor,
      base: 0,
      height: _debugExtrusionHeightMeters * 0.4,
      opacity: 0.60,
    );
    await _upsertExtrusionLayer(
      style: style,
      layerId: unvisitedNearbyPubsMiddleLayerId,
      sourceId: unvisitedNearbyPubsSourceId,
      color: _unvisitedExtrusionColor,
      base: _debugExtrusionHeightMeters * 0.4,
      height: _debugExtrusionHeightMeters * 0.75,
      opacity: 0.42,
    );
    await _upsertExtrusionLayer(
      style: style,
      layerId: unvisitedNearbyPubsTopLayerId,
      sourceId: unvisitedNearbyPubsSourceId,
      color: _unvisitedExtrusionColor,
      base: _debugExtrusionHeightMeters * 0.75,
      height: _debugExtrusionHeightMeters,
      opacity: 0.16,
    );

    await _upsertGreeneKingOverlay(
      mapboxMap: mapboxMap,
      features: nearbyFeatures,
    );

    return true;
  } catch (error, stackTrace) {
    debugPrint('Mapbox pubs debug error: $error');
    debugPrint('Mapbox pubs debug stackTrace: $stackTrace');
    return false;
  }
}

Future<void> _upsertGreeneKingOverlay({
  required mbx.MapboxMap mapboxMap,
  required List<PubFeature> features,
}) async {
  try {
    final mbx.PointAnnotationManager manager =
        await _getGreeneKingAnnotationManager(mapboxMap);
    await manager.deleteAll();

    final Uint8List image = await _loadGreeneKingAnnotationImage();
    final List<mbx.PointAnnotationOptions> annotations = features
        .where((PubFeature feature) => _isGreeneKing(feature.brand))
        .map(
          (PubFeature feature) => mbx.PointAnnotationOptions(
            geometry: mbx.Point(
              coordinates: mbx.Position(
                _featureCenter(feature.coordinates)[0],
                _featureCenter(feature.coordinates)[1],
              ),
            ),
            image: image,
            iconAnchor: mbx.IconAnchor.BOTTOM,
            iconSize: _greeneKingIconSize,
            iconOpacity: 0.6,
            iconEmissiveStrength: 1,
            symbolZOffset: _greeneKingSymbolZOffsetMeters,
          ),
        )
        .toList(growable: false);

    if (annotations.isNotEmpty) {
      await manager.createMulti(annotations);
    }
  } catch (error, stackTrace) {
    debugPrint('Mapbox Greene King overlay debug error: $error');
    debugPrint('Mapbox Greene King overlay debug stackTrace: $stackTrace');
  }
}

Future<mbx.PointAnnotationManager> _getGreeneKingAnnotationManager(
  mbx.MapboxMap mapboxMap,
) async {
  final mbx.PointAnnotationManager? existingManager =
      _greeneKingAnnotationManagers[mapboxMap];
  if (existingManager != null) {
    return existingManager;
  }

  final mbx.PointAnnotationManager manager =
      await mapboxMap.annotations.createPointAnnotationManager();
  await manager.setIconAllowOverlap(true);
  await manager.setIconIgnorePlacement(true);
  _greeneKingAnnotationManagers[mapboxMap] = manager;
  return manager;
}

Future<Uint8List> _loadGreeneKingAnnotationImage() async {
  final Uint8List? cached = _cachedGreeneKingAnnotationImage;
  if (cached != null) {
    return cached;
  }

  final ByteData imageData = await rootBundle.load(_greeneKingBrandAssetPath);
  final Uint8List output = imageData.buffer.asUint8List();
  _cachedGreeneKingAnnotationImage = output;
  return output;
}

bool _isGreeneKing(String? brand) {
  return brand?.trim().toLowerCase() == _greeneKingBrandValue.toLowerCase();
}

List<double> _featureCenter(List<List<List<double>>> coordinates) {
  if (coordinates.isEmpty || coordinates.first.isEmpty) {
    return <double>[0, 0];
  }

  final List<List<double>> outerRing = coordinates.first;
  double longitudeTotal = 0;
  double latitudeTotal = 0;

  for (final List<double> point in outerRing) {
    longitudeTotal += point[0];
    latitudeTotal += point[1];
  }

  final double pointsCount = outerRing.length.toDouble();
  return <double>[longitudeTotal / pointsCount, latitudeTotal / pointsCount];
}

Future<void> _upsertExtrusionLayer({
  required mbx.StyleManager style,
  required String layerId,
  required String sourceId,
  required int color,
  required double base,
  required double height,
  required double opacity,
}) async {
  final mbx.FillExtrusionLayer layer = mbx.FillExtrusionLayer(
    id: layerId,
    sourceId: sourceId,
    fillExtrusionColor: color,
    fillExtrusionHeight: height,
    fillExtrusionBase: base,
    fillExtrusionOpacity: opacity,
    fillExtrusionVerticalGradient: true,
  );

  final mbx.Layer? existingLayer = await _tryGetLayer(
    style: style,
    layerId: layerId,
  );
  if (existingLayer == null) {
    await style.addLayer(layer);
  } else {
    await style.updateLayer(layer);
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