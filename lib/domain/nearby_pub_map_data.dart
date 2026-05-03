class NearbyPubMapData {
  const NearbyPubMapData({
    required this.visitedAreaFeatureCollection,
    required this.unvisitedAreaFeatureCollection,
    required this.nearbyFeatureIds,
    required this.visitedNearbyFeatureIds,
    required this.unvisitedNearbyFeatureIds,
  });

  final String visitedAreaFeatureCollection;
  final String unvisitedAreaFeatureCollection;
  final List<String> nearbyFeatureIds;
  final List<String> visitedNearbyFeatureIds;
  final List<String> unvisitedNearbyFeatureIds;
}