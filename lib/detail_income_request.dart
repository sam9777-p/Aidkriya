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
  Position? _currentPosition; // ✅ Store walker's current location

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // ✅ Get location on init
  }

  // ✅ Get walker's current location
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMapSection(), // ✅ Fixed map section
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  _buildSenderInfoCard(),
                  const SizedBox(height: 24),
                  _buildWalkDetailsSection(),
                  const SizedBox(height: 32),
                  if (widget.displayRequest.status == 'Pending')
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

  // ✅ Fixed map section with proper data
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
        // ✅ Show distance if we have both locations
        if (_currentPosition != null) ...[
          WalkInfoRow(
            icon: Icons.location_on,
            iconColor: const Color(0xFF6BCBA6),
            primaryText: 'Distance',
            secondaryText: _calculateDistance(),
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

  // ✅ Calculate distance between walker and request location
  String _calculateDistance() {
    if (_currentPosition == null) return 'Calculating...';

    final distance =
        Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          widget.displayRequest.latitude,
          widget.displayRequest.longitude,
        ) /
        1000; // Convert to km

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
    showDialog(
      context: context,
      barrierDismissible: !_isRejecting,
      builder: (context) => AlertDialog(
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
            onPressed: _isRejecting ? null : _onRejectPressed,
            child: _isRejecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _onRejectPressed() async {
    if (_isRejecting || _isAccepting) return;

    setState(() => _isRejecting = true);

    try {
      bool success = await _walkService.declineRequest(
        widget.displayRequest.walkId,
      );
      if (!mounted) return;

      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected successfully.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      } else {
        _showErrorSnackBar('Failed to reject request. Please try again.');
      }
    } catch (e) {
      debugPrint("[DetailIncomeRequest] Error rejecting request: $e");
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackBar('An error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isRejecting = false);
      }
    }
  }

  void _showAcceptConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: !_isAccepting,
      builder: (context) => AlertDialog(
        title: const Text('Accept Walk Request'),
        content: const Text(
          'Accepting this will notify the sender and may decline other requests from them. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: _isAccepting ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _isAccepting ? null : _onAcceptPressed,
            child: _isAccepting
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
      ),
    );
  }

  Future<void> _onAcceptPressed() async {
    if (_isRejecting || _isAccepting) return;

    setState(() => _isAccepting = true);

    try {
      bool success = await _walkService.acceptRequest(
        walkId: widget.displayRequest.walkId,
        senderId: widget.displayRequest.senderId,
        recipientId: widget.displayRequest.recipientId,
      );
      if (!mounted) return;

      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request accepted!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        _showErrorSnackBar(
          'Failed to accept request. It might have been cancelled or an error occurred.',
        );
      }
    } catch (e) {
      debugPrint("[DetailIncomeRequest] Error accepting request: $e");
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackBar('An error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
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

    if (statusText == 'Pending') return const SizedBox.shrink();

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
