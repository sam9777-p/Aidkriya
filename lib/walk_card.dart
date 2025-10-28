import 'package:flutter/material.dart';

class WalkCard extends StatelessWidget {
  final String name;
  final String date;
  final String duration;
  final String distance;
  final String imageUrl;

  const WalkCard({
    super.key,
    required this.name,
    required this.date,
    required this.duration,
    required this.distance,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.green.shade100,
            backgroundImage:
            imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Walk with $name",
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.map, size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 4),
                    Text(distance, style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(width: 12),
                    Icon(Icons.timer, size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 4),
                    Text(duration, style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // message logic
            },
            icon: const Icon(Icons.message_outlined,
                color: Colors.green, size: 24),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
