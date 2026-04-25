import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'map_animation_logic.dart';
import 'map_camera_logic.dart';
import 'map_location_access.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.onMapReady,
    this.onModelReady,
  });

  final VoidCallback? onMapReady;
  final VoidCallback? onModelReady;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  LatLng? _playerLatLng;
  bool _hasSentMapReady = false;
  bool _hasSentModelReady = false;
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
    _startTracking();
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
      final LatLng initialLatLng =
          LatLng(initialPosition.latitude, initialPosition.longitude);
      _playerLatLng = initialLatLng;
      await _cameraLogic.updateCamera(
        controller: _controller,
        target: initialLatLng,
        tilt: _tilt,
        zoom: _zoom,
      );
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // More responsive movement updates.
      ),
    ).listen((Position position) async {
      final LatLng playerLatLng = LatLng(position.latitude, position.longitude);
      final double fallbackHeading = _cameraLogic.sanitizeHeading(position.heading);

      _cameraLogic.setInitialBearingIfUnset(fallbackHeading);

      final String previousAnimation = _animationLogic.currentAnimationName;
      _animationLogic.updateAnimation(position, DateTime.now());
      if (previousAnimation != _animationLogic.currentAnimationName) {
        setState(() {});
      }
      _playerLatLng = playerLatLng;

      await _cameraLogic.updateCamera(
        controller: _controller,
        target: playerLatLng,
        tilt: _tilt,
        zoom: _zoom,
      );
    });
  }

  void _startCompassTracking() {
    _compassStream = FlutterCompass.events?.listen((CompassEvent event) async {
      if (!mounted || _playerLatLng == null || _controller == null) return;

      final double? heading = event.heading;
      if (heading == null || heading.isNaN || heading.isInfinite) return;

      final DateTime now = DateTime.now();
      if (!_cameraLogic.canProcessCompassUpdate(now)) {
        return;
      }

      _cameraLogic.updateBearingFromCompass(heading);
      await _cameraLogic.updateCamera(
        controller: _controller,
        target: _playerLatLng!,
        tilt: _tilt,
        zoom: _zoom,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: _zoom,
              tilt: _tilt,
            ),
            myLocationEnabled: false,
            myLocationButtonEnabled: false, // Cleaner UI
            compassEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: false,
            scrollGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller = controller;
              if (!_hasSentMapReady) {
                _hasSentMapReady = true;
                widget.onMapReady?.call();
              }
              if (_playerLatLng != null) {
                _cameraLogic.updateCamera(
                  controller: _controller,
                  target: _playerLatLng!,
                  tilt: _tilt,
                  zoom: _zoom,
                );
              }
            },
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
                          orientation: '180deg ${180 + 30}deg 0deg', // Tilt the character model to match the Google Maps tilt.
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
    _positionStream?.cancel();
    _compassStream?.cancel();
    super.dispose();
  }

}