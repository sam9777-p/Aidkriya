import 'dart:async';

import 'package:aidkriya_walker/screens/walk_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../backend/walk_request_service.dart';
import '../model/incoming_request_display.dart';
import '../find_walker_screen.dart';
import '../components/walker_avatar.dart';
import '../screens/chat_screen.dart'; // Import ChatScreen

// --- Timer Display Widget (_LiveTimeDisplay) ---
class _LiveTimeDisplay extends StatefulWidget {
  final DateTime startTime;
  const _LiveTimeDisplay({required this.startTime});
  @override
  _LiveTimeDisplayState createState() => _LiveTimeDisplayState();
}

class _LiveTimeDisplayState extends State<_LiveTimeDisplay> {
  late Timer _timer;
  String _timeString = '00:00';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateTimeString();
        });
      }
    });
    _updateTimeString();
  }

  void _updateTimeString() {
    final elapsed = DateTime.now().difference(widget.startTime);
    final totalSeconds = elapsed.inSeconds;
    final minutes = totalSeconds < 0 ? 0 : (totalSeconds % 3600) ~/ 60;
    final remainingSeconds = totalSeconds < 0 ? 0 : totalSeconds % 60;
    _timeString =
    "${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _timeString,
      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
    );
  }
}
// --- END TIMER WIDGET ---

class WandererActiveWalkScreen extends StatefulWidget {
  final String walkId;
  const WandererActiveWalkScreen({super.key, required this.walkId});
  @override
  State<WandererActiveWalkScreen> createState() =>
      _WandererActiveWalkScreenState();
}

