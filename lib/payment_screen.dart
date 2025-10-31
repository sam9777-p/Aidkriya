import 'dart:async';
import 'package:aidkriya_walker/screens/walk_summary_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'model/incoming_request_display.dart';


class PaymentScreen extends StatefulWidget {
  final double amount;
  final String walkId;
  final IncomingRequestDisplay walkData;
  final Map<String, dynamic> finalStats;

  const PaymentScreen({
    super.key,
    required this.amount,
    required this.walkId,
    required this.walkData,
    required this.finalStats,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Razorpay _razorpay;
  Timer? _timer;
  int _secondsLeft = 300;
  bool _isPaymentHandled = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _startTimer();
    _openCheckout();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 0) {
        _handleTimeout();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _openCheckout() {
    var options = {
      'key': 'YOUR_RAZORPAY_KEY',
      'amount': (widget.amount * 100).toInt(),
      'name': 'AidKriya',
      'description': 'Walk Payment',
      'prefill': {'contact': '', 'email': ''},
    };
    _razorpay.open(options);
  }

  Future<void> _handleSuccess(PaymentSuccessResponse response) async {
    if (_isPaymentHandled) return;
    _isPaymentHandled = true;

    final docRef =
    FirebaseFirestore.instance.collection('accepted_walks').doc(widget.walkId);

    await docRef.update({
      'paymentStatus': 'Paid',
      'status': 'Completed',
      'paymentId': response.paymentId,
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WalkSummaryScreen(
            walkData: widget.walkData,
            finalStats: widget.finalStats,
          ),
        ),
      );
    }
  }

  Future<void> _handleError(PaymentFailureResponse response) async {
    if (_isPaymentHandled) return;
    _isPaymentHandled = true;

    await FirebaseFirestore.instance
        .collection('accepted_walks')
        .doc(widget.walkId)
        .update({
      'paymentStatus': 'Cancelled',
    });

    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleTimeout() async {
    if (_isPaymentHandled) return;
    _isPaymentHandled = true;

    _timer?.cancel();

    await FirebaseFirestore.instance
        .collection('accepted_walks')
        .doc(widget.walkId)
        .update({
      'paymentStatus': 'Cancelled',
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = (_secondsLeft / 60).floor();
    final secs = _secondsLeft % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            Text(
              'Complete your payment in',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              '$mins:${secs.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Amount: ₹${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
