import 'dart:async';
import 'package:aidkriya_walker/components/request_map_widget.dart';
import 'package:aidkriya_walker/components/walker_avatar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../backend/walk_request_service.dart';
import '../model/incoming_request_display.dart';
import 'chat_screen.dart';
import 'walk_summary_screen.dart';

class WalkActiveScreen extends StatefulWidget {
  final IncomingRequestDisplay walkData;

  const WalkActiveScreen({super.key, required this.walkData});

  @override
  State<WalkActiveScreen> createState() => _WalkActiveScreenState();
}

class _WalkActiveScreenState extends State<WalkActiveScreen> {
  final WalkRequestService _walkService = WalkRequestService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

  final Stopwatch _stopwatch = Stopwatch();
  late Timer _timer;
  Timer? _autoEndTimer;

  // Walk state
  String _currentStatus = 'Accepted';
  Duration _elapsedDuration = Duration.zero;

  // Initial/Simulated Data
  late double _scheduledDurationMinutes;
  double _currentDistance = 0.0;
  final double _agreedRatePerHour = 100.0;

  // Initial location - Initialized in initState
  double? _walkerLat;
  double? _walkerLon;


  @override
  void initState() {
    super.initState();

    _scheduledDurationMinutes = double.tryParse(widget.walkData.duration.split(' ')[0]) ?? 30.0;
    _currentDistance = widget.walkData.distance.toDouble();

    _walkerLat = widget.walkData.latitude + 0.005;
    _walkerLon = widget.walkData.longitude - 0.005;

    // Start the UI update loop
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_stopwatch.isRunning && mounted) {
        setState(() {
          _elapsedDuration = _stopwatch.elapsed;
          // Simulate distance update when actually walking
          if (_currentStatus == 'Started') {
            _currentDistance = 0.5 + (_elapsedDuration.inMinutes * 0.05);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _autoEndTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  // --- Auto-End Logic ---
  void _startAutoEndTimer() {
    // Schedule a timer that fires when the scheduled duration is met
    final duration = Duration(minutes: _scheduledDurationMinutes.toInt());

    _autoEndTimer?.cancel();

    _autoEndTimer = Timer(duration, () {
      debugPrint("[WalkActiveScreen] AUTO-END triggered after $_scheduledDurationMinutes minutes.");
      _endWalk(isWalkerInitiated: false, isAutoEnd: true);
    });

    debugPrint("[WalkActiveScreen] Auto-End timer set for: $duration.");
  }


  // --- End Walk Implementation ---
  Future<void> _endWalk({required bool isWalkerInitiated, bool isAutoEnd = false}) async {
    // Stop timers immediately
    _stopwatch.stop();
    _timer.cancel();
    _autoEndTimer?.cancel();

    if (_currentStatus == 'Ending' || _currentStatus == 'Completed') return;

    setState(() => _currentStatus = 'Ending');

    final double elapsedMinutes = _elapsedDuration.inSeconds / 60.0;

    final userIdEnding = _currentUserId;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isAutoEnd ? "Walk time reached. Finalizing..." : "Finalizing Walk..."),
        duration: const Duration(seconds: 15),
      ),
    );

    try {
      final Map<String, dynamic> finalStats = await _walkService.endWalk(
        walkId: widget.walkData.walkId,
        userIdEnding: userIdEnding,
        isWalker: isWalkerInitiated,
        scheduledDurationMinutes: _scheduledDurationMinutes,
        elapsedMinutes: elapsedMinutes,
        agreedRatePerHour: _agreedRatePerHour,
        finalDistanceKm: _currentDistance,
      );

      if (mounted) {
        // Navigate to the Summary Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WalkSummaryScreen(
              walkData: widget.walkData,
              finalStats: finalStats,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("[WalkActiveScreen] Error finalizing walk: $e");
      if (mounted) {
        setState(() => _currentStatus = 'Started');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end walk: $e')),
        );
      }
    }
  }

  // --- Start Walk Implementation ---
  Future<void> _onStartWalkPressed() async {
    if (_currentStatus == 'Starting...' || _currentStatus == 'Started') return;

    setState(() => _currentStatus = 'Starting...');

    final success = await _walkService.startWalk(widget.walkData.walkId);

    if (mounted) {
      if (success) {
        // StreamBuilder will handle the rest
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start walk.')),
        );
        setState(() => _currentStatus = 'Accepted');
      }
    }
  }

  // --- UI Builders ---

