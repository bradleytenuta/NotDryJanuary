import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../debug/location_override.dart';
import '../domain/pub_feature.dart';
import '../features/feature_service.dart';
import '../features/pub_cache.dart';
import '../user_session_store.dart';
import '../ui/components/pub_beam.dart';

export '../domain/pub_feature.dart';

typedef OnPubFeatureTapped = void Function(PubFeature featureDetails);

class MapboxMapController {
  MapboxMapController(this._mapboxMap);

  final mbx.MapboxMap _mapboxMap;
  bool _isMapLoaded = false;
  bool _isNearbyPubsRefreshInFlight = false;
  ({double latitude, double longitude})? _lastVisitedPubsCheckLocation;
  ({double latitude, double longitude})? _nearbyPubsOrigin;
  ({double latitude, double longitude})? _pendingNearbyPubsLocation;

  static const double _visitedPubsCheckDistanceMeters = 5;
  static const int _maxVisitedPubsToAddPerCheck = 5;

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

  Future<void> markMapLoaded() async {
    _isMapLoaded = true;

    ({double latitude, double longitude})? pendingLocation =
        _pendingNearbyPubsLocation;
    pendingLocation ??= await _resolveCurrentTrackingLocation();

    if (pendingLocation == null) {
      return;
    }

    _pendingNearbyPubsLocation = null;
    await refreshNearbyPubsIfNeeded(
      latitude: pendingLocation.latitude,
      longitude: pendingLocation.longitude,
    );
  }

  Future<void> refreshNearbyPubsIfNeeded({
    required double latitude,
    required double longitude,
  }) async {
    if (!_isMapLoaded) {
      _pendingNearbyPubsLocation = (latitude: latitude, longitude: longitude);
      return;
    }

    if (_isNearbyPubsRefreshInFlight) {
      _pendingNearbyPubsLocation = (latitude: latitude, longitude: longitude);
      return;
    }

    _isNearbyPubsRefreshInFlight = true;
    try {
      await _recordVisitedPubsAtLocation(
        latitude: latitude,
        longitude: longitude,
      );

      final ({double latitude, double longitude})? origin = _nearbyPubsOrigin;

      if (origin == null) {
        final bool didUpdateNearbyFeatures = await addNearbyPubFeatures(
          _mapboxMap,
          latitude: latitude,
          longitude: longitude,
          forceRefresh: true,
        );
        if (didUpdateNearbyFeatures) {
          _nearbyPubsOrigin = (latitude: latitude, longitude: longitude);
        }
      } else {
        final double distanceMoved = geo.Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          latitude,
          longitude,
        );

        if (distanceMoved >= nearbyPubsRefreshDistanceMeters) {
          final bool didUpdateNearbyFeatures = await addNearbyPubFeatures(
            _mapboxMap,
            latitude: latitude,
            longitude: longitude,
            forceRefresh: true,
          );
          if (didUpdateNearbyFeatures) {
            _nearbyPubsOrigin = (latitude: latitude, longitude: longitude);
          }
        }
      }
    } finally {
      _isNearbyPubsRefreshInFlight = false;
    }

    final ({double latitude, double longitude})? pendingLocation =
        _pendingNearbyPubsLocation;
    if (pendingLocation == null) {
      return;
    }

    _pendingNearbyPubsLocation = null;
    await refreshNearbyPubsIfNeeded(
      latitude: pendingLocation.latitude,
      longitude: pendingLocation.longitude,
    );
  }

  Future<void> _recordVisitedPubsAtLocation({
    required double latitude,
    required double longitude,
  }) async {
    final ({double latitude, double longitude})? lastCheckedLocation =
        _lastVisitedPubsCheckLocation;
    if (lastCheckedLocation != null) {
      final double distanceSinceLastCheck = geo.Geolocator.distanceBetween(
        lastCheckedLocation.latitude,
        lastCheckedLocation.longitude,
        latitude,
        longitude,
      );

      if (distanceSinceLastCheck < _visitedPubsCheckDistanceMeters) {
        return;
      }
    }

    _lastVisitedPubsCheckLocation = (latitude: latitude, longitude: longitude);

    final List<PubFeature> candidateFeatures =
        await PubsGeoJsonCache.instance.loadNearbyFeatures(
      userLatitude: latitude,
      userLongitude: longitude,
      radiusMeters: PubsGeoJsonCache.visitedCheckRadiusMeters,
      refreshDistanceMeters: _visitedPubsCheckDistanceMeters,
    );

    final List<String> visitedPubIds = FeatureService.findContainingFeatureIds(
      features: candidateFeatures,
      userLatitude: latitude,
      userLongitude: longitude,
    );

    if (visitedPubIds.isEmpty) {
      return;
    }

    if (visitedPubIds.length > _maxVisitedPubsToAddPerCheck) {
      debugPrint(
        'Mapbox visited pubs guard: refusing to add ${visitedPubIds.length} IDs in one check at '
        '($latitude, $longitude).',
      );
      return;
    }

    await UserSessionStore.instance.addVisitedPubs(visitedPubIds);
  }

  Future<({double latitude, double longitude})?> _resolveCurrentTrackingLocation() async {
    try {
      final geo.Position position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );

      return resolveTrackingLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return null;
    }
  }
}

typedef MapboxMapProviderBuilder = Widget Function({
  required ValueChanged<MapboxMapController> onControllerCreated,
  required OnPubFeatureTapped onPubFeatureTapped,
  required double initialLatitude,
  required double initialLongitude,
  required double initialZoom,
  required double initialTilt,
});

const String _mapboxStandardBasemapImportId = 'basemap';
const double _maxZoomOutLevel = 16;

Widget mapboxMap({
  required ValueChanged<MapboxMapController> onControllerCreated,
  required OnPubFeatureTapped onPubFeatureTapped,
  required double initialLatitude,
  required double initialLongitude,
  required double initialZoom,
  required double initialTilt,
}) {
  mbx.MapboxMap? createdMap;
  MapboxMapController? createdController;
  bool isMapLoaded = false;

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

      // Create controller before async map setup so onMapLoaded cannot outrun it.
      createdController = MapboxMapController(mapboxMap);
      onControllerCreated(createdController!);

      if (isMapLoaded) {
        unawaited(createdController!.markMapLoaded());
      }

      await mapboxMap.setBounds(
        mbx.CameraBoundsOptions(
          minZoom: _maxZoomOutLevel,
        ),
      );

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
    },
    onMapLoadedListener: (_) {
      isMapLoaded = true;
      final MapboxMapController? controller = createdController;
      if (controller != null) {
        unawaited(controller.markMapLoaded());
      }
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
      mbx.RenderedQueryOptions(
        layerIds: nearbyPubsLayerIds.map<String?>((String id) => id).toList(
              growable: false,
            ),
      ),
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