import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'walk_card.dart';

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
        journeyIds = journeyList.cast<String>();
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

              final walkerProfile =
                  data['walkerProfile'] ?? <String, dynamic>{};

              final name = walkerProfile['name'] ?? 'Unknown';
              final distance = walkerProfile['distance'] ?? 0;
              final imageUrl = walkerProfile['imageUrl'] ?? '';

              return WalkCard(
                name: name,
                date: data['date'] ?? 'Unknown date',
                duration: data['duration'] ?? 'Unknown',
                distance: "$distance m",
                imageUrl: imageUrl,
                isActive: isActive,
              );
            },
          );
        },
      ),
    );
  }
}
