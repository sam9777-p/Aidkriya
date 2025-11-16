import 'package:cloud_firestore/cloud_firestore.dart';
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
  final int walks;
  final int earnings;
  String? activeWalkId;
  final bool isPaymentSuspicious;
  final int stepsToday;
  final Timestamp? lastStepReset;
  final String? suspiciousWalkId; // The ID of the walk that failed payment
  final double? suspiciousAmount;
  String? activeGroupWalkId;

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
    required this.walks,
    required this.earnings,
    this.activeWalkId,
    this.isPaymentSuspicious = false,
    this.stepsToday = 0,
    this.lastStepReset,
    this.suspiciousAmount,
    this.suspiciousWalkId,
    this.activeGroupWalkId,
  });

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
      walks: (map['walks'] ?? 0).toInt(),
      earnings: (map['earnings'] ?? 0).toInt(),
      activeWalkId: map['activeWalkId'],
      activeGroupWalkId: map['activeGroupWalkId'],
      isPaymentSuspicious: map['isPaymentSuspicious'] as bool? ?? false,
      suspiciousWalkId: map['suspiciousWalkId'] as String?,
      suspiciousAmount: (map['suspiciousAmount'] as num?)?.toDouble(),

      // Read new fields from map
      stepsToday: (map['stepsToday'] ?? 0).toInt(),
      lastStepReset: map['lastStepReset'] as Timestamp?,
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
      'walks': walks,
      'earnings': earnings,
      'activeWalkId': activeWalkId,
      'activeGroupWalkId': activeGroupWalkId,
      'isPaymentSuspicious': isPaymentSuspicious,
      'suspiciousWalkId': suspiciousWalkId,
      'suspiciousAmount': suspiciousAmount,
      'stepsToday': stepsToday,
      'lastStepReset': lastStepReset,
    };
  }
}