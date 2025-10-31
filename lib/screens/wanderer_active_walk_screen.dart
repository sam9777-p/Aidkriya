import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../model/incoming_request_display.dart';
import 'walk_summary_screen.dart';
import 'chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WandererActiveWalkScreen extends StatefulWidget {
  final String walkId;

  const WandererActiveWalkScreen({super.key, required this.walkId});

  @override
  State<WandererActiveWalkScreen> createState() => _WandererActiveWalkScreenState();
}

class _WandererActiveWalkScreenState extends State<WandererActiveWalkScreen> {
  late final Stream<DocumentSnapshot> _walkStream;
  bool _isNavigating = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _walkStream = _firestore.collection('accepted_walks').doc(widget.walkId).snapshots();
  }

  void _handleWalkUpdate(DocumentSnapshot doc) {
    if (_isNavigating || !mounted) return;

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final status = data['status'] ?? '';
    final finalStats = data['finalStats'];

    if ((status == 'Completed' || status == 'Cancelled') && finalStats != null) {
      _isNavigating = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WalkSummaryScreen(
            walkData: IncomingRequestDisplay(
              walkId: widget.walkId,
              senderId: data['senderId'] ?? '',
              recipientId: data['recipientId'] ?? '',
              senderName: data['senderInfo']?['fullName'] ?? '',
              latitude: data['location']?['lat'] ?? 0.0,
              longitude: data['location']?['lon'] ?? 0.0,
              distance: (data['distance'] ?? 0.0).toDouble(),
              duration: data['duration']?.toString() ?? '0 min',
              status: status,
              date: '',
              time: '',
              notes: '',
            ),
            finalStats: finalStats,
          ),
        ),
      );
    }
  }

  Future<void> _cancelWalk() async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('endWalk')
          .call({'walkId': widget.walkId});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Walk cancelled successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling walk: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Walk'),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _walkStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text('Walk not found.'));
          }

          WidgetsBinding.instance.addPostFrameCallback(
                (_) => _handleWalkUpdate(snapshot.data!),
          );

          final status = data['status'] ?? 'Unknown';

          // Determine partner info dynamically
          final senderId = data['senderId'] ?? '';
          final recipientId = data['recipientId'] ?? '';
          final senderInfo = data['senderInfo'] ?? {};
          final recipientInfo = data['recipientInfo'] ?? {};

          final bool isCurrentUserSender = senderId == currentUserId;

          final partnerId =
          isCurrentUserSender ? recipientId : senderId;
          final partnerInfo =
          isCurrentUserSender ? recipientInfo : senderInfo;
          final partnerName = partnerInfo['fullName'] ?? 'Partner';
          final partnerImage = partnerInfo['imageUrl'] ?? '';
          final partnerBio = partnerInfo['bio'] ?? 'Your partner is on the way.';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                  partnerImage.isNotEmpty ? NetworkImage(partnerImage) : null,
                  child: partnerImage.isEmpty
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  partnerName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(partnerBio, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Text('Status: $status', style: const TextStyle(fontSize: 18)),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text('Chat with Partner'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          walkId: widget.walkId,
                          partnerId: partnerId,
                          partnerName: partnerName,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel Walk'),
                  onPressed: _cancelWalk,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _isNavigating = true;
    super.dispose();
  }
}
