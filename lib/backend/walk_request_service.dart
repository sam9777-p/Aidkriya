import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import '../model/walk_request.dart';

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
