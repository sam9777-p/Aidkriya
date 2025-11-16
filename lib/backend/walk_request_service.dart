import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../model/walk_request.dart';

// [NEW CONSTANTS FOR DYNAMIC PRICING MODEL]
const double _BASE_FARE = 10.0; // Fixed starting price
const double _RATE_PER_MINUTE = 2.0; // ₹2.00 per minute
const double _RATE_PER_KM = 5.0; // ₹5.00 per kilometer
const double _MINIMUM_CHARGE = 30.0; // Minimum charge for any walk (non-cancelled by Walker)

/// Utility function to calculate the final fare based on a dynamic model.
/// Fare is calculated based on distance, time, and minimum charge.
double _calculateFare({
  required double scheduledDurationMinutes,
  required double elapsedMinutes,
  required double finalDistanceKm,
  required String status, // Pass status for cancellation logic
}) {
  // If Walker cancels, charge is always 0.0
  if (status == 'CancelledByWalker') {
    return 0.0;
  }

  // Calculate raw time-based fare. Time is capped at scheduled duration.
  final billableMinutes = elapsedMinutes.clamp(0.0, scheduledDurationMinutes);
  final timeFare = billableMinutes * _RATE_PER_MINUTE;

  // Calculate distance-based fare
  final distanceFare = finalDistanceKm * _RATE_PER_KM;

  // Initial Total Fare = Base + Time + Distance
  double totalFare = _BASE_FARE + timeFare + distanceFare;

  // Apply Minimum Charge
  if (totalFare < _MINIMUM_CHARGE) {
    totalFare = _MINIMUM_CHARGE;
  }

  return totalFare;
}

class WalkRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final CollectionReference _requestsCollection = FirebaseFirestore.instance
      .collection('requests');
  final CollectionReference _acceptedWalksCollection = FirebaseFirestore
      .instance
      .collection('accepted_walks');
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('users');

  // [NEW] Collection for Group Walks (Added to fix undefined name error)
  final CollectionReference _groupWalksCollection = FirebaseFirestore.instance
      .collection('group_walks');

  // 🔥 Replace this with your deployed backend URL
  final String _serverUrl = "https://aid-backend-1.onrender.com/api/sendNotification";

  final String _scheduleUrl = "https://aid-backend-1.onrender.com/api/schedule-walk";

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
        debugPrint(
          "[FCM] Failed to send notification (${response.statusCode}): ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("[FCM] Error sending notification: $e");
    }
  }

  /// ------------------ 1-on-1 WALK FUNCTIONS ------------------

  Future<String?> sendRequest(Map<String, dynamic> requestData) async {
    try {
      if (requestData['senderId'] == null ||
          requestData['recipientId'] == null) {
        throw ArgumentError("senderId and recipientId must be provided.");
      }

      if (requestData['scheduledTimestamp'] == null) {
        debugPrint("[WalkRequestService] Creating INSTANT walk (no scheduledTimestamp)");
        requestData['status'] = 'Pending';
        requestData['scheduledTimestamp'] = FieldValue.serverTimestamp();
      } else {
        final timestamp = requestData['scheduledTimestamp'];

        if (timestamp is Timestamp) {
          final scheduledDate = timestamp.toDate();
          final now = DateTime.now();
          final twoMinutesFromNow = now.add(const Duration(minutes: 2));

          if (scheduledDate.isAfter(twoMinutesFromNow)) {
            debugPrint("[WalkRequestService] Creating SCHEDULED walk for: $scheduledDate");
            requestData['status'] = 'Scheduled';
          } else {
            debugPrint("[WalkRequestService] Scheduled time too close, treating as INSTANT walk");
            requestData['status'] = 'Pending';
            requestData['scheduledTimestamp'] = FieldValue.serverTimestamp();
          }
        } else {
          requestData['status'] = 'Pending';
          requestData['scheduledTimestamp'] = FieldValue.serverTimestamp();
        }
      }

      requestData['createdAt'] = FieldValue.serverTimestamp();
      requestData['updatedAt'] = FieldValue.serverTimestamp();

      DocumentReference docRef = await _requestsCollection.add(requestData);

      await _triggerNotification(
        recipientId: requestData['recipientId'],
        type: 'walk_request',
        data: {'walkId': docRef.id, 'senderId': requestData['senderId']},
      );

      return docRef.id;
    } catch (e) {
      debugPrint("[WalkRequestService] Error sending request: $e");
      return null;
    }
  }

  Stream<List<WalkRequest>> getPendingRequestsForWalker(String walkerId) {
    return _requestsCollection
        .where('recipientId', isEqualTo: walkerId)
        .where('status', whereIn: ['Pending', 'Scheduled'])
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
    });
  }

  Future<bool> acceptRequest({
    required String walkId,
    required String senderId,
    required String recipientId,
  }) async {
    try {
      WriteBatch batch = _firestore.batch();
      DocumentSnapshot requestDoc = await _requestsCollection.doc(walkId).get();

      if (!requestDoc.exists) throw Exception("Request $walkId not found.");

      Map<String, dynamic> acceptedRequestData = requestDoc.data() as Map<String, dynamic>;

      QuerySnapshot otherPendingRequests = await _requestsCollection
          .where('senderId', isEqualTo: senderId)
          .where('status', whereIn: ['Pending', 'Scheduled'])
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
      acceptedRequestData['messagesCount'] = 0;
      if (acceptedRequestData['createdAt'] == null) {
        acceptedRequestData['createdAt'] = FieldValue.serverTimestamp();
      }

      batch.set(_acceptedWalksCollection.doc(walkId), acceptedRequestData);

      final scheduledTimestamp = acceptedRequestData['scheduledTimestamp'];
      DateTime scheduledDateTime;

      if (scheduledTimestamp is Timestamp) {
        scheduledDateTime = scheduledTimestamp.toDate();
      } else if (scheduledTimestamp is String) {
        scheduledDateTime = DateTime.parse(scheduledTimestamp);
      } else {
        scheduledDateTime = DateTime.now();
      }

      final bool isScheduledForFuture = scheduledDateTime.isAfter(DateTime.now().add(const Duration(minutes: 2)));

      if (isScheduledForFuture) {
        batch.update(_usersCollection.doc(senderId), {'journeys': FieldValue.arrayUnion([walkId])});
        batch.update(_usersCollection.doc(recipientId), {'journeys': FieldValue.arrayUnion([walkId])});
        await batch.commit();

        try {
          await http.post(Uri.parse(_scheduleUrl), headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'walkId': walkId, 'senderId': senderId, 'recipientId': recipientId, 'scheduledTimestampISO': scheduledDateTime.toIso8601String()}));
        } catch (e) {
          debugPrint("Error calling scheduler: $e");
        }
      } else {
        batch.update(_usersCollection.doc(senderId), {'journeys': FieldValue.arrayUnion([walkId]), 'activeWalkId': walkId});
        batch.update(_usersCollection.doc(recipientId), {'journeys': FieldValue.arrayUnion([walkId]), 'activeWalkId': walkId});
        await batch.commit();
      }

      await _triggerNotification(recipientId: senderId, type: 'request_accepted', data: {'walkId': walkId});
      return true;
    } catch (e) {
      debugPrint("[WalkRequestService] Error accepting request: $e");
      return false;
    }
  }

  Future<bool> startWalk(String walkId) async {
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

      final walkDoc = await _acceptedWalksCollection.doc(walkId).get();
      final data = walkDoc.data() as Map<String, dynamic>;
      await _triggerNotification(recipientId: data['senderId'], type: 'walk_started', data: {'walkId': walkId});
      await _triggerNotification(recipientId: data['recipientId'], type: 'walk_started', data: {'walkId': walkId});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> endWalk({
    required String walkId,
    required String userIdEnding,
    required bool isWalker,
    required double scheduledDurationMinutes,
    required double elapsedMinutes,
    // [REMOVED] agreedRatePerHour
    required double finalDistanceKm,
  }) async {
    final WriteBatch batch = _firestore.batch();

    String status;
    if (isWalker && elapsedMinutes < scheduledDurationMinutes) {
      status = 'CancelledByWalker';
    } else if (!isWalker && elapsedMinutes < scheduledDurationMinutes) {
      status = 'CancelledByWanderer';
    } else {
      status = 'Completed';
    }

    // [MODIFIED] Call new calculation function
    double amountDue = _calculateFare(
      scheduledDurationMinutes: scheduledDurationMinutes,
      elapsedMinutes: elapsedMinutes,
      finalDistanceKm: finalDistanceKm,
      status: status,
    );

    final finalStatsData = {
      'elapsedMinutes': elapsedMinutes.round(),
      'finalDistanceKm': double.parse(finalDistanceKm.toStringAsFixed(1)),
      'amountDue': double.parse(amountDue.toStringAsFixed(2)),
      'status': status,
    };

    final endData = {
      'status': status,
      'endTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'completedBy': userIdEnding,
      'finalStats': finalStatsData,
      'summaryAvailable': true,
    };

    batch.update(_requestsCollection.doc(walkId), endData);
    batch.update(_acceptedWalksCollection.doc(walkId), endData);

    final walkDoc = await _acceptedWalksCollection.doc(walkId).get();
    final walkData = walkDoc.data() as Map<String, dynamic>? ?? {};
    final senderId = walkData['senderId'] as String?;
    final recipientId = walkData['recipientId'] as String?;

    if (senderId != null) batch.update(_usersCollection.doc(senderId), {'activeWalkId': FieldValue.delete()});
    if (recipientId != null) batch.update(_usersCollection.doc(recipientId), {'activeWalkId': FieldValue.delete()});

    await batch.commit();

    // Ensure redundant write for summary availability
    await _acceptedWalksCollection.doc(walkId).update({
      'finalStats': finalStatsData,
      'status': status,
      'summaryAvailable': true,
    });

    if (senderId != null) {
      await _triggerNotification(recipientId: senderId, type: 'walk_summary_available', data: {'walkId': walkId, 'finalStats': finalStatsData, 'status': status});
    }
    if (recipientId != null) {
      await _triggerNotification(recipientId: recipientId, type: 'walk_summary_available', data: {'walkId': walkId, 'finalStats': finalStatsData, 'status': status});
    }

    return finalStatsData;
  }

  Future<bool> declineRequest(String walkId) async {
    try {
      await _requestsCollection.doc(walkId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

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
      await _acceptedWalksCollection.doc(walkId).set({'messagesCount': FieldValue.increment(1)}, SetOptions(merge: true));

      final walkDoc = await _acceptedWalksCollection.doc(walkId).get();
      final walkData = walkDoc.data() as Map<String, dynamic>? ?? {};
      final recipientId = walkData['senderId'] == senderId ? walkData['recipientId'] : walkData['senderId'];

      if (recipientId != null) {
        await _triggerNotification(recipientId: recipientId, type: 'chat_message', data: {'walkId': walkId, 'text': text});
      }
    } catch (e) {
      debugPrint("[WalkRequestService] Error sending message for $walkId: $e");
      throw Exception('Failed to send message.');
    }
  }

  Stream<List<Map<String, dynamic>>> getWalkMessages(String walkId) {
    return _acceptedWalksCollection
        .doc(walkId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // --- [NEW] GROUP WALK FUNCTIONS ---

  // 1. Create Group Walk
  Future<String?> createGroupWalk(Map<String, dynamic> walkData) async {
    try {
      DocumentReference docRef = await _groupWalksCollection.add(walkData);
      debugPrint("[WalkRequestService] Group Walk created with ID: ${docRef.id}");
      return docRef.id;
    } catch (e) {
      debugPrint("[WalkRequestService] Error creating group walk: $e");
      return null;
    }
  }

  // 2. Join Group Walk
  Future<bool> joinGroupWalk(String walkId, String userId, Map<String, dynamic> userInfo) async {
    try {
      await _groupWalksCollection.doc(walkId).update({
        'participants': FieldValue.arrayUnion([{
          'userId': userId,
          'name': userInfo['name'],
          'imageUrl': userInfo['imageUrl'],
        }]),
        'participantCount': FieldValue.increment(1),
      });
      debugPrint("[WalkRequestService] User $userId joined group walk $walkId");
      return true;
    } catch (e) {
      debugPrint("[WalkRequestService] Error joining group walk: $e");
      return false;
    }
  }

  // 3. Start Group Walk
  Future<bool> startGroupWalk(String walkId, String walkerId) async {
    try {
      WriteBatch batch = _firestore.batch();

      final doc = await _groupWalksCollection.doc(walkId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final participants = (data['participants'] as List<dynamic>?)?.map((p) => p['userId'] as String).toList() ?? [];

      // Set walk status to Started
      batch.update(_groupWalksCollection.doc(walkId), {
        'status': 'Started',
        'actualStartTime': FieldValue.serverTimestamp(),
      });

      // Set activeGroupWalkId for the Walker
      batch.update(_usersCollection.doc(walkerId), {
        'activeGroupWalkId': walkId,
      });

      // Set activeGroupWalkId for all participants
      for (String userId in participants) {
        batch.update(_usersCollection.doc(userId), {
          'activeGroupWalkId': walkId,
        });
        // Notify participant
        await _triggerNotification(
          recipientId: userId,
          type: 'group_walk_started',
          data: {'walkId': walkId, 'title': data['title']},
        );
      }

      await batch.commit();
      debugPrint("[WalkRequestService] Group Walk $walkId started.");
      return true;

    } catch (e) {
      debugPrint("[WalkRequestService] Error starting group walk: $e");
      return false;
    }
  }

  // 4. End Group Walk
  Future<bool> endGroupWalk(String walkId, String walkerId, double price, int participantCount) async {
    try {
      WriteBatch batch = _firestore.batch();

      final doc = await _groupWalksCollection.doc(walkId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final participants = (data['participants'] as List<dynamic>?)?.map((p) => p['userId'] as String).toList() ?? [];

      // Calculate earnings if not passed (optional safety check)
      if (price == 0.0) price = (data['price'] as num?)?.toDouble() ?? 0.0;
      if (participantCount == 0) participantCount = (data['participantCount'] as num?)?.toInt() ?? 0;

      final double totalEarnings = price * participantCount;

      // Set walk status to Completed
      batch.update(_groupWalksCollection.doc(walkId), {
        'status': 'Completed',
        'endTime': FieldValue.serverTimestamp(),
        'totalEarnings': totalEarnings,
      });

      // Clear activeGroupWalkId for the Walker and update earnings
      batch.update(_usersCollection.doc(walkerId), {
        'activeGroupWalkId': FieldValue.delete(),
        'earnings': FieldValue.increment(totalEarnings),
        'walks': FieldValue.increment(1),
      });

      // Clear activeGroupWalkId for all participants
      for (String userId in participants) {
        batch.update(_usersCollection.doc(userId), {
          'activeGroupWalkId': FieldValue.delete(),
          'walks': FieldValue.increment(1),
        });
        await _triggerNotification(
          recipientId: userId,
          type: 'group_walk_completed',
          data: {'walkId': walkId, 'title': data['title']},
        );
      }

      await batch.commit();
      debugPrint("[WalkRequestService] Group Walk $walkId ended. Walker earned $totalEarnings");
      return true;

    } catch (e) {
      debugPrint("[WalkRequestService] Error ending group walk: $e");
      return false;
    }
  }

  // 5. Send Group Message
  Future<void> sendGroupMessage({
    required String walkId,
    required String senderId,
    required String text,
  }) async {
    try {
      await _groupWalksCollection.doc(walkId).collection('messages').add({
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("[WalkRequestService] Error sending group message for $walkId: $e");
    }
  }

  // 6. Get Group Messages
  Stream<List<Map<String, dynamic>>> getGroupWalkMessages(String walkId) {
    return _groupWalksCollection
        .doc(walkId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }
}