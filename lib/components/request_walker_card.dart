import 'package:aidkriya_walker/model/incoming_request_display.dart';
import 'package:flutter/material.dart';

class RequestWalkerCard extends StatelessWidget {
  final IncomingRequestDisplay walker;

  const RequestWalkerCard({Key? key, required this.walker}) : super(key: key);

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
            backgroundImage: walker.senderImageUrl != null
                ? NetworkImage(walker.senderImageUrl!)
                : null,
            child: walker.senderImageUrl == null
                ? Icon(Icons.person, color: Colors.grey[600], size: 32)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  walker.senderName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  walker.senderBio ?? 'nice',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
