import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'edit_profile_bottom_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
      await _uploadToCloudinary(_profileImage!);
    }
  }

  Future<void> _uploadToCloudinary(File image) async {
    const cloudName = "doturqykw";
    const uploadPreset = "profileImageAid";
    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
    );

    try {
      setState(() => _isUploading = true);

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', image.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(await response.stream.bytesToString());
        final imageUrl = jsonResponse['secure_url'];

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'profileImage': imageUrl,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

          setState(() {
            _uploadedImageUrl = imageUrl;
            _profileImage = null;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Profile photo updated successfully!'),
              ),
            );
          }
        }
      } else {
        debugPrint("❌ Cloudinary upload failed: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Please try again.')),
        );
      }
    } catch (e) {
      debugPrint("⚠️ Cloudinary upload error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _removeProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'profileImage': FieldValue.delete(),
    });

    setState(() {
      _uploadedImageUrl = null;
      _profileImage = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile photo removed.')));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    final userId = user.uid;
    final width = MediaQuery.of(context).size.width;
    final isLarge = width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
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

            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final fullName = data['fullName'] ?? 'User';
            final city = data['city'] ?? 'Unknown City';
            final bio =
                data['bio'] ??
                'No bio available. Add something about yourself!';
            final profileUrl =
                _uploadedImageUrl ??
                (data['profileImage'] ?? '') as String? ??
                '';
            final interests =
                (data['interests'] as List<dynamic>?)?.cast<String>() ?? [];
            final earnings = data['earnings'] ?? 0;
            final totalWalksFuture = FirebaseFirestore.instance
                .collection('accepted_walks')
                .where('walkerId', isEqualTo: userId)
                .get();
            final role = data['role'] ?? "Walker";

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
                            backgroundImage: profileUrl.isNotEmpty
                                ? NetworkImage(profileUrl)
                                : const NetworkImage(
                                    "https://cdn-icons-png.flaticon.com/512/3135/3135715.png",
                                  ),
                            backgroundColor: Colors.grey.shade300,
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: _isUploading ? null : _pickImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: _isUploading
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.edit,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (profileUrl.isNotEmpty)
                                  InkWell(
                                    onTap: _removeProfileImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
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
                      ),
                      Text(
                        city,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('accepted_walks')
                                .where('walkerId', isEqualTo: userId)
                                .get(),
                            builder: (context, snapshot) {
                              int totalWalks = 0;
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Expanded(
                                  child: _buildStatCard("Total Walks", "..."),
                                );
                              }
                              if (snapshot.hasData) {
                                totalWalks = snapshot.data!.docs.length;
                              }
                              return Expanded(
                                child: _buildStatCard(
                                  "Total Walks",
                                  totalWalks.toString(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              role == "Walker"
                                  ? "Total Earnings"
                                  : "Total Impact",
                              "₹${(earnings ?? 0).toDouble().toStringAsFixed(2)}",
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
                        textAlign: TextAlign.center,
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
                                  .map((i) => _InterestChip(i))
                                  .toList(),
                            ),

                      const SizedBox(height: 24),
                      _buildSettingsList(context, data),
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

  Widget _buildStatCard(String title, String value) => Expanded(
    child: Container(
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
          Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
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
    ),
  );

  Widget _buildSectionTitle(String title) => Padding(
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

  Widget _buildSettingsList(
    BuildContext context,
    Map<String, dynamic> userData,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _buildSettingsItem(Icons.edit, "Edit Profile", Colors.grey, () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => EditProfileBottomSheet(userData: userData),
            );
          }),
          Divider(color: Colors.grey.shade300, height: 1),
          _buildSettingsItem(Icons.logout, "Log Out", Colors.red, () {
            _showLogoutDialog(context);
          }),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) => ListTile(
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.logout, color: Colors.green),
            SizedBox(width: 8),
            Text(
              "Confirm Logout",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No", style: TextStyle(color: Colors.green)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Yes", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
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
