import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WalkDetailsScreen extends StatelessWidget {
  final String walkId;

  const WalkDetailsScreen({super.key, required this.walkId});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F1412)
          : const Color(0xFFF9F9F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor:
        Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
        title: const Text('Walk Details'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => {},
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('accepted_walks').doc(walkId).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snap.data!;
          if (!doc.exists) return const Center(child: Text('Walk not found'));

          final data = doc.data() as Map<String, dynamic>;

          final duration = data['duration'] ?? '';
          final walkerProfile = data['walkerProfile'] as Map<String, dynamic>? ?? {};
          final distance = walkerProfile['distance'] ?? '';
          final status = data['status'] ?? '';
          final updatedAtTs = data['updatedAt'];
          DateTime? updatedAt;
          if (updatedAtTs is Timestamp) updatedAt = updatedAtTs.toDate();
          else if (updatedAtTs is int) updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtTs);
          else if (updatedAtTs is String) {
            try {
              updatedAt = DateTime.parse(updatedAtTs);
            } catch (_) {
              updatedAt = null;
            }
          }

          final recipientId = data['recipientId'] as String?;
          final senderId = data['senderId'] as String?;

          String? otherUserId;
          if (currentUid != null) {
            if (recipientId != null && recipientId != currentUid) {
              otherUserId = recipientId;
            } else if (senderId != null && senderId != currentUid)
            {
              otherUserId = senderId;
            }
          } else {
            otherUserId = recipientId ?? senderId;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isWide = width > 420;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Container(
                      width: double.infinity,
                      height: isWide ? 220 : 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.green.shade900
                                : Colors.green.shade200,
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.black
                                : Colors.white,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.directions_walk,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Walk Summary',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  status.toString().isNotEmpty ? 'Status: $status' : 'Status: —',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (updatedAt != null)
                                  Text(
                                    'Updated ${DateFormat.yMMMd().add_jm().format(updatedAt)}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white60
                                          : Colors.black45,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatCard(
                          icon: Icons.map,
                          label: 'Distance',
                          value: distance.toString().isNotEmpty ? '$distance km' : '—',
                          width: (width - 44) / 2,
                        ),
                        _StatCard(
                          icon: Icons.timer,
                          label: 'Duration',
                          value: duration.toString().isNotEmpty ? duration.toString() : '—',
                          width: (width - 44) / 2,
                        ),
                        _StatCard(
                          icon: Icons.info_outline,
                          label: 'Status',
                          value: status.toString().isNotEmpty ? status.toString() : '—',
                          width: width - 32,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'You walked with',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 10),
                            if (otherUserId == null)
                              const Text('No participant info available')
                            else
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
                                builder: (ctx, userSnap) {
                                  if (userSnap.hasError) {
                                    return Text('Error: ${userSnap.error}');
                                  }
                                  if (!userSnap.hasData) {
                                    return const SizedBox(
                                      height: 64,
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }
                                  final udoc = userSnap.data!;
                                  if (!udoc.exists) {
                                    return const Text('Participant profile not found');
                                  }
                                  final udata = udoc.data() as Map<String, dynamic>? ?? {};
                                  final displayName = udata['displayName'] ?? udata['name'] ?? 'Unnamed';
                                  final role = udata['role'] ?? '';
                                  final photoUrl = udata['photoUrl'] ?? udata['avatarUrl'] ?? '';

                                  return Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.grey.shade200,
                                        child: photoUrl.toString().isNotEmpty
                                            ? ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: photoUrl.toString(),
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            placeholder: (c, s) => const CircularProgressIndicator(strokeWidth: 2),
                                            errorWidget: (c, s, e) => const Icon(Icons.person, size: 32),
                                          ),
                                        )
                                            : const Icon(Icons.person, size: 32),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName.toString(),
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            role.toString(),
                                            style: const TextStyle(color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () {

                                        },
                                        icon: const Icon(Icons.chevron_right),
                                      )
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    updatedAt != null
                                        ? DateFormat.yMMMMd().format(updatedAt)
                                        : 'Date not available',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    updatedAt != null
                                        ? DateFormat.jm().format(updatedAt)
                                        : '',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.green.shade800.withOpacity(0.12)
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: const [
                                  Text('Contribution', style: TextStyle(fontSize: 12)),
                                  SizedBox(height: 6),
                                  Text('\$2.50', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              );
            }),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_walk), label: 'Walks'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double width;

  const _StatCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 6),
            blurRadius: 14,
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isDark ? Colors.green.shade900 : Colors.green.shade50,
            child: Icon(icon, size: 20, color: isDark ? Colors.white : Colors.green.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ]),
          ),
        ],
      ),
    );
  }
}
