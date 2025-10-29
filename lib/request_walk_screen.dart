import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'backend/walk_request_service.dart';
import 'components/duration_minute_picker.dart';
import 'components/walk_detail_item.dart';
import 'components/walker_profile_card.dart';
import 'model/Walker.dart';
import 'model/user_model.dart'; // Import UserModel

class RequestWalkScreen extends StatefulWidget {
  final Walker walker; // Walker being requested

  const RequestWalkScreen({Key? key, required this.walker}) : super(key: key);

  @override
  State<RequestWalkScreen> createState() => _RequestWalkScreenState();
}

class _RequestWalkScreenState extends State<RequestWalkScreen> {
  // Use the new service
  final WalkRequestService _walkRequestService = WalkRequestService();
  final String? _currentUserId =
      FirebaseAuth.instance.currentUser?.uid; // Get current user ID

  String _currentTime = '';
  String _currentDate = '';
  Position? _currentPosition;
  bool _isSending = false;

  // [NEW] State for current user profile data (needed for 'senderInfo')
  UserModel? _currentUserProfile;

  // Walk details data
  DateTime _selectedDateTime =
  DateTime.now(); // Store as DateTime for easier use
  String selectedDuration = 'Select duration';
  int? _selectedDurationMinutes; // Store the raw minutes
  String selectedLocation = 'Your Location';

  @override
  void initState() {
    super.initState();
    _updateDisplayedDateTime();
    _getCurrentLocation();
    _fetchCurrentUserProfile(); // [NEW] Fetch profile data
  }

