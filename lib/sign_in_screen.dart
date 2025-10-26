import 'package:aidkriya_walker/sign_up_screen.dart';
import 'package:aidkriya_walker/walker_home.dart';
import 'package:aidkriya_walker/wanderer_home.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _isGoogleHovered = false;
  bool _isEmailHovered = false;
  bool _isSignUpHovered = false;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final role = doc.data()?['role'] ?? 'Walker';

        if (role == 'Walker') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const WalkerHome()),
          );
        } else if (role == 'Wanderer') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const WandererHome()),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome, ${user.email}!')),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        default:
          message = e.message ?? 'Sign-in failed.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final snapshot = await userDoc.get();

        if (!snapshot.exists) {
          await userDoc.set({
            'email': user.email,
            'name': user.displayName ?? '',
            'role': 'Walker',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        final role = snapshot.data()?['role'] ?? 'Walker';

        if (role == 'Walker') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const WalkerHome()),
          );
        } else if (role == 'Wanderer') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const WandererHome()),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed in with Google successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign-in failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
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
      bool isPassword = false,
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

        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
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
                        "Welcome to aidKRIYA Walker",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 30,
                          fontWeight: FontWeight.bold,
                          color: isDark ? textDark : textLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Walk together, make a difference.",
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
                            isPassword: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      MouseRegion(
                        onEnter: (_) => setState(() => _isGoogleHovered = true),
                        onExit: (_) => setState(() => _isGoogleHovered = false),
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
                          ),
                          icon: const Icon(
                            Icons.g_mobiledata_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          label: const Text(
                            "Sign in with Google",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
                        onEnter: (_) => setState(() => _isEmailHovered = true),
                        onExit: (_) => setState(() => _isEmailHovered = false),
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _signInWithEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isEmailHovered
                                ? buttonHoverColor(primaryGreen)
                                : primaryGreen,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          icon: const Icon(
                            Icons.mail_outline_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Sign in with Email",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      MouseRegion(
                        onEnter: (_) => setState(() => _isSignUpHovered = true),
                        onExit: (_) => setState(() => _isSignUpHovered = false),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: Text.rich(
                            TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(
                                color: isDark ? textDark : Colors.black,
                              ),
                              children: [
                                TextSpan(
                                  text: "Sign Up",
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontWeight: FontWeight.bold,
                                    decoration: _isSignUpHovered
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
              color: Colors.black.withOpacity(0.4),
              width: double.infinity,
              height: double.infinity,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF20DF6C)),
              ),
            ),
        ],
      ),
    );
  }
}
