
import 'dart:async';
import 'package:aidkriya_walker/setup_flow_screen.dart';
import 'package:aidkriya_walker/sign_in_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';


class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _timer;
  bool _canResendEmail = false;
  int _resendCooldown = 30;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
    _startResendCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startVerificationCheck() {
    _checkVerification();

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkVerification();
    });
  }

  Future<void> _checkVerification() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      _timer?.cancel();
      _navigateToSignIn();
      return;
    }

    await user.reload();
    if (user.emailVerified) {
      _timer?.cancel();
      await _onVerificationSuccess(user);
    }
  }

  void _startResendCooldown() {
    setState(() => _canResendEmail = false);
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) {
        timer.cancel();
        setState(() {
          _canResendEmail = true;
          _resendCooldown = 30;
        });
      }
    });
  }

  Future<void> _onVerificationSuccess(User user) async {
    if (!mounted) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        _navigateToSetup(user, user.displayName ?? "", user.email ?? "");
        return;
      }

      final data = doc.data();
      final String? role = data?['role'];
      final String fullName = data?['name'] ?? user.displayName ?? "";
      final String email = data?['email'] ?? user.email ?? "";

      if (role == null || role.isEmpty) {
        _navigateToSetup(user, fullName, email);
      } else {
        _navigateToHome();
      }
    } catch (e) {
      debugPrint("Error checking profile: $e");
      _navigateToSetup(user, user.displayName ?? "", user.email ?? "");
    }
  }

  Future<void> _resendEmail() async {
    if (!_canResendEmail) return;

    try {
      await _auth.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _startResendCooldown();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resending email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    _navigateToSignIn();
  }

  void _navigateToSetup(User user, String fullName, String email) {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => SetupFlowScreen(
          fullNameFromSignup: fullName,
          userId: user.uid,
          email: email,
        ),
      ),
          (route) => false,
    );
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
    );
  }

  void _navigateToSignIn() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _auth.currentUser?.email ?? 'your email';

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 100, color: Color(0xFF6BCBA6)),
              const SizedBox(height: 32),
              const Text(
                'Verify Your Email',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'A verification link has been sent to\n$userEmail\n\nPlease check your inbox and click the link to continue.',
                style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Color(0xFF6BCBA6)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _canResendEmail ? _resendEmail : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6BCBA6),
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.send, color: Colors.white),
                label: Text(
                  _canResendEmail
                      ? 'Resend Email'
                      : 'Resend in $_resendCooldown s',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _signOut,
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}