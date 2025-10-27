import 'package:aidkriya_walker/backend/walk_request_service.dart';
import 'package:aidkriya_walker/model/walk_request.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../components/date_chip.dart';
import '../components/option_chip.dart';
import '../components/time_chip.dart';
import '../components/walker_selection_card.dart';
import 'Walker.dart';

class ScheduleWalkScreen extends StatefulWidget {
  final Walker? preselectedWalker;
  final List<Walker> availableWalkers;

  const ScheduleWalkScreen({
    Key? key,
    this.preselectedWalker,
    required this.availableWalkers,
  }) : super(key: key);

  @override
  State<ScheduleWalkScreen> createState() => _ScheduleWalkScreenState();
}

class _ScheduleWalkScreenState extends State<ScheduleWalkScreen> {
  bool _isLoading = false;
  int _currentIndex = 1;
  late List<DateTime> availableDates;
  late List<TimeOfDay> availableTimes;
  Position? _currentPosition;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String selectedDuration = '45 min';
  String selectedPace = 'Moderate';
  Walker? selectedWalker;
  final TextEditingController _locationController = TextEditingController();

  final WalkRequestService _walkService = WalkRequestService();

  @override
  void initState() {
    super.initState();
    _generateAvailableDates();
    _generateAvailableTimes();
    _getCurrentLocation();
    selectedWalker = widget.preselectedWalker ?? widget.availableWalkers[0];
    if (availableDates.isNotEmpty) selectedDate = availableDates[0];
    if (availableTimes.isNotEmpty) selectedTime = availableTimes[0];
  }

  void _generateAvailableDates() {
    availableDates = [];
    final today = DateTime.now();
    for (int i = 0; i < 5; i++) {
      availableDates.add(today.add(Duration(days: i)));
    }
  }

  void _generateAvailableTimes() {
    availableTimes = [];
    final now = DateTime.now();

    int startHour = 9;
    int endHour = 18;

    // If the selected date is today, skip past times
    if (selectedDate != null && _isSameDay(selectedDate!, now)) {
      // Start from next half-hour or hour slot
      int nextHour = now.minute < 30 ? now.hour : now.hour + 1;
      int nextMinute = now.minute < 30 ? 30 : 0;

      // Only show times after the current time
      DateTime nextAvailableTime = DateTime(
        now.year,
        now.month,
        now.day,
        nextHour,
        nextMinute,
      );

      while (nextAvailableTime.hour < endHour) {
        availableTimes.add(
          TimeOfDay(
            hour: nextAvailableTime.hour,
            minute: nextAvailableTime.minute,
          ),
        );

        nextAvailableTime = nextAvailableTime.add(const Duration(minutes: 30));
      }
    } else {
      // Future days: show all times from 9 AM to 6 PM
      for (int hour = startHour; hour < endHour; hour++) {
        availableTimes.add(TimeOfDay(hour: hour, minute: 0));
        availableTimes.add(TimeOfDay(hour: hour, minute: 30));
      }
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) =>
      date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
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
            _buildDateTimeSection(),
            const SizedBox(height: 32),
            _buildWalkerSection(),
            const SizedBox(height: 32),
            _buildWalkPreferencesSection(),
            const SizedBox(height: 32),
            _buildMeetingPointSection(),
            const SizedBox(height: 24),
            _buildSummary(),
            const SizedBox(height: 24),
            _buildConfirmButton(),
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
        'Schedule a Walk',
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date & Time',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildDateSelector(),
        const SizedBox(height: 16),
        _buildTimeSelector(),
      ],
    );
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: availableDates.length,
        itemBuilder: (context, index) {
          final date = availableDates[index];
          final isSelected =
              selectedDate != null && _isSameDay(date, selectedDate!);
          return DateChip(
            date: date,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                selectedDate = date;
                _generateAvailableTimes();
                if (availableTimes.isNotEmpty) selectedTime = availableTimes[0];
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildTimeSelector() {
    if (availableTimes.isEmpty) {
      return Center(
        child: Text(
          'No available times for selected date',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: availableTimes.map((time) {
        final isSelected =
            selectedTime?.hour == time.hour &&
            selectedTime?.minute == time.minute;
        return TimeChip(
          time: time,
          isSelected: isSelected,
          onTap: () => setState(() => selectedTime = time),
        );
      }).toList(),
    );
  }

  Widget _buildWalkerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a Walker',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...widget.availableWalkers.map((walker) {
          final isSelected = selectedWalker?.id == walker.id;
          return WalkerSelectionCard(
            walker: walker,
            isSelected: isSelected,
            onTap: () => setState(() => selectedWalker = walker),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildWalkPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Walk Preferences',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Duration',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: ['30 min', '45 min', '60 min'].map((duration) {
            return OptionChip(
              label: duration,
              isSelected: selectedDuration == duration,
              onTap: () => setState(() => selectedDuration = duration),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMeetingPointSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meeting Point',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text(
              'Your Location',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    if (selectedDate == null ||
        selectedTime == null ||
        selectedWalker == null) {
      return const SizedBox.shrink();
    }

    final dateStr = DateFormat('EEE, MMM d').format(selectedDate!);
    final timeStr = selectedTime!.format(context);
    final walkerFirstName = selectedWalker!.name?.split(' ')[0];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'A $selectedDuration $selectedPace walk with $walkerFirstName on $dateStr at $timeStr.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onConfirmWalk, // disable while loading
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00E676),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Confirm Walk',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  /// ✅ Confirm walk -> save to Firestore
  Future<void> _onConfirmWalk() async {
    if (selectedDate == null ||
        selectedTime == null ||
        selectedWalker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
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

    setState(() => _isLoading = true); // show loader

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final formattedDate = DateFormat('MMM dd, yyyy').format(selectedDate!);
      final formattedTime = selectedTime!.format(context); // "3:00 PM" format

      final walkRequest = WalkRequest(
        id: userId,
        walker: selectedWalker!,
        date: formattedDate,
        time: formattedTime,
        duration: selectedDuration,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        notes: null,
        status: 'Pending',
      );

      await _walkService.sendRequest(
        walkRequest,
        userId,
        walkRequest.walker.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Walk request sent successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send request: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false); // hide loader
    }
  }
}
