import 'package:aidkriya_walker/components/walker_avatar.dart';
import 'package:aidkriya_walker/home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GroupWalkSummaryScreen extends StatefulWidget {
  final String walkId;
  final Map<String, dynamic> walkData;
  final bool isWalker;

  const GroupWalkSummaryScreen({
    super.key,
    required this.walkId,
    required this.walkData,
    required this.isWalker,
  });

  @override
  State<GroupWalkSummaryScreen> createState() => _GroupWalkSummaryScreenState();
}

class _GroupWalkSummaryScreenState extends State<GroupWalkSummaryScreen> {
  int _currentRating = 0;
  bool _isSubmitting = false;

  Future<void> _onSubmitFeedback(BuildContext context) async {
    if (_currentRating == 0) return;
    setState(() => _isSubmitting = true);

    final String walkerId = widget.walkData['walkerId'];
    final walkerDocRef = FirebaseFirestore.instance.collection('users').doc(walkerId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(walkerDocRef);
        final data = snapshot.data();
        final double currentRatingSum = (data?['totalRatingSum'] as num?)?.toDouble() ?? 0.0;
        final int currentRatingCount = (data?['ratingCount'] as int?) ?? 0;

        final double newRatingSum = currentRatingSum + _currentRating;
        final int newRatingCount = currentRatingCount + 1;
        final double newAvgRating = newRatingSum / newRatingCount;

        transaction.update(walkerDocRef, {
          'rating': double.parse(newAvgRating.toStringAsFixed(1)),
          'totalRatingSum': newRatingSum,
          'ratingCount': newRatingCount,
        });
      });

      if (mounted) {
        _navigateToHome();
      }
    } catch (e) {
      debugPrint("Error updating rating: $e");
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.walkData['title'] ?? 'Group Walk';
    final walkerInfo = widget.walkData['walkerInfo'] as Map<String, dynamic>? ?? {};
    final totalEarnings = (widget.walkData['totalEarnings'] as num?)?.toDouble() ?? 0.0;
    final participantCount = (widget.walkData['participantCount'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Walk Summary'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WalkerAvatar(imageUrl: walkerInfo['imageUrl'], size: 100),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              "Led by ${walkerInfo['fullName']}",
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 48),

            if (widget.isWalker)
              Column(
                children: [
                  Text(
                    'You earned:',
                    style: TextStyle(fontSize: 18, color: Colors.grey[800]),
                  ),
                  Text(
                    '₹${totalEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF00C853)),
                  ),
                  Text(
                    'from $participantCount ${participantCount == 1 ? "participant" : "participants"}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Text(
                    'How was your walk with ${walkerInfo['fullName']}?',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        onPressed: () => setState(() => _currentRating = starValue),
                        icon: Icon(
                          starValue <= _currentRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 36,
                        ),
                      );
                    }),
                  ),
                ],
              ),

            const Spacer(),

            if (widget.isWalker)
              ElevatedButton(
                onPressed: _navigateToHome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA8D8B9),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Back to Home', style: TextStyle(fontSize: 18, color: Colors.white)),
              )
            else
              ElevatedButton(
                onPressed: (_currentRating == 0 || _isSubmitting) ? null : () => _onSubmitFeedback(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA8D8B9),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Feedback', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}