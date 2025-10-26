import 'package:aidkriya_walker/components/request_accept_button.dart';
import 'package:aidkriya_walker/components/request_detail_row.dart';
import 'package:aidkriya_walker/components/request_reject_button.dart';
import 'package:aidkriya_walker/components/walker_avatar.dart';
import 'package:flutter/material.dart';

import '../model/incoming_request.dart';

class RequestCard extends StatelessWidget {
  final IncomingRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onTap;

  const RequestCard({
    Key? key,
    required this.request,
    required this.onAccept,
    required this.onReject,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
        child: Column(
          children: [
            Row(
              children: [
                WalkerAvatar(imageUrl: request.walkerImageUrl, size: 60),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.walkerName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      RequestDetailRow(
                        icon: Icons.access_time,
                        text: request.dateTime,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RequestDetailRow(icon: Icons.location_on, text: request.location),
            const SizedBox(height: 12),
            RequestDetailRow(icon: Icons.speed, text: request.pace),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: RequestRejectButton(onPressed: onReject)),
                const SizedBox(width: 12),
                Expanded(child: RequestAcceptButton(onPressed: onAccept)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
