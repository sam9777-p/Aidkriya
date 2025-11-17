import 'package:aidkriya_walker/components/request_button.dart';
import 'package:aidkriya_walker/components/walker_avatar.dart';
import 'package:flutter/material.dart';

import '../model/Walker.dart';

class WalkerCard extends StatelessWidget {
  final Walker walker;
  final VoidCallback onRequestPressed;
  final bool isBestMatch; // [NEW] To show the badge

  const WalkerCard({
    super.key,
    required this.walker,
    required this.onRequestPressed,
    this.isBestMatch = false, // [NEW] Default to false
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            isBestMatch // [NEW] Add border for best match
            ? Border.all(color: const Color(0xFF6BCBA6), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: isBestMatch
                ? const Color(0xFF6BCBA6).withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WalkerAvatar(imageUrl: walker.imageUrl, size: 60),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            walker.name ?? 'guest',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        // [NEW] Best Match Badge
                        if (isBestMatch)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6BCBA6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Best Match',
                              style: TextStyle(
                                color: Color(0xFF00695C),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: Color(0xFFFFD700),
                        ),
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
              Column(children: [RequestButton(onPressed: onRequestPressed)]),
            ],
          ),
          // [NEW] Common Interests Section
          if (walker.commonInterests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, left: 4.0, right: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      text: 'You both like: ',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      children: [
                        TextSpan(
                          text: walker.commonInterests.join(', '),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
