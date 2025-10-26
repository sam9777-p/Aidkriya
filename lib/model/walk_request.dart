import 'Walker.dart';

class WalkRequest {
  final String id;
  final Walker walker;
  final String dateTime;
  final String duration;
  final String location;
  final double latitude;
  final double longitude;
  final String? notes;

  WalkRequest({
    required this.id,
    required this.walker,
    required this.dateTime,
    required this.duration,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.notes,
  });
}
