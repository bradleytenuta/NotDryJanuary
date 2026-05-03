import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import '../debug_location_override.dart';
import '../pubs_geojson_cache.dart';
import '../map_provider.dart';

const String _nearbyPubsSourceId = 'nearby-pubs-source';
const String _nearbyPubsLayerId = 'nearby-pubs-3d-layer';
const String _mapboxStandardBasemapImportId = 'basemap';
const double _nearbyPubsRadiusMeters = 1000;
const String _debugTargetFeatureId = 'way/263674306';
const double _debugExtrusionHeightMeters = 250;

class _MapboxMapsFlutterController implements MapProviderController {
  _MapboxMapsFlutterController(this._mapboxMap);

  final mbx.MapboxMap _mapboxMap;

  @override
  Future<void> moveCamera({
    required double latitude,
    required double longitude,
    required double tilt,
    required double zoom,
    required double bearing,
  }) async {
    final mbx.CameraState cameraState = await _mapboxMap.getCameraState();
    return _mapboxMap.setCamera(
      mbx.CameraOptions(
        center: mbx.Point(
          coordinates: mbx.Position(longitude, latitude),
        ),
        pitch: tilt,
        zoom: cameraState.zoom,
        bearing: bearing,
      ),
    );
  }
}

Widget buildMapboxMapsFlutterProvider({
  required ValueChanged<MapProviderController> onControllerCreated,
  required VoidCallback onMapReady,
  required OnPubFeatureTapped onPubFeatureTapped,
  required double initialLatitude,
  required double initialLongitude,
  required double initialZoom,
  required double initialTilt,
}) {
  mbx.MapboxMap? createdMap;

  return mbx.MapWidget(
    // ignore: deprecated_member_use
    cameraOptions: mbx.CameraOptions(
      center: mbx.Point(
        coordinates: mbx.Position(initialLongitude, initialLatitude),
      ),
      zoom: initialZoom,
      pitch: initialTilt,
    ),
    onMapCreated: (mbx.MapboxMap mapboxMap) async {
      createdMap = mapboxMap;
      await mapboxMap.gestures.updateSettings(
        mbx.GesturesSettings(
          pinchToZoomEnabled: true,
          scrollEnabled: false,
          rotateEnabled: false,
          pitchEnabled: false,
          doubleTapToZoomInEnabled: false,
          doubleTouchToZoomOutEnabled: false,
          quickZoomEnabled: false,
        ),
      );

      await mapboxMap.compass.updateSettings(
        mbx.CompassSettings(enabled: false),
      );

      await mapboxMap.scaleBar.updateSettings(
        mbx.ScaleBarSettings(enabled: false),
      );

      onControllerCreated(_MapboxMapsFlutterController(mapboxMap));
    },
    onMapLoadedListener: (_) {
      if (createdMap != null) {
        unawaited(() async {
          await _addNearbyPubFeatures(createdMap!);
        }());
      }
      onMapReady();
    },
    onStyleLoadedListener: (_) {
      if (createdMap != null) {
        unawaited(() async {
          await _hideDefaultPlaceIcons(createdMap!);
        }());
      }
    },
    // ignore: deprecated_member_use
    onTapListener: (mbx.MapContentGestureContext context) {
      final mbx.MapboxMap? mapboxMap = createdMap;
      if (mapboxMap == null) {
        return;
      }
      unawaited(() async {
        final PubFeatureDetails? details = await _getTappedPubFeatureDetails(
          mapboxMap: mapboxMap,
          gestureContext: context,
        );
        if (details != null) {
          onPubFeatureTapped(details);
        }
      }());
    },
  );
}

