import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../map_provider.dart';

class _GoogleMapsFlutterController implements MapProviderController {
  _GoogleMapsFlutterController(this._controller);

  final GoogleMapController _controller;

  @override
  Future<void> moveCamera({
    required double latitude,
    required double longitude,
    required double tilt,
    required double zoom,
    required double bearing,
  }) {
    return _controller.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(latitude, longitude),
          tilt: tilt,
          zoom: zoom,
          bearing: bearing,
        ),
      ),
    );
  }
}

Widget buildGoogleMapsFlutterProvider({
  required ValueChanged<MapProviderController> onControllerCreated,
  required VoidCallback onMapReady,
  required double initialLatitude,
  required double initialLongitude,
  required double initialZoom,
  required double initialTilt,
}) {
  return GoogleMap(
    initialCameraPosition: CameraPosition(
      target: LatLng(initialLatitude, initialLongitude),
      zoom: initialZoom,
      tilt: initialTilt,
    ),
    myLocationEnabled: false,
    myLocationButtonEnabled: false,
    compassEnabled: false,
    zoomControlsEnabled: false,
    zoomGesturesEnabled: false,
    scrollGesturesEnabled: false,
    rotateGesturesEnabled: false,
    tiltGesturesEnabled: false,
    onMapCreated: (GoogleMapController controller) {
      onControllerCreated(_GoogleMapsFlutterController(controller));
      onMapReady();
    },
  );
}
