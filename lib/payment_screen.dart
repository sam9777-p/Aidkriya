import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'home_screen.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String walkId;

  const PaymentScreen({
    super.key,
    required this.amount,
    required this.walkId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  late Razorpay _razorpay;
  late Timer _timer;
  int _remainingSeconds = 300;
  bool _isPaymentDone = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 5),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds == 0) {
        timer.cancel();
        if (!_isPaymentDone && mounted) {
          await _markAsCancelled("Timeout");
          _redirectToHome();
        }
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _redirectToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
    );
  }
  void _openPaymentSheet(String method) async {
    final options = {
      'key': 'rzp_test_RZP2JKgTnlbx5M',
      'amount': (widget.amount * 100).toInt(),
      'name': 'AidKriya Walk',
      'description': 'Payment for your walk journey',
      'prefill': {'contact': '', 'email': ''},
      'theme': {'color': '#4CAF50'},
      'method': method.toLowerCase(),
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isPaymentDone = true);

    await FirebaseFirestore.instance
        .collection('accepted_walks')
        .doc(widget.walkId)
        .update({
      'paymentStatus': 'Paid',
      'status': 'Completed',
    });

    final walkDoc = await FirebaseFirestore.instance
        .collection('accepted_walks')
        .doc(widget.walkId)
        .get();
    final walkData = walkDoc.data() ?? {};
    final recipientId = walkData['recipientId'] as String?;

    if (recipientId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .update({'earnings': FieldValue.increment(widget.amount)});
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Payment Successful!")),
      );
      Future.delayed(const Duration(seconds: 2), _redirectToHome);
    }
  }

  Future<void> _handlePaymentError(PaymentFailureResponse response) async {
    if (!_isPaymentDone) {
      await _markAsCancelled("UserCancelled");
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("❌ Payment failed: ${response.message ?? 'Cancelled'}"),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External Wallet: ${response.walletName}")),
    );
  }

  Future<void> _markAsCancelled(String reason) async {
    try {
      await FirebaseFirestore.instance
          .collection('accepted_walks')
          .doc(widget.walkId)
          .update({
        'paymentStatus': 'Cancelled',
        'status': 'Cancelled',
        'cancelReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      debugPrint("🟡 Payment cancelled ($reason) for walk ${widget.walkId}");
    } catch (e) {
      debugPrint("Error marking as cancelled: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text('Payment'),
        centerTitle: true,
        backgroundColor: const Color(0xFFA8D8B9),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFA8D8B9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA8D8B9), width: 1),
              ),
              child: Column(
                children: [
                  const Icon(Icons.timer, color: Color(0xFFA8D8B9), size: 32),
                  const SizedBox(height: 8),
                  Text(
                    "Auto redirecting in $minutes:$seconds",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return LinearProgressIndicator(
                          value: 1.0 - _animationController.value,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFA8D8B9)),
                          minHeight: 8,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Payable Amount',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "₹${widget.amount.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA8D8B9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openPaymentSheet("UPI"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA8D8B9),
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code, color: Colors.white),
                    label: const Text(
                      "Pay with UPI",
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _openPaymentSheet("CARD"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA8D8B9),
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: const Icon(Icons.credit_card, color: Colors.white),
                    label: const Text(
                      "Pay with Card",
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
