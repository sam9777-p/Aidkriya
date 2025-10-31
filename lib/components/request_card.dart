import 'package:aidkriya_walker/components/request_detail_row.dart';
import 'package:aidkriya_walker/components/walker_avatar.dart';
import 'package:aidkriya_walker/model/incoming_request_display.dart';
import 'package:flutter/material.dart';

class RequestCard extends StatelessWidget {
  final IncomingRequestDisplay request;
  final VoidCallback onTap;

  const RequestCard({Key? key, required this.request, required this.onTap})
    : super(key: key);

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
                WalkerAvatar(imageUrl: request.senderImageUrl, size: 60),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.senderName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      RequestDetailRow(
                        icon: Icons.access_time,
                        text: "${request.date}, ${request.time}",
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RequestDetailRow(
              icon: Icons.location_on,
              text: "${request.distance.toString()} km",
            ),
            const SizedBox(height: 12),
            RequestDetailRow(
              icon: Icons.timelapse_outlined,
              text: request.duration,
            ),
          ],
        ),
      ),
    );
  }
}
