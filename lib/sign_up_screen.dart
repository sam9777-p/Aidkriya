import 'package:aidkriya_walker/setup_flow_screen.dart';
import 'package:aidkriya_walker/sign_in_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _isGoogleHovered = false;
  bool _isEmailHovered = false;
  bool _isSignInHovered = false;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _initializeTokenListener(String uid) {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await _firestore.collection('users').doc(uid).set({
          'fcmToken': newToken,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Failed to update refreshed FCM token: $e");
      }
    });
  }

  Future<void> _signUpWithEmail() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill all fields.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint("🔄 Starting signup process...");
      debugPrint("📧 Email: $email");
      debugPrint("👤 Name: $name");

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint("✅ User credential created: ${userCredential.user?.uid}");

      if (userCredential.user == null) {
        throw Exception("User credential is null");
      }

      final userId = userCredential.user!.uid;
      final userEmail = userCredential.user!.email ?? email;

      try {
        await userCredential.user!.updateDisplayName(name);
        debugPrint("Display name updated");
      } catch (e) {
        debugPrint("Could not update display name: $e");
      }

      // get FCM token
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint("Warning: couldn't get FCM token: $e");
        fcmToken = null;
      }

      try {
        await _firestore.collection('users').doc(userId).set({
          'name': name,
          'email': userEmail,
          if (fcmToken != null) 'fcmToken': fcmToken,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("Failed writing user doc: $e");
      }

      _initializeTokenListener(userId);

      _showSnackBar('Account created successfully!');

      if (!mounted) return;
      setState(() => _isLoading = false);

      debugPrint(" Attempting navigation to SetupFlowScreen...");

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SetupFlowScreen(
            fullNameFromSignup: name,
            userId: userId,
            email: userEmail,
          ),
        ),
      );

      debugPrint("✅ Navigation completed");
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase error code: ${e.code}");
      debugPrint("Firebase error message: ${e.message}");
      if (!mounted) return;
      setState(() => _isLoading = false);

      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Password is too weak. Use at least 6 characters.';
          break;
        case 'email-already-in-use':
          errorMessage = 'This email is already registered. Try signing in.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        default:
          errorMessage = e.message ?? 'Sign-up failed. Please try again.';
      }
      _showSnackBar(errorMessage);
    } catch (e, stackTrace) {
      debugPrint("Unexpected error type: ${e.runtimeType}");
      debugPrint("Unexpected error: $e");
      debugPrint("Stack trace: $stackTrace");
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showSnackBar('Google Sign-in cancelled.');
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final userId = userCredential.user!.uid;
      final userEmail = userCredential.user!.email ?? googleUser.email;
      final userName =
          userCredential.user?.displayName ?? googleUser.displayName ?? "";

      debugPrint("Google sign-in success: $userId");
      debugPrint("Name: $userName");
      debugPrint("Email: $userEmail");

      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint("Warning: couldn't get FCM token: $e");
        fcmToken = null;
      }

      final userDocRef = _firestore.collection('users').doc(userId);
      final existing = await userDocRef.get();

      if (!existing.exists) {
        await userDocRef.set({
          'name': userName,
          'email': userEmail,
          if (fcmToken != null) 'fcmToken': fcmToken,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final Map<String, dynamic> updateMap = {
          if (fcmToken != null) 'fcmToken': fcmToken,
        };
        if ((existing.data()?['name'] ?? '').toString().isEmpty &&
            userName.isNotEmpty) {
          updateMap['name'] = userName;
        }
        if (updateMap.isNotEmpty) {
          await userDocRef.set(updateMap, SetOptions(merge: true));
        }
      }
      _initializeTokenListener(userId);

      if (!mounted) return;
      setState(() => _isLoading = false);

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SetupFlowScreen(
            fullNameFromSignup: userName,
            userId: userId,
            email: userEmail,
          ),
        ),
      );

      _showSnackBar('Signed in with Google!');
    } on FirebaseAuthException catch (e) {
      debugPrint(" Google sign-in error: ${e.code} - ${e.message}");
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(e.message ?? 'Google sign-in failed.');
    } catch (e) {
      debugPrint(" Unexpected error: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('An unexpected error occurred.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    const Color primaryGreen = Color(0xFF6BCBA6);
    const Color fadedGreen = Color(0xFFE8F5E9);
    const Color lightGrey = Color(0xFFE0E0E0);
    const Color backgroundDark = Color(0xFF112117);
    const Color textLight = Colors.black;
    const Color textDark = Colors.white;

    Color buttonHoverColor(Color baseColor) {
      return HSLColor.fromColor(baseColor)
          .withLightness(
            (HSLColor.fromColor(baseColor).lightness * 0.8).clamp(0.3, 0.9),
          )
          .toColor();
    }

    InputDecoration buildInputDecoration(
      String hint,
      FocusNode focusNode, {
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? Colors.grey[300] : Colors.black54,
          fontSize: 14,
        ),
        filled: true,
        fillColor: focusNode.hasFocus
            ? (isDark ? fadedGreen.withOpacity(0.3) : fadedGreen)
            : (isDark ? Colors.grey[800] : lightGrey),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: lightGrey, width: 1),
          borderRadius: BorderRadius.circular(15),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
          borderRadius: BorderRadius.circular(15),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        suffixIcon: suffixIcon,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? backgroundDark : const Color(0xFFE8F5E9),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final bool isMobile = width < 600;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 24 : width * 0.25,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isMobile ? 100 : 120,
                        height: isMobile ? 100 : 120,
                        decoration: const BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          image: DecorationImage(
                            image: AssetImage("assets/images/logo.png"),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        "Create your aidKRIYA Walker account",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 30,
                          fontWeight: FontWeight.bold,
                          color: isDark ? textDark : textLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Join us and start making a difference today.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.black54,
                          fontSize: isMobile ? 14 : 16,
                        ),
                      ),
                      const SizedBox(height: 30),

                      Focus(
                        onFocusChange: (_) => setState(() {}),
                        child: TextField(
                          controller: _nameController,
                          focusNode: _nameFocus,
                          style: TextStyle(
                            color: isDark ? textDark : Colors.black,
                          ),
                          decoration: buildInputDecoration(
                            "Full Name",
                            _nameFocus,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Focus(
                        onFocusChange: (_) => setState(() {}),
                        child: TextField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          style: TextStyle(
                            color: isDark ? textDark : Colors.black,
                          ),
                          decoration: buildInputDecoration(
                            "Email",
                            _emailFocus,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Focus(
                        onFocusChange: (_) => setState(() {}),
                        child: TextField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          obscureText: !_isPasswordVisible,
                          style: TextStyle(
                            color: isDark ? textDark : Colors.black,
                          ),
                          decoration: buildInputDecoration(
                            "Password",
                            _passwordFocus,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      MouseRegion(
                        onEnter: (_) => setState(() => _isEmailHovered = true),
                        onExit: (_) => setState(() => _isEmailHovered = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _signUpWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEmailHovered
                                  ? buttonHoverColor(primaryGreen)
                                  : primaryGreen,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: _isEmailHovered ? 8 : 4,
                            ),
                            icon: const Icon(
                              Icons.person_add_alt_1,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Sign up with Email",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark ? Colors.grey[700] : Colors.grey,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Text(
                              "Or",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark ? Colors.grey[700] : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      MouseRegion(
                        onEnter: (_) => setState(() => _isGoogleHovered = true),
                        onExit: (_) => setState(() => _isGoogleHovered = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isGoogleHovered
                                  ? buttonHoverColor(primaryGreen)
                                  : primaryGreen,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: _isGoogleHovered ? 8 : 4,
                            ),
                            icon: const Icon(
                              Icons.g_mobiledata_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            label: const Text(
                              "Sign up with Google",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      MouseRegion(
                        onEnter: (_) => setState(() => _isSignInHovered = true),
                        onExit: (_) => setState(() => _isSignInHovered = false),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignInScreen(),
                              ),
                            );
                          },
                          child: Text.rich(
                            TextSpan(
                              text: "Already have an account? ",
                              style: TextStyle(
                                color: isDark ? textDark : Colors.black,
                              ),
                              children: [
                                TextSpan(
                                  text: "Sign In",
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontWeight: FontWeight.bold,
                                    decoration: _isSignInHovered
                                        ? TextDecoration.underline
                                        : TextDecoration.none,
                                    decorationThickness: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      Text(
                        "Terms of Service · Privacy Policy",
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
            ),
        ],
      ),
    );
  }
}
