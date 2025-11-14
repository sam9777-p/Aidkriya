import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/chat_screen.dart';

class WalkDetailsScreen extends StatefulWidget {
  final String walkId;
  const WalkDetailsScreen({Key? key, required this.walkId}) : super(key: key);

  @override
  State<WalkDetailsScreen> createState() => _WalkDetailsScreenState();
}

class _WalkDetailsScreenState extends State<WalkDetailsScreen> {
  String? otherUserId;

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFFB5DDB8);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Walk Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
      ),

      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryGreen.withOpacity(0.15),
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Foreground content
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('accepted_walks')
                .doc(widget.walkId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(
                    child: Text('Walk not found',
                        style: TextStyle(fontSize: 16)));
              }

              final walkData = snapshot.data!.data() as Map<String, dynamic>;
              final currentUserId = FirebaseAuth.instance.currentUser!.uid;

              // Determine the other participant
              final senderId = walkData['senderId'];
              final recipientId = walkData['recipientId'];
              if (currentUserId == senderId) {
                otherUserId = recipientId;
              } else {
                otherUserId = senderId;
              }

              final walkStatus = walkData['status'] ?? 'unknown';
              final duration = walkData['duration'] ?? '';
              final distance =
              (walkData['walkerProfile']?['distance'] ?? 0).toString();
              final updatedAt = walkData['updatedAt'] != null
                  ? (walkData['updatedAt'] as Timestamp).toDate()
                  : null;

              return SingleChildScrollView(
                padding:
                const EdgeInsets.only(left: 16, right: 16, top: 110, bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Walk info card
                    _buildWalkInfoCard(walkStatus, duration, distance, updatedAt),

                    const SizedBox(height: 25),

                    // Walker details section
                    if (otherUserId != null)
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(otherUserId)
                            .snapshots(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (!userSnapshot.hasData ||
                              !userSnapshot.data!.exists) {
                            return const Text("Walker details not found.");
                          }

                          final userData = userSnapshot.data!.data()
                          as Map<String, dynamic>;

                          final fullName = userData['fullName'] ?? 'Unknown';
                          final email = userData['email'] ?? '';
                          final phone = userData['phone'] ?? '';
                          final city = userData['city'] ?? '';
                          final bio = userData['bio'] ?? '';
                          final role = userData['role'] ?? '';
                          final profilePic = userData['photoUrl'] ??
                              userData['imageUrl'] ??
                              '';

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.shade100.withOpacity(0.5),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  "Walk Partner Details",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                CircleAvatar(
                                  radius: 45,
                                  backgroundColor: Colors.green.shade50,
                                  backgroundImage: profilePic.isNotEmpty
                                      ? NetworkImage(profilePic)
                                      : null,
                                  child: profilePic.isEmpty
                                      ? const Icon(Icons.person,
                                      size: 45, color: Colors.grey)
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  role.toString(),
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Divider(height: 24, thickness: 1),
                                _detailRow(Icons.email_outlined, "Email", email),
                                _detailRow(Icons.phone, "Phone", phone),
                                _detailRow(Icons.location_on_outlined, "City", city),
                                if (bio.toString().isNotEmpty)
                                  _detailRow(Icons.info_outline, "Bio", bio),
                              ],
                            ),
                          );
                        },
                      )
                    else
                      const Text("Unable to load walker details."),
                  ],
                ),
              );
            },
          ),
        ],
      ),

      // Bottom “Message” button
      bottomSheet: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.message, color: Colors.white),
            label: const Text(
              'Message',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF61CF63),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 5,
            ),
            onPressed: () {
              if (otherUserId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      walkId: widget.walkId,
                      partnerId: otherUserId!,
                      partnerName: 'Chat',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Chat partner not available right now')),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // -------------------
  // UI Helper Components
  // -------------------

  Widget _buildWalkInfoCard(
      String status, String duration, String distance, DateTime? updatedAt) {
    Color statusColor;
    Color textColor;

    switch (status) {
      case 'completed':
        statusColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        break;
      case 'cancelled':
        statusColor = Colors.red.shade100;
        textColor = Colors.red.shade700;
        break;
      default:
        statusColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.directions_walk_rounded,
                  color: Colors.green, size: 28),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(Icons.timer_outlined, 'Duration', duration),
          _infoRow(Icons.route_outlined, 'Distance', '$distance km'),
          if (updatedAt != null)
            _infoRow(Icons.update, 'Updated',
                '${updatedAt.toLocal().toString().substring(0, 16)}'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black54, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$label: $value",
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}