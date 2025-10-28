class WalkerListEarly {
  final String id;
  double? distance;
  final double latitude;
  final double longitude;
  final bool active;
  WalkerListEarly({
    required this.id,
    this.distance,
    required this.latitude,
    required this.longitude,
    required this.active,
  });

  factory WalkerListEarly.fromMap(String id, Map data) {
    // Add checks for null or incorrect types if necessary
    final lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
    final lon = (data['longitude'] as num?)?.toDouble() ?? 0.0;
    print("WalkerListEarly: Parsing $id - Lat: $lat, Lon: $lon"); // Add print
    return WalkerListEarly(
      id: id,
      latitude: lat,
      longitude: lon,
      active: data['active'] ?? false,
    );
  }
}
