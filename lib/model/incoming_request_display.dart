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
  // Maybe add distance calculation here if needed for display

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
}