  Widget _buildStatsCard(String durationText, double distance, double pace) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Distance', '${distance.toStringAsFixed(1)} km', Icons.directions_walk),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            _buildStatItem('Duration', durationText, Icons.timer),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            _buildStatItem('Pace', '${pace.toStringAsFixed(1)} km/h', Icons.speed),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6BCBA6)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildHeader(String walkerName, String wandererName, String? wandererImageUrl) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Walker: $walkerName',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Wanderer: $wandererName',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8),
                WalkerAvatar(imageUrl: wandererImageUrl, size: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onMessageTapped() {
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(content: Text('Chat screen navigation coming soon!')),
    // ); // [REMOVE] Old placeholder

    // [NEW] Navigate to ChatScreen
    final isWalker = _currentUserId == widget.walkData.recipientId;
    final partnerName = isWalker ? widget.walkData.senderName : widget.walkData.recipientId; // Use Wanderer's name
    final partnerId = isWalker ? widget.walkData.senderId : widget.walkData.recipientId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          walkId: widget.walkData.walkId,
          partnerName: partnerName,
          partnerId: partnerId,
        ),
      ),
    );
  }

  Widget _buildActionButtons(String status) {
    if (status == 'Started') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
            heroTag: 'SOS',
            onPressed: () => print('SOS Pressed'),
            icon: const Icon(Icons.sos, color: Colors.white),
            label: const Text('SOS', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: 'EndWalk',
            onPressed: () => _endWalk(isWalkerInitiated: true),
            icon: const Icon(Icons.stop, color: Colors.black87),
            label: const Text('End Walk', style: TextStyle(color: Colors.black87)),
            backgroundColor: Colors.white,
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'Chat',
            onPressed: _onMessageTapped,
            child: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
            heroTag: 'StartWalk',
            onPressed: status == 'Starting...' ? null : _onStartWalkPressed,
            icon: status == 'Starting...'
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.play_arrow, color: Colors.white),
            label: Text(
                status == 'Starting...' ? 'Starting...' : 'Start Walk',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF6BCBA6),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'Chat',
            onPressed: _onMessageTapped,
            child: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      );
    }
    if (status == 'Started') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
// ... (SOS and EndWalk buttons are unchanged)
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'Chat',
            onPressed: _onMessageTapped, // [MODIFIED] Use new callback
            child: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
// ... (StartWalk button is unchanged)
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'Chat',
            onPressed: _onMessageTapped, // [MODIFIED] Use new callback
            child: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      );
    }
  }

  Widget _buildFooter(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: Colors.orange.shade400, size: 20),
              const SizedBox(width: 4),
              const Text('22°C', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          Text(time, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }


  // --- Main Build Logic with StreamBuilder ---
  @override
  Widget build(BuildContext context) {
    final wandererName = widget.walkData.senderName;
    final wandererImageUrl = widget.walkData.senderImageUrl;
    const walkerName = "You (Walker)";
    final now = DateTime.now();
    final timeStr = DateFormat('h:mm a').format(now);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('accepted_walks').doc(widget.walkData.walkId).snapshots(),
      builder: (context, snapshot) {

        String currentStatus = _currentStatus;
        double currentDistance = _currentDistance;
        double currentPace = 0.0;
        String durationText = widget.walkData.duration;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          currentStatus = data?['status'] as String? ?? widget.walkData.status;

          // STATUS: Started
          if (currentStatus == 'Started') {
            final startTimeTimestamp = data?['actualStartTime'] as Timestamp?;

            if (!_stopwatch.isRunning) {
              _stopwatch.start();
              _startAutoEndTimer();
            }

            final seconds = _elapsedDuration.inSeconds;
            final hours = seconds ~/ 3600;
            final minutes = (seconds % 3600) ~/ 60;
            final remainingSeconds = seconds % 60;

            durationText =
            hours > 0
                ? '${hours}h ${minutes.toString().padLeft(2, '0')}m'
                : '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')} min';

            currentPace = (currentDistance / (_elapsedDuration.inMinutes / 60.0));
            if (!currentPace.isFinite || currentDistance < 0.1) currentPace = 0.0;

          }

          // STATUS: Completed or Cancelled (Check if ending occurred on backend)
          else if (currentStatus == 'Completed' || currentStatus.contains('Cancelled')) {
            final finalStats = data?['finalStats'] as Map<String, dynamic>?;
            if (finalStats != null && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WalkSummaryScreen(
                      walkData: widget.walkData,
                      finalStats: finalStats,
                    ),
                  ),
                );
              });
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // Update local status for button logic
          if(currentStatus != _currentStatus) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _currentStatus = currentStatus;
              });
            });
          }
        }

        return Scaffold(
          body: Stack(
            children: [
              // 1. Main Map Background
              Positioned.fill(
                child: RequestMapWidget(
                  requestLatitude: widget.walkData.latitude,
                  requestLongitude: widget.walkData.longitude,
                  walkerLatitude: _walkerLat,
                  walkerLongitude: _walkerLon,
                  senderName: wandererName,
                ),
              ),

              // 2. Overlay Content
              Column(
                children: [
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildHeader(walkerName, wandererName, wandererImageUrl),
                    ),
                  ),
                  _buildStatsCard(durationText, currentDistance, currentPace),

                  const Spacer(),

                  // Action Buttons (Dynamic based on status)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: _buildActionButtons(currentStatus),
                  ),

                  // Footer
                  _buildFooter(timeStr),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}