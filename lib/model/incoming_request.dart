import 'Walker.dart';

class IncomingRequest {
  final String id;
  final Walker walker;
  final String date;
  final String time;
  final String duration;
  final double latitude;
  final double longitude;
  final String? notes;
  final String status;
  final String? imageUrl;
  final String name;
  final String bio;

  IncomingRequest({
    required this.id,
    required this.walker,
    required this.date,
    required this.time,
    required this.duration,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.imageUrl,
    this.notes,
    required this.bio,
    required this.name,
  });
}
