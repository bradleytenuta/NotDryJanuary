class NearbyPubMapData {
  const NearbyPubMapData({
    required this.areaFeatureCollection,
    required this.nearbyFeatureIds,
  });

  final String areaFeatureCollection;
  final List<String> nearbyFeatureIds;
}