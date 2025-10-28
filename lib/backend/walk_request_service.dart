import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import '../model/walk_request.dart';


double _calculateFare({
  required double scheduledDurationMinutes,
  required double elapsedMinutes,
  required double agreedRatePerHour, // Assuming a rate exists on the walker's profile or in the request
}) {
  // If elapsed time is less than half the scheduled time, the fare is minimal (e.g., 0 for walker-initiated premature end).
  // If the walk is completed successfully (either on time or automatically), the full fare is usually paid.

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
  final CollectionReference _requestsCollection = FirebaseFirestore.instance
      .collection('requests');
  final CollectionReference _acceptedWalksCollection = FirebaseFirestore
      .instance
      .collection('accepted_walks');
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('users');

  // --- 1. Send Request ---
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
      debugPrint(
        "[WalkRequestService] Request sent successfully with ID: ${docRef.id}",
      );
      return docRef.id;
    } catch (e) {
      debugPrint("[WalkRequestService] Error sending request: $e");
      return null;
    }
  }

  // --- 2. Get Pending Requests for Walker ---
  /// 🔧 FIXED: Removed orderBy to prevent composite index requirement
  Stream<List<WalkRequest>> getPendingRequestsForWalker(String walkerId) {
    debugPrint(
      "[WalkRequestService] Subscribing to pending requests for Walker: $walkerId",
    );

    return _requestsCollection
        .where('recipientId', isEqualTo: walkerId)
        .where('status', isEqualTo: 'Pending')
        // ❌ Removed: .orderBy('createdAt', descending: true)
        // This requires a composite index that may not exist
        .snapshots()
        .map((snapshot) {
          debugPrint(
            "[WalkRequestService] ✅ Received ${snapshot.docs.length} pending requests for Walker: $walkerId",
          );

          // Sort in memory instead (small dataset)
          final requests = snapshot.docs.map((doc) {
            return WalkRequest.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();

          // Sort by createdAt in memory
          requests.sort((a, b) {
            final aTime = a.createdAt ?? DateTime(2000);
            final bTime = b.createdAt ?? DateTime(2000);
            return bTime.compareTo(aTime); // Descending
          });

          debugPrint("[WalkRequestService] Sorted ${requests.length} requests");
          return requests;
        })
        .handleError((error) {
          debugPrint(
            "[WalkRequestService] ❌ Error fetching pending requests: $error",
          );
          // Return empty list instead of throwing
          return <WalkRequest>[];
        });
  }

  // --- 3. Accept Request ---
  Future<bool> acceptRequest({
    required String walkId,
    required String senderId,
    required String recipientId,
  }) async {
    debugPrint("[WalkRequestService] Attempting to accept request: $walkId");
    try {
      WriteBatch batch = _firestore.batch();

      DocumentSnapshot requestDoc = await _requestsCollection.doc(walkId).get();
      if (!requestDoc.exists) {
        throw Exception("Request $walkId not found in 'requests' collection.");
      }
      Map<String, dynamic> acceptedRequestData =
          requestDoc.data() as Map<String, dynamic>;

      // Delete other pending requests from the same sender
      QuerySnapshot otherPendingRequests = await _requestsCollection
          .where('senderId', isEqualTo: senderId)
          .where('status', isEqualTo: 'Pending')
          .get();

      for (var doc in otherPendingRequests.docs) {
        if (doc.id != walkId) {
          batch.delete(doc.reference);
          debugPrint(
            "[WalkRequestService] Deleting conflicting request: ${doc.id}",
          );
        }
      }

      // Update status to Accepted
      batch.update(_requestsCollection.doc(walkId), {
        'status': 'Accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create in accepted_walks
      acceptedRequestData['status'] = 'Accepted';
      acceptedRequestData['updatedAt'] = FieldValue.serverTimestamp();
      if (acceptedRequestData['createdAt'] == null ||
          !(acceptedRequestData['createdAt'] is Timestamp)) {
        acceptedRequestData['createdAt'] = FieldValue.serverTimestamp();
      }
      batch.set(_acceptedWalksCollection.doc(walkId), acceptedRequestData);

      // Update journeys and activeWalkId
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
      return true;
    } catch (e) {
      debugPrint("[WalkRequestService] Error accepting request $walkId: $e");
      return false;
    }
  }

  // --- 4. Decline Request ---
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

  Future<Map<String, dynamic>> endWalk({
    required String walkId,
    required String userIdEnding,
    required bool isWalker,
    required double scheduledDurationMinutes,
    required double elapsedMinutes,
    required double agreedRatePerHour,
    required double finalDistanceKm,
  }) async {
    debugPrint("[WalkRequestService] Ending walk: $walkId by $userIdEnding");
    WriteBatch batch = _firestore.batch();

    // Determine status and final payment terms
    String status = 'Completed';
    double amountDue = 0.0;

    // Check for premature end by the Walker (no pay)
    if (isWalker && elapsedMinutes < scheduledDurationMinutes) {
      // Walker ends early, which is usually penalized or results in 0 pay.
      amountDue = 0.0;
      status = 'CancelledByWalker';
      debugPrint("[WalkRequestService] Walk cancelled prematurely by Walker. Amount Due: 0.");
    } else if (!isWalker && elapsedMinutes < scheduledDurationMinutes) {
      // Wanderer ends early. Pay pro-rata.
      amountDue = _calculateFare(
        scheduledDurationMinutes: scheduledDurationMinutes,
        elapsedMinutes: elapsedMinutes,
        agreedRatePerHour: agreedRatePerHour,
      );
      debugPrint("[WalkRequestService] Walk cancelled prematurely by Wanderer. Amount Due: $amountDue (pro-rata).");
      status = 'CancelledByWanderer';
    } else {
      // Completed fully or ended automatically (full pay)
      amountDue = _calculateFare(
        scheduledDurationMinutes: scheduledDurationMinutes,
        elapsedMinutes: scheduledDurationMinutes, // Pay full if completed or auto-ended
        agreedRatePerHour: agreedRatePerHour,
      );
      status = 'Completed';
      debugPrint("[WalkRequestService] Walk completed successfully/automatically. Amount Due: $amountDue (full fare).");
    }

    final endData = {
      'status': status,
      'endTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'completedBy': userIdEnding,
      'finalStats': {
        'elapsedMinutes': elapsedMinutes.round(),
        'finalDistanceKm': double.parse(finalDistanceKm.toStringAsFixed(1)),
        'amountDue': double.parse(amountDue.toStringAsFixed(2)),
      },
    };

    // 1. Update status and final stats in both collections
    batch.update(_requestsCollection.doc(walkId), endData);
    batch.update(_acceptedWalksCollection.doc(walkId), endData);

    // 2. Clear activeWalkId from both users
    // (You need to fetch senderId/recipientId from the walkDoc first or pass them)
    DocumentSnapshot walkDoc = await _acceptedWalksCollection.doc(walkId).get();
    if (walkDoc.exists && walkDoc.data() != null) {
      Map<String, dynamic> walkData = walkDoc.data() as Map<String, dynamic>;
      String senderId = walkData['senderId'];
      String recipientId = walkData['recipientId'];

      batch.update(_usersCollection.doc(senderId), {'activeWalkId': null});
      batch.update(_usersCollection.doc(recipientId), {'activeWalkId': null});
    }

    await batch.commit();
    debugPrint("[WalkRequestService] Walk $walkId finalized successfully. Status: $status");

    return endData['finalStats'] as Map<String, dynamic>;
  }

  // --- . Start Walk (New) ---
  Future<bool> startWalk(String walkId) async {
    debugPrint("[WalkRequestService] Starting walk: $walkId");
    try {
      WriteBatch batch = _firestore.batch();

      // Data to update in both documents
      final updateData = {
        'status': 'Started',
        'actualStartTime': FieldValue.serverTimestamp(), // New field for start time
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update in the original requests collection
      batch.update(_requestsCollection.doc(walkId), updateData);

      // Update in the accepted_walks collection
      batch.update(_acceptedWalksCollection.doc(walkId), updateData);

      await batch.commit();
      debugPrint("[WalkRequestService] Walk $walkId started successfully");

      // TODO: Implement FCM notification to the Wanderer that the walk has started
      return true;
    } catch (e) {
      debugPrint("[WalkRequestService] Error starting walk $walkId: $e");
      return false;
    }
  }

  // --- 5. Get ALL Requests Sent By a User ---
  /// 🔧 FIXED: Single where clause, no composite index needed
  Stream<List<WalkRequest>> getAllSentRequests(String senderId) {
    debugPrint(
      "[WalkRequestService] Subscribing to sent requests for: $senderId",
    );
    return _requestsCollection
        .where('senderId', isEqualTo: senderId)
        // Removed orderBy - sort in memory if needed
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs.map((doc) {
            return WalkRequest.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();

          // Sort in memory
          requests.sort((a, b) {
            final aTime = a.createdAt ?? DateTime(2000);
            final bTime = b.createdAt ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });

          return requests;
        })
        .handleError((error) {
          debugPrint(
            "[WalkRequestService] Error fetching sent requests: $error",
          );
          return <WalkRequest>[];
        });
  }

  // --- 6. Get ALL Requests Received By a User ---
  Stream<List<WalkRequest>> getAllReceivedRequests(String recipientId) {
    debugPrint(
      "[WalkRequestService] Subscribing to received requests for: $recipientId",
    );
    return _requestsCollection
        .where('recipientId', isEqualTo: recipientId)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs.map((doc) {
            return WalkRequest.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();

          requests.sort((a, b) {
            final aTime = a.createdAt ?? DateTime(2000);
            final bTime = b.createdAt ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });

          return requests;
        })
        .handleError((error) {
          debugPrint(
            "[WalkRequestService] Error fetching received requests: $error",
          );
          return <WalkRequest>[];
        });
  }

  // --- 7. Get Accepted Walks ---
  Stream<List<WalkRequest>> getMyAcceptedWalksAsWalker(String userId) {
    debugPrint(
      "[WalkRequestService] Subscribing to accepted walks as Walker: $userId",
    );
    return _acceptedWalksCollection
        .where('recipientId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final walks = snapshot.docs.map((doc) {
            return WalkRequest.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();

          walks.sort((a, b) {
            final aTime = a.createdAt ?? DateTime(2000);
            final bTime = b.createdAt ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });

          return walks;
        })
        .handleError((error) {
          debugPrint(
            "[WalkRequestService] Error fetching accepted walks: $error",
          );
          return <WalkRequest>[];
        });
  }

  Stream<List<WalkRequest>> getMyAcceptedWalksAsWanderer(String userId) {
    debugPrint(
      "[WalkRequestService] Subscribing to accepted walks as Wanderer: $userId",
    );
    return _acceptedWalksCollection
        .where('senderId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final walks = snapshot.docs.map((doc) {
            return WalkRequest.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();

          walks.sort((a, b) {
            final aTime = a.createdAt ?? DateTime(2000);
            final bTime = b.createdAt ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });

          return walks;
        })
        .handleError((error) {
          debugPrint(
            "[WalkRequestService] Error fetching accepted walks: $error",
          );
          return <WalkRequest>[];
        });
  }

  // --- 8. Cancel an Accepted Walk ---
  Future<bool> cancelAcceptedWalk(
    String walkId,
    String userIdCancelling,
  ) async {
    debugPrint("[WalkRequestService] Cancelling walk $walkId");
    WriteBatch batch = _firestore.batch();
    try {
      DocumentSnapshot walkDoc = await _acceptedWalksCollection
          .doc(walkId)
          .get();

      if (!walkDoc.exists) {
        DocumentSnapshot originalRequestDoc = await _requestsCollection
            .doc(walkId)
            .get();
        if (!originalRequestDoc.exists || originalRequestDoc.data() == null) {
          throw Exception("Walk $walkId not found");
        }

        batch.update(_requestsCollection.doc(walkId), {
          'status': 'Cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
          'cancelledBy': userIdCancelling,
        });

        Map<String, dynamic> originalData =
            originalRequestDoc.data() as Map<String, dynamic>;
        String? senderId = originalData['senderId'];
        String? recipientId = originalData['recipientId'];

        if (senderId != null) {
          batch.update(_usersCollection.doc(senderId), {'activeWalkId': null});
        }
        if (recipientId != null) {
          batch.update(_usersCollection.doc(recipientId), {
            'activeWalkId': null,
          });
        }
      } else {
        Map<String, dynamic> walkData = walkDoc.data() as Map<String, dynamic>;
        String senderId = walkData['senderId'];
        String recipientId = walkData['recipientId'];

        batch.update(_requestsCollection.doc(walkId), {
          'status': 'Cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
          'cancelledBy': userIdCancelling,
        });

        batch.update(_acceptedWalksCollection.doc(walkId), {
          'status': 'Cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
          'cancelledBy': userIdCancelling,
        });

        batch.update(_usersCollection.doc(senderId), {
          'journeys': FieldValue.arrayRemove([walkId]),
          'activeWalkId': null,
        });

        batch.update(_usersCollection.doc(recipientId), {
          'journeys': FieldValue.arrayRemove([walkId]),
          'activeWalkId': null,
        });
      }

      await batch.commit();
      debugPrint("[WalkRequestService] Walk $walkId cancelled successfully");
      return true;
    } catch (e) {
      debugPrint("[WalkRequestService] Error cancelling walk $walkId: $e");
      return false;
    }
  }

  // --- 9. Complete a Walk ---
  Future<bool> completeWalk(String walkId, String userIdCompleting) async {
    debugPrint("[WalkRequestService] Completing walk $walkId");
    WriteBatch batch = _firestore.batch();
    try {
      DocumentSnapshot walkDoc = await _acceptedWalksCollection
          .doc(walkId)
          .get();
      if (!walkDoc.exists || walkDoc.data() == null) {
        throw Exception("Accepted walk $walkId not found");
      }

      Map<String, dynamic> walkData = walkDoc.data() as Map<String, dynamic>;
      String senderId = walkData['senderId'];
      String recipientId = walkData['recipientId'];

      batch.update(_requestsCollection.doc(walkId), {
        'status': 'Completed',
        'updatedAt': FieldValue.serverTimestamp(),
        'completedBy': userIdCompleting,
      });

      batch.update(_acceptedWalksCollection.doc(walkId), {
        'status': 'Completed',
        'updatedAt': FieldValue.serverTimestamp(),
        'completedBy': userIdCompleting,
      });

      batch.update(_usersCollection.doc(senderId), {'activeWalkId': null});
      batch.update(_usersCollection.doc(recipientId), {'activeWalkId': null});

      await batch.commit();
      debugPrint("[WalkRequestService] Walk $walkId completed successfully");
      return true;
    } catch (e) {
      debugPrint("[WalkRequestService] Error completing walk $walkId: $e");
      return false;
    }
  }
}
