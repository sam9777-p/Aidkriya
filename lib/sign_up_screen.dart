import 'package:aidkriya_walker/setup_flow_screen.dart';
import 'package:aidkriya_walker/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<void> _signUpWithEmail() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill all fields.');
      return;
    }

    try {
      setState(() => _isLoading = true);
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user?.updateDisplayName(name);

      final user = userCredential.user;

      _showSnackBar('Account created successfully!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SetupFlowScreen(
            fullNameFromSignup: _nameController.text.trim(),
            userId: user!.uid,
            email: user.email!,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Sign-up failed. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      setState(() => _isLoading = true);

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _showSnackBar('Google Sign-in cancelled.');
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);

      _showSnackBar('Signed in with Google!');
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Google sign-in failed.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    const Color primaryGreen = Color(0xFF20DF6C);
    const Color fadedGreen = Color(0xFFE8F5E9);
    const Color lightGrey = Color(0xFFE0E0E0);
    const Color backgroundDark = Color(0xFF112117);
    const Color textLight = Colors.black;
    const Color textDark = Colors.white;

    Color buttonHoverColor(Color baseColor) {
      return HSLColor.fromColor(baseColor)
          .withLightness(
          (HSLColor.fromColor(baseColor).lightness * 0.8).clamp(0.3, 0.9))
          .toColor();
    }

    InputDecoration buildInputDecoration(String hint, FocusNode focusNode,
        {Widget? suffixIcon}) {
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
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                          style:
                          TextStyle(color: isDark ? textDark : Colors.black),
                          decoration:
                          buildInputDecoration("Full Name", _nameFocus),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Focus(
                        onFocusChange: (_) => setState(() {}),
                        child: TextField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          style:
                          TextStyle(color: isDark ? textDark : Colors.black),
                          decoration: buildInputDecoration("Email", _emailFocus),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Focus(
                        onFocusChange: (_) => setState(() {}),
                        child: TextField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          obscureText: !_isPasswordVisible,
                          style:
                          TextStyle(color: isDark ? textDark : Colors.black),
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
                        onEnter: (_) => setState(() => _isGoogleHovered = true),
                        onExit: (_) => setState(() => _isGoogleHovered = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: ElevatedButton.icon(
                            onPressed: _signInWithGoogle,
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
                            icon: const Icon(Icons.g_mobiledata_rounded,
                                color: Colors.white, size: 28),
                            label: const Text(
                              "Sign up with Google",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                              child: Divider(
                                  color:
                                  isDark ? Colors.grey[700] : Colors.grey)),
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              "Or",
                              style: TextStyle(
                                color:
                                isDark ? Colors.grey[300] : Colors.black87,
                              ),
                            ),
                          ),
                          Expanded(
                              child: Divider(
                                  color:
                                  isDark ? Colors.grey[700] : Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      MouseRegion(
                        onEnter: (_) => setState(() => _isEmailHovered = true),
                        onExit: (_) => setState(() => _isEmailHovered = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: ElevatedButton.icon(
                            onPressed: _signUpWithEmail,
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
                            icon: const Icon(Icons.person_add_alt_1,
                                color: Colors.white),
                            label: const Text(
                              "Sign up with Email",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
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
                                  builder: (context) => const SignInScreen()),
                            );
                          },
                          child: Text.rich(
                            TextSpan(
                              text: "Already have an account? ",
                              style: TextStyle(
                                  color: isDark ? textDark : Colors.black),
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
                            fontSize: 12),
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
