import 'package:flutter/material.dart';

class WalkCard extends StatelessWidget {
  final String name;
  final String date;
  final String duration;
  final String distance;
  final String imageUrl;
  final bool isActive;

  const WalkCard({
    super.key,
    required this.name,
    required this.date,
    required this.duration,
    required this.distance,
    required this.imageUrl,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor = isActive ? Colors.green.shade400 : Colors.green.shade50;
    final Color textColor = isActive ? Colors.white : Colors.black87;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: !isActive ? baseColor : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? Colors.green.withOpacity(0.5)
                : Colors.green.withOpacity(0.15),
            blurRadius: isActive ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor:
            isActive ? Colors.white.withOpacity(0.3) : Colors.green.shade100,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Walk with $name",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Active",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    color: isActive ? Colors.white70 : Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.map,
                        size: 16,
                        color: isActive ? Colors.white70 : Colors.grey[700]),
                    const SizedBox(width: 4),
                    Text(distance,
                        style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey[700])),
                    const SizedBox(width: 12),
                    Icon(Icons.timer,
                        size: 16,
                        color: isActive ? Colors.white70 : Colors.grey[700]),
                    const SizedBox(width: 4),
                    Text(duration,
                        style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey[700])),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // message logic
            },
            icon: Icon(
              Icons.message_outlined,
              color: isActive ? Colors.white : Colors.green,
              size: 24,
            ),
          ),
          Icon(Icons.chevron_right,
              color: isActive ? Colors.white : Colors.grey),
        ],
      ),
    );
  }
}
