// lib/screens/walk_summary_screen.dart

import 'package:aidkriya_walker/model/incoming_request_display.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // [NEW] Import Firestore
import 'package:flutter/material.dart';
import '../home_screen.dart';

class WalkSummaryScreen extends StatefulWidget { // [CHANGE] Changed to StatefulWidget
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

class _WalkSummaryScreenState extends State<WalkSummaryScreen> { // [NEW] State class
  int _currentRating = 0; // State for the selected rating (1 to 5)
  bool _isSubmitting = false; // State for feedback submission

  // --- Feedback Submission Logic ---

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

    // 1. Prepare references
    final walkerDocRef = FirebaseFirestore.instance.collection('users').doc(walkerId);

    try {
      // 2. Transactionally update the Walker's rating
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(walkerDocRef);

        final data = snapshot.data();

        // Define default values if the columns do not exist
        final double currentRatingSum = (data?['totalRatingSum'] as num?)?.toDouble() ?? 0.0;
        final int currentRatingCount = (data?['ratingCount'] as int?) ?? 0;

        // 3. Calculation
        final double newRatingSum = currentRatingSum + _currentRating;
        final int newRatingCount = currentRatingCount + 1;
        final double newAvgRating = newRatingSum / newRatingCount;

        // 4. Update the document
        transaction.update(walkerDocRef, {
          'rating': double.parse(newAvgRating.toStringAsFixed(1)), // Update the final 'rating' field
          'totalRatingSum': newRatingSum,                      // Update the cumulative sum
          'ratingCount': newRatingCount,                        // Update the count
          'lastRatedWalkId': widget.walkData.walkId,            // Optional: Prevent double-rating from the same walk
        });
      });

      // Success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted and rating updated!')),
        );
        // Navigate away after successful submission
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


  // --- Build Methods (Updated to be methods of the State class) ---

  // Helper method to build stat cards (Time/Distance)
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
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
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

  // Helper method to build the Amount Due card
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

  // Helper method for payment button (now accepts context)
  Widget _buildPayNowButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment system activated for Wanderer.')),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFA8D8B9),
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      icon: const Icon(Icons.credit_card, size: 24),
      label: const Text(
        'Pay Now with AppName',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Helper method to build the feedback section (now accepts context)
  Widget _buildFeedbackSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How was your walk?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Star Rating Selection
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
                color: starValue <= _currentRating ? Colors.amber : Colors.grey[400],
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
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          child: _isSubmitting
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
          )
              : const Text('Submit Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // Helper method to build the contribution section
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
    final double elapsedMinutes = (widget.finalStats['elapsedMinutes'] as int?)?.toDouble() ?? 0.0;
    final double finalDistanceKm = widget.finalStats['finalDistanceKm'] as double? ?? 0.0;
    final double amountDue = widget.finalStats['amountDue'] as double? ?? 0.0;

    final double contributionAmount = finalDistanceKm * 5.0;

    final timeStr = "${elapsedMinutes.round()} min";
    final distanceStr = "${finalDistanceKm.toStringAsFixed(1)} km";
    final amountDueStr = "₹${amountDue.toStringAsFixed(2)}";
    final contributionStr = "₹${contributionAmount.toStringAsFixed(0)}";


    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
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
            _buildPayNowButton(context),
            const SizedBox(height: 40),
            _buildFeedbackSection(context),
            const SizedBox(height: 40),
            _buildContributionSection(distanceStr, contributionStr),
          ],
        ),
      ),
    );
  }
}