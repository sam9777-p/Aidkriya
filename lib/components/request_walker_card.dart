import 'package:aidkriya_walker/model/incoming_request.dart';
import 'package:flutter/material.dart';

class RequestWalkerCard extends StatelessWidget {
  final IncomingRequest walker;
  final VoidCallback onMessageTapped;

  const RequestWalkerCard({
    Key? key,
    required this.walker,
    required this.onMessageTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[300],
            backgroundImage: walker.imageUrl != null
                ? NetworkImage(walker.imageUrl!)
                : null,
            child: walker.imageUrl == null
                ? Icon(Icons.person, color: Colors.grey[600], size: 32)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  walker.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  walker.bio,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onMessageTapped,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Color(0xFF6BCBA6),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
