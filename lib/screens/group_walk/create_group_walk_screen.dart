// create_group_walk_screen.dart
import 'package:aidkriya_walker/backend/walk_request_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class CreateGroupWalkScreen extends StatefulWidget {
  const CreateGroupWalkScreen({super.key});

  @override
  State<CreateGroupWalkScreen> createState() => _CreateGroupWalkScreenState();
}

class _CreateGroupWalkScreenState extends State<CreateGroupWalkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _walkService = WalkRequestService();
  final _auth = FirebaseAuth.instance;

  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxParticipantsController = TextEditingController();

  // Focus nodes for independent animated cards (Option 3)
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _priceFocus = FocusNode();
  final FocusNode _maxParticipantsFocus = FocusNode();

  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  GoogleMapController? _mapController;
  LatLng? _meetingPoint;
  bool _isLoading = false;
  Map<String, dynamic>? _walkerInfo;

  @override
  void initState() {
    super.initState();
    _fetchWalkerInfo();

    // Add listeners so UI updates when focus changes
    _titleFocus.addListener(() => setState(() {}));
    _priceFocus.addListener(() => setState(() {}));
    _maxParticipantsFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _maxParticipantsController.dispose();

    _titleFocus.removeListener(() {});
    _priceFocus.removeListener(() {});
    _maxParticipantsFocus.removeListener(() {});

    _titleFocus.dispose();
    _priceFocus.dispose();
    _maxParticipantsFocus.dispose();

    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchWalkerInfo() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _walkerInfo = {
          'fullName': data['fullName'] ?? 'Walker',
          'imageUrl': data['imageUrl'],
        };
        // setState not strictly required here (only used before submission),
        // but it's okay to call to reflect if UI wants to show walker info later.
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Error fetching walker info: $e");
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _meetingPoint = position;
    });
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _createGroupWalk() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_meetingPoint == null) {
      _showError("Please select a meeting point on the map.");
      return;
    }
    if (_walkerInfo == null) {
      _showError("Could not load your profile. Please try again.");
      return;
    }
    if (DateTime.now().add(const Duration(minutes: 30)).isAfter(_selectedDateTime)) {
      _showError("Scheduled time must be at least 30 minutes in the future.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final walkData = {
        'walkerId': _auth.currentUser!.uid,
        'walkerInfo': _walkerInfo,
        'title': _titleController.text,
        'scheduledTime': Timestamp.fromDate(_selectedDateTime),
        'meetingPoint': GeoPoint(_meetingPoint!.latitude, _meetingPoint!.longitude),
        'duration': "60 min",
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'maxParticipants': int.tryParse(_maxParticipantsController.text) ?? 1,
        'participants': [],
        'participantCount': 0,
        'status': 'Scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final walkId = await _walkService.createGroupWalk(walkData);

      if (walkId != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group Walk Created!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        _showError("Failed to create walk. Service returned null.");
      }
    } catch (e) {
      _showError("An error occurred: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF6BCBA6);

    // Border and style used for all fields (functionality unchanged)
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade400),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: green, width: 2),
    );

    // animation params for Option A (Scale + Elevation)
    const Duration animDuration = Duration(milliseconds: 180);
    const double focusedScale = 1.02;
    const double unfocusedScale = 1.0;
    const double focusedElevation = 8.0;
    const double unfocusedElevation = 0.5;

    Widget _animatedInputCard({
      required FocusNode focusNode,
      required Widget child,
      EdgeInsetsGeometry margin = const EdgeInsets.symmetric(vertical: 6),
    }) {
      final bool isFocused = focusNode.hasFocus;
      return AnimatedScale(
        scale: isFocused ? focusedScale : unfocusedScale,
        duration: animDuration,
        curve: Curves.easeOut,
        child: AnimatedPhysicalModel(
          duration: animDuration,
          curve: Curves.easeOut,
          shape: BoxShape.rectangle,
          elevation: isFocused ? focusedElevation : unfocusedElevation,
          color: Colors.white,
          shadowColor: green.withOpacity(isFocused ? 0.35 : 0.12),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Container(
            margin: margin,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: child,
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Group Walk'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 100, 16, 16), // keep content below status bar
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // TITLE - animated independent card
              _animatedInputCard(
                focusNode: _titleFocus,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: TextFormField(
                    focusNode: _titleFocus,
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Walk Title',
                      hintText: 'e.g., Morning Park Loop',
                      filled: true,
                      fillColor: Colors.white,
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: focusedBorder,
                      floatingLabelStyle: const TextStyle(color: green),
                    ),
                    validator: (val) =>
                    val!.isEmpty ? 'Please enter a title' : null,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Row with two independent animated cards (each animates separately — Option 3)
              Row(
                children: [
                  Expanded(
                    child: _animatedInputCard(
                      focusNode: _priceFocus,
                      margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                      child: Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: TextFormField(
                          focusNode: _priceFocus,
                          controller: _priceController,
                          decoration: InputDecoration(
                            labelText: 'Price per Wanderer',
                            prefixText: '₹',
                            filled: true,
                            fillColor: Colors.white,
                            border: inputBorder,
                            enabledBorder: inputBorder,
                            focusedBorder: focusedBorder,
                            floatingLabelStyle: const TextStyle(color: green),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) =>
                          (double.tryParse(val ?? '0') ?? 0) <= 0
                              ? 'Price must be > 0'
                              : null,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _animatedInputCard(
                      focusNode: _maxParticipantsFocus,
                      margin: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
                      child: Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: TextFormField(
                          focusNode: _maxParticipantsFocus,
                          controller: _maxParticipantsController,
                          decoration: InputDecoration(
                            labelText: 'Max Wanderers',
                            filled: true,
                            fillColor: Colors.white,
                            border: inputBorder,
                            enabledBorder: inputBorder,
                            focusedBorder: focusedBorder,
                            floatingLabelStyle: const TextStyle(color: green),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) =>
                          (int.tryParse(val ?? '0') ?? 0) <= 0
                              ? 'Must be at least 1'
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              const Text('Select Date & Time',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: green),
                title: Text(
                    DateFormat('EEE, MMM d, yyyy \n@ h:mm a').format(_selectedDateTime)),
                onTap: _selectDateTime,
              ),

              const SizedBox(height: 24),

              const Text('Select Meeting Point',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),

              Container(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  onTap: _onMapTap,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(23.7957, 86.4304), // Default to Dhanbad
                    zoom: 12,
                  ),
                  markers: _meetingPoint == null
                      ? {}
                      : {
                    Marker(
                      markerId: const MarkerId('meetingPoint'),
                      position: _meetingPoint!,
                    ),
                  },
                ),
              ),

              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _createGroupWalk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.add),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Walk Event', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
