import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'walk_card.dart';

class WalkHistoryPage extends StatelessWidget {
  const WalkHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
            onPressed: () {},
            icon: const Icon(Icons.tune, color: Colors.green),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text("Please log in"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('journeys')
            .where('status', isEqualTo: 'Accepted')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No accepted walks yet"));
          }

          final journeys = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: journeys.length,
            itemBuilder: (context, index) {
              final journey = journeys[index].data() as Map<String, dynamic>;
              final walkId = journeys[index].id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('accepted_walks')
                    .doc(walkId)
                    .get(),
                builder: (context, acceptedSnapshot) {
                  if (!acceptedSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final acceptedData =
                  acceptedSnapshot.data!.data() as Map<String, dynamic>?;

                  if (acceptedData == null) return const SizedBox.shrink();

                  final walkerProfile =
                      acceptedData['walkerProfile'] ?? {};

                  return WalkCard(
                    name: walkerProfile['name'] ?? 'Unknown Walker',
                    date: acceptedData['date'] ?? 'Unknown date',
                    duration: acceptedData['duration'] ?? 'Unknown',
                    distance:
                    "${(walkerProfile['distance'] ?? 0).toString()} m",
                    imageUrl: walkerProfile['imageUrl'] ?? '',
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
