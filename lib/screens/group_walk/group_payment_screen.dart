import 'package:aidkriya_walker/backend/walk_request_service.dart';
import 'package:aidkriya_walker/model/user_model.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class GroupPaymentScreen extends StatefulWidget {
  final double amount;
  final String walkId;
  final String walkTitle;
  final UserModel currentUser;
  final Map<String, dynamic> walkerInfo;

  const GroupPaymentScreen({
    super.key,
    required this.amount,
    required this.walkId,
    required this.walkTitle,
    required this.currentUser,
    required this.walkerInfo,
  });

  @override
  State<GroupPaymentScreen> createState() => _GroupPaymentScreenState();
}

class _GroupPaymentScreenState extends State<GroupPaymentScreen> {
  late Razorpay _razorpay;
  final _walkService = WalkRequestService();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openPaymentSheet();
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _openPaymentSheet() async {
    final options = {
      'key': 'rzp_test_RZP2JKgTnlbx5M', // Replace with your key
      'amount': (widget.amount * 100).toInt(),
      'name': 'AidKriya Group Walk',
      'description': widget.walkTitle,
      'prefill': {
        'contact': widget.currentUser.phone,
        'email': widget.currentUser.id != null
            ? '${widget.currentUser.id}@aidkriya.com'
            : ''
      },
      'theme': {'color': '#4CAF50'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
      _showErrorAndPop('Failed to open payment gateway.');
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final success = await _walkService.joinGroupWalk(
        widget.walkId,
        widget.currentUser.id!,
        {'name': widget.currentUser.fullName, 'imageUrl': widget.currentUser.imageUrl},
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Payment Successful! You've joined the walk."), backgroundColor: Colors.green),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        _showErrorAndPop('Payment succeeded but failed to join walk. Please contact support.');
      }
    } catch (e) {
      _showErrorAndPop('An error occurred after payment: $e');
    }
  }

  Future<void> _handlePaymentError(PaymentFailureResponse response) async {
    if (!mounted) return;
    _showErrorAndPop("❌ Payment failed: ${response.message ?? 'Cancelled by user'}");
  }

  void _showErrorAndPop(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing Payment...'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text('Connecting to payment gateway...'),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            )
          ],
        ),
      ),
    );
  }
}