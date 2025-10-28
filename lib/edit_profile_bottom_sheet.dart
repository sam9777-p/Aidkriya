import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileBottomSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfileBottomSheet({super.key, required this.userData});

  @override
  State<EditProfileBottomSheet> createState() => _EditProfileBottomSheetState();
}

class _EditProfileBottomSheetState extends State<EditProfileBottomSheet> {
  late TextEditingController _nameController;
  late TextEditingController _cityController;
  late TextEditingController _bioController;
  late TextEditingController _interestsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['fullName'] ?? '');
    _cityController = TextEditingController(text: widget.userData['city'] ?? '');
    _bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    _interestsController = TextEditingController(
      text: (widget.userData['interests'] as List<dynamic>?)?.join(', ') ?? '',
    );
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final interestsList = _interestsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fullName': _nameController.text.trim(),
      'city': _cityController.text.trim(),
      'bio': _bioController.text.trim(),
      'interests': interestsList,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF112117) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Container(
        color: bgColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Edit Profile",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 12),
            _buildTextField("Full Name", _nameController, textColor),
            _buildTextField("City", _cityController, textColor),
            _buildTextField("Bio", _bioController, textColor, maxLines: 2),
            _buildTextField("Interests (comma-separated)", _interestsController, textColor),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, Color textColor,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.green),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}