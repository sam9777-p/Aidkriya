import 'package:flutter/material.dart';

import 'components/request_card.dart';
import 'model/incoming_request.dart';

class IncomingRequestsScreen extends StatefulWidget {
  const IncomingRequestsScreen({super.key});

  @override
  State<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends State<IncomingRequestsScreen> {
  // Sample data
  final List<IncomingRequest> requests = [
    IncomingRequest(
      id: '1',
      walkerName: 'Elara Vance',
      walkerImageUrl: null,
      dateTime: 'Tomorrow, 3:00 PM',
      location: 'Central Park Loop',
      pace: 'Leisurely Pace',
    ),
    IncomingRequest(
      id: '2',
      walkerName: 'Leo Maxwell',
      walkerImageUrl: null,
      dateTime: 'Fri, Nov 29, 9:00 AM',
      location: 'Riverside Trail',
      pace: 'Moderate Pace',
    ),
    IncomingRequest(
      id: '3',
      walkerName: 'Cora Diaz',
      walkerImageUrl: null,
      dateTime: 'Sat, Nov 30, 6:00 PM',
      location: 'Harbor View Path',
      pace: 'Brisk Pace',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: requests.isEmpty ? _buildEmptyState() : _buildRequestsList(),
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
        'Incoming Requests',
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildRequestsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        return RequestCard(
          request: requests[index],
          onAccept: () => _onAcceptRequest(requests[index]),
          onReject: () => _onRejectRequest(requests[index]),
          onTap: () => _onRequestTapped(requests[index]),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Incoming Requests',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Callback methods
  void _onFilterPressed() {
    print('Filter requests');
    // Show filter options
  }

  void _onRequestTapped(IncomingRequest request) {
    print('View request details: ${request.walkerName}');
    // Navigate to detailed request screen
  }

  void _onAcceptRequest(IncomingRequest request) {
    print('Accept request from ${request.walkerName}');
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Request'),
        content: Text('Accept walk request from ${request.walkerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                requests.remove(request);
              });
              // API call to accept
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

  void _onRejectRequest(IncomingRequest request) {
    print('Reject request from ${request.walkerName}');
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: Text('Reject walk request from ${request.walkerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                requests.remove(request);
              });
              // API call to reject
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
