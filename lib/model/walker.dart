class Walker {
  final String id;
  final String name;
  final double rating;
  final double distance;
  final String? imageUrl;
  final double latitude;
  final double longitude;

  Walker({
    required this.id,
    required this.name,
    required this.rating,
    required this.distance,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
  });
}
