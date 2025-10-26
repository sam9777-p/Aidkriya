import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String? id;
  final String fullName;
  final int age;
  final String city;
  final String bio;
  final String phone;
  final List<String> interests;
  final int rating;
  final String? imageUrl;

  UserModel({
    this.id,
    required this.fullName,
    required this.age,
    required this.city,
    required this.bio,
    required this.phone,
    required this.interests,
    required this.rating,
    required this.imageUrl,
  });

  // ✅ Convert a Map (from Firebase or JSON) to UserProfile
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String?,
      fullName: map['fullName'] ?? '',
      age: map['age'] ?? 0,
      city: map['city'] ?? '',
      bio: map['bio'] ?? '',
      phone: map['phone'] ?? '',
      interests: List<String>.from(map['interests'] ?? []),
      rating: (map['rating'] ?? 0).toInt(),
      imageUrl: map['imageUrl'],
    );
  }

  // ✅ Convert UserProfile to Map (for Firebase)
  Map<String, dynamic> toMap() {
    return {
      'id': id ?? FirebaseAuth.instance.currentUser?.uid,
      'fullName': fullName,
      'age': age,
      'city': city,
      'bio': bio,
      'phone': phone,
      'interests': interests,
      'rating': rating,
      'imageUrl': imageUrl,
    };
  }
}
