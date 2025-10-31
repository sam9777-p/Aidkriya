import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../payment_screen.dart';

class WalkSummaryScreen extends StatelessWidget {
  final String walkId;
  const WalkSummaryScreen({super.key, required this.walkId});

  @override
  Widget build(BuildContext context) {
    final walkRef = FirebaseFirestore.instance.collection('accepted_walks').doc(walkId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walk Summary'),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: walkRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) return const Center(child: Text('Walk not found'));

          final finalStats = data['finalStats'] ?? {};
          final duration = finalStats['elapsedMinutes'] ?? 0;
          final distance = finalStats['finalDistanceKm'] ?? 0.0;
          final amount = finalStats['amountDue'] ?? 0.0;
          final paymentStatus = data['paymentStatus'] ?? 'Pending';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Your Walk Summary',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        Text('Duration: $duration min'),
                        Text('Distance: ${distance.toStringAsFixed(2)} km'),
                        Text('Amount Due: ₹${amount.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (paymentStatus != 'Paid')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    ),
                    icon: const Icon(Icons.payment),
                    label: const Text('Pay Now'),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(amount: amount, walkId: walkId),
                        ),
                      );
                    },
                  )
                else
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const Spacer(),
                const Text(
                  'Thank you for walking with AidKriya!',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
