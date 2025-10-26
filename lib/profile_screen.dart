import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final width = MediaQuery.of(context).size.width;
    final isLarge = width > 600;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF112117)
          : const Color(0xFFF6F8F7),
      body: SafeArea(
        child: userId == null
            ? const Center(child: Text("User not logged in"))
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(child: Text("No profile data found."));
                  }

                  final data =
                      snapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final fullName = data['fullName'] ?? 'User';
                  final city = data['city'] ?? 'Unknown City';
                  final bio =
                      data['bio'] ??
                      'No bio available. Add something about yourself!';
                  final interests =
                      (data['interests'] as List<dynamic>?)?.cast<String>() ??
                      [];

                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 700),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: isLarge ? 80 : 64,
                                  backgroundImage: _profileImage != null
                                      ? FileImage(_profileImage!)
                                      : const NetworkImage(
                                              "https://lh3.googleusercontent.com/aida-public/AB6AXuAz1n15Gug5zzJVl0BGHMzGhrhRGSSoIH6elOScsq4N7NCeMi81nwXatTPqS7JuCf7te2LQI2-L_NShWCYwEYXjwCZr9EDnQAlG4DohiyUec_yZGP54RTjdRwzGvo55vs73WbfwvFpEZEhgK-rjw4qQK8oh6W-nbIPeNQYGBRvg0cHbwDlM_H5pgkXU_ZVWq_V-gWKiuez86dSmWvetPzBuSuW0EOjYWovYPUdf39fCdFTUmxYY8UBOyaxYnLLWar8Mco1hEUh-oxA",
                                            )
                                            as ImageProvider,
                                  backgroundColor: Colors.grey.shade300,
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: InkWell(
                                    onTap: _pickImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              city,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Flex(
                              direction: isLarge
                                  ? Axis.horizontal
                                  : Axis.horizontal,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: _buildStatCard("Total Walks", "128"),
                                ),
                                const SizedBox(width: 12, height: 12),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: _buildStatCard(
                                    "Total Impact",
                                    "256 hrs",
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildSectionTitle("About"),
                            Text(
                              bio,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionTitle("Interests"),
                            interests.isEmpty
                                ? const Text(
                                    "No interests added.",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: interests
                                        .map(
                                          (interest) => _InterestChip(interest),
                                        )
                                        .toList(),
                                  ),
                            const SizedBox(height: 24),
                            _buildSettingsList(context),
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

  Widget _buildStatCard(String title, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _buildSettingsItem(Icons.edit, "Edit Profile", Colors.grey, () {}),
          _divider(),
          _buildSettingsItem(Icons.settings, "Settings", Colors.grey, () {}),
          _divider(),
          _buildSettingsItem(Icons.logout, "Log Out", Colors.red, () {}),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: color == Colors.red ? Colors.red : Colors.black87,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade500),
    );
  }

  Widget _divider() => Divider(color: Colors.grey.shade300, height: 1);
}

class _InterestChip extends StatelessWidget {
  final String label;
  const _InterestChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.green,
        ),
      ),
      backgroundColor: Colors.green.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }
}
