// lib/screens/wanderer_active_walk_screen.dart
import 'dart:async';

import 'package:aidkriya_walker/screens/walk_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

import '../backend/walk_request_service.dart';
import '../model/incoming_request_display.dart';
import '../find_walker_screen.dart';
import '../components/walker_avatar.dart';
import '../screens/chat_screen.dart';
import '../components/request_map_widget.dart';

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
  Widget build(BuildContext context) {
    return Text(
      _timeString,
      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
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

  // [MODIFIED] Only one bool needed
  bool _isCancelling = false;

  // Live Walker Location State
  StreamSubscription<DatabaseEvent>? _walkerLocationSubscription;
  double? _walkerLiveLat;
  double? _walkerLiveLon;

  @override
  void initState() {
    super.initState();
    _fetchWalkDataAndStartLocationStream();
  }

  @override
  void dispose() {
    _walkerLocationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchWalkDataAndStartLocationStream() async {
    try {
      final walkDoc = await _firestore.collection('accepted_walks').doc(widget.walkId).get();
      if (!walkDoc.exists) return;

      final walkerId = walkDoc.data()?['recipientId'] as String?;
      if (walkerId == null) {
        debugPrint("[WandererActiveWalkScreen] Walker ID not found.");
        return;
      }

      // Start listening to the Walker's location in the Realtime Database
      final dbRef = FirebaseDatabase.instance.ref('locations/$walkerId');

      _walkerLocationSubscription = dbRef.onValue.listen((event) {
        if (event.snapshot.value != null && mounted) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final bool isActive = data['active'] ?? false;
          final double? lat = (data['latitude'] as num?)?.toDouble();
          final double? lon = (data['longitude'] as num?)?.toDouble();

          // Check if location changed significantly before calling setState
          const double threshold = 0.00005; // ~5 meters change required

          final bool latChanged = (_walkerLiveLat == null || lat == null) || (math.Point(_walkerLiveLat as num, _walkerLiveLon as num).distanceTo(math.Point(lat, lon as num)) > threshold);

          if (isActive && lat != null && lon != null && latChanged) {
            setState(() {
              _walkerLiveLat = lat;
              _walkerLiveLon = lon;
            });
          }
        }
      }, onError: (error) {
        debugPrint("[WandererActiveWalkScreen] RTDB Stream Error: $error");
      });
    } catch (e) {
      debugPrint("[WandererActiveWalkScreen] Error setting up RTDB stream: $e");
    }
  }

  // [REMOVED] _clearActiveWalkId - This is now handled by the service

  // Launch Emergency Call
  Future<void> _launchEmergencyCall() async {
    const emergencyNumber = 'tel:112';

    final Uri phoneUri = Uri.parse(emergencyNumber);

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open dialer. Please call 112 manually.')),
      );
    }
  }

  // [REMOVED] _navigateToSummaryOrFindWalker - This is now handled by HomeScreen

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
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('accepted_walks').doc(widget.walkId).snapshots(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // [MODIFIED] If this screen is open and the doc is gone,
        // it means the walk was cancelled/ended and HomeScreen is
        // already handling navigation. Just show a loader.
        if (!snapshot.hasData || !snapshot.data!.exists || snapshot.hasError) {
          return const Scaffold(body: Center(child: Text("Walk session not found.")));
        }

        // --- Data Processing ---
        final walkData = snapshot.data!.data() as Map<String, dynamic>;
        final currentStatus = walkData['status'] as String? ?? 'Accepted';

        // [REMOVED] Summary Navigation Check. HomeScreen handles this.

        // --- Build Active UI ---
        final isWalkStarted = currentStatus == 'Started';
        final walkLatitude = (walkData['latitude'] as num?)?.toDouble() ?? 0.0;
        final walkLongitude = (walkData['longitude'] as num?)?.toDouble() ?? 0.0;

        final walkerName = walkData['recipientInfo']?['fullName'] ?? 'Walker';
        final walkerImageUrl = walkData['recipientInfo']?['imageUrl'];
        final DateTime? actualStartTime = (walkData['actualStartTime'] as Timestamp?)?.toDate();

        final isLocationLive = _walkerLiveLat != null;

        return Scaffold(
          body: Stack(
            children: [
              // 1. Map View (Live Walker Tracking)
              Positioned.fill(
                child: RequestMapWidget(
                  requestLatitude: walkLatitude,
                  requestLongitude: walkLongitude,
                  // Pass live coordinates from RTDB stream
                  walkerLatitude: _walkerLiveLat,
                  walkerLongitude: _walkerLiveLon,
                  senderName: walkerName,
                ),
              ),

              // 2. Overlay Content (Status, Info, Buttons)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0, left: 16.0, right: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Bar Card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              WalkerAvatar(imageUrl: walkerImageUrl, size: 50),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        "Walker: $walkerName",
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                        "Scheduled: ${walkData['time'] ?? ''} for ${walkData['duration'] ?? ''}",
                                        style: TextStyle(fontSize: 13, color: Colors.grey[600])
                                    ),
                                    if (isWalkStarted && actualStartTime != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.timer, size: 18, color: Colors.green),
                                          const SizedBox(width: 4),
                                          const Text("Elapsed: ", style: TextStyle(color: Colors.green)),
                                          _LiveTimeDisplay(startTime: actualStartTime),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      _buildStatusIndicator(currentStatus, isLocationLive),

                      const Spacer(),

                      // Action Buttons (White Card at bottom)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // [REMOVED] Call Button
                            TextButton.icon(
                              onPressed: () => _onMessageTapped(walkData),
                              icon: const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
                              label: const Text("Chat", style: TextStyle(color: Colors.blueAccent)),
                            ),
                            // Spacer to separate buttons, ensuring Cancel is clearly visible
                            const SizedBox(width: 20),
                            // [MODIFIED] Show loader when cancelling
                            _isCancelling
                                ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            )
                                : TextButton.icon(
                              onPressed: () => _showCancelConfirmation(context, walkData),
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              label: const Text("Cancel", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 20),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          appBar: AppBar(
            title: const Text("Live Walk Status"),
            backgroundColor: isWalkStarted ? Colors.green : Colors.orange,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'SOS_Wanderer',
            onPressed: _launchEmergencyCall,
            icon: const Icon(Icons.sos, color: Colors.white),
            label: const Text('SOS', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator(String status, bool isLocationLive) {
    Color color;
    String message;
    IconData icon;

    if (status == 'Started') {
      color = Colors.green;
      message = isLocationLive ? "Walk is LIVE! Tracking location." : "Walk Started. Awaiting location signal.";
      icon = Icons.directions_run;
    } else if (status == 'Accepted') {
      color = Colors.orange;
      message = isLocationLive ? "Walker is En Route." : "Walker confirmed. Awaiting movement.";
      icon = Icons.check_circle_outline;
    } else {
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
    // [MODIFIED] Set loading state
    if (_isCancelling) return;
    setState(() => _isCancelling = true);

    double elapsedMinutes = 0.0;
    if (walkData['status'] == 'Started') {
      final startTime = (walkData['actualStartTime'] as Timestamp?)?.toDate();
      if (startTime != null) {
        elapsedMinutes = DateTime.now().difference(startTime).inSeconds / 60.0;
      }
    }
    try {
      final double scheduledDurationMinutes = double.tryParse(walkData['duration'].toString().split(' ')[0]) ?? 30.0;

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Finalizing cancellation...")));

      // [MODIFIED] Only call the service. HomeScreen listener handles navigation.
      await _walkService.endWalk(
          walkId: widget.walkId,
          userIdEnding: _currentUserId,
          isWalker: false,
          scheduledDurationMinutes: scheduledDurationMinutes,
          elapsedMinutes: elapsedMinutes,
          finalDistanceKm: 0.0
      );

    } catch (e, stackTrace) { // [FIXED] Added stackTrace variable
      debugPrint("Error ending walk as Wanderer: $e");
      debugPrint(stackTrace.toString());
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel walk: $e')));
        // [MODIFIED] Reset loading state on error
        setState(() => _isCancelling = false);
      }
    }
    // [REMOVED] No 'finally' block needed, state is handled
  }
}