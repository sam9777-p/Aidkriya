import 'package:aidkriya_walker/components/walker_avatar.dart';
import 'package:aidkriya_walker/screens/group_walk/group_walk_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FindGroupWalksScreen extends StatelessWidget {
  const FindGroupWalksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('group_walks')
            .where('status', isEqualTo: 'Scheduled')
            .where('scheduledTime', isGreaterThan: Timestamp.now())
            .orderBy('scheduledTime')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Group Walks Scheduled',
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  Text(
                    'Check back later for new events!',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final walks = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: walks.length,
            itemBuilder: (context, index) {
              final walk = walks[index];
              final data = walk.data() as Map<String, dynamic>;
              final walkerInfo = data['walkerInfo'] as Map<String, dynamic>? ?? {};

              return _GroupWalkCard(
                walkId: walk.id,
                title: data['title'] ?? 'Group Walk',
                walkerName: walkerInfo['fullName'] ?? 'Walker',
                walkerImageUrl: walkerInfo['imageUrl'],
                price: (data['price'] as num?)?.toDouble() ?? 0.0,
                scheduledTime: (data['scheduledTime'] as Timestamp).toDate(),
                participantCount: (data['participantCount'] as num?)?.toInt() ?? 0,
                maxParticipants: (data['maxParticipants'] as num?)?.toInt() ?? 0,
              );
            },
          );
        },
      ),
    );
  }
}

class _GroupWalkCard extends StatelessWidget {
  final String walkId;
  final String title;
  final String walkerName;
  final String? walkerImageUrl;
  final double price;
  final DateTime scheduledTime;
  final int participantCount;
  final int maxParticipants;

  const _GroupWalkCard({
    required this.walkId,
    required this.title,
    required this.walkerName,
    this.walkerImageUrl,
    required this.price,
    required this.scheduledTime,
    required this.participantCount,
    required this.maxParticipants,
  });

  @override
  Widget build(BuildContext context) {
    final spotsLeft = maxParticipants - participantCount;
    final bool isFull = spotsLeft <= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => GroupWalkDetailsScreen(walkId: walkId),
          ));
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  WalkerAvatar(imageUrl: walkerImageUrl, size: 30),
                  const SizedBox(width: 8),
                  Text("Led by $walkerName", style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic)),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('EEE, MMM d').format(scheduledTime), style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(DateFormat('h:mm a').format(scheduledTime), style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("₹${price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00C853))),
                      Text(
                        isFull ? "Full" : "$spotsLeft ${spotsLeft == 1 ? 'spot' : 'spots'} left",
                        style: TextStyle(color: isFull ? Colors.red : Colors.blueAccent),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}