class _WandererActiveWalkScreenState extends State<WandererActiveWalkScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalkRequestService _walkService = WalkRequestService();
  bool _isNavigating = false; // Prevents double navigation attempts

  @override
  void dispose() {
    // Make sure no async operations try to update state after disposal
    super.dispose();
  }

  Future<void> _clearActiveWalkId() async {
    if (_currentUserId.isNotEmpty) {
      try {
        // NOTE: This logic is redundant because endWalk already clears it, but kept as a safeguard.
        await _firestore
            .collection('users')
            .doc(_currentUserId)
            .update({'activeWalkId': FieldValue.delete()});
        debugPrint(
            "[WandererActiveWalkScreen] Successfully Cleared activeWalkId for user $_currentUserId");
      } catch (e) {
        debugPrint("[WandererActiveWalkScreen] Error clearing activeWalkId: $e");
        // Non-critical error, proceed with navigation if possible
      }
    }
  }

  // --- Navigation Logic ---
  void _navigateToSummaryOrFindWalker({
    required BuildContext context, // Pass context for navigation
    required Map<String, dynamic> walkData,
    required String status,
    required Map<String, dynamic> finalStats, // Final stats from backend
  }) async {
    // Prevent navigation if already navigating or widget is disposed
    if (!mounted || _isNavigating) {
      debugPrint(
          "[WandererActiveWalkScreen] Navigation prevented: mounted=$mounted, _isNavigating=$_isNavigating");
      return;
    }

    setState(() => _isNavigating = true); // Set lock immediately
    debugPrint("[WandererActiveWalkScreen] Preparing to navigate to Summary Screen...");

    // Construct Display Data (robust selection of walker info)
    Map<String, dynamic> recipientInfo = walkData['recipientInfo'] ?? {};
    Map<String, dynamic> senderInfo = walkData['senderInfo'] ?? {}; // if present

    // Determine walker info: prefer recipientInfo, fall back to senderInfo if roles are inverted
    final Map<String, dynamic> walkerInfo =
    recipientInfo.isNotEmpty ? recipientInfo : senderInfo;

    final String walkerName = walkerInfo['fullName'] ?? 'Walker';
    final String? walkerImageUrl = walkerInfo['imageUrl'];
    final String? walkerBio = walkerInfo['bio'];

    // Safety check for distance in case it was not present in walkData
    final distance = (finalStats['finalDistanceKm'] as num?)?.toInt() ?? 0;

    final IncomingRequestDisplay displayData = IncomingRequestDisplay(
      walkId: widget.walkId,
      senderId: walkData['senderId'] ?? '',
      recipientId: walkData['recipientId'] ?? '',
      senderName: walkerName,
      senderImageUrl: walkerImageUrl,
      senderBio: walkerBio,
      date: walkData['date'] ?? '',
      time: walkData['time'] ?? '',
      duration: walkData['duration'] ?? '',
      latitude: (walkData['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (walkData['longitude'] as num?)?.toDouble() ?? 0.0,
      status: status,
      distance: distance, // Use the final distance from finalStats
      notes: walkData['notes'],
    );

    // Clearing active walk ID is handled by the backend during endWalk,
    // but a final local check/clear doesn't hurt.
    await _clearActiveWalkId();

    if (!mounted) return; // Re-check after await

    debugPrint("[WandererActiveWalkScreen] Navigation to WalkSummaryScreen commencing...");
    try {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => WalkSummaryScreen(
            walkData: displayData,
            finalStats: finalStats,
          ),
        ),
      );
      // Do not attempt to reset _isNavigating here — the screen is being replaced.
    } catch (e) {
      debugPrint("[WandererActiveWalkScreen] Navigation to summary failed: $e");
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  // --- Chat Navigation ---
  void _onMessageTapped(Map<String, dynamic> walkData) {
    final walkerName = walkData['recipientInfo']?['fullName'] ?? 'Walker';
    final walkerId = walkData['recipientId'] ?? 'unknown';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          walkId: widget.walkId,
          partnerName: walkerName,
          partnerId: walkerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        "[WandererActiveWalkScreen] Build method called. Listening for walkId: ${widget.walkId}");
    return StreamBuilder<DocumentSnapshot>(
      stream:
      _firestore.collection('accepted_walks').doc(widget.walkId).snapshots(),
      builder: (context, snapshot) {
        // --- 1. Handle Loading/Error/Missing Data ---
        if (snapshot.connectionState == ConnectionState.waiting && !_isNavigating) {
          debugPrint("[WandererActiveWalkScreen] Stream waiting...");
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // If navigating, show loader to prevent brief screen flash
        if (_isNavigating) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: "Navigating...",
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint(
              "[WandererActiveWalkScreen] Stream Error: ${snapshot.error}. Scheduling navigation to FindWalker.");
          if (!_isNavigating) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _clearActiveWalkId();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const FindWalkerScreen()));
              }
            });
          }
          return const Scaffold(body: Center(child: Text("Error loading walk data.")));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          debugPrint("[WandererActiveWalkScreen] Document does not exist. Scheduling navigation to FindWalker.");
          if (!_isNavigating) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _clearActiveWalkId();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const FindWalkerScreen()));
              }
            });
          }
          return const Scaffold(body: Center(child: Text("Walk session ended or not found.")));
        }

        // --- 2. Process Valid Data (Robust) ---
        final walkData = snapshot.data!.data() as Map<String, dynamic>;
        final currentStatus = walkData['status'] as String? ?? 'Accepted';
        final finalStats = walkData['finalStats'] as Map<String, dynamic>?;
        final summaryAvailable = walkData['summaryAvailable'] as bool? ?? false;
        final List<dynamic> summaryShownToRaw = walkData['summaryShownTo'] as List<dynamic>? ?? [];
        final Set<String> summaryShownTo = summaryShownToRaw.map((e) => e.toString()).toSet();

        debugPrint(
            "[WandererActiveWalkScreen] Received data update at ${DateTime.now()}. Status: $currentStatus, FinalStats present: ${finalStats != null}, summaryAvailable: $summaryAvailable, summaryShownTo: $summaryShownTo");

        // --- 3. Decide whether to show the summary ---
        final bool isFinalStatus =
        (currentStatus == 'Completed' || currentStatus.contains('Cancelled'));
        final bool canShowSummary =
            (finalStats != null) && (isFinalStatus || summaryAvailable);

        // If final status but finalStats missing, wait
        if (isFinalStatus && finalStats == null) {
          debugPrint("[WandererActiveWalkScreen] Final status ($currentStatus) detected BUT finalStats are MISSING. Waiting for next update...");
          return const Scaffold(body: Center(child: Text("Finalizing Walk Data... Please Wait.")));
        }

        if (canShowSummary) {
          debugPrint("[WandererActiveWalkScreen] Summary ready (status=$currentStatus, summaryAvailable=$summaryAvailable).");

          final bool alreadyShown = summaryShownTo.contains(_currentUserId);
          debugPrint("[WandererActiveWalkScreen] alreadyShown=$alreadyShown, _isNavigating=$_isNavigating");

          // If not already shown for this user, mark and navigate
          if (!_isNavigating && !alreadyShown) {
            setState(() => _isNavigating = true);

            WidgetsBinding.instance.addPostFrameCallback((_) async {
              // Mark doc as shown for this user to avoid duplicate navigations
              try {
                debugPrint("[WandererActiveWalkScreen] Marking summaryShownTo for user $_currentUserId on walk ${widget.walkId}");
                await _firestore.collection('accepted_walks').doc(widget.walkId).update({
                  'summaryShownTo': FieldValue.arrayUnion([_currentUserId]),
                });
              } catch (e) {
                debugPrint("[WandererActiveWalkScreen] Failed to update summaryShownTo: $e");
                // continue to navigate regardless of marking result
              }

              if (!mounted) {
                debugPrint("[WandererActiveWalkScreen] Widget unmounted before navigation. Aborting navigation.");
                if (mounted) setState(() => _isNavigating = false);
                return;
              }

              try {
                _navigateToSummaryOrFindWalker(
                  context: context,
                  walkData: walkData,
                  status: currentStatus,
                  finalStats: finalStats ?? {},
                );
              } catch (e) {
                debugPrint("[WandererActiveWalkScreen] Navigation error: $e");
                if (mounted) setState(() => _isNavigating = false);
              }
            });

            // Show loader while navigating
            return const Scaffold(body: Center(child: CircularProgressIndicator( semanticsLabel: "Navigating to Summary...",)));
          }

          // If already shown, attempt a final fallback navigation (defensive) only if not navigating
          if (alreadyShown && !_isNavigating) {
            debugPrint("[WandererActiveWalkScreen] summaryShownTo indicates already shown, attempting fallback navigation.");
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_isNavigating && mounted) {
                setState(() => _isNavigating = true);
                try {
                  _navigateToSummaryOrFindWalker(
                    context: context,
                    walkData: walkData,
                    status: currentStatus,
                    finalStats: finalStats ?? {},
                  );
                } catch (e) {
                  debugPrint("[WandererActiveWalkScreen] Fallback navigation error: $e");
                  if (mounted) setState(() => _isNavigating = false);
                }
              }
            });

            return const Scaffold(body: Center(child: CircularProgressIndicator( semanticsLabel: "Navigating to Summary...",)));
          }

          // Otherwise, wait while navigation is ongoing
          return const Scaffold(body: Center(child: CircularProgressIndicator( semanticsLabel: "Waiting...",)));
        }

        // --- 4. Build Active Walk UI (Status is 'Accepted' or 'Started') ---
        final isWalkStarted = currentStatus == 'Started';
        final walkerName = walkData['recipientInfo']?['fullName'] ?? 'Walker';
        final walkerImageUrl = walkData['recipientInfo']?['imageUrl'];
        final DateTime? actualStartTime = (walkData['actualStartTime'] as Timestamp?)?.toDate();

        return Scaffold(
          appBar: AppBar(
            title: const Text("My Active Walk"),
            backgroundColor: isWalkStarted ? Colors.green : Colors.orange,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
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
                        Expanded( // Use Expanded to prevent overflow
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Walker: $walkerName", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text("Scheduled: ${walkData['time'] ?? ''} for ${walkData['duration'] ?? ''}", overflow: TextOverflow.ellipsis),
                              if (isWalkStarted && actualStartTime != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.timer, size: 18, color: Colors.green),
                                    const SizedBox(width: 4),
                                    const Text("Elapsed: ", style: TextStyle(color: Colors.green)),
                                    _LiveTimeDisplay(startTime: actualStartTime), // Use the isolated timer widget
                                  ],
                                ),
                              ] else if (isWalkStarted) ...[
                                const Text("Walk started", style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                _buildStatusIndicator(currentStatus),
                const SizedBox(height: 30),
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
                        "Walker confirmed. Preparing to meet at the location.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _onMessageTapped(walkData),
                  icon: const Icon(Icons.message),
                  label: const Text("Chat with Walker"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15)
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  // Disable cancel if already navigating
                  onPressed: _isNavigating ? null : () => _showCancelConfirmation(context, walkData),
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
    Color color; String message; IconData icon;
    switch (status) {
      case 'Accepted':
        color = Colors.orange;
        message = "Walker is confirmed.";
        icon = Icons.check_circle_outline;
        break;
      case 'Started':
        color = Colors.green;
        message = "Walk is LIVE! Timer running.";
        icon = Icons.directions_walk;
        break;
      default:
        color = Colors.blueGrey;
        message = "Status: $status";
        icon = Icons.info_outline;
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
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context, Map<String, dynamic> walkData) {
    showDialog( context: context, builder: (context) => AlertDialog( title: const Text("Cancel Walk?"), content: Text( walkData['status'] == 'Started' ? "The walk has started. Cancelling now will end the walk and you will be charged pro-rata for time elapsed." : "Are you sure you want to cancel the pending request?", ), actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text("Go Back")), TextButton( onPressed: () async { Navigator.pop(context); await _endWalkAsWanderer(walkData); }, child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red)), ), ], ), );
  }

  // Uses unified backend service now
  Future<void> _endWalkAsWanderer(Map<String, dynamic> walkData) async {

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

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Finalizing cancellation...")));

      // Call the unified endWalk service method
      await _walkService.endWalk(
          walkId: widget.walkId, userIdEnding: _currentUserId, isWalker: false,
          scheduledDurationMinutes: scheduledDurationMinutes, elapsedMinutes: elapsedMinutes,
          agreedRatePerHour: agreedRatePerHour, finalDistanceKm: 0.0
      );
      // The StreamBuilder will detect the change and navigate automatically

    } catch (e) {
      debugPrint("Error ending walk as Wanderer: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel walk: $e')));
      }
    }
  }
}
