// lib/backend/walk_request_service.dart
// (No changes to imports or _calculateFare)

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
  // In a real system, you might cap at scheduled + grace period.
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

  // 🔥 Replace this with your deployed backend URL
  final String _serverUrl = "http://172.22.72.110:3000/api/sendNotification";

  final String _scheduleUrl = "http://172.22.72.110:3000/api/schedule-walk";
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

  /// ------------------ FIXED SEND REQUEST ------------------
  /// This properly handles both instant and scheduled walks
  Future<String?> sendRequest(Map<String, dynamic> requestData) async {
    try {
      if (requestData['senderId'] == null ||
          requestData['recipientId'] == null) {
        throw ArgumentError("senderId and recipientId must be provided.");
      }

      // ✅ KEY FIX: Check if scheduledTimestamp exists AND is a future date
      if (requestData['scheduledTimestamp'] == null) {
        // It's an INSTANT walk - no scheduled time provided
        debugPrint(
          "[WalkRequestService] Creating INSTANT walk (no scheduledTimestamp)",
        );
        requestData['status'] = 'Pending';
        requestData['scheduledTimestamp'] = FieldValue.serverTimestamp();
      } else {
        // scheduledTimestamp exists - need to check if it's actually in the future
        final timestamp = requestData['scheduledTimestamp'];

        if (timestamp is Timestamp) {
          final scheduledDate = timestamp.toDate();
          final now = DateTime.now();
          final twoMinutesFromNow = now.add(const Duration(minutes: 2));

          if (scheduledDate.isAfter(twoMinutesFromNow)) {
            // It's a SCHEDULED walk for the future
            debugPrint(
              "[WalkRequestService] Creating SCHEDULED walk for: $scheduledDate",
            );
            requestData['status'] = 'Scheduled';
          } else {
            // The timestamp is too close or in the past - treat as instant
            debugPrint(
              "[WalkRequestService] Scheduled time too close, treating as INSTANT walk",
            );
            requestData['status'] = 'Pending';
            requestData['scheduledTimestamp'] = FieldValue.serverTimestamp();
          }
        } else {
          // Invalid timestamp format - treat as instant
          debugPrint(
            "[WalkRequestService] WARNING: Invalid scheduledTimestamp format, treating as INSTANT",
          );
          requestData['status'] = 'Pending';
          requestData['scheduledTimestamp'] = FieldValue.serverTimestamp();
        }
      }

      requestData['createdAt'] = FieldValue.serverTimestamp();
      requestData['updatedAt'] = FieldValue.serverTimestamp();

      debugPrint(
        "[WalkRequestService] Final request status: ${requestData['status']}",
      );

      DocumentReference docRef = await _requestsCollection.add(requestData);
      debugPrint(
        "[WalkRequestService] Request sent successfully with ID: ${docRef.id}",
      );

      // ✅ Notify walker (recipient)
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
    debugPrint(
      "[WalkRequestService] Subscribing to pending/scheduled requests for Walker: $walkerId",
    );
    return _requestsCollection
        .where('recipientId', isEqualTo: walkerId)
    // [MODIFIED] Query for both statuses
        .where('status', whereIn: ['Pending', 'Scheduled'])
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map(
            (doc) => WalkRequest.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
          .toList();

      requests.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return requests;
    })
        .handleError((error) {
      debugPrint(
        "[WalkRequestService] Error fetching pending requests: $error",
      );
      return <WalkRequest>[];
    });
  }

  /// ------------------ ACCEPT REQUEST (FIXED VERSION) ------------------
  /// This version has comprehensive error handling and debugging
  Future<bool> acceptRequest({
    required String walkId,
    required String senderId,
    required String recipientId,
  }) async {
    debugPrint("========================================");
    debugPrint("[WalkRequestService] Attempting to accept request: $walkId");
    debugPrint("[WalkRequestService] SenderId: $senderId");
    debugPrint("[WalkRequestService] RecipientId: $recipientId");
    debugPrint("========================================");

    try {
      WriteBatch batch = _firestore.batch();

      // Step 1: Get the request document
      debugPrint("[WalkRequestService] Step 1: Fetching request document...");
      DocumentSnapshot requestDoc = await _requestsCollection.doc(walkId).get();

      if (!requestDoc.exists) {
        debugPrint(
          "[WalkRequestService] ERROR: Request $walkId not found in Firestore",
        );
        throw Exception("Request $walkId not found.");
      }

      debugPrint("[WalkRequestService] ✅ Request document found");
      Map<String, dynamic> acceptedRequestData =
      requestDoc.data() as Map<String, dynamic>;
      debugPrint(
        "[WalkRequestService] Request data: ${acceptedRequestData.toString().substring(0, 200)}...",
      );

      // Step 2: Delete other pending/scheduled requests from this sender
      debugPrint(
        "[WalkRequestService] Step 2: Checking for other pending requests...",
      );
      QuerySnapshot otherPendingRequests = await _requestsCollection
          .where('senderId', isEqualTo: senderId)
          .where('status', whereIn: ['Pending', 'Scheduled'])
          .get();

      debugPrint(
        "[WalkRequestService] Found ${otherPendingRequests.docs.length} other pending requests",
      );

      for (var doc in otherPendingRequests.docs) {
        if (doc.id != walkId) {
          debugPrint("[WalkRequestService] Deleting other request: ${doc.id}");
          batch.delete(doc.reference);
        }
      }

      // Step 3: Update the request status
      debugPrint(
        "[WalkRequestService] Step 3: Updating request status to Accepted...",
      );
      batch.update(_requestsCollection.doc(walkId), {
        'status': 'Accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      acceptedRequestData['status'] = 'Accepted';
      acceptedRequestData['updatedAt'] = FieldValue.serverTimestamp();
      acceptedRequestData['messagesCount'] =
          acceptedRequestData['messagesCount'] ?? 0;
      if (acceptedRequestData['createdAt'] == null ||
          !(acceptedRequestData['createdAt'] is Timestamp)) {
        acceptedRequestData['createdAt'] = FieldValue.serverTimestamp();
      }

      // Step 4: Create accepted walk document
      debugPrint(
        "[WalkRequestService] Step 4: Creating accepted_walks document...",
      );
      batch.set(_acceptedWalksCollection.doc(walkId), acceptedRequestData);

      // Step 5: Check if scheduled for future
      debugPrint(
        "[WalkRequestService] Step 5: Checking if walk is scheduled for future...",
      );
      final scheduledTimestamp = acceptedRequestData['scheduledTimestamp'];

      if (scheduledTimestamp == null) {
        debugPrint("[WalkRequestService] ERROR: scheduledTimestamp is null!");
        throw Exception("scheduledTimestamp is missing in request data");
      }

      debugPrint(
        "[WalkRequestService] scheduledTimestamp type: ${scheduledTimestamp.runtimeType}",
      );
      debugPrint(
        "[WalkRequestService] scheduledTimestamp value: $scheduledTimestamp",
      );

      // Convert to DateTime
      DateTime scheduledDateTime;
      try {
        if (scheduledTimestamp is Timestamp) {
          scheduledDateTime = scheduledTimestamp.toDate();
          debugPrint(
            "[WalkRequestService] Converted Timestamp to DateTime: $scheduledDateTime",
          );
        } else if (scheduledTimestamp is String) {
          scheduledDateTime = DateTime.parse(scheduledTimestamp);
          debugPrint(
            "[WalkRequestService] Parsed String to DateTime: $scheduledDateTime",
          );
        } else {
          throw Exception(
            "Invalid scheduledTimestamp format: ${scheduledTimestamp.runtimeType}",
          );
        }
      } catch (e) {
        debugPrint("[WalkRequestService] ERROR parsing scheduledTimestamp: $e");
        throw Exception("Failed to parse scheduledTimestamp: $e");
      }

      final now = DateTime.now();
      final twoMinutesFromNow = now.add(const Duration(minutes: 2));
      final bool isScheduledForFuture = scheduledDateTime.isAfter(
        twoMinutesFromNow,
      );

      debugPrint("[WalkRequestService] Current time: $now");
      debugPrint("[WalkRequestService] Scheduled time: $scheduledDateTime");
      debugPrint(
        "[WalkRequestService] Two minutes from now: $twoMinutesFromNow",
      );
      debugPrint(
        "[WalkRequestService] Is scheduled for future? $isScheduledForFuture",
      );

      if (isScheduledForFuture) {
        // IT'S A SCHEDULED WALK
        debugPrint("========================================");
        debugPrint("[WalkRequestService] 🕐 SCHEDULED WALK DETECTED");
        debugPrint("[WalkRequestService] Will activate at: $scheduledDateTime");
        debugPrint("========================================");

        // 1. Only add to journeys. DO NOT set activeWalkId.
        debugPrint(
          "[WalkRequestService] Step 6a: Adding to user journeys (no activeWalkId)...",
        );
        batch.update(_usersCollection.doc(senderId), {
          'journeys': FieldValue.arrayUnion([walkId]),
        });
        batch.update(_usersCollection.doc(recipientId), {
          'journeys': FieldValue.arrayUnion([walkId]),
        });

        // 2. Commit Firestore changes BEFORE calling backend
        debugPrint(
          "[WalkRequestService] Step 7a: Committing Firestore batch...",
        );
        await batch.commit();
        debugPrint(
          "[WalkRequestService] ✅ Firestore batch committed successfully",
        );

        // 3. Call backend to schedule the activation
        debugPrint(
          "[WalkRequestService] Step 8a: Calling backend scheduler...",
        );
        debugPrint("[WalkRequestService] Backend URL: $_scheduleUrl");
        debugPrint("[WalkRequestService] Payload:");
        debugPrint("  - walkId: $walkId");
        debugPrint("  - senderId: $senderId");
        debugPrint("  - recipientId: $recipientId");
        debugPrint(
          "  - scheduledTimestampISO: ${scheduledDateTime.toIso8601String()}",
        );

        try {
          final response = await http
              .post(
            Uri.parse(_scheduleUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'walkId': walkId,
              'senderId': senderId,
              'recipientId': recipientId,
              'scheduledTimestampISO': scheduledDateTime.toIso8601String(),
            }),
          )
              .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception("Backend request timed out after 10 seconds");
            },
          );

          debugPrint(
            "[WalkRequestService] Backend response status: ${response.statusCode}",
          );
          debugPrint(
            "[WalkRequestService] Backend response body: ${response.body}",
          );

          if (response.statusCode != 200) {
            throw Exception(
              "Backend scheduling failed with status ${response.statusCode}: ${response.body}",
            );
          }

          debugPrint(
            "[WalkRequestService] ✅ Backend scheduler called successfully",
          );
        } catch (e) {
          debugPrint("========================================");
          debugPrint("[WalkRequestService] ❌ ERROR calling backend scheduler");
          debugPrint("[WalkRequestService] Error type: ${e.runtimeType}");
          debugPrint("[WalkRequestService] Error message: $e");
          debugPrint("[WalkRequestService] Stack trace:");
          debugPrint("========================================");

          // Rollback: Delete the accepted walk since scheduling failed
          debugPrint(
            "[WalkRequestService] Rolling back: Deleting accepted walk...",
          );
          try {
            await _acceptedWalksCollection.doc(walkId).delete();
            await _requestsCollection.doc(walkId).update({'status': 'Pending'});
            debugPrint("[WalkRequestService] Rollback completed");
          } catch (rollbackError) {
            debugPrint("[WalkRequestService] Rollback failed: $rollbackError");
          }

          throw Exception("Failed to schedule walk on backend: $e");
        }
      } else {
        // IT'S AN INSTANT WALK
        debugPrint("========================================");
        debugPrint("[WalkRequestService] ⚡ INSTANT WALK DETECTED");
        debugPrint("[WalkRequestService] Setting activeWalkId immediately");
        debugPrint("========================================");

        debugPrint(
          "[WalkRequestService] Step 6b: Setting activeWalkId for both users...",
        );
        batch.update(_usersCollection.doc(senderId), {
          'journeys': FieldValue.arrayUnion([walkId]),
          'activeWalkId': walkId,
        });
        batch.update(_usersCollection.doc(recipientId), {
          'journeys': FieldValue.arrayUnion([walkId]),
          'activeWalkId': walkId,
        });

        debugPrint(
          "[WalkRequestService] Step 7b: Committing Firestore batch...",
        );
        await batch.commit();
        debugPrint(
          "[WalkRequestService] ✅ Firestore batch committed successfully",
        );
      }

      debugPrint(
        "[WalkRequestService] Step 9: Sending notification to sender...",
      );
      // Notify wanderer (sender)
      await _triggerNotification(
        recipientId: senderId,
        type: 'request_accepted',
        data: {'walkId': walkId},
      );

      debugPrint("========================================");
      debugPrint(
        "[WalkRequestService] ✅ Request $walkId accepted successfully",
      );
      debugPrint("========================================");
      return true;
    } catch (e, stackTrace) {
      debugPrint("========================================");
      debugPrint("[WalkRequestService] ❌❌❌ ERROR accepting request $walkId");
      debugPrint("[WalkRequestService] Error type: ${e.runtimeType}");
      debugPrint("[WalkRequestService] Error message: $e");
      debugPrint("[WalkRequestService] Stack trace:");
      debugPrint(stackTrace.toString());
      debugPrint("========================================");
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
      final data = walkDoc.data() as Map<String, dynamic>;
      await _triggerNotification(
        recipientId: data['senderId'],
        type: 'walk_started',
        data: {'walkId': walkId},
      );
      await _triggerNotification(
        recipientId: data['recipientId'],
        type: 'walk_started',
        data: {'walkId': walkId},
      );

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
    // [REMOVED] required double agreedRatePerHour,
    required double finalDistanceKm,
  }) async {
    debugPrint(
      "[WalkRequestService] Ending walk: $walkId by $userIdEnding. Initiated by ${isWalker ? 'Walker' : 'Wanderer'}.",
    );

    final WriteBatch batch = _firestore.batch();

    String status;
    double amountDue;

    if (isWalker && elapsedMinutes < scheduledDurationMinutes) {
      status = 'CancelledByWalker';
    } else if (!isWalker && elapsedMinutes < scheduledDurationMinutes) {
      status = 'CancelledByWanderer';
    } else {
      status = 'Completed';
    }

    // [MODIFIED] Call new calculation function
    amountDue = _calculateFare(
      scheduledDurationMinutes: scheduledDurationMinutes,
      elapsedMinutes: elapsedMinutes,
      finalDistanceKm: finalDistanceKm,
      status: status, // Pass status for internal logic
    );

    final finalStatsData = {
      'elapsedMinutes': elapsedMinutes.round(),
      'finalDistanceKm': double.parse(finalDistanceKm.toStringAsFixed(1)),
      'amountDue': double.parse(amountDue.toStringAsFixed(2)),
      'status': status, // <-- [ADDED THIS LINE]
    };

    // include a summaryAvailable flag so clients know summary is ready
    final endData = {
      'status': status,
      'endTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'completedBy': userIdEnding,
      'finalStats': finalStatsData,
      'summaryAvailable': true, // <-- NEW
      // optionally track who has seen it:
      'summaryShownTo': FieldValue.arrayUnion([]), // start empty
    };

    batch.update(_requestsCollection.doc(walkId), endData);
    batch.update(_acceptedWalksCollection.doc(walkId), endData);

    final walkDoc = await _acceptedWalksCollection.doc(walkId).get();
    final walkData = walkDoc.data() as Map<String, dynamic>? ?? {};
    final senderId = walkData['senderId'] as String?;
    final recipientId = walkData['recipientId'] as String?;

    if (senderId != null) {
      batch.update(_usersCollection.doc(senderId), {
        'activeWalkId': FieldValue.delete(),
      });
    }
    if (recipientId != null) {
      batch.update(_usersCollection.doc(recipientId), {
        'activeWalkId': FieldValue.delete(),
      });
    }

    await batch.commit();

    // Ensure the accepted_walks document has finalStats + summaryAvailable set (redundant safe write)
    await _firestore.collection('accepted_walks').doc(walkId).update({
      'finalStats': finalStatsData,
      'status': status,
      'summaryAvailable': true,
    });

    // ✅ Notify both users: existing 'walk_$status' AND explicit 'walk_summary_available' with finalStats
    if (senderId != null) {
      await _triggerNotification(
        recipientId: senderId,
        type: 'walk_$status',
        data: {'walkId': walkId, 'status': status},
      );

      await _triggerNotification(
        recipientId: senderId,
        type: 'walk_summary_available',
        data: {'walkId': walkId, 'finalStats': finalStatsData, 'status': status},
      );
    }
    if (recipientId != null) {
      await _triggerNotification(
        recipientId: recipientId,
        type: 'walk_$status',
        data: {'walkId': walkId, 'status': status},
      );

      await _triggerNotification(
        recipientId: recipientId,
        type: 'walk_summary_available',
        data: {'walkId': walkId, 'finalStats': finalStatsData, 'status': status},
      );
    }

    return finalStatsData;
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

      await _acceptedWalksCollection
          .doc(walkId)
          .collection('messages')
          .add(messageData);

      await _acceptedWalksCollection.doc(walkId).set({
        'messagesCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

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
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }
}