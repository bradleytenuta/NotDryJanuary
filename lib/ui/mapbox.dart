import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../domain/pub_feature.dart';
import 'nearby_pubs.dart';

export '../domain/pub_feature.dart';

typedef OnPubFeatureTapped = void Function(PubFeature featureDetails);

class MapboxMapController {
  MapboxMapController(this._mapboxMap);

  final mbx.MapboxMap _mapboxMap;

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

typedef MapboxMapProviderBuilder = Widget Function({
  required ValueChanged<MapboxMapController> onControllerCreated,
  required VoidCallback onMapReady,
  required OnPubFeatureTapped onPubFeatureTapped,
  required double initialLatitude,
  required double initialLongitude,
  required double initialZoom,
  required double initialTilt,
});

const String _mapboxStandardBasemapImportId = 'basemap';

Widget buildMapboxMapsFlutterProvider({
  required ValueChanged<MapboxMapController> onControllerCreated,
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

      onControllerCreated(MapboxMapController(mapboxMap));
    },
    onMapLoadedListener: (_) {
      if (createdMap != null) {
        unawaited(() async {
          await addNearbyPubFeatures(createdMap!);
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
        final PubFeature? details = await _getTappedPubFeatureDetails(
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

Future<PubFeature?> _getTappedPubFeatureDetails({
  required mbx.MapboxMap mapboxMap,
  required mbx.MapContentGestureContext gestureContext,
}) async {
  try {
    final List<mbx.QueriedRenderedFeature?> queriedFeatures =
        await mapboxMap.queryRenderedFeatures(
      mbx.RenderedQueryGeometry.fromScreenCoordinate(
        gestureContext.touchPosition,
      ),
      mbx.RenderedQueryOptions(layerIds: <String?>[nearbyPubsLayerId]),
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
    final Map<String, Object?> properties = _asObjectMap(feature['properties']);

    final String id =
        _stringFrom(feature['id']) ?? _stringFrom(properties['sourceId']) ?? '';
    final Map<String, Object?> propertiesWithId = <String, Object?>{
      ...properties,
      'sourceId': id,
    };

    return PubFeature.fromProperties(properties: propertiesWithId);
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