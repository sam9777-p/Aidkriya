// lib/screens/group_walk/group_walk_details_screen.dart
import 'package:aidkriya_walker/components/walker_avatar.dart';
import 'package:aidkriya_walker/model/user_model.dart';
import 'package:aidkriya_walker/screens/chat_screen.dart';
import 'package:aidkriya_walker/screens/group_walk/group_payment_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../backend/walk_request_service.dart';

class GroupWalkDetailsScreen extends StatefulWidget {
  final String walkId;
  const GroupWalkDetailsScreen({super.key, required this.walkId});

  @override
  State<GroupWalkDetailsScreen> createState() => _GroupWalkDetailsScreenState();
}

class _GroupWalkDetailsScreenState extends State<GroupWalkDetailsScreen> {
  final _auth = FirebaseAuth.instance;
  final _walkService = WalkRequestService();
  UserModel? _currentUserModel;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserModel();
  }

  Future<void> _fetchCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _currentUserModel = UserModel.fromMap(doc.data()!);
        });
      }
    } catch (e) {
      debugPrint("Error fetching current user model: $e");
    }
  }

  void _onJoinWalkPressed(double price, String title, Map<String, dynamic> walkerInfo) {
    if (_currentUserModel == null) return;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => GroupPaymentScreen(
        amount: price,
        walkId: widget.walkId,
        walkTitle: title,
        currentUser: _currentUserModel!,
        walkerInfo: walkerInfo,
      ),
    ));
  }

  void _onStartWalkPressed(String walkerId, List<String> participantIds) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Group Walk?'),
        content: Text('This will notify all ${participantIds.length} participants and begin the walk.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start')),
        ],
      ),
    );

    if (confirm != true) return;
    await _walkService.startGroupWalk(widget.walkId, walkerId);
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      extendBodyBehindAppBar: true,

      // 🔥 IMMERSIVE APP BAR ADDED
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          'Group Walk Details',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('group_walks').doc(widget.walkId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Walk not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final walkerId = data['walkerId'] as String? ?? '';
          final walkerInfo = data['walkerInfo'] as Map<String, dynamic>? ?? {};
          final participants =
              (data['participants'] as List<dynamic>?)?.map((p) => p as Map<String, dynamic>).toList() ?? [];
          final participantIds = participants.map((p) => p['userId'] as String).toList();

          final bool isWalker = currentUserId == walkerId;
          final bool hasJoined = participantIds.contains(currentUserId);
          final bool isFull = (data['participantCount'] ?? 0) >= (data['maxParticipants'] ?? 1);
          final bool canJoin = !isWalker && !hasJoined && !isFull;

          final scheduledTime = (data['scheduledTime'] as Timestamp).toDate();
          final bool canStart = isWalker && scheduledTime.isBefore(DateTime.now().add(const Duration(minutes: 15)));

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 0, left: 16, right: 16, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(0),
                        child: Container(
                          height: 260,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                (data['meetingPoint'] as GeoPoint).latitude,
                                (data['meetingPoint'] as GeoPoint).longitude,
                              ),
                              zoom: 15,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('meetup'),
                                position: LatLng(
                                  (data['meetingPoint'] as GeoPoint).latitude,
                                  (data['meetingPoint'] as GeoPoint).longitude,
                                ),
                              ),
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(data['title'],
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: WalkerAvatar(imageUrl: walkerInfo['imageUrl'], size: 45),
                        title: Text("Led by ${walkerInfo['fullName']}"),
                      ),
                      const Divider(),

                      InfoRow(icon: Icons.calendar_today, title: 'Date', value: DateFormat('EEE, MMM d').format(scheduledTime)),
                      InfoRow(icon: Icons.access_time, title: 'Time', value: DateFormat('h:mm a').format(scheduledTime)),
                      InfoRow(icon: Icons.timelapse, title: 'Duration', value: data['duration']),
                      InfoRow(icon: Icons.group, title: 'Slots', value: "${data['participantCount']} / ${data['maxParticipants']}"),
                      InfoRow(icon: Icons.payments, title: 'Price', value: "₹${(data['price'] as num).toDouble().toStringAsFixed(2)} per person"),

                      const Divider(),
                      const SizedBox(height: 12),

                      Text('Participants (${data['participantCount']})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      if (participants.isEmpty)
                        const Text("Be the first to join!", style: TextStyle(color: Colors.grey)),

                      if (!isWalker && !hasJoined)
                        const Text("Join to see other participants.",
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),

                      if (isWalker || hasJoined)
                        ...participants.map((p) => ParticipantTile(
                          name: p['name'],
                          imageUrl: p['imageUrl'],
                          onTap: () => _showProfileDialog(context, p),
                        )),
                    ],
                  ),
                ),
              ),

              // FOOTER BUTTONS (unchanged)
              Container(
                padding: const EdgeInsets.all(16).copyWith(bottom: 32),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    if (isWalker && canStart)
                      ElevatedButton(
                        onPressed: () => _onStartWalkPressed(walkerId, participantIds),
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.green),
                        child: const Text('Start Walk Now',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                      )
                    else if (isWalker)
                      Text(
                        'You can start the walk 15 min before scheduled time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700]),
                      )
                    else if (hasJoined)
                        ElevatedButton.icon(
                          onPressed: () => _onChatPressed(data['title']),
                          icon: const Icon(Icons.chat, color: Colors.white),
                          label: const Text('Open Group Chat',
                              style: TextStyle(color: Colors.white, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.blueAccent,
                          ),
                        )
                      else if (isFull)
                          ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50)),
                            child: const Text('This Walk is Full', style: TextStyle(fontSize: 16)),
                          )
                        else if (canJoin && _currentUserModel != null)
                            ElevatedButton(
                              onPressed: () => _onJoinWalkPressed(
                                  (data['price'] as num).toDouble(), data['title'], walkerInfo),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: const Color(0xFF6BCBA6),
                              ),
                              child: Text(
                                "Join & Pay ₹${(data['price'] as num).toDouble().toStringAsFixed(2)}",
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            )
                          else
                            const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showProfileDialog(BuildContext context, Map<String, dynamic> participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WalkerAvatar(imageUrl: participant['imageUrl'], size: 80),
            const SizedBox(height: 16),
            Text(participant['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const InfoRow({super.key, required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class ParticipantTile extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final VoidCallback onTap;

  const ParticipantTile({super.key, required this.name, this.imageUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: WalkerAvatar(imageUrl: imageUrl, size: 40),
      title: Text(name),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}
