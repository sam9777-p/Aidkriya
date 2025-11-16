import 'dart:async';
import 'package:aidkriya_walker/components/request_map_widget.dart';
import 'package:aidkriya_walker/screens/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../backend/walk_request_service.dart';

class GroupWalkActiveScreen extends StatefulWidget {
  final String walkId;
  final bool isWalker;
  const GroupWalkActiveScreen({
    super.key,
    required this.walkId,
    required this.isWalker
  });

  @override
  State<GroupWalkActiveScreen> createState() => _GroupWalkActiveScreenState();
}

class _GroupWalkActiveScreenState extends State<GroupWalkActiveScreen> {
  final _auth = FirebaseAuth.instance;
  final _walkService = WalkRequestService();
  bool _isEnding = false;

  StreamSubscription<DatabaseEvent>? _walkerLocationSubscription;
  double? _walkerLiveLat;
  double? _walkerLiveLon;

  @override
  void initState() {
    super.initState();
    _subscribeToWalkerLocation();
  }

  @override
  void dispose() {
    _walkerLocationSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToWalkerLocation() async {
    try {
      final walkDoc = await FirebaseFirestore.instance.collection('group_walks').doc(widget.walkId).get();
      if (!walkDoc.exists) return;

      final walkerId = walkDoc.data()?['walkerId'] as String?;
      if (walkerId == null) return;

      final dbRef = FirebaseDatabase.instance.ref('locations/$walkerId');
      _walkerLocationSubscription = dbRef.onValue.listen((event) {
        if (event.snapshot.value != null && mounted) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          if (data['active'] == true && data['latitude'] != null) {
            setState(() {
              _walkerLiveLat = (data['latitude'] as num).toDouble();
              _walkerLiveLon = (data['longitude'] as num).toDouble();
            });
          }
        }
      });
    } catch (e) {
      debugPrint("Error subscribing to walker location: $e");
    }
  }

  Future<void> _endWalk() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);

    final success = await _walkService.endGroupWalk(
      widget.walkId,
      _auth.currentUser!.uid,
      0.0,
      0,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to end walk.'), backgroundColor: Colors.red),
      );
      setState(() => _isEnding = false);
    }
  }

  void _onChatPressed(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          walkId: widget.walkId,
          partnerName: "$title (Group)",
          partnerId: "group_chat",
        ),
      ),
    );
  }

  Future<void> _launchEmergencyCall() async {
    const emergencyNumber = 'tel:112';
    final Uri phoneUri = Uri.parse(emergencyNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Group Walk'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('group_walks').doc(widget.walkId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Loading walk..."));
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final title = data['title'] ?? 'Group Walk';
          final meetingPoint = data['meetingPoint'] as GeoPoint;

          return Stack(
            children: [
              RequestMapWidget(
                requestLatitude: meetingPoint.latitude,
                requestLongitude: meetingPoint.longitude,
                walkerLatitude: _walkerLiveLat,
                walkerLongitude: _walkerLiveLon,
                senderName: "Meeting Point",
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(
                          "Status: ${data['status']}",
                          style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                        const Divider(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            IconButton(
                              onPressed: () => _onChatPressed(title),
                              icon: const Icon(Icons.chat),
                              iconSize: 28,
                              color: Colors.blueAccent,
                            ),
                            IconButton(
                              onPressed: _launchEmergencyCall,
                              icon: const Icon(Icons.sos),
                              iconSize: 28,
                              color: Colors.red,
                            ),
                            if (widget.isWalker)
                              ElevatedButton(
                                onPressed: _isEnding ? null : _endWalk,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: _isEnding
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('End Walk', style: TextStyle(color: Colors.white)),
                              )
                            else
                              ElevatedButton(
                                onPressed: _isEnding ? null : () {},
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Leave Walk', style: TextStyle(color: Colors.white)),
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}