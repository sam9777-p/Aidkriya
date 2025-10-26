class Walker {
  final String id;
  final String? name;
  final double? rating;
  final double distance;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final double age;
  final String bio;

  Walker({
    required this.id,
    required this.name,
    required this.rating,
    required this.distance,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.age,
    required this.bio,
  });

  /// Convert Walker to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name ?? '',
      'rating': rating ?? 0.0,
      'distance': distance,
      'imageUrl': imageUrl ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'age': age,
      'bio': bio,
    };
  }

  /// Create Walker object from Firestore Map
  factory Walker.fromMap(Map<String, dynamic> map) {
    return Walker(
      id: map['id'] ?? '',
      name: map['name'],
      rating: (map['rating'] as num?)?.toDouble(),
      distance: (map['distance'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['imageUrl'],
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      age: (map['age'] as num?)?.toDouble() ?? 0.0,
      bio: map['bio'] ?? '',
    );
  }
}
