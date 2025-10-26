import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    const Color primaryGreen = Color(0xFFA8D8B9);
    const Color fadedGreen = Color(0xFFE8F5E9);
    const Color lightGrey = Color(0xFFE0E0E0);
    const Color backgroundLight = Color(0xFFF6F8F7);
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

    InputDecoration buildInputDecoration(String hint, FocusNode focusNode) {
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
      );
    }

    return Scaffold(
      backgroundColor: isDark ? backgroundDark : Color(0xFFE8F5E9),
      body: LayoutBuilder(
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

                  // email
                  Focus(
                    onFocusChange: (_) => setState(() {}),
                    child: TextField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      style: TextStyle(color: isDark ? textDark : Colors.black),
                      decoration: buildInputDecoration("Email", _emailFocus),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // pass
                  Focus(
                    onFocusChange: (_) => setState(() {}),
                    child: TextField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: true,
                      style: TextStyle(color: isDark ? textDark : Colors.black),
                      decoration: buildInputDecoration(
                        "Password",
                        _passwordFocus,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // google signin
                  MouseRegion(
                    onEnter: (_) => setState(() => _isGoogleHovered = true),
                    onExit: (_) => setState(() => _isGoogleHovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: ElevatedButton.icon(
                        onPressed: () {},
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
                          "Sign in with Google",
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
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "Or",
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.black87,
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: ElevatedButton.icon(
                        onPressed: () {},
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
                          Icons.mail_outline,
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
                  ),
                  const SizedBox(height: 24),

                  MouseRegion(
                    onEnter: (_) => setState(() => _isSignUpHovered = true),
                    onExit: (_) => setState(() => _isSignUpHovered = false),
                    child: Column(
                      children: [
                        Text.rich(
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
                      ],
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
    );
  }
}
