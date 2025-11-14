// lib/walk_history_page.dart

import 'package:aidkriya_walker/walk_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'walk_card.dart';
import 'screens/chat_screen.dart'; // [NEW] Import ChatScreen

class WalkHistoryPage extends StatefulWidget {
  const WalkHistoryPage({super.key});

  @override
  State<WalkHistoryPage> createState() => _WalkHistoryPageState();
}

class _WalkHistoryPageState extends State<WalkHistoryPage> {
  final user = FirebaseAuth.instance.currentUser;
  List<String> journeyIds = [];
  String? activeWalkId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserJourneys();
  }

  Future<void> fetchUserJourneys() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    final data = doc.data();
    if (data != null) {
      final List<dynamic> journeyList = data['journeys'] ?? [];
      setState(() {
        // Reverse the list to show the most recent walk first
        journeyIds = journeyList.cast<String>().reversed.toList();
        activeWalkId = data['activeWalkId'];
        isLoading = false;
      });
    } else {
      setState(() {
        journeyIds = [];
        activeWalkId = null;
        isLoading = false;
      });
    }
  }

  // [NEW] Function to handle navigation to chat screen
  void _navigateToChat(String walkId, String partnerName, String partnerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          walkId: walkId,
          partnerName: partnerName,
          partnerId: partnerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text(
          "Walk History",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        actions: [
          IconButton(
            onPressed: () {
              fetchUserJourneys(); // refresh manually if needed
            },
            icon: const Icon(Icons.refresh, color: Colors.green),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : journeyIds.isEmpty
          ? const Center(
          child: Text("No walk history yet",
              style: TextStyle(color: Colors.grey, fontSize: 16)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: journeyIds.length,
        itemBuilder: (context, index) {
          final walkId = journeyIds[index];
          final isActive = (walkId == activeWalkId);

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('accepted_walks')
                .doc(walkId)
                .get(),
            builder: (context, acceptedSnapshot) {
              if (acceptedSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                );
              }

              if (!acceptedSnapshot.hasData ||
                  !acceptedSnapshot.data!.exists) {
                return const SizedBox.shrink();
              }

              final data = acceptedSnapshot.data!.data()
              as Map<String, dynamic>?;

              if (data == null) return const SizedBox.shrink();

              // Determine if the current user was the Wanderer (sender) or the Walker (recipient)
              final isSender = data['senderId'] == user!.uid;

              // Identify the chat partner's info and ID
              final partnerId = isSender ? data['recipientId'] : data['senderId'];
              final partnerProfileData = isSender
                  ? data['recipientInfo'] as Map<String, dynamic>? // Show Walker's info
                  : data['senderInfo'] as Map<String, dynamic>?; // Show Wanderer's info

              // Fallback to older walkerProfile structure if necessary
              final walkerProfileFallback = data['walkerProfile'] ?? <String, dynamic>{};

              final name = partnerProfileData?['fullName'] ?? walkerProfileFallback['name'] ?? 'Unknown';
              // Use finalStats distance and format it to 1 decimal place. Default to '0.0'
              final distance = (data['finalStats']?['finalDistanceKm'] as num?)?.toStringAsFixed(1) ?? '0.0';
              final imageUrl = partnerProfileData?['imageUrl'] ?? walkerProfileFallback['imageUrl'] ?? '';
              final duration = data['duration'] ?? 'Unknown duration';
              final date = data['date'] ?? 'Unknown date';
              final messagesCount = (data['messagesCount'] as num?)?.toInt() ?? 0;

              return WalkCard(
                name: name,
                date: date,
                duration: duration,
                distance: "$distance km",
                imageUrl: imageUrl,
                isActive: isActive,
                messagesCount: messagesCount,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WalkDetailsScreen(walkId: walkId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}