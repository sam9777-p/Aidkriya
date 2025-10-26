import 'package:aidkriya_walker/home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'profile_setup_screen.dart';
import 'role_setup_screen.dart';

class SetupFlowScreen extends StatefulWidget {
  final String fullNameFromSignup;
  final String userId;
  final String email;

  const SetupFlowScreen({
    super.key,
    required this.fullNameFromSignup,
    required this.userId,
    required this.email,
  });

  @override
  State<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends State<SetupFlowScreen> {
  int _currentStep = 1;

  // store collected data
  Map<String, dynamic> _profileData = {};

  void _saveProfileData(Map<String, dynamic> data) {
    _profileData = data;
  }

  void _saveRoleAndFinish(String role) async {
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);

    await userDoc.set({
      ..._profileData,
      'email': widget.email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (role == "Walker") {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF112117) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (_currentStep > 1) {
                      setState(() => _currentStep--);
                    } else {
                      Navigator.of(context).maybePop();
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    _currentStep == 1
                        ? "Let's Get to Know You"
                        : 'Choose Your Role',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _currentStep == 1
                    ? ProfileSetupScreen(
                        key: const ValueKey(1),
                        onSaveAndContinue: (profileData) {
                          _saveProfileData(profileData);
                          setState(() => _currentStep = 2);
                        },
                        fullName: widget.fullNameFromSignup,
                      )
                    : RoleSetupScreen(
                        key: const ValueKey(2),
                        onRoleSelected: _saveRoleAndFinish,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
