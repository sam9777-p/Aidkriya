class IncomingRequest {
  final String id;
  final String walkerName;
  final String? walkerImageUrl;
  final String dateTime;
  final String location;
  final String pace;

  IncomingRequest({
    required this.id,
    required this.walkerName,
    this.walkerImageUrl,
    required this.dateTime,
    required this.location,
    required this.pace,
  });
}
