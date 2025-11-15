import 'package:aidkriya_walker/backend/walk_request_service.dart';
import 'package:aidkriya_walker/model/user_model.dart';
import 'package:aidkriya_walker/screens/location_picker_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // <-- IMPORT THIS
import 'package:intl/intl.dart';

import 'components/date_chip.dart';
import 'components/option_chip.dart';
import 'components/time_chip.dart';
import 'components/walker_selection_card.dart';
import 'model/Walker.dart';

class ScheduleWalkScreen extends StatefulWidget {
  final Walker? preselectedWalker; // Preselected Walker (optional)
  final List<Walker> availableWalkers; // List of walkers to choose from

  const ScheduleWalkScreen({
    Key? key,
    this.preselectedWalker,
    required this.availableWalkers,
  }) : super(key: key);

  @override
  State<ScheduleWalkScreen> createState() => _ScheduleWalkScreenState();
}

class _ScheduleWalkScreenState extends State<ScheduleWalkScreen> {
  // New service instance
  final WalkRequestService _walkService = WalkRequestService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State variables
  bool _isLoading = false; // For the confirm button loader
  late List<DateTime> availableDates;
  late List<TimeOfDay> availableTimes;
  Position? _currentPosition;
  LatLng? _selectedMeetingPoint; // <-- ADD THIS
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String selectedDuration = '45 min'; // Default duration
  // String selectedPace = 'Moderate'; // Not currently used in request data
  Walker? selectedWalker; // The chosen walker
  UserModel?
  _currentUserProfile; // To store sender's profile for denormalization

  @override
  void initState() {
    super.initState();
    _generateAvailableDates(); // Generate dates first
    selectedDate = availableDates.isNotEmpty
        ? availableDates[0]
        : null; // Set initial date
    _generateAvailableTimes(); // Generate times based on initial date
    selectedTime = availableTimes.isNotEmpty
        ? availableTimes[0]
        : null; // Set initial time

    _getCurrentLocation();
    _fetchCurrentUserProfile(); // Fetch sender profile

    // Set initial selected walker
    if (widget.preselectedWalker != null) {
      selectedWalker = widget.preselectedWalker;
    } else if (widget.availableWalkers.isNotEmpty) {
      selectedWalker = widget.availableWalkers[0];
    }
  }

  /// Fetches the current user's profile for denormalization (senderInfo).
  Future<void> _fetchCurrentUserProfile() async {
    if (_currentUserId != null) {
      try {
        final doc = await _firestore
            .collection('users')
            .doc(_currentUserId!)
            .get();
        if (doc.exists) {
          setState(() {
            _currentUserProfile = UserModel.fromMap(doc.data()!);
            debugPrint(
              "[ScheduleWalkScreen] Current user profile loaded: ${_currentUserProfile?.fullName}",
            );
          });
        } else {
          debugPrint(
            "[ScheduleWalkScreen] Warning: Current user profile not found in Firestore.",
          );
        }
      } catch (e) {
        debugPrint(
          "[ScheduleWalkScreen] Error fetching current user profile: $e",
        );
      }
    }
  }

  /// Generates a list of dates (e.g., next 5 days) for selection.
  void _generateAvailableDates() {
    availableDates = [];
    final today = DateTime.now();
    for (int i = 0; i < 7; i++) {
      // Show next 7 days
      availableDates.add(
        DateTime(today.year, today.month, today.day).add(Duration(days: i)),
      );
    }
    debugPrint(
      "[ScheduleWalkScreen] Generated available dates: $availableDates",
    );
  }

  /// Generates available time slots (e.g., 9 AM - 6 PM, every 30 mins).
  /// Adjusts based on the selected date (skips past times for today).
  void _generateAvailableTimes() {
    availableTimes = [];
    final now = DateTime.now();
    final TimeOfDay nowTime = TimeOfDay.fromDateTime(now);

    const int startHour = 9;
    const int endHour = 18; // Up to 6 PM

    // Check if the selected date is today
    bool isToday =
        selectedDate != null &&
        selectedDate!.year == now.year &&
        selectedDate!.month == now.month &&
        selectedDate!.day == now.day;

    for (int hour = startHour; hour < endHour; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        // 30-minute intervals
        final timeSlot = TimeOfDay(hour: hour, minute: minute);

        // If today, only add times that are in the future
        if (isToday) {
          final slotHour = timeSlot.hour;
          final slotMinute = timeSlot.minute;
          final currentHour = nowTime.hour;
          final currentMinute = nowTime.minute;

          // Compare times: add if slot is later than current time
          if (slotHour > currentHour ||
              (slotHour == currentHour && slotMinute > currentMinute)) {
            availableTimes.add(timeSlot);
          }
        } else {
          // If not today, add all time slots within the range
          availableTimes.add(timeSlot);
        }
      }
    }
    debugPrint(
      "[ScheduleWalkScreen] Generated available times for selected date: $availableTimes",
    );

