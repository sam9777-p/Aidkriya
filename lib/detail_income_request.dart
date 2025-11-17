// lib/detail_income_request.dart

import 'package:aidkriya_walker/model/incoming_request_display.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'backend/walk_request_service.dart';
import 'components/accept_button.dart';
import 'components/reject_button.dart';
import 'components/request_map_widget.dart';
import 'components/request_walker_card.dart';
import 'components/walk_info_row.dart';
// THIS IS THE ONLY REQUIRED IMPORT FOR THE SCREEN:
import 'screens/walk_active_screen.dart';

class DetailIncomeRequest extends StatefulWidget {
  final IncomingRequestDisplay displayRequest;

  const DetailIncomeRequest({Key? key, required this.displayRequest})
    : super(key: key);

  @override
  State<DetailIncomeRequest> createState() => _DetailIncomeRequestState();
}

class _DetailIncomeRequestState extends State<DetailIncomeRequest> {
  final WalkRequestService _walkService = WalkRequestService();
  GoogleMapController? _mapController;

  bool _isAccepting = false;
  bool _isRejecting = false;
  bool _isLoadingLocation = true;
  Position? _currentPosition; // Store walker's current location

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Get location on init
  }

  // Get walker's current location
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied');
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      debugPrint(
        'Got current location: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      // [MODIFIED] Wrap body in a Stack to show overlay
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMapSection(), // Fixed map section
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      _buildSenderInfoCard(),
                      const SizedBox(height: 24),
                      _buildWalkDetailsSection(),
                      const SizedBox(height: 32),
                      if (widget.displayRequest.status == 'Pending' ||
                          widget.displayRequest.status == 'Scheduled')
                        _buildActionButtons()
                      else
                        _buildStatusIndicator(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // [NEW] Full-screen loading overlay
          if (_isAccepting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Accepting Walk...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none, // Ensure no underlines
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
        'Walk Request Details',
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  // Fixed map section with proper data
  Widget _buildMapSection() {
    if (_isLoadingLocation) {
      return SizedBox(
        height: 300,
        child: Container(
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Show map even if current location is not available
    return SizedBox(
      height: 300,
      child: RequestMapWidget(
        // Pass the request location
        requestLatitude: widget.displayRequest.latitude,
        requestLongitude: widget.displayRequest.longitude,
        // Pass walker's current location (can be null)
        walkerLatitude: _currentPosition?.latitude,
        walkerLongitude: _currentPosition?.longitude,
        // Optional: Pass sender name for marker info
        senderName: widget.displayRequest.senderName,
        onMapCreated: (controller) => _mapController = controller,
      ),
    );
  }

  Widget _buildSenderInfoCard() {
    return RequestWalkerCard(walker: widget.displayRequest);
  }

  Widget _buildWalkDetailsSection() {
    return Column(
      children: [
        WalkInfoRow(
          icon: Icons.calendar_today,
          iconColor: const Color(0xFF6BCBA6),
          primaryText: widget.displayRequest.date,
          secondaryText: widget.displayRequest.time,
        ),
        const SizedBox(height: 16),
        WalkInfoRow(
          icon: Icons.hourglass_empty,
          iconColor: const Color(0xFF6BCBA6),
          primaryText: 'Duration',
          secondaryText: widget.displayRequest.duration,
        ),
        const SizedBox(height: 16),
        // Show distance if we have both locations
        if (_currentPosition != null) ...[
          WalkInfoRow(
            icon: Icons.location_on,
            iconColor: const Color(0xFF6BCBA6),
            primaryText: 'Distance',
            secondaryText:
                _calculateDistanceString(), // Use the formatted string
          ),
          const SizedBox(height: 16),
        ],
        if (widget.displayRequest.notes != null &&
            widget.displayRequest.notes!.isNotEmpty) ...[
          WalkInfoRow(
            icon: Icons.note_alt_outlined,
            iconColor: Colors.blueGrey,
            primaryText: 'Notes',
            secondaryText: widget.displayRequest.notes,
          ),
        ],
      ],
    );
  }

  // Utility to calculate raw distance value in KM (double)
  double _calculateDistanceValue() {
    if (_currentPosition == null) return 0.0;

    final distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.displayRequest.latitude,
      widget.displayRequest.longitude,
    );

    return distanceInMeters / 1000.0; // Return distance in km as a double
  }

  // Utility to display the formatted distance string
  String _calculateDistanceString() {
    final distance = _calculateDistanceValue();
    return '${distance.toStringAsFixed(1)} km away';
  }

  Widget _buildActionButtons() {
    bool isDisabled = _isAccepting || _isRejecting;

    return Row(
      children: [
        Expanded(
          child: RejectButton(
            onPressed: isDisabled ? null : _showRejectConfirmation,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: AcceptButton(
            onPressed: isDisabled ? null : _showAcceptConfirmation,
          ),
        ),
      ],
    );
  }

  void _showRejectConfirmation() {
    // [MODIFIED] Use StatefulBuilder to manage dialog's internal state
    showDialog(
      context: context,
      barrierDismissible: !_isRejecting, // Use screen-level blocking
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Reject Walk Request'),
            content: const Text(
              'Are you sure you want to reject this walk request?',
            ),
            actions: [
              TextButton(
                onPressed: _isRejecting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: _isRejecting
                    ? null
                    : () async {
                        // Call _onRejectPressed, but manage dialog state
                        setDialogState(() {
                          _isRejecting = true;
                        });
                        await _onRejectPressed(context); // Pass dialog context
                        // No need to set state false, dialog will be gone
                      },
                child: _isRejecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Reject', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      ),
    );
  }

  // [MODIFIED] To accept dialog context
  Future<void> _onRejectPressed(BuildContext dialogContext) async {
    // No need for 'if (_isRejecting || _isAccepting) return;'
    // state is already set by dialog

    try {
      bool success = await _walkService.declineRequest(
        widget.displayRequest.walkId,
      );
      if (!mounted) return;

      Navigator.pop(dialogContext); // Close the dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected successfully.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context); // Pop the detail screen
      } else {
        _showErrorSnackBar('Failed to reject request. Please try again.');
      }
    } catch (e) {
      debugPrint("[DetailIncomeRequest] Error rejecting request: $e");
      if (mounted) {
        Navigator.pop(dialogContext); // Close the dialog on error
        _showErrorSnackBar('An error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isRejecting = false); // Reset screen-level state
      }
    }
  }

  void _showAcceptConfirmation() {
    // [MODIFIED] Use StatefulBuilder to manage dialog's internal state
    showDialog(
      context: context,
      barrierDismissible: !_isAccepting, // Use screen-level blocking
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isDialogLoading =
              false; // [NEW] Internal state for dialog button

          return AlertDialog(
            title: const Text('Accept Walk Request'),
            content: const Text(
              'Accepting this will notify the sender and may decline other requests from them. Proceed?',
            ),
            actions: [
              TextButton(
                onPressed: (isDialogLoading || _isAccepting)
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: (isDialogLoading || _isAccepting)
                    ? null
                    : () async {
                        setDialogState(() {
                          isDialogLoading = true; // Show spinner in button
                        });
                        // [MODIFIED] Call _onAcceptPressed and pass dialog context
                        await _onAcceptPressed(context);
                        // No need to set state false, dialog will be gone
                      },
                child:
                    isDialogLoading // Use internal state
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Accept',
                        style: TextStyle(color: Color(0xFF6BCBA6)),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // [MODIFIED] To accept dialog context
  Future<void> _onAcceptPressed(BuildContext dialogContext) async {
    if (_isRejecting || _isAccepting) return;

    // [MODIFIED] Pop dialog *first* and show full-screen loader
    Navigator.pop(dialogContext); // Close the dialog
    setState(() => _isAccepting = true); // Show full-screen loader

    debugPrint("========================================");
    debugPrint("[DetailIncomeRequest] Starting accept process");
    debugPrint(
      "[DetailIncomeRequest] Walk ID: ${widget.displayRequest.walkId}",
    );
    debugPrint(
      "[DetailIncomeRequest] Sender ID: ${widget.displayRequest.senderId}",
    );
    debugPrint(
      "[DetailIncomeRequest] Recipient ID: ${widget.displayRequest.recipientId}",
    );
    debugPrint("[DetailIncomeRequest] Status: ${widget.displayRequest.status}");
    debugPrint("========================================");

    try {
      debugPrint("[DetailIncomeRequest] Calling acceptRequest...");

      bool success = await _walkService.acceptRequest(
        walkId: widget.displayRequest.walkId,
        senderId: widget.displayRequest.senderId,
        recipientId: widget.displayRequest.recipientId,
      );

      debugPrint("[DetailIncomeRequest] acceptRequest returned: $success");

      if (!mounted) {
        debugPrint("[DetailIncomeRequest] Widget not mounted, returning");
        return;
      }

      // [REMOVED] Navigator.pop(context); // Close the dialog (already done)

      if (success) {
        debugPrint("[DetailIncomeRequest] ✅ Request accepted successfully");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request accepted!'),
            backgroundColor: Colors.green,
          ),
        );

        // Create updated walk data
        final updatedWalkData = IncomingRequestDisplay(
          walkId: widget.displayRequest.walkId,
          senderId: widget.displayRequest.senderId,
          recipientId: widget.displayRequest.recipientId,
          senderName: widget.displayRequest.senderName,
          senderImageUrl: widget.displayRequest.senderImageUrl,
          senderBio: widget.displayRequest.senderBio,
          date: widget.displayRequest.date,
          time: widget.displayRequest.time,
          duration: widget.displayRequest.duration,
          latitude: widget.displayRequest.latitude,
          longitude: widget.displayRequest.longitude,
          status: 'Accepted',
          distance: _calculateDistanceValue().toInt(),
          notes: widget.displayRequest.notes,
        );

        // Check if it's an instant walk (status was 'Pending')
        final bool isInstantWalk = widget.displayRequest.status == 'Pending';
        debugPrint("[DetailIncomeRequest] Is instant walk? $isInstantWalk");

        if (isInstantWalk) {
          debugPrint("[DetailIncomeRequest] Navigating to WalkActiveScreen...");
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    WalkActiveScreen(walkData: updatedWalkData),
              ),
            );
          }
        } else {
          debugPrint(
            "[DetailIncomeRequest] Scheduled walk - just popping back",
          );
          if (mounted) {
            Navigator.of(context).pop(); // Pop detail screen
          }
        }
      } else {
        debugPrint("[DetailIncomeRequest] ❌ acceptRequest returned false");
        _showErrorSnackBar(
          'Failed to accept request. It might have been cancelled or an error occurred.',
        );
        if (mounted) Navigator.pop(context); // Pop detail screen on failure
      }
    } catch (e, stackTrace) {
      debugPrint("========================================");
      debugPrint("[DetailIncomeRequest] ❌ Exception in _onAcceptPressed");
      debugPrint("[DetailIncomeRequest] Error: $e");
      debugPrint("[DetailIncomeRequest] Stack trace:");
      debugPrint(stackTrace.toString());
      debugPrint("========================================");

      if (mounted) {
        // [REMOVED] Navigator.pop(context); // No dialog to pop
        _showErrorSnackBar('An error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false); // Hide full-screen loader
      }
    }
  }

  Widget _buildStatusIndicator() {
    Color statusColor;
    String statusText = widget.displayRequest.status;

    switch (statusText) {
      case 'Accepted':
        statusColor = Colors.green;
        break;
      case 'Rejected':
      case 'Cancelled':
      case 'Expired':
        statusColor = Colors.red;
        break;
      case 'Completed':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'Pending';
        break;
    }

    if (statusText == 'Pending' || statusText == 'Scheduled')
      return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Center(
        child: Text(
          'Status: $statusText',
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
