import 'package:aidkriya_walker/components/request_button.dart';
import 'package:aidkriya_walker/components/walker_avatar.dart';
import 'package:flutter/material.dart';

import '../model/Walker.dart';
import 'instant_walk_button.dart';

class WalkerCard extends StatelessWidget {
  final Walker walker;
  final bool showInstantWalk;
  final VoidCallback onRequestPressed;
  final VoidCallback? onInstantWalkPressed;

  const WalkerCard({
    super.key,
    required this.walker,
    this.showInstantWalk = false,
    required this.onRequestPressed,
    this.onInstantWalkPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
          WalkerAvatar(imageUrl: walker.imageUrl, size: 60),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  walker.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Color(0xFFFFD700)),
                    const SizedBox(width: 4),
                    Text(
                      walker.rating.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${walker.distance} km away',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (!showInstantWalk)
                RequestButton(onPressed: onRequestPressed)
              else
                InstantWalkButton(onPressed: onInstantWalkPressed!),
            ],
          ),
        ],
      ),
    );
  }
}
