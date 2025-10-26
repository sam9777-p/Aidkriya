import 'Walker.dart';

class WalkRequest {
  final String id;
  final Walker walker;
  final String date;
  final String time;
  final String duration;
  final double latitude;
  final double longitude;
  final String? notes;
  final String status;

  WalkRequest({
    required this.id,
    required this.walker,
    required this.date,
    required this.time,
    required this.duration,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.notes,
  });
}
