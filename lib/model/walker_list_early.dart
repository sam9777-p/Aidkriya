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
    return WalkerListEarly(
      id: id,
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      active: data['active'] ?? false,
    );
  }
}
