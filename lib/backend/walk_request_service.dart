// lib/backend/walk_request_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http; // Required for HTTP requests
import 'dart:convert'; // Required for JSON encoding

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

  // [UPDATED] Use the real deployed URL for the Node.js server
  static const String NODE_SERVER_URL = "https://aid-backend-1.onrender.com/api/sendNotification";

  // --- Custom Server HTTP Notification Sender ---
  /// This function calls your Node.js server to send FCM.
  Future<void> _sendNotificationToServer({
    required String recipientId,
    required String notificationType,
    required Map<String, dynamic> data,
  }) async {

    final payload = {
      'recipientId': recipientId,
      'type': notificationType,
      'data': data,
    };

    try {
      // [UNCOMMENTED] Actual HTTP POST call to the external server
      final response = await http.post(
        Uri.parse(NODE_SERVER_URL),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint(
            "[WalkRequestService] HTTP Error: Server responded with status ${response.statusCode}");
      } else {
        debugPrint(
            "[WalkRequestService] HTTP Success: Notification request sent to server successfully.");
      }
    } catch (e) {
      debugPrint("[WalkRequestService] HTTP Post Failed: $e");
    }
  }
  // --- END Custom Server HTTP Notification Sender ---


  /// ------------------ SEND REQUEST ------------------
  Future<String?> sendRequest(Map<String, dynamic> requestData) async {
    try {
      if (requestData['senderId'] == null ||
          requestData['recipientId'] == null) {
        throw ArgumentError("senderId and recipientId must be provided.");
      }

      requestData['status'] = 'Pending';
      requestData['createdAt'] = FieldValue.serverTimestamp();
      requestData['updatedAt'] = FieldValue.serverTimestamp();

      DocumentReference docRef = await _requestsCollection.add(requestData);
      final walkId = docRef.id;

      // [TRIGGER] Trigger FCM via custom server for the Walker (Recipient)
      _sendNotificationToServer(
        recipientId: requestData['recipientId'] as String,
        notificationType: 'new_request',
        data: {'walkId': walkId, 'senderName': requestData['senderInfo']['fullName']},
      );

      debugPrint(
          "[WalkRequestService] Request sent successfully with ID: $walkId");
      return docRef.id;
    } catch (e) {
      debugPrint("[WalkRequestService] Error sending request: $e");
      return null;
    }
  }

  /// ------------------ GET PENDING REQUESTS FOR WALKER ------------------
  Stream<List<WalkRequest>> getPendingRequestsForWalker(String walkerId) {
    debugPrint(
        "[WalkRequestService] Subscribing to pending requests for Walker: $walkerId");
    return _requestsCollection
        .where('recipientId', isEqualTo: walkerId)
        .where('status', isEqualTo: 'Pending')
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) =>
          WalkRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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
      Map<String, dynamic> acceptedRequestData =
      requestDoc.data() as Map<String, dynamic>;

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

      acceptedRequestData['status'] = 'Accepted';
      acceptedRequestData['updatedAt'] = FieldValue.serverTimestamp();
      if (acceptedRequestData['createdAt'] == null ||
          !(acceptedRequestData['createdAt'] is Timestamp)) {
        acceptedRequestData['createdAt'] = FieldValue.serverTimestamp();
      }

      acceptedRequestData['messagesCount'] = 0;

      batch.set(_acceptedWalksCollection.doc(walkId), acceptedRequestData);

      // Set activeWalkId for BOTH users
      batch.update(_usersCollection.doc(senderId), {
        'journeys': FieldValue.arrayUnion([walkId]),
        'activeWalkId': walkId,
      });
      batch.update(_usersCollection.doc(recipientId), {
        'journeys': FieldValue.arrayUnion([walkId]),
        'activeWalkId': walkId,
      });

      await batch.commit();

      // [TRIGGER] Trigger FCM via custom server for the Wanderer (Sender)
      _sendNotificationToServer(
        recipientId: senderId,
        notificationType: 'request_accepted',
        data: {'walkId': walkId, 'walkerName': acceptedRequestData['recipientInfo']['fullName']},
      );

      debugPrint("[WalkRequestService] Request $walkId accepted successfully");
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

      // Fetch walk data to get sender ID for notification
      final walkDoc = await _acceptedWalksCollection.doc(walkId).get();
      final walkData = walkDoc.data() as Map<String, dynamic>? ?? {};
      final senderId = walkData['senderId'] as String? ?? '';

      // [TRIGGER] Trigger FCM via custom server for the Wanderer (Sender)
      if(senderId.isNotEmpty) {
        _sendNotificationToServer(
          recipientId: senderId,
          notificationType: 'walk_started',
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

    // [TRIGGER] Trigger FCM via custom server for both parties about the end status
    if (senderId != null) {
      _sendNotificationToServer(
        recipientId: senderId,
        notificationType: 'walk_ended',
        data: {'walkId': walkId, 'status': status},
      );
    }
    if (recipientId != null) {
      _sendNotificationToServer(
        recipientId: recipientId,
        notificationType: 'walk_ended',
        data: {'walkId': walkId, 'status': status},
      );
    }

    debugPrint(
        "[WalkRequestService] Confirmed finalStats & status persisted for accepted_walks/$walkId");

    return finalStatsData;
  }


  /// ------------------ DECLINE REQUEST ------------------
  Future<bool> declineRequest(String walkId) async {
    debugPrint("[WalkRequestService] Declining request: $walkId");
    try {
      // Fetch walk data to get sender ID
      final walkDoc = await _requestsCollection.doc(walkId).get();
      final walkData = walkDoc.data() as Map<String, dynamic>? ?? {};
      final senderId = walkData['senderId'] as String? ?? '';

      await _requestsCollection.doc(walkId).delete();

      // [TRIGGER] Trigger FCM via custom server for the Wanderer (Sender)
      if(senderId.isNotEmpty) {
        _sendNotificationToServer(
          recipientId: senderId,
          notificationType: 'request_declined',
          data: {'walkId': walkId},
        );
      }

      debugPrint("[WalkRequestService] Request $walkId declined successfully");
      return true;
    } catch (e) {
      debugPrint("[WalkRequestService] Error declining request $walkId: $e");
      return false;
    }
  }

  // --- CHAT FUNCTIONALITY ---

  /// Sends a message and updates the walk document's messages sub-collection.
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

      // 1. Add message to the messages sub-collection of the accepted walk
      await _acceptedWalksCollection
          .doc(walkId)
          .collection('messages')
          .add(messageData);

      // 2. Increment message counter in the main document (denormalization)
      await _acceptedWalksCollection.doc(walkId).set(
        {
          'messagesCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      // 3. Identify recipient and trigger notification
      final walkDoc = await _acceptedWalksCollection.doc(walkId).get();
      final walkData = walkDoc.data() as Map<String, dynamic>? ?? {};

      final isSenderTheWanderer = walkData['senderId'] == senderId;

      final recipientId = isSenderTheWanderer
          ? walkData['recipientId']
          : walkData['senderId'];

      if (recipientId != null) {
        _sendNotificationToServer(
          recipientId: recipientId,
          notificationType: 'new_message',
          data: {'walkId': walkId, 'senderId': senderId, 'message': text},
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
      return snapshot.docs
          .map((doc) => doc.data())
          .toList();
    });
  }
}