    // If the previously selected time is no longer valid for the new date, reset it
    if (selectedTime != null &&
        !availableTimes.any(
          (t) =>
              t.hour == selectedTime!.hour && t.minute == selectedTime!.minute,
        )) {
      selectedTime = availableTimes.isNotEmpty ? availableTimes.first : null;
      debugPrint(
        "[ScheduleWalkScreen] Reset selected time as previous was invalid for new date.",
      );
    }
  }

  /// Gets the current geographical position of the device.
  void _getCurrentLocation() async {
    debugPrint("[ScheduleWalkScreen] Attempting to get current location...");
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
        _showErrorSnackBar('Location permissions are permanently denied.');
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          // --- [MODIFIED] ---
          // Set the default meeting point to the user's current location
          _selectedMeetingPoint = LatLng(position.latitude, position.longitude);
          // --- [END MODIFIED] ---
          debugPrint(
            "[ScheduleWalkScreen] Current Location obtained: ${position.latitude}, ${position.longitude}",
          );
        });
      }
    } catch (e) {
      debugPrint("[ScheduleWalkScreen] Error getting location: $e");
      if (mounted) {
        _showErrorSnackBar('Could not get current location.');
      }
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
            _buildDateTimeSection(),
            const SizedBox(height: 32),
            _buildWalkerSection(),
            const SizedBox(height: 32),
            _buildWalkPreferencesSection(),
            const SizedBox(height: 32),
            _buildMeetingPointSection(), // <-- This widget is now updated
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
      height: 100, // Fixed height for date chips
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: availableDates.length,
        itemBuilder: (context, index) {
          final date = availableDates[index];
          final isSelected =
              selectedDate != null &&
              date.year == selectedDate!.year &&
              date.month == selectedDate!.month &&
              date.day == selectedDate!.day;

          return DateChip(
            date: date,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                selectedDate = date;
                _generateAvailableTimes(); // Regenerate times for the new date
                // Optionally reset time or select the first available
                selectedTime = availableTimes.isNotEmpty
                    ? availableTimes.first
                    : null;
                debugPrint("[ScheduleWalkScreen] Date selected: $selectedDate");
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildTimeSelector() {
    if (availableTimes.isEmpty) {
      return Container(
        // Provide some height even when empty
        height: 50,
        alignment: Alignment.center,
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
            selectedTime != null &&
            selectedTime!.hour == time.hour &&
            selectedTime!.minute == time.minute;
        return TimeChip(
          time: time,
          isSelected: isSelected,
          onTap: () => setState(() {
            selectedTime = time;
            debugPrint("[ScheduleWalkScreen] Time selected: $selectedTime");
          }),
        );
      }).toList(),
    );
  }

  Widget _buildWalkerSection() {
    if (widget.availableWalkers.isEmpty) {
      return const SizedBox.shrink(); // Hide if no walkers passed
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a Walker',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // Create scrollable list if many walkers, otherwise just list them
        (widget.availableWalkers.length > 3)
            ? SizedBox(
                height: 120 * 3, // Adjust height based on card size
                child: ListView(
                  children: widget.availableWalkers.map((walker) {
                    final isSelected = selectedWalker?.id == walker.id;
                    return WalkerSelectionCard(
                      walker: walker,
                      isSelected: isSelected,
                      onTap: () => setState(() {
                        selectedWalker = walker;
                        debugPrint(
                          "[ScheduleWalkScreen] Walker selected: ${walker.name} (ID: ${walker.id})",
                        );
                      }),
                    );
                  }).toList(),
                ),
              )
            : Column(
                // If few walkers, just display them directly
                children: widget.availableWalkers.map((walker) {
                  final isSelected = selectedWalker?.id == walker.id;
                  return WalkerSelectionCard(
                    walker: walker,
                    isSelected: isSelected,
                    onTap: () => setState(() {
                      selectedWalker = walker;
                      debugPrint(
                        "[ScheduleWalkScreen] Walker selected: ${walker.name} (ID: ${walker.id})",
                      );
                    }),
                  );
                }).toList(),
              ),
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
          runSpacing: 12, // Allow wrapping if needed
          children: ['30 min', '45 min', '60 min', '90 min', '120 min'].map((
            duration,
          ) {
            return OptionChip(
              label: duration,
              isSelected: selectedDuration == duration,
              onTap: () => setState(() {
                selectedDuration = duration;
                debugPrint(
                  "[ScheduleWalkScreen] Duration selected: $selectedDuration",
                );
              }),
            );
          }).toList(),
        ),
        // Add Pace selection if needed later
        // const SizedBox(height: 16),
        // const Text(
        //   'Pace',
        //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        // ),
        // const SizedBox(height: 12),
        // Wrap(...)
      ],
    );
  }

  // --- [WIDGET MODIFIED] ---
  Widget _buildMeetingPointSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meeting Point',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(
            left: 16,
            top: 4,
            bottom: 4,
            right: 8,
          ), // Adjust padding for button
          decoration: BoxDecoration(
            color: Colors.white, // Use white for better contrast
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Colors.grey[600], size: 20),
              const SizedBox(width: 12),
              Expanded(
                // Show coordinates from _selectedMeetingPoint
                child: Text(
                  _selectedMeetingPoint != null
                      ? 'Lat: ${_selectedMeetingPoint!.latitude.toStringAsFixed(4)}, Lng: ${_selectedMeetingPoint!.longitude.toStringAsFixed(4)}'
                      : 'Fetching location...',
                  style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // --- ADD THIS BUTTON ---
              IconButton(
                icon: const Icon(
                  Icons.edit_location_alt_outlined,
                  color: Color(0xFF00E676),
                ),
                onPressed: _openLocationPicker,
                tooltip: 'Change Meeting Point',
              ),
              // --- END ADD ---
            ],
          ),
        ),
      ],
    );
  }

  // --- [NEW FUNCTION] ---
  /// Opens the location picker screen and updates the meeting point
  void _openLocationPicker() async {
    // We need a valid location to center the map
    if (_currentPosition == null && _selectedMeetingPoint == null) {
      _showErrorSnackBar("Still fetching your current location...");
      return;
    }

    // Use _selectedMeetingPoint as the initial, fallback to _currentPosition
    final LatLng initialPoint =
        _selectedMeetingPoint ??
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    final newLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LocationPickerScreen(initialLocation: initialPoint),
      ),
    );

    // After the picker screen returns a location, update the state
    if (newLocation != null && newLocation is LatLng) {
      setState(() {
        _selectedMeetingPoint = newLocation;
        debugPrint(
          "[ScheduleWalkScreen] New meeting point selected: $newLocation",
        );
      });
    }
  }

  Widget _buildSummary() {
    // Show summary only when all necessary parts are selected
    if (selectedDate == null ||
        selectedTime == null ||
        selectedWalker == null) {
      return const SizedBox.shrink(); // Don't show if incomplete
    }

    final dateStr = DateFormat('EEE, MMM d').format(selectedDate!);
    final timeStr = selectedTime!.format(context);
    final walkerFirstName = selectedWalker!.name?.split(' ').first ?? 'Walker';

    // --- [MODIFIED] ---
    // Change summary text to reflect custom location
    final locationText = _selectedMeetingPoint == _currentPosition
        ? "at your current location"
        : "at the selected meeting point";

    return Container(
      width: double.infinity, // Take full width
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100], // Subtle background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        'You are scheduling a $selectedDuration walk with $walkerFirstName on $dateStr at $timeStr, meeting $locationText.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
      ),
    );
  }

  // --- [MODIFIED] ---
  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        // Add _selectedMeetingPoint to the check
        onPressed:
            (_isLoading ||
                _currentUserId == null ||
                _selectedMeetingPoint == null || // <-- ADDED THIS CHECK
                selectedWalker == null ||
                _currentUserProfile == null)
            ? null
            : _onConfirmWalk,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(
            0xFF00E676,
          ), // Use a distinct confirm color
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 16,
          ), // Ensure consistent height
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
                'Confirm & Send Request',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  /// ✅ Handles the confirmation and sending of the walk request using the new service.
  /// ✅ CORRECTED _onConfirmWalk method for schedule_walk_screen.dart
  /// Replace your existing _onConfirmWalk method with this one
  Future<void> _onConfirmWalk() async {
    // --- Validation ---
    if (_currentUserId == null ||
        selectedWalker == null ||
        selectedDate == null ||
        selectedTime == null ||
        _selectedMeetingPoint ==
            null || // <-- [MODIFIED] Check _selectedMeetingPoint
        _currentUserProfile == null) {
      _showErrorSnackBar(
        'Please ensure all details are selected and location is available.',
      );
      debugPrint(
        "[ScheduleWalkScreen] Aborted Confirmation: Missing required data.",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- ⬇️ START: TEMPORARY HARDCODING FOR TESTING ⬇️ ---
      // This block overrides user selection and schedules the walk for 3 minutes from now.
      // debugPrint("!!!!!!!!!! -- TESTING OVERRIDE ENABLED -- !!!!!!!!!!");
      // final DateTime hardcodedDateTime = DateTime.now().add(
      //   const Duration(minutes: 3),
      // );
      // final String hardcodedDuration =
      //     '45 min'; // Or any duration you want to test
      //
      // // Override user-selected values
      // DateTime combinedDateTime = hardcodedDateTime;
      // final formattedDate = DateFormat('MMMM d, yyyy').format(combinedDateTime);
      // final formattedTime = DateFormat('h:mm a').format(combinedDateTime);
      // final String finalDuration = hardcodedDuration;
      //
      // debugPrint("Hardcoded Time: $formattedTime on $formattedDate");
      // debugPrint("Hardcoded Duration: $finalDuration");
      // debugPrint("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      // --- ⬆️ END: TEMPORARY HARDCODING FOR TESTING ⬆️ ---

      // --- ORIGINAL CODE (COMMENTED OUT FOR TESTING) ---

      // Create the DateTime object for the scheduled time
      DateTime combinedDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );
      // Format date and time for DISPLAY purposes only
      final formattedDate = DateFormat('MMMM d, yyyy').format(combinedDateTime);
      final formattedTime = DateFormat('h:mm a').format(combinedDateTime);
      final String finalDuration = selectedDuration;

      // --- END ORIGINAL CODE ---

      debugPrint("[ScheduleWalkScreen] Scheduled DateTime: $combinedDateTime");
      debugPrint("[ScheduleWalkScreen] Formatted Date: $formattedDate");
      debugPrint("[ScheduleWalkScreen] Formatted Time: $formattedTime");

      // ✅ CRITICAL FIX: Use Timestamp.fromDate() for scheduledTimestamp
      final requestData = {
        'senderId': _currentUserId!,
        'recipientId': selectedWalker!.id,
        'senderInfo': {
          'fullName': _currentUserProfile!.fullName,
          'imageUrl': _currentUserProfile!.imageUrl,
        },
        'walkerProfile': selectedWalker!.toMap(),
        'date': formattedDate, // ✅ Display format
        'time': formattedTime, // ✅ FIXED: Use actual formatted time
        'duration': finalDuration, // Use final (hardcoded or selected) duration
        // --- [MODIFIED] ---
        'latitude':
            _selectedMeetingPoint!.latitude, // <-- Use the chosen meeting point
        'longitude': _selectedMeetingPoint!
            .longitude, // <-- Use the chosen meeting point
        // --- [END MODIFIED] ---
        'status': 'Scheduled', // <-- This is the logic fix from before
        // ✅ CRITICAL: Store as Timestamp object, NOT string
        'scheduledTimestamp': Timestamp.fromDate(combinedDateTime),
        'notes': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      debugPrint(
        "[ScheduleWalkScreen] Sending request with Timestamp: ${Timestamp.fromDate(combinedDateTime)}",
      );

      // Call the service (this logic is from your previous fix, it is correct)
      final String? walkId = await _walkService.sendRequest(requestData);

      if (walkId != null) {
        debugPrint(
          "[ScheduleWalkScreen] Request sent successfully. Walk ID: $walkId",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Walk request sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception("Service returned null ID.");
      }
    } catch (e) {
      debugPrint("[ScheduleWalkScreen] Failed to send request: $e");
      if (mounted) {
        _showErrorSnackBar('Failed to send request: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Helper to show error messages.
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
