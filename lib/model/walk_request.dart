import 'package:cloud_firestore/cloud_firestore.dart';

import 'Walker.dart';

enum WalkStatus {
  pending,
  accepted,
  enRoute, // New Status: Walker is traveling to Wanderer's location
  arrived, // New Status: Walker has reached the Wanderer's location
  started, // New Status: The walk has begun
  completed,
  cancelled,
}

class WalkRequest {
  final String walkId; // Document ID from 'requests' collection
  final String senderId; // ID of the Wanderer sending the request
  final String recipientId; // ID of the Walker receiving the request
  final Walker walkerProfile; // Walker's profile details (denormalized)
  final String date;
  final String time;
  final String duration;
  final double latitude;
  final double longitude;
  String? notes;
  final String status;
  final DateTime? createdAt; // Added for sorting/querying
  final DateTime? updatedAt; // Added for tracking updates

  WalkRequest({
    required this.walkId, // Now required
    required this.senderId, // New
    required this.recipientId, // New
    required this.walkerProfile,
    required this.date,
    required this.time,
    required this.duration,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.notes,
    this.createdAt, // Optional
    this.updatedAt, // Optional
  });


  factory WalkRequest.fromMap(Map<String, dynamic> map, String documentId) {
    return WalkRequest(
      walkId: documentId, // Use the document ID passed in
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      walkerProfile: Walker.fromMap(
        map['walkerProfile'] as Map<String, dynamic>? ?? {},
      ), // Assuming Walker.fromMap exists
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      duration: map['duration'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'Unknown',
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Method to convert WalkRequest to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'recipientId': recipientId,
      'walkerProfile': walkerProfile
          .toMap(), // Assuming walkerProfile has a toMap method
      'date': date,
      'time': time,
      'duration': duration,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'notes': notes,
      'createdAt':
          createdAt ??
          FieldValue.serverTimestamp(), // Use server timestamp if not provided
      'updatedAt':
          updatedAt ?? FieldValue.serverTimestamp(), // Use server timestamp
    };
  }
}
