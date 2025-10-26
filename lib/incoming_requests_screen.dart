import 'package:aidkriya_walker/backend/walk_request_service.dart';
import 'package:aidkriya_walker/detail_income_request.dart';
import 'package:aidkriya_walker/model/walk_request.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'components/request_card.dart';
import 'model/incoming_request.dart';

class IncomingRequestsScreen extends StatefulWidget {
  const IncomingRequestsScreen({super.key});

  @override
  State<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends State<IncomingRequestsScreen> {
  final walkService = WalkRequestService();
  final userID = FirebaseAuth.instance.currentUser?.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: StreamBuilder<List<WalkRequest>>(
        stream: walkService.getReceivedRequests(userID ?? 'guest'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          // Only pending requests
          final pendingRequests = snapshot.data!
              .where((request) => request.status == 'Pending')
              .toList();

          if (pendingRequests.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingRequests.length,
            itemBuilder: (context, index) {
              final request = pendingRequests[index];

              // Use FutureBuilder to fetch Walker details
              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(request.id).get(),
                builder: (context, walkerSnapshot) {
                  if (!walkerSnapshot.hasData) {
                    return const SizedBox(); // Or a small loading placeholder
                  }

                  final walkerData =
                      walkerSnapshot.data!.data() as Map<String, dynamic>;
                  final mergedRequest = IncomingRequest(
                    id: request.id,
                    walker: request.walker,
                    date: request.date,
                    time: request.time,
                    duration: request.duration,
                    latitude: request.latitude,
                    longitude: request.longitude,
                    status: request.status,
                    notes: request.notes,
                    name: walkerData['name'] ?? request.walker.name ?? '',
                    bio: walkerData['bio'] ?? request.walker.bio,
                    imageUrl: walkerData['imageUrl'] ?? null,
                  );

                  return RequestCard(
                    request: mergedRequest,
                    onTap: () => _onRequestTapped(mergedRequest),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF5F5F5),
      elevation: 0,
      title: const Text(
        'Incoming Requests',
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Pending Requests',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _onRequestTapped(IncomingRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailIncomeRequest(walkRequest: request),
      ),
    );
  }
}
