import 'package:aidkriya_walker/backend/walk_request_service.dart';
import 'package:aidkriya_walker/model/walk_request.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'components/duration_minute_picker.dart';
import 'components/walk_detail_item.dart';
import 'components/walker_profile_card.dart';
import 'model/Walker.dart';

class RequestWalkScreen extends StatefulWidget {
  final Walker walker;

  const RequestWalkScreen({Key? key, required this.walker}) : super(key: key);

  @override
  State<RequestWalkScreen> createState() => _RequestWalkScreenState();
}

class _RequestWalkScreenState extends State<RequestWalkScreen> {
  int _currentIndex = 1;
  String _currentTime = '';
  String _currentDate = '';
  Position? _currentPosition;
  bool _isSending = false;
  final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  // Walk details data
  String selectedDate = 'May 20, 2024';
  String selectedTime = '3:00 PM';
  String selectedDuration = 'Select duration';
  String selectedPace = 'Leisurely';
  String selectedLocation = 'Your Location';

  final List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    _setCurrentDateTime();
    _getCurrentLocation();
    super.initState();
  }

  void _getCurrentLocation() async {
    // Get the current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = position;
    });
  }

  void _setCurrentDateTime() {
    DateTime now = DateTime.now();

    // Format date like "May 20, 2024"
    String month = months[now.month - 1];
    _currentDate = "$month ${now.day}, ${now.year}";

    // Format time like "3:00 PM"
    int hour = now.hour;
    String period = hour >= 12 ? "PM" : "AM";
    hour = hour % 12;
    if (hour == 0) hour = 12;
    String minute = now.minute.toString().padLeft(2, '0');
    _currentTime = "$hour:$minute $period";

    setState(() {});
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
      centerTitle: false,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Walk Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
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
                onTap: () => _onDateTapped(),
              ),
              const Divider(height: 32),
              WalkDetailItem(
                icon: Icons.access_time,
                label: 'Time',
                value: _currentTime,
                onTap: () => _onTimeTapped(),
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
        onPressed: _isSending
            ? null
            : _onSendRequestPressed, // disable while sending
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6BCBA6),
          foregroundColor: Colors.white,
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

  // Callback methods
  void _onProfileTapped() {
    print('Profile tapped: ${widget.walker.name}');
    // Navigate to walker profile
  }

  void _onEditPressed() {
    print('Edit walk details');
    // Open edit mode or dialog
  }

  void _onDateTapped() {
    print('Select date');
    // Show date picker
  }

  void _onTimeTapped() {
    print('Select time');
    // Show time picker
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
        selectedDuration = '$result minutes';
      });
    }
  }

  void _onLocationTapped() {
    print('Select location');
    // Show location picker
  }

  void _onSendRequestPressed() async {
    if (selectedDuration == 'Select duration') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a duration for the walk.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your location. Please try again.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true; // start loading
    });

    final req_service = WalkRequestService();
    final req_data = WalkRequest(
      id: userId,
      longitude: _currentPosition!.longitude,
      latitude: _currentPosition!.latitude,
      date: _currentDate,
      time: _currentTime,
      duration: selectedDuration,
      status: 'Pending',
      walker: widget.walker,
      notes: null,
    );

    try {
      await req_service.sendRequest(req_data, userId, widget.walker.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Walk request sent successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      setState(() {
        selectedDuration = 'Select duration'; // reset duration
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send request: $error'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isSending = false; // stop loading
      });
    }
  }
}
