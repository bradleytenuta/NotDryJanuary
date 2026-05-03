class PubFeature {
  const PubFeature({
    required this.id,
    required this.name,
    required this.city,
    required this.street,
    required this.houseNumber,
    required this.postcode,
    required this.wheelchair,
    required this.coordinates,
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
  final List<List<List<double>>> coordinates;

  factory PubFeature.fromProperties({
    required Map<String, Object?> properties,
    List<List<List<double>>> coordinates = const <List<List<double>>>[],
  }) {
    return PubFeature(
      id: _stringFrom(properties['sourceId']) ?? '',
      brand: _stringFrom(properties['brand']),
      name: _stringFrom(properties['name']) ?? 'Unknown',
      city: _stringFrom(properties['city']) ?? 'Unknown',
      street: _stringFrom(properties['street']) ?? 'Unknown',
      houseNumber: _stringFrom(properties['housenumber']) ?? 'Unknown',
      postcode: _stringFrom(properties['postcode']) ?? 'Unknown',
      wheelchair: _stringFrom(properties['wheelchair']) ?? 'Unknown',
      coordinates: coordinates,
    );
  }

  static String? _stringFrom(Object? value) {
    if (value == null) {
      return null;
    }

    final String output = value.toString().trim();
    if (output.isEmpty) {
      return null;
    }

    return output;
  }
}