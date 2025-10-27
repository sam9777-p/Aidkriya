import 'package:aidkriya_walker/model/incoming_request_display.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'backend/walk_request_service.dart';
import 'components/accept_button.dart';
import 'components/reject_button.dart';
import 'components/request_map_widget.dart';
import 'components/request_walker_card.dart';
import 'components/walk_info_row.dart';

class DetailIncomeRequest extends StatefulWidget {
  // Constructor now accepts the display model from IncomingRequestsScreen
  final IncomingRequestDisplay displayRequest;

  const DetailIncomeRequest({Key? key, required this.displayRequest})
    : super(key: key);

  @override
  State<DetailIncomeRequest> createState() => _DetailIncomeRequestState();
}

class _DetailIncomeRequestState extends State<DetailIncomeRequest> {
  // Instance of the WalkRequestService
  final WalkRequestService _walkService = WalkRequestService();
  GoogleMapController? _mapController;

  // State for loading indicators on buttons
  bool _isAccepting = false;
  bool _isRejecting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMapSection(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  _buildSenderInfoCard(), // Renamed for clarity
                  const SizedBox(height: 24),
                  _buildWalkDetailsSection(),
                  const SizedBox(height: 32),
                  // Show buttons only if the request is still pending
                  if (widget.displayRequest.status == 'Pending')
                    _buildActionButtons()
                  else
                    _buildStatusIndicator(), // Show status if not pending
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
        'Walk Request Details', // More specific title
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildMapSection() {
    return SizedBox(
      height: 300, // Adjust height as needed
      child: RequestMapWidget(
        // Use walkId for marker uniqueness if name isn't guaranteed unique
        location: widget.displayRequest.walkId,
        latitude: widget.displayRequest.latitude,
        longitude: widget.displayRequest.longitude,
        onMapCreated: (controller) => _mapController = controller,
      ),
    );
  }

  Widget _buildSenderInfoCard() {
    // Ensure RequestWalkerCard is updated to accept IncomingRequestDisplay
    // and correctly display senderName, senderImageUrl, senderBio
    return RequestWalkerCard(
      walker: widget.displayRequest, // Keep message functionality
    );
  }

  Widget _buildWalkDetailsSection() {
    // Calculate distance if needed, or assume it's pre-calculated/not shown here
    // String distanceText = widget.displayRequest.distance != null
    //    ? '${widget.displayRequest.distance!.toStringAsFixed(1)} km away'
    //    : 'Distance unavailable'; // Fallback

    return Column(
      children: [
        WalkInfoRow(
          icon: Icons.calendar_today,
          iconColor: const Color(0xFF6BCBA6),
          primaryText: widget.displayRequest.date,
          secondaryText: widget.displayRequest.time, // Show time here
        ),
        const SizedBox(height: 16),
        WalkInfoRow(
          icon: Icons.hourglass_empty,
          iconColor: const Color(0xFF6BCBA6),
          primaryText: 'Duration',
          secondaryText: widget.displayRequest.duration, // Show duration
        ),
        const SizedBox(height: 16),
        // Optional: Show distance if calculated/needed
        // WalkInfoRow(
        //   icon: Icons.location_on,
        //   iconColor: const Color(0xFF6BCBA6),
        //   primaryText: 'Approx. Distance',
        //   secondaryText: distanceText,
        // ),
        // Optional: Show Notes if available
        if (widget.displayRequest.notes != null &&
            widget.displayRequest.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          WalkInfoRow(
            icon: Icons.note_alt_outlined,
            iconColor: Colors.blueGrey,
            primaryText: 'Notes',
            secondaryText: widget.displayRequest.notes, // Display notes
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    // Disable buttons if an action is already in progress
    bool isDisabled = _isAccepting || _isRejecting;

    return Row(
      children: [
        Expanded(
          child: RejectButton(
            onPressed: isDisabled
                ? null
                : _showRejectConfirmation, // Show confirmation first
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: AcceptButton(
            onPressed: isDisabled
                ? null
                : _showAcceptConfirmation, // Show confirmation first
          ),
        ),
      ],
    );
  }

  /// Shows a confirmation dialog before rejecting.
  void _showRejectConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: !_isRejecting, // Prevent dismissal while loading
      builder: (context) => AlertDialog(
        title: const Text('Reject Walk Request'),
        content: const Text(
          'Are you sure you want to reject this walk request?',
        ),
        actions: [
          TextButton(
            onPressed: _isRejecting
                ? null
                : () => Navigator.pop(context), // Close dialog
            child: const Text('Cancel'),
          ),
          // --- Updated Reject Button ---
          TextButton(
            onPressed: _isRejecting
                ? null
                : _onRejectPressed, // Call actual reject logic
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

  /// Handles the actual rejection logic after confirmation.
  Future<void> _onRejectPressed() async {
    // Prevent multiple calls
    if (_isRejecting || _isAccepting) return;

    setState(() => _isRejecting = true); // Show loading indicator in dialog

    try {
      bool success = await _walkService.declineRequest(
        widget.displayRequest.walkId,
      );
      if (!mounted) return; // Check if screen still exists

      Navigator.pop(context); // Close the confirmation dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected successfully.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context); // Go back to the previous screen (request list)
      } else {
        _showErrorSnackBar('Failed to reject request. Please try again.');
      }
    } catch (e) {
      debugPrint("[DetailIncomeRequest] Error rejecting request: $e");
      if (mounted) {
        Navigator.pop(context); // Close the confirmation dialog on error
        _showErrorSnackBar('An error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isRejecting = false); // Hide loading indicator
      }
    }
  }

  /// Shows a confirmation dialog before accepting.
  void _showAcceptConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: !_isAccepting, // Prevent dismissal while loading
      builder: (context) => AlertDialog(
        title: const Text('Accept Walk Request'),
        content: const Text(
          'Accepting this will notify the sender and may decline other requests from them. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: _isAccepting
                ? null
                : () => Navigator.pop(context), // Close dialog
            child: const Text('Cancel'),
          ),
          // --- Updated Accept Button ---
          TextButton(
            onPressed: _isAccepting
                ? null
                : _onAcceptPressed, // Call actual accept logic
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

  /// Handles the actual acceptance logic after confirmation.
  Future<void> _onAcceptPressed() async {
    // Prevent multiple calls
    if (_isRejecting || _isAccepting) return;

    setState(() => _isAccepting = true); // Show loading indicator in dialog

    try {
      bool success = await _walkService.acceptRequest(
        walkId: widget.displayRequest.walkId,
        senderId: widget.displayRequest.senderId,
        recipientId: widget
            .displayRequest
            .recipientId, // This is the current user (Walker)
      );
      if (!mounted) return; // Check if screen still exists

      Navigator.pop(context); // Close the confirmation dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request accepted!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back to the request list or potentially to an "Active Walk" screen
        Navigator.pop(context); // Go back to the previous screen (request list)
      } else {
        _showErrorSnackBar(
          'Failed to accept request. It might have been cancelled or an error occurred.',
        );
      }
    } catch (e) {
      debugPrint("[DetailIncomeRequest] Error accepting request: $e");
      if (mounted) {
        Navigator.pop(context); // Close the confirmation dialog on error
        _showErrorSnackBar('An error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false); // Hide loading indicator
      }
    }
  }

  /// Builds a simple text indicator for non-pending statuses.
  Widget _buildStatusIndicator() {
    Color statusColor;
    String statusText = widget.displayRequest.status; // Get status

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
      default: // Pending or unknown
        statusColor = Colors.orange;
        statusText = 'Pending'; // Default to pending if unknown
        break;
    }

    // Don't show indicator for 'Pending' as buttons are shown instead
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

  // --- Helper Methods ---
  void _onMessageTapped() {
    debugPrint(
      '[DetailIncomeRequest] Open chat with sender ID: ${widget.displayRequest.senderId}',
    );
    // TODO: Implement navigation to chat screen using senderId
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat functionality not yet implemented.')),
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
    _mapController?.dispose(); // Dispose map controller
    super.dispose();
  }
}
