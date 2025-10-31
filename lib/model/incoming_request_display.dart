class IncomingRequestDisplay {
  final String walkId; // The ID of the request document
  final String senderId;
  final String recipientId;
  final String senderName; // Denormalized or fetched
  final String? senderImageUrl; // Denormalized or fetched
  final String? senderBio; // Denormalized or fetched (Optional)
  final String date;
  final String time;
  final String duration;
  final double latitude;
  final double longitude;
  final String status;
  final int distance;
  String? notes;

  IncomingRequestDisplay({
    required this.walkId,
    required this.senderId,
    required this.recipientId,
    required this.senderName,
    this.senderImageUrl,
    this.senderBio,
    required this.date,
    required this.time,
    required this.duration,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.distance,
    required this.notes,
  });

  /// ✅ Add this to fix the "method empty not defined" error
  factory IncomingRequestDisplay.empty() {
    return IncomingRequestDisplay(
      walkId: '',
      senderId: '',
      recipientId: '',
      senderName: '',
      senderImageUrl: '',
      senderBio: '',
      date: '',
      time: '',
      duration: '',
      latitude: 0.0,
      longitude: 0.0,
      status: '',
      distance: 0,
      notes: '',
    );
  }

  /// Optional helper to create from Firestore map
  factory IncomingRequestDisplay.fromMap(Map<String, dynamic> map) {
    return IncomingRequestDisplay(
      walkId: map['walkId'] ?? '',
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderImageUrl: map['senderImageUrl'],
      senderBio: map['senderBio'],
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      duration: map['duration'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      status: map['status'] ?? '',
      distance: (map['distance'] ?? 0).toInt(),
      notes: map['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'walkId': walkId,
      'senderId': senderId,
      'recipientId': recipientId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'senderBio': senderBio,
      'date': date,
      'time': time,
      'duration': duration,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'distance': distance,
      'notes': notes,
    };
  }
}
