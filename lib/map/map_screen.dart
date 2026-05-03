import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'map_animation_logic.dart';
import 'map_camera_logic.dart';
import 'debug_location_override.dart';
import 'map_location_access.dart';
import 'map_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.mapProviderBuilder,
    this.onMapReady,
    this.onModelReady,
  });

  final MapProviderBuilder mapProviderBuilder;
  final VoidCallback? onMapReady;
  final VoidCallback? onModelReady;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  MapProviderController? _mapController;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  double? _playerLatitude;
  double? _playerLongitude;
  bool _isCameraUpdateInFlight = false;
  bool _hasPendingCameraUpdate = false;
  bool _hasSentMapReady = false;
  bool _hasSentModelReady = false;
  bool _isPubSheetOpen = false;
  final MapAnimationLogic _animationLogic = MapAnimationLogic();
  final MapCameraLogic _cameraLogic = MapCameraLogic();

  static const String _characterModelPath = 'assets/models/casual_character.glb';
  static const double _avatarWidth = 90;
  static const double _avatarHeight = 110;
  static const double _modelTopCrop = 5;

  // The "3rd Person" camera settings
  static const double _tilt = 60.0; // Angled view
  static const double _zoom = 18.5; // Close to ground

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _startTracking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      WakelockPlus.disable();
    }
  }

  void _startTracking() async {
    // 1. Ensure location services and permissions are available.
    final bool canTrack = await ensureLocationAccess();
    if (!canTrack) return;

    try {
      // 2. Prime with the current location so camera can snap immediately.
      final Position initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final ({double latitude, double longitude}) trackingLocation =
          resolveTrackingLocation(
        latitude: initialPosition.latitude,
        longitude: initialPosition.longitude,
      );
      _playerLatitude = trackingLocation.latitude;
      _playerLongitude = trackingLocation.longitude;
      await _updateCameraToPlayer();
      final String previousAnimation = _animationLogic.currentAnimationName;
      _animationLogic.updateAnimation(initialPosition, DateTime.now());
      if (previousAnimation != _animationLogic.currentAnimationName) {
        setState(() {});
      }
    } catch (_) {
      // If an initial fix is unavailable, live stream updates will still drive camera.
    }

    _startCompassTracking();

    // 3. Listen to position & heading changes continuously.
    _positionStream = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen((Position position) async {
      _cameraLogic.setInitialBearingIfUnset(
        _cameraLogic.sanitizeHeading(position.heading),
      );

      final String previousAnimation = _animationLogic.currentAnimationName;
      _animationLogic.updateAnimation(position, DateTime.now());
      if (previousAnimation != _animationLogic.currentAnimationName) {
        setState(() {});
      }
      final ({double latitude, double longitude}) trackingLocation =
          resolveTrackingLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _playerLatitude = trackingLocation.latitude;
      _playerLongitude = trackingLocation.longitude;

      await _updateCameraToPlayer();
    });
  }

  LocationSettings _buildLocationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 250),
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  void _startCompassTracking() {
    _compassStream = FlutterCompass.events?.listen((CompassEvent event) async {
      if (!mounted ||
          _playerLatitude == null ||
          _playerLongitude == null ||
          _mapController == null) {
        return;
      }

      final double? heading = event.heading;
      if (heading == null || heading.isNaN || heading.isInfinite) return;

      _cameraLogic.updateBearingFromCompass(heading);
      await _updateCameraToPlayer();
    });
  }

  Future<void> _updateCameraToPlayer() async {
    if (_isCameraUpdateInFlight) {
      _hasPendingCameraUpdate = true;
      return;
    }

    final MapProviderController? controller = _mapController;
    final double? latitude = _playerLatitude;
    final double? longitude = _playerLongitude;

    if (controller == null || latitude == null || longitude == null) {
      return;
    }

    _isCameraUpdateInFlight = true;
    try {
      await controller.moveCamera(
        latitude: latitude,
        longitude: longitude,
        tilt: _tilt,
        zoom: _zoom,
        bearing: _cameraLogic.cameraBearingDegrees,
      );
    } finally {
      _isCameraUpdateInFlight = false;
    }

    if (_hasPendingCameraUpdate) {
      _hasPendingCameraUpdate = false;
      await _updateCameraToPlayer();
    }
  }

  void _onProviderControllerCreated(MapProviderController controller) {
    _mapController = controller;
    _updateCameraToPlayer();
  }

  void _onProviderMapReady() {
    if (_hasSentMapReady) {
      return;
    }
    _hasSentMapReady = true;
    widget.onMapReady?.call();
  }

  Future<void> _onPubFeatureTapped(PubFeatureDetails featureDetails) async {
    if (!mounted) {
      return;
    }

    if (_isPubSheetOpen) {
      await Navigator.of(context).maybePop();
      if (!mounted) {
        return;
      }
    }

    _isPubSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return _PubDetailsBottomSheet(featureDetails: featureDetails);
      },
    );

    _isPubSheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.mapProviderBuilder(
            onControllerCreated: _onProviderControllerCreated,
            onMapReady: _onProviderMapReady,
            onPubFeatureTapped: (PubFeatureDetails details) {
              unawaited(_onPubFeatureTapped(details));
            },
            initialLatitude: 0,
            initialLongitude: 0,
            initialZoom: _zoom,
            initialTilt: _tilt,
          ),
          Align(
            alignment: Alignment.center,
            child: IgnorePointer(
              child: Transform.translate(
                offset: const Offset(0, -32),
                child: SizedBox(
                  width: _avatarWidth,
                  height: _avatarHeight,
                  child: ClipRect(
                    child: Transform.translate(
                      offset: const Offset(0, -_modelTopCrop),
                      child: SizedBox(
                        width: _avatarWidth,
                        height: _avatarHeight + _modelTopCrop,
                        child: ModelViewer(
                          key: ValueKey<String>(
                            _animationLogic.currentAnimationName,
                          ),
                          src: _characterModelPath,
                          alt: 'Player character',
                          ar: false,
                          autoRotate: false,
                          autoPlay: true,
                          animationName: _animationLogic.currentAnimationName,
                          animationCrossfadeDuration: 250,
                          orientation: '180deg ${180 + 30}deg 0deg', // Tilt the character model to match the maps tilt.
                          cameraControls: false,
                          disableZoom: true,
                          backgroundColor: Colors.transparent,
                          onWebViewCreated: (_) {
                            if (_hasSentModelReady) return;
                            _hasSentModelReady = true;
                            widget.onModelReady?.call();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _positionStream?.cancel();
    _compassStream?.cancel();
    super.dispose();
  }

}

class _PubDetailsBottomSheet extends StatelessWidget {
  const _PubDetailsBottomSheet({required this.featureDetails});

  final PubFeatureDetails featureDetails;

  @override
  Widget build(BuildContext context) {
    final String address =
        '${featureDetails.city}, ${featureDetails.street}, ${featureDetails.houseNumber} - ${featureDetails.postcode}';

    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (featureDetails.brand != null && featureDetails.brand!.isNotEmpty)
                Text('Brand: ${featureDetails.brand}'),
              Text('Name: ${featureDetails.name}'),
              Text('Address: $address'),
              Text('Wheelchair access: ${featureDetails.wheelchair}'),
            ],
          ),
        ),
      ),
    );
  }
}