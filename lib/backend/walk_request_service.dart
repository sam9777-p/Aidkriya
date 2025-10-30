

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../model/walk_request.dart';

/// Utility function to calculate the final fare based on duration.
double _calculateFare({
  required double scheduledDurationMinutes,
  required double elapsedMinutes,
  required double agreedRatePerHour,
}) {
  if (elapsedMinutes >= scheduledDurationMinutes) {
    // Walk completed fully or auto-completed on schedule. Pay full agreed fare.
    return (scheduledDurationMinutes / 60.0) * agreedRatePerHour;
  }
  if (elapsedMinutes > 0 && elapsedMinutes < scheduledDurationMinutes) {
    // Walk ended early (by Wanderer or a mid-point agreement). Pay pro-rata.
    return (elapsedMinutes / 60.0) * agreedRatePerHour;
  }
  return 0.0; // Walk ended instantly or prematurely without significant time passing.
}

class WalkRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final CollectionReference _requestsCollection =
  FirebaseFirestore.instance.collection('requests');
  final CollectionReference _acceptedWalksCollection =
  FirebaseFirestore.instance.collection('accepted_walks');
  final CollectionReference _usersCollection =
  FirebaseFirestore.instance.collection('users');

  // 🔥 Replace this with your deployed backend URL
  final String _serverUrl = "https://aid-backend-1.onrender.com/api/sendNotification";

  // -------------------- Helper to trigger FCM via backend --------------------
  Future<void> _triggerNotification({
    required String recipientId,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipientId': recipientId,
          'type': type,
          'data': data ?? {},
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("[FCM] Notification sent successfully for type: $type");
      } else {
        debugPrint("[FCM] Failed to send notification (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      debugPrint("[FCM] Error sending notification: $e");
    }
  }

  /// ------------------ SEND REQUEST ------------------
  Future<String?> sendRequest(Map<String, dynamic> requestData) async {
    try {
      if (requestData['senderId'] == null || requestData['recipientId'] == null) {
        throw ArgumentError("senderId and recipientId must be provided.");
      }

      requestData['status'] = 'Pending';
      requestData['createdAt'] = FieldValue.serverTimestamp();
      requestData['updatedAt'] = FieldValue.serverTimestamp();

      DocumentReference docRef = await _requestsCollection.add(requestData);
      debugPrint("[WalkRequestService] Request sent successfully with ID: ${docRef.id}");

      // ✅ Notify walker (recipient)
      await _triggerNotification(
        recipientId: requestData['recipientId'],
        type: 'walk_request',
        data: {
          'walkId': docRef.id,
          'senderId': requestData['senderId'],
        },
      );

      return docRef.id;
    } catch (e) {
      debugPrint("[WalkRequestService] Error sending request: $e");
      return null;
    }
  }

  /// ------------------ GET PENDING REQUESTS FOR WALKER ------------------
  Stream<List<WalkRequest>> getPendingRequestsForWalker(String walkerId) {
    debugPrint("[WalkRequestService] Subscribing to pending requests for Walker: $walkerId");
    return _requestsCollection
        .where('recipientId', isEqualTo: walkerId)
        .where('status', isEqualTo: 'Pending')
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => WalkRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      requests.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return requests;
    }).handleError((error) {
      debugPrint("[WalkRequestService] Error fetching pending requests: $error");
      return <WalkRequest>[];
    });
  }

  /// ------------------ ACCEPT REQUEST ------------------
  Future<bool> acceptRequest({
    required String walkId,
    required String senderId, // Wanderer ID
    required String recipientId, // Walker ID
  }) async {
    debugPrint("[WalkRequestService] Attempting to accept request: $walkId");
    try {
      WriteBatch batch = _firestore.batch();

      DocumentSnapshot requestDoc = await _requestsCollection.doc(walkId).get();
      if (!requestDoc.exists) throw Exception("Request $walkId not found.");
      Map<String, dynamic> acceptedRequestData = requestDoc.data() as Map<String, dynamic>;

      // Delete other pending requests from this wanderer
      QuerySnapshot otherPendingRequests = await _requestsCollection
          .where('senderId', isEqualTo: senderId)
          .where('status', isEqualTo: 'Pending')
          .get();
      for (var doc in otherPendingRequests.docs) {
        if (doc.id != walkId) batch.delete(doc.reference);
      }

      batch.update(_requestsCollection.doc(walkId), {
        'status': 'Accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Ensure acceptedRequestData has sane defaults and metadata
      acceptedRequestData['status'] = 'Accepted';
      acceptedRequestData['updatedAt'] = FieldValue.serverTimestamp();
      acceptedRequestData['messagesCount'] = acceptedRequestData['messagesCount'] ?? 0;
      if (acceptedRequestData['createdAt'] == null || !(acceptedRequestData['createdAt'] is Timestamp)) {
        acceptedRequestData['createdAt'] = FieldValue.serverTimestamp();
      }

      batch.set(_acceptedWalksCollection.doc(walkId), acceptedRequestData);

      // Set activeWalkId and append to journeys for BOTH users
      batch.update(_usersCollection.doc(senderId), {
        'journeys': FieldValue.arrayUnion([walkId]),
        'activeWalkId': walkId,
      });
      batch.update(_usersCollection.doc(recipientId), {
        'journeys': FieldValue.arrayUnion([walkId]),
        'activeWalkId': walkId,
      });

      await batch.commit();
      debugPrint("[WalkRequestService] Request $walkId accepted successfully");

      // ✅ Notify wanderer (sender)
      await _triggerNotification(
        recipientId: senderId,
        type: 'request_accepted',
        data: {'walkId': walkId},
      );

      return true;
    } catch (e) {
      debugPrint("[WalkRequestService] Error accepting request $walkId: $e");
      return false;
    }
  }

  /// ------------------ START WALK ------------------
  Future<bool> startWalk(String walkId) async {
    debugPrint("[WalkRequestService] Starting walk: $walkId");
    try {
      WriteBatch batch = _firestore.batch();
      final updateData = {
        'status': 'Started',
        'actualStartTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.update(_requestsCollection.doc(walkId), updateData);
      batch.update(_acceptedWalksCollection.doc(walkId), updateData);
      await batch.commit();

      // ✅ Notify both users
      final walkDoc = await _acceptedWalksCollection.doc(walkId).get();
      final data = walkDoc.data() as Map<String, dynamic>? ?? {};
      if (data['senderId'] != null) {
        await _triggerNotification(
          recipientId: data['senderId'],
          type: 'walk_started',
          data: {'walkId': walkId},
        );
      }
      if (data['recipientId'] != null) {
        await _triggerNotification(
          recipientId: data['recipientId'],
          type: 'walk_started',
          data: {'walkId': walkId},
        );
      }

      debugPrint("[WalkRequestService] Walk $walkId started successfully");
      return true;
    } catch (e) {
      debugPrint("[WalkRequestService] Error starting walk $walkId: $e");
      return false;
    }
  }

  /// ------------------ END / COMPLETE WALK ------------------
  Future<Map<String, dynamic>> endWalk({
    required String walkId,
    required String userIdEnding,
    required bool isWalker,
    required double scheduledDurationMinutes,
    required double elapsedMinutes,
    required double agreedRatePerHour,
    required double finalDistanceKm,
  }) async {
    debugPrint(
        "[WalkRequestService] Ending walk: $walkId by $userIdEnding. Initiated by ${isWalker ? 'Walker' : 'Wanderer'}.");

    final WriteBatch batch = _firestore.batch();

    String status;
    double amountDue;

    // --- Determine Status + Fare ---
    if (isWalker && elapsedMinutes < scheduledDurationMinutes) {
      status = 'CancelledByWalker';
      amountDue = 0.0;
    } else if (!isWalker && elapsedMinutes < scheduledDurationMinutes) {
      status = 'CancelledByWanderer';
      amountDue = _calculateFare(
        scheduledDurationMinutes: scheduledDurationMinutes,
        elapsedMinutes: elapsedMinutes,
        agreedRatePerHour: agreedRatePerHour,
      );
    } else {
      status = 'Completed';
      amountDue = _calculateFare(
        scheduledDurationMinutes: scheduledDurationMinutes,
        elapsedMinutes: scheduledDurationMinutes,
        agreedRatePerHour: agreedRatePerHour,
      );
    }

    final finalStatsData = {
      'elapsedMinutes': elapsedMinutes.round(),
      'finalDistanceKm': double.parse(finalDistanceKm.toStringAsFixed(1)),
      'amountDue': double.parse(amountDue.toStringAsFixed(2)),
    };

    final endData = {
      'status': status,
      'endTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'completedBy': userIdEnding,
      'finalStats': finalStatsData,
    };

    // ✅ Ensure both collections get updated
    batch.update(_requestsCollection.doc(walkId), endData);
    batch.update(_acceptedWalksCollection.doc(walkId), endData);

    // --- Clear Active Walk for both users ---
    final walkDoc = await _acceptedWalksCollection.doc(walkId).get();
    final walkData = walkDoc.data() as Map<String, dynamic>? ?? {};
    final senderId = walkData['senderId'] as String?;
    final recipientId = walkData['recipientId'] as String?;

    if (senderId != null) {
      batch.update(_usersCollection.doc(senderId), {'activeWalkId': FieldValue.delete()});
    }
    if (recipientId != null) {
      batch.update(_usersCollection.doc(recipientId), {'activeWalkId': FieldValue.delete()});
    }

    await batch.commit();
    debugPrint("[WalkRequestService] Batch committed successfully for $walkId");

    // ✅ Extra safeguard: Ensure finalStats exist in accepted_walks after commit
    await _firestore.collection('accepted_walks').doc(walkId).update({
      'finalStats': finalStatsData,
      'status': status,
    });

    debugPrint("[WalkRequestService] Confirmed finalStats & status persisted for accepted_walks/$walkId");

    // ✅ Notify both users about final status
    if (senderId != null) {
      await _triggerNotification(
        recipientId: senderId,
        type: 'walk_$status',
        data: {'walkId': walkId, 'status': status},
      );
    }
    if (recipientId != null) {
      await _triggerNotification(
        recipientId: recipientId,
        type: 'walk_$status',
        data: {'walkId': walkId, 'status': status},
      );
    }

    return {
      'walkId': walkId,
      'amountDue': double.parse(amountDue.toStringAsFixed(2)),
      'status': status,
      'finalDistanceKm': double.parse(finalDistanceKm.toStringAsFixed(1)),
      'elapsedMinutes': elapsedMinutes.round(),
      'finalStats': finalStatsData,
    };
  }

  /// ------------------ DECLINE REQUEST ------------------
  Future<bool> declineRequest(String walkId) async {
    debugPrint("[WalkRequestService] Declining request: $walkId");
    try {
      await _requestsCollection.doc(walkId).delete();
      debugPrint("[WalkRequestService] Request $walkId declined successfully");
      return true;
    } catch (e) {
      debugPrint("[WalkRequestService] Error declining request $walkId: $e");
      return false;
    }
  }

  /// ------------------ CHAT FUNCTIONALITY ------------------
  Future<void> sendMessage({
    required String walkId,
    required String senderId,
    required String text,
  }) async {
    try {
      final messageData = {
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _acceptedWalksCollection.doc(walkId).collection('messages').add(messageData);

      await _acceptedWalksCollection.doc(walkId).set(
        {
          'messagesCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      final walkDoc = await _acceptedWalksCollection.doc(walkId).get();
      final walkData = walkDoc.data() as Map<String, dynamic>? ?? {};
      final recipientId = walkData['senderId'] == senderId
          ? walkData['recipientId']
          : walkData['senderId'];

      if (recipientId != null) {
        await _triggerNotification(
          recipientId: recipientId,
          type: 'chat_message',
          data: {'walkId': walkId, 'text': text},
        );
      }
    } catch (e) {
      debugPrint("[WalkRequestService] Error sending message for $walkId: $e");
      throw Exception('Failed to send message.');
    }
  }

  /// Streams messages for a given walk ID.
  Stream<List<Map<String, dynamic>>> getWalkMessages(String walkId) {
    return _acceptedWalksCollection
        .doc(walkId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    });
  }
}
