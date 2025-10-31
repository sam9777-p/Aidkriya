import 'package:aidkriya_walker/model/incoming_request_display.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../payment_screen.dart';
import '../home_screen.dart';

class WalkSummaryScreen extends StatefulWidget {
  final IncomingRequestDisplay walkData;
  final Map<String, dynamic> finalStats;

  const WalkSummaryScreen({
    super.key,
    required this.walkData,
    required this.finalStats,
  });

  @override
  State<WalkSummaryScreen> createState() => _WalkSummaryScreenState();
}

class _WalkSummaryScreenState extends State<WalkSummaryScreen> {
  int _currentRating = 0;
  bool _isSubmitting = false;

  Future<void> _onSubmitFeedback(BuildContext context) async {
    if (_currentRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating first.')),
      );
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final String walkerId = widget.walkData.recipientId;
    final walkerDocRef =
    FirebaseFirestore.instance.collection('users').doc(walkerId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(walkerDocRef);
        final data = snapshot.data();

        final double currentRatingSum =
            (data?['totalRatingSum'] as num?)?.toDouble() ?? 0.0;
        final int currentRatingCount = (data?['ratingCount'] as int?) ?? 0;

        final double newRatingSum = currentRatingSum + _currentRating;
        final int newRatingCount = currentRatingCount + 1;
        final double newAvgRating = newRatingSum / newRatingCount;

        transaction.update(walkerDocRef, {
          'rating': double.parse(newAvgRating.toStringAsFixed(1)),
          'totalRatingSum': newRatingSum,
          'ratingCount': newRatingCount,
          'lastRatedWalkId': widget.walkData.walkId,
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted and rating updated!')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint("Error updating rating: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildStatCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How was your walk?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return GestureDetector(
              onTap: () => setState(() => _currentRating = starValue),
              child: Icon(
                starValue <= _currentRating ? Icons.star : Icons.star_border,
                color: starValue <= _currentRating
                    ? Colors.amber
                    : Colors.grey[400],
                size: 36,
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => _onSubmitFeedback(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA8D8B9),
            padding: const EdgeInsets.all(14),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          child: _isSubmitting
              ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.black54))
              : const Text('Submit Feedback',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final walkRef = FirebaseFirestore.instance
        .collection('accepted_walks')
        .doc(widget.walkData.walkId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walk Summary'),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: walkRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text('Walk not found.'));
          }

          final finalStats = data['finalStats'] ?? {};
          final duration = finalStats['elapsedMinutes'] ?? 0;
          final distance = finalStats['finalDistanceKm'] ?? 0.0;
          final amount = finalStats['amountDue'] ?? 0.0;
          final paymentStatus = data['paymentStatus'] ?? 'Pending';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Your Walk Summary',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const Divider(),
                        Row(
                          children: [
                            _buildStatCard('Duration', '$duration min'),
                            const SizedBox(width: 12),
                            _buildStatCard(
                                'Distance', '${distance.toStringAsFixed(2)} km'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Amount Due: ₹${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (paymentStatus != 'Paid')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 12),
                    ),
                    icon: const Icon(Icons.payment),
                    label: const Text('Pay Now'),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(
                            amount: amount,
                            walkId: widget.walkData.walkId,
                            walkData: widget.walkData,
                            finalStats: finalStats,
                          ),
                        ),
                      );
                    },
                  )
                else
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 48),
                const SizedBox(height: 30),
                _buildFeedbackSection(context),
                const SizedBox(height: 40),
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
