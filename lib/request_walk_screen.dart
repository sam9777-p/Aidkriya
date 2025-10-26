import 'package:flutter/material.dart';

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

  // Walk details data
  String selectedDate = 'May 20, 2024';
  String selectedTime = '3:00 PM';
  String selectedDuration = 'Select duration';
  String selectedPace = 'Leisurely';
  String selectedLocation = 'Your Location';

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
                value: selectedDate,
                onTap: () => _onDateTapped(),
              ),
              const Divider(height: 32),
              WalkDetailItem(
                icon: Icons.access_time,
                label: 'Time',
                value: selectedTime,
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
        onPressed: _onSendRequestPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6BCBA6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: const Text(
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

  void _onPaceTapped() {
    print('Select pace');
    // Show pace options
  }

  void _onLocationTapped() {
    print('Select location');
    // Show location picker
  }

  void _onSendRequestPressed() {
    print('Send walk request to ${widget.walker.name}');
    // Send request to API
    // Show confirmation dialog
  }
}
