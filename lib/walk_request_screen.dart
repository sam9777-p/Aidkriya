import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'components/accept_button.dart';
import 'components/reject_button.dart';
import 'components/request_map_widget.dart';
import 'components/request_walker_card.dart';
import 'components/walk_info_row.dart';
import 'model/walk_request.dart';

class WalkRequestScreen extends StatefulWidget {
  final WalkRequest walkRequest;

  const WalkRequestScreen({Key? key, required this.walkRequest})
    : super(key: key);

  @override
  State<WalkRequestScreen> createState() => _WalkRequestScreenState();
}

class _WalkRequestScreenState extends State<WalkRequestScreen> {
  int _currentIndex = 1;
  GoogleMapController? _mapController;

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
                  _buildWalkerInfoCard(),
                  const SizedBox(height: 24),
                  _buildWalkDetailsSection(),
                  const SizedBox(height: 32),
                  _buildActionButtons(),
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
        'Walk Request',
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
      height: 300,
      child: RequestMapWidget(
        location: widget.walkRequest.location,
        latitude: widget.walkRequest.latitude,
        longitude: widget.walkRequest.longitude,
        onMapCreated: (controller) => _mapController = controller,
      ),
    );
  }

  Widget _buildWalkerInfoCard() {
    return RequestWalkerCard(
      walker: widget.walkRequest.walker,
      onMessageTapped: _onMessageTapped,
    );
  }

  Widget _buildWalkDetailsSection() {
    return Column(
      children: [
        WalkInfoRow(
          icon: Icons.calendar_today,
          iconColor: const Color(0xFF6BCBA6),
          primaryText: widget.walkRequest.dateTime,
          secondaryText: widget.walkRequest.duration,
        ),
        const SizedBox(height: 16),
        WalkInfoRow(
          icon: Icons.location_on,
          iconColor: const Color(0xFF6BCBA6),
          primaryText: widget.walkRequest.location,
          secondaryText: null,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(child: RejectButton(onPressed: _onRejectPressed)),
        const SizedBox(width: 16),
        Expanded(child: AcceptButton(onPressed: _onAcceptPressed)),
      ],
    );
  }

  // Callback methods
  void _onMessageTapped() {
    print('Open chat with ${widget.walkRequest.walker.name}');
    // Navigate to chat screen
  }

  void _onRejectPressed() {
    print('Reject walk request');
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Walk Request'),
        content: const Text(
          'Are you sure you want to reject this walk request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // API call to reject
              Navigator.pop(context); // Return to previous screen
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _onAcceptPressed() {
    print('Accept walk request');
    // Show confirmation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Walk Request'),
        content: const Text(
          'You will be notified with walk details once confirmed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // API call to accept
              Navigator.pop(context); // Return to previous screen
            },
            child: const Text(
              'Accept',
              style: TextStyle(color: Color(0xFF6BCBA6)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
