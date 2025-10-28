import 'package:aidkriya_walker/screens/walk_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/incoming_request_display.dart';
import '../find_walker_screen.dart';
import '../components/walker_avatar.dart'; // Assuming path

class WandererActiveWalkScreen extends StatefulWidget {
  final String walkId;

  const WandererActiveWalkScreen({super.key, required this.walkId});

  @override
  State<WandererActiveWalkScreen> createState() => _WandererActiveWalkScreenState();
}

class _WandererActiveWalkScreenState extends State<WandererActiveWalkScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper to clear the active walk ID from the user profile
  Future<void> _clearActiveWalkId() async {
    if (_currentUserId.isNotEmpty) {
      await _firestore.collection('users').doc(_currentUserId).update({'activeWalkId': FieldValue.delete()});
    }
  }

  void _navigateToSummaryOrFindWalker({required Map<String, dynamic> walkData, required String status, Map<String, dynamic>? finalStats}) {
    if (!mounted) return;

    // Clear the active walk ID from the Wanderer's profile
    _clearActiveWalkId();

    if (status == 'Completed' || status.contains('Cancelled')) {
      // Reconstruct basic IncomingRequestDisplay for the Summary Screen
      final IncomingRequestDisplay displayData = IncomingRequestDisplay(
        walkId: widget.walkId,
        senderId: walkData['senderId'] ?? '',
        recipientId: walkData['recipientId'] ?? '',
        senderName: walkData['senderInfo']?['fullName'] ?? 'Wanderer',
        date: walkData['date'] ?? '',
        time: walkData['time'] ?? '',
        duration: walkData['duration'] ?? '',
        latitude: (walkData['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (walkData['longitude'] as num?)?.toDouble() ?? 0.0,
        status: status,
        distance: (finalStats?['finalDistanceKm'] as num?)?.toInt() ?? (walkData['walkerProfile']?['distance'] as num?)?.toInt() ?? 0,
        notes: walkData['notes'],
      );

      // Navigate to Summary (even if cancelled, the summary shows the details)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => WalkSummaryScreen(
            walkData: displayData,
            finalStats: finalStats ?? {}, // Pass final stats if available
          ),
        ),
      );
    } else {
      // Should navigate to FindWalkerScreen if somehow activeWalkId was cleared but we ended up here.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const FindWalkerScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      // Listen to the accepted_walks document for real-time updates
      stream: _firestore.collection('accepted_walks').doc(widget.walkId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If document is missing or stream errors, handle as ended/missing
        if (!snapshot.hasData || !snapshot.data!.exists || snapshot.hasError) {
          return const Scaffold(body: Center(child: Text("Walk session ended or not found.")));
        }

        final walkData = snapshot.data!.data() as Map<String, dynamic>;
        final currentStatus = walkData['status'] as String? ?? 'Accepted';

        // 1. CHECK FOR FINAL STATUS AND NAVIGATE
        if (currentStatus == 'Completed' || currentStatus.contains('Cancelled')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToSummaryOrFindWalker(
              walkData: walkData,
              status: currentStatus,
              finalStats: walkData['finalStats'] as Map<String, dynamic>?,
            );
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. BUILD ACTIVE STATUS VIEW
        final walkerName = walkData['recipientInfo']?['fullName'] ?? 'Walker';
        final walkerImageUrl = walkData['recipientInfo']?['imageUrl'];
        final isWalkStarted = currentStatus == 'Started';

        return Scaffold(
          appBar: AppBar(
            title: const Text("My Active Walk"),
            backgroundColor: isWalkStarted ? Colors.green : Colors.orange,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false, // The only way back is by ending the walk/app closure
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Display Walker Info
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        WalkerAvatar(imageUrl: walkerImageUrl, size: 50),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Walker: $walkerName", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Scheduled: ${walkData['time'] ?? ''} for ${walkData['duration'] ?? ''}"),
                            if (isWalkStarted)
                              const Text("Walk started!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Live Status Indicator/Message
                _buildStatusIndicator(currentStatus),

                const SizedBox(height: 30),

                // Map/Tracker Placeholder
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
                    ),
                    child: Center(
                      child: Text(
                        isWalkStarted ?
                        "Walk in progress! Stay safe." :
                        "Walker accepted and is preparing to meet you at the agreed location. Stay near your pick-up spot.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Call / Message Button (Placeholder for now)
                ElevatedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calling/Messaging Walker...'))),
                  icon: const Icon(Icons.call),
                  label: const Text("Contact Walker"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15)
                  ),
                ),
                const SizedBox(height: 10),

                // Cancel Button (Calls finalization logic)
                TextButton(
                  onPressed: () => _showCancelConfirmation(context, walkData),
                  child: const Text(
                      "Cancel Walk",
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color color;
    String message;

    switch (status) {
      case 'Accepted':
        color = Colors.orange;
        message = "Walker is confirmed.";
        break;
      case 'Started':
        color = Colors.green;
        message = "Walk is LIVE! Timer running.";
        break;
      default:
        color = Colors.blueGrey;
        message = "Awaiting Walker's action.";
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(Icons.info, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text("Current Status: $status. $message", style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context, Map<String, dynamic> walkData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Walk?"),
        content: Text(
          walkData['status'] == 'Started'
              ? "The walk has started. Cancelling now will end the walk and you will be charged pro-rata for time elapsed."
              : "Are you sure you want to cancel the pending request?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Go Back")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _endWalkAsWanderer(walkData);
            },
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _endWalkAsWanderer(Map<String, dynamic> walkData) async {
    // In a real app, Wanderer must have a way to track elapsedMinutes.
    // Since our logic for payment lives in endWalk, we must call it.
    // We simulate the elapsed time here based on difference from startTime, if available.
    // For simplicity, we default elapsedMinutes to 0 if not started, ensuring 0 fare/easy cancellation.

    double elapsedMinutes = 0.0;
    if (walkData['status'] == 'Started') {
      final startTime = (walkData['actualStartTime'] as Timestamp?)?.toDate();
      if (startTime != null) {
        elapsedMinutes = DateTime.now().difference(startTime).inSeconds / 60.0;
      }
    }

    try {
      final double scheduledDurationMinutes = double.tryParse(walkData['duration'].toString().split(' ')[0]) ?? 30.0;
      final double agreedRatePerHour = 100.0; // Mock rate

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Finalizing cancellation...")));

      final Map<String, dynamic> finalStats = await _firestore.runTransaction((transaction) async {
        // Since the Wanderer is initiating the end, we need to provide accurate stats
        // or let the Cloud Function handle the final calculation.
        // For now, we simulate the completion stats:
        return await _firestore.collection('accepted_walks').doc(widget.walkId).get().then((doc) async {
          if (doc.exists) {
            // Simulate calling the backend service's final logic (simplified here)
            // In production, this call would be wrapped in a Cloud Function
            await _firestore.collection('accepted_walks').doc(widget.walkId).update({'status': 'Cancelling'});

            return {
              'elapsedMinutes': elapsedMinutes.round(),
              'finalDistanceKm': 0.0, // Cannot get accurate distance from Wanderer side easily
              'amountDue': (elapsedMinutes / 60.0) * agreedRatePerHour, // Pro-rata fare
            };
          } else {
            throw Exception("Walk data missing.");
          }
        });
      });

      // Update walk status to final state and navigate
      await _firestore.collection('accepted_walks').doc(widget.walkId).update({
        'status': 'CancelledByWanderer',
        'finalStats': finalStats,
        'endTime': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('requests').doc(widget.walkId).update({'status': 'CancelledByWanderer'});

    } catch (e) {
      debugPrint("Error ending walk as Wanderer: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel walk: $e')));
    }
  }
}