// lib/screens/walk_summary_screen.dart

import 'package:aidkriya_walker/model/incoming_request_display.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../home_screen.dart';
import '../payment_screen.dart';

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

  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;



  Future<void> _updateWandererSocialImpact(double amountPaid) async {
    // Get the current user (Wanderer) ID
    final String? wandererId = FirebaseAuth.instance.currentUser?.uid;

    if (wandererId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(wandererId)
          .update({
        // Incrementing 'earnings' to represent Social Impact/Contribution
        'earnings': FieldValue.increment(amountPaid),
      });

      debugPrint("Social impact (earnings) updated for wanderer: $wandererId");
    } catch (e) {
      debugPrint("Error updating wanderer impact: $e");
    }
  }

  Future<void> _onSubmitFeedback(BuildContext context) async {
    if (_currentRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating first.')),
      );
      return;
    }

    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    // The Walker is the recipient of the walk request
    final String walkerId = widget.walkData.recipientId;

    final walkerDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(walkerId);

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
      debugPrint("Error updating rating in transaction: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // --- Build Methods ---

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountDueCard(String amount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount Due',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00C853),
            ),
          ),
        ],
      ),
    );
  }

  // [NEW] Widget to display charity note instead of checkbox
  Widget _buildCharityNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.volunteer_activism, color: Colors.pink[300], size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              "Note: 2% of this amount goes to charity.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayNowButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        // [MODIFIED] Only use base amount. No extra donation added.
        final double amountToPay = widget.finalStats['amountDue'] ?? 0.0;

        final bool? paymentSuccess = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              amount: amountToPay,
              walkId: widget.walkData.walkId,
            ),
          ),
        );

        if (paymentSuccess == true) {
          // Update Social Impact with the amount paid
          await _updateWandererSocialImpact(amountToPay);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment successful! Your social impact score has increased.'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (Route<dynamic> route) => false,
            );
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFA8D8B9),
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      icon: const Icon(Icons.credit_card, size: 24),
      label: const Text(
        'Pay Now',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );

  }

  Widget _buildFeedbackSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How was your walk?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentRating = starValue;
                });
              },
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
        const SizedBox(height: 12),
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const TextField(
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'Tell us more...',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => _onSubmitFeedback(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA8D8B9),
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.all(15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.black54,
            ),
          )
              : const Text(
            'Submit Feedback',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildWalkerSummaryView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Walk Complete!",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          "Waiting for the Wanderer to complete payment and leave feedback.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (Route<dynamic> route) => false,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA8D8B9),
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.all(15),
          ),
          child: const Text(
            'Back to Home',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildContributionSection(String distance, String contribution) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
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
          const Icon(Icons.favorite, color: Colors.red, size: 50),
          const SizedBox(height: 16),
          const Text(
            'You just walked for a cause!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your $distance walk helped contribute $contribution to social causes.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final double elapsedMinutes =
        (widget.finalStats['elapsedMinutes'] as int?)?.toDouble() ?? 0.0;
    final double finalDistanceKm =
        widget.finalStats['finalDistanceKm'] as double? ?? 0.0;
    final double amountDue = widget.finalStats['amountDue'] as double? ?? 0.0;

    final double contributionAmount = finalDistanceKm * 5.0;

    final timeStr = "${elapsedMinutes.round()} min";
    final distanceStr = "${finalDistanceKm.toStringAsFixed(1)} km";
    final amountDueStr = "₹${amountDue.toStringAsFixed(2)}";
    final contributionStr = "₹${contributionAmount.toStringAsFixed(0)}";

    final bool isWanderer = (currentUserId == widget.walkData.senderId);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFFf5f5ff),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (Route<dynamic> route) => false,
            );
          },
        ),
        title: const Text('Walk Summary'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _buildStatCard('Time', timeStr, Icons.timer),
                const SizedBox(width: 20),
                _buildStatCard('Distance', distanceStr, Icons.directions_walk),
              ],
            ),
            const SizedBox(height: 20),
            _buildAmountDueCard(amountDueStr),
            const SizedBox(height: 20),

            if (isWanderer) ...[
              // [MODIFIED] Replaced Checkbox with static Charity Note
              _buildCharityNote(),
              _buildPayNowButton(context),
              const SizedBox(height: 40),
              _buildFeedbackSection(context),
            ] else ...[
              const SizedBox(height: 20),
              _buildWalkerSummaryView(context),
            ],

            const SizedBox(height: 40),
            _buildContributionSection(distanceStr, contributionStr),
          ],
        ),
      ),
    );
  }
}