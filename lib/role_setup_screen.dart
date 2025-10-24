import 'package:flutter/material.dart';

class RoleSetupScreen extends StatefulWidget {
  const RoleSetupScreen({super.key});

  @override
  State<RoleSetupScreen> createState() => _RoleSetupScreenState();
}

class _RoleSetupScreenState extends State<RoleSetupScreen> {
  String? _selectedRole;

  void _onContinue() {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a role to continue.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected Role: $_selectedRole')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFFA8D8B9);
    final accent = const Color(0xFFE0F2E9);
    final backgroundDark = const Color(0xFF112117);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? backgroundDark : Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            final horizontalPadding = isWide ? 48.0 : 16.0;
            final contentMaxWidth = isWide ? 480.0 : double.infinity;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),

                      const SizedBox(height: 20),
                      const Text(
                        'How would you like to make a difference?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 28),


                      _buildRoleCard(
                        title: 'Walker (Companion)',
                        icon: Icons.groups_2,
                        description:
                        'Help others walk safely and stay active\n• Earn while helping others\n• Build meaningful connections\n• Contribute to social causes',
                        selected: _selectedRole == 'Walker',
                        onTap: () {
                          setState(() => _selectedRole = 'Walker');
                        },
                        accent: accent,
                        primary: primary,
                      ),
                      const SizedBox(height: 20),
                      _buildRoleCard(
                        title: 'Wanderer (User)',
                        icon: Icons.favorite_outline,
                        description:
                        'Find a walking companion and stay safe\n• Walk with verified companions\n• Feel safe and supported\n• Make every step count',
                        selected: _selectedRole == 'Wanderer',
                        onTap: () {
                          setState(() => _selectedRole = 'Wanderer');
                        },
                        accent: accent,
                        primary: primary,
                      ),

                      const SizedBox(height: 36),
                      ElevatedButton(
                        onPressed: _onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required IconData icon,
    required String description,
    required bool selected,
    required VoidCallback onTap,
    required Color accent,
    required Color primary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? primary.withOpacity(0.2) : accent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: selected ? primary : accent,
              child: Icon(
                icon,
                color: selected ? Colors.white : primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