Future<void> _addNearbyPubFeatures(
  mbx.MapboxMap mapboxMap,
) async {
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

    final NearbyPubMapData nearbyMapData =
        await PubsGeoJsonCache.instance.buildNearbyMapData(
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
      sourceId: _nearbyPubsSourceId,
    );
    if (existingSource case final mbx.GeoJsonSource source) {
      await source.updateGeoJSON(nearbyMapData.areaFeatureCollection);
    } else {
      await style.addSource(
        mbx.GeoJsonSource(
          id: _nearbyPubsSourceId,
          data: nearbyMapData.areaFeatureCollection,
        ),
      );
    }

    final mbx.FillExtrusionLayer debugLayer = mbx.FillExtrusionLayer(
      id: _nearbyPubsLayerId,
      sourceId: _nearbyPubsSourceId,
      fillExtrusionColor: 0xFFD32F2F,
      fillExtrusionHeight: _debugExtrusionHeightMeters,
      fillExtrusionBase: 0,
      fillExtrusionOpacity: 0.85,
      fillExtrusionVerticalGradient: true,
    );

    final mbx.Layer? existingLayer = await _tryGetLayer(
      style: style,
      layerId: _nearbyPubsLayerId,
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

Future<PubFeatureDetails?> _getTappedPubFeatureDetails({
  required mbx.MapboxMap mapboxMap,
  required mbx.MapContentGestureContext gestureContext,
}) async {
  try {
    final List<mbx.QueriedRenderedFeature?> queriedFeatures =
        await mapboxMap.queryRenderedFeatures(
      mbx.RenderedQueryGeometry.fromScreenCoordinate(
        gestureContext.touchPosition,
      ),
      mbx.RenderedQueryOptions(layerIds: <String?>[_nearbyPubsLayerId]),
    );

    final mbx.QueriedRenderedFeature? firstFeature = queriedFeatures
        .whereType<mbx.QueriedRenderedFeature>()
        .cast<mbx.QueriedRenderedFeature?>()
        .firstWhere(
          (mbx.QueriedRenderedFeature? feature) => feature != null,
          orElse: () => null,
        );

    if (firstFeature == null) {
      return null;
    }

    final Map<String, Object?> feature = firstFeature.queriedFeature.feature
        .map((String? key, Object? value) => MapEntry(key ?? '', value));
    final Map<String, Object?> properties =
        _asObjectMap(feature['properties']);

    final String id = _stringFrom(feature['id']) ?? _stringFrom(properties['sourceId']) ?? '';
    final String name = _stringFrom(properties['name']) ?? 'Unknown';
    final String city = _stringFrom(properties['city']) ?? 'Unknown';
    final String street = _stringFrom(properties['street']) ?? 'Unknown';
    final String houseNumber = _stringFrom(properties['housenumber']) ?? 'Unknown';
    final String postcode = _stringFrom(properties['postcode']) ?? 'Unknown';
    final String wheelchair = _stringFrom(properties['wheelchair']) ?? 'Unknown';

    return PubFeatureDetails(
      id: id,
      brand: _stringFrom(properties['brand']),
      name: name,
      city: city,
      street: street,
      houseNumber: houseNumber,
      postcode: postcode,
      wheelchair: wheelchair,
    );
  } catch (error, stackTrace) {
    debugPrint('Mapbox pubs tap debug error: $error');
    debugPrint('Mapbox pubs tap debug stackTrace: $stackTrace');
    return null;
  }
}

Map<String, Object?> _asObjectMap(Object? raw) {
  if (raw is Map) {
    final Map<String, Object?> output = <String, Object?>{};
    raw.forEach((Object? key, Object? value) {
      output[key?.toString() ?? ''] = value;
    });
    return output;
  }

  return <String, Object?>{};
}

String? _stringFrom(Object? value) {
  if (value == null) {
    return null;
  }

  final String output = value.toString().trim();
  if (output.isEmpty) {
    return null;
  }

  return output;
}

Future<void> _hideDefaultPlaceIcons(mbx.MapboxMap mapboxMap) async {
  try {
    await mapboxMap.style.setStyleImportConfigProperties(
      _mapboxStandardBasemapImportId,
      <String, Object>{
        'showPointOfInterestLabels': false,
        'showTransitLabels': false,
      },
    );
  } catch (error, stackTrace) {
    debugPrint('Mapbox style config debug error: $error');
    debugPrint('Mapbox style config debug stackTrace: $stackTrace');
  }
}
