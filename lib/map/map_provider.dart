import 'package:flutter/material.dart';

class PubFeatureDetails {
  const PubFeatureDetails({
    required this.id,
    required this.name,
    required this.city,
    required this.street,
    required this.houseNumber,
    required this.postcode,
    required this.wheelchair,
    this.brand,
  });

  final String id;
  final String? brand;
  final String name;
  final String city;
  final String street;
  final String houseNumber;
  final String postcode;
  final String wheelchair;
}

typedef OnPubFeatureTapped = void Function(PubFeatureDetails featureDetails);

abstract class MapProviderController {
  Future<void> moveCamera({
    required double latitude,
    required double longitude,
    required double tilt,
    required double zoom,
    required double bearing,
  });
}

typedef MapProviderBuilder = Widget Function({
  required ValueChanged<MapProviderController> onControllerCreated,
  required VoidCallback onMapReady,
  required OnPubFeatureTapped onPubFeatureTapped,
  required double initialLatitude,
  required double initialLongitude,
  required double initialZoom,
  required double initialTilt,
});