  // [NEW] Function to fetch the current user's profile
  Future<void> _fetchCurrentUserProfile() async {
    if (_currentUserId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId!)
            .get();
        if (doc.exists) {
          setState(() {
            _currentUserProfile = UserModel.fromMap(doc.data()!);
            debugPrint("[RequestWalkScreen] Current user profile loaded.");
          });
        }
      } catch (e) {
        debugPrint("[RequestWalkScreen] Error fetching user profile: $e");
        // Fallback to minimal placeholder profile in case of fetch failure
        _currentUserProfile = UserModel(
            fullName: 'Wanderer User',
            age: 0, city: '', bio: '', phone: '', interests: [],
            rating: 5, imageUrl: '', walks: 0, earnings: 0
        );
      }
    }
  }

  void _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar(
          'Location permissions are permanently denied, we cannot request permissions.',
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        selectedLocation = "Current Location"; // Update display text
        debugPrint(
          "[RequestWalkScreen] Current Location obtained: ${position.latitude}, ${position.longitude}",
        );
      });
    } catch (e) {
      debugPrint("[RequestWalkScreen] Error getting location: $e");
      _showErrorSnackBar('Could not get current location.');
      setState(() {
        selectedLocation = "Location Unknown";
      });
    }
  }

  void _updateDisplayedDateTime() {
    // Format date like "October 27, 2025"
    _currentDate = DateFormat('MMMM d, yyyy').format(_selectedDateTime);
    // Format time like "11:10 PM"
    _currentTime = DateFormat('h:mm a').format(_selectedDateTime);
    setState(() {});
  }

  // --- Date Picker (Example) ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(), // Allow selection from today onwards
      lastDate: DateTime.now().add(
        const Duration(days: 30),
      ), // Allow up to 30 days in advance
    );
    if (picked != null && picked != _selectedDateTime) {
      setState(() {
        // Keep the time, change the date
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
        _updateDisplayedDateTime();
      });
    }
  }

  // --- Time Picker (Example) ---
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null) {
      setState(() {
        // Keep the date, change the time
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
        _updateDisplayedDateTime();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWalkerProfileCard(),
            const SizedBox(height: 32),
            _buildWalkDetailsSection(),
            const SizedBox(height: 32),
            _buildSendRequestButton(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF5F5F5),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Request a Walk',
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false, // Align title to the start
    );
  }

  Widget _buildWalkerProfileCard() {
    return WalkerProfileCard(
      walker: widget.walker,
      onTap: () => _onProfileTapped(),
    );
  }

  Widget _buildWalkDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Walk Details',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              WalkDetailItem(
                icon: Icons.calendar_today,
                label: 'Date',
                value: _currentDate,
                onTap: () => _selectDate(context), // Use Date Picker
              ),
              const Divider(height: 32),
              WalkDetailItem(
                icon: Icons.access_time,
                label: 'Time',
                value: _currentTime,
                onTap: () => _selectTime(context), // Use Time Picker
              ),
              const Divider(height: 32),
              WalkDetailItem(
                icon: Icons.hourglass_empty,
                label: 'Duration',
                value: selectedDuration,
                onTap: () => _onDurationTapped(),
              ),
              const Divider(height: 32),
              WalkDetailItem(
                icon: Icons.location_on,
                label: 'Location',
                value: selectedLocation,
                onTap: () => _onLocationTapped(),
              ),
              const Divider(height: 32),
              // Add Notes Field (Optional)
              TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.note_add_outlined, color: Colors.grey[600]),
                  hintText: 'Add optional notes for the walker...',
                  border: InputBorder.none,
                ),
                maxLines: 2,
                // controller: _notesController, // Add a TextEditingController if needed
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSendRequestButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        // [MODIFIED] Check that _currentUserProfile is also available
        onPressed:
        _isSending ||
            _currentUserId == null ||
            _currentUserProfile == null // Check if profile data is loaded
            ? null
            : _onSendRequestPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6BCBA6),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400], // Indicate disabled state
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: _isSending
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        )
            : const Text(
          'Send Request',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // --- UI Action Callbacks ---

  void _onProfileTapped() {
    debugPrint('[RequestWalkScreen] Profile tapped: ${widget.walker.name}');
    // Navigate to walker profile if needed
  }

  void _onDurationTapped() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const DurationMinutePicker(),
    );

    if (result != null) {
      setState(() {
        _selectedDurationMinutes = result;
        selectedDuration = '$result min'; // Update display string
        debugPrint("[RequestWalkScreen] Duration selected: $result minutes");
      });
    }
  }

  void _onLocationTapped() {
    debugPrint(
      '[RequestWalkScreen] Location tapped. Current: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}',
    );
    // Show location picker or map view if needed
    // For now, it just uses the current location determined in initState
    if (_currentPosition == null) {
      _showErrorSnackBar("Still trying to get your location...");
      _getCurrentLocation(); // Attempt to get it again
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Meeting point set to your current location."),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // --- Send Request Logic ---

  void _onSendRequestPressed() async {
    debugPrint("[RequestWalkScreen] Send Request button pressed.");
    // --- Validation ---
    if (_currentUserId == null) {
      _showErrorSnackBar("You must be logged in to send a request.");
      debugPrint("[RequestWalkScreen] Aborted: User not logged in.");
      return;
    }
    if (_selectedDurationMinutes == null ||
        selectedDuration == 'Select duration') {
      _showErrorSnackBar('Please select a duration for the walk.');
      debugPrint("[RequestWalkScreen] Aborted: Duration not selected.");
      return;
    }
    if (_currentPosition == null) {
      _showErrorSnackBar(
        'Could not get your location. Please check permissions and try again.',
      );
      debugPrint("[RequestWalkScreen] Aborted: Current position is null.");
      _getCurrentLocation(); // Try getting location again
      return;
    }
    // [NEW CHECK] Ensure profile data is available for notification payload
    if (_currentUserProfile == null) {
      _showErrorSnackBar(
        'User profile data is still loading. Please wait a moment.',
      );
      debugPrint("[RequestWalkScreen] Aborted: User profile is null.");
      _fetchCurrentUserProfile();
      return;
    }


    setState(() => _isSending = true); // Start loading indicator

    // --- Prepare Request Data ---
    final requestMap = {
      'senderId': _currentUserId!,
      'recipientId': widget.walker.id, // The ID of the walker profile shown
      'walkerProfile': widget.walker
          .toMap(), // Include selected walker's details
      'date': _currentDate, // Use the formatted date string
      'time': _currentTime, // Use the formatted time string
      'duration': selectedDuration, // e.g., "45 min"
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
      'status':
      'Pending', // Initial status set by service, but good practice here too
      'notes': null, // Get from _notesController if you add one
      'createdAt': FieldValue.serverTimestamp(), // Set by service
      'updatedAt': FieldValue.serverTimestamp(), // Set by service
      // [FIX] Sender Info block now guaranteed to be present if validation passes
      'senderInfo': {
        'fullName': _currentUserProfile!.fullName,
        'imageUrl': _currentUserProfile!.imageUrl,
      },
    };

    debugPrint("[RequestWalkScreen] Prepared request data: $requestMap");

    // --- Call Service ---
    try {
      final String? walkId = await _walkRequestService.sendRequest(requestMap);

      if (walkId != null) {
        debugPrint(
          "[RequestWalkScreen] Request sent successfully. Walk ID: $walkId",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Walk request sent successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          // Optionally navigate back or reset the form
          Navigator.pop(context); // Go back after successful request
        }
      } else {
        // This path is hit if the Firestore write succeeds but the server HTTP call fails,
        // causing the exception to bubble up and be caught by the outer block.
        throw Exception("Service returned null ID.");
      }
    } catch (error) {
      // The error is a generic catch-all for any exception during the request process.
      debugPrint("[RequestWalkScreen] Failed to send request with ERROR: $error");
      if (mounted) {
        _showErrorSnackBar('Failed to send request: Check network connection and server URL.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false); // Stop loading indicator
      }
    }
  }

  // --- Helper for SnackBar ---
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}