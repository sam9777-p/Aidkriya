import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/Walker.dart';
import '../model/walk_request.dart';

class WalkRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send a walk request
  Future<void> sendRequest(
    WalkRequest request,
    String senderId,
    String recipientId,
  ) async {
    final requestData = {
      'id': request.id,
      'walker': request.walker.toMap(), // nested map
      'date': request.date,
      'time': request.time,
      'duration': request.duration,
      'latitude': request.latitude,
      'longitude': request.longitude,
      'status': request.status,
      'notes': request.notes ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Save under recipient -> from -> sender
    await _firestore
        .collection('requests')
        .doc(recipientId)
        .collection('from')
        .doc(senderId)
        .set(requestData);

    // Save under sender -> to -> recipient
    await _firestore
        .collection('requests')
        .doc(senderId)
        .collection('to')
        .doc(recipientId)
        .set(requestData);
  }

  /// Update request status (accept/reject/cancel)
  Future<void> updateRequestStatus({
    required String senderId,
    required String recipientId,
    required String newStatus,
  }) async {
    // Update recipient document
    await _firestore
        .collection('requests')
        .doc(recipientId)
        .collection('from')
        .doc(senderId)
        .update({
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    // Update sender document
    await _firestore
        .collection('requests')
        .doc(senderId)
        .collection('to')
        .doc(recipientId)
        .update({
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Get all requests received by a recipient
  Stream<List<WalkRequest>> getReceivedRequests(String recipientId) {
    return _firestore
        .collection('requests')
        .doc(recipientId)
        .collection('from')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            final walkerMap = data['walker'] as Map<String, dynamic>;
            return WalkRequest(
              id: data['id'],
              walker: Walker.fromMap(walkerMap),
              date: data['date'],
              time: data['time'],
              duration: data['duration'],
              latitude: (data['latitude'] as num).toDouble(),
              longitude: (data['longitude'] as num).toDouble(),
              status: data['status'],
              notes: data['notes'],
            );
          }).toList(),
        );
  }

  /// Get all requests sent by a sender
  Stream<List<WalkRequest>> getSentRequests(String senderId) {
    return _firestore
        .collection('requests')
        .doc(senderId)
        .collection('to')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            final walkerMap = data['walker'] as Map<String, dynamic>;
            return WalkRequest(
              id: data['id'],
              walker: Walker.fromMap(walkerMap),
              date: data['date'],
              time: data['time'],
              duration: data['duration'],
              latitude: (data['latitude'] as num).toDouble(),
              longitude: (data['longitude'] as num).toDouble(),
              status: data['status'],
              notes: data['notes'],
            );
          }).toList(),
        );
  }
}
