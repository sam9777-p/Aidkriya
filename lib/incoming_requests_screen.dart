import 'dart:async';

import 'package:aidkriya_walker/backend/walk_request_service.dart';
import 'package:aidkriya_walker/detail_income_request.dart';
import 'package:aidkriya_walker/model/walk_request.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'components/request_card.dart';
import 'model/incoming_request_display.dart';
import 'model/user_model.dart';

class IncomingRequestsScreen extends StatefulWidget {
  const IncomingRequestsScreen({super.key});

  @override
  State<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends State<IncomingRequestsScreen> {
  // Service to interact with Firestore
  final WalkRequestService _walkService = WalkRequestService();
  // Firestore instance for direct user fetching
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Get current user ID
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // State variables
  List<IncomingRequestDisplay> _displayRequests = []; // List to show in the UI
  bool _isLoadingRequests =
      true; // Loading state for initial request stream connection
  bool _isLoadingUserData =
      false; // Loading state specifically for fetching user profiles
  StreamSubscription? _requestsSubscription; // To manage the stream listener
  final Map<String, UserModel> _userCache =
      {}; // Cache to avoid refetching user profiles

  @override
  void initState() {
    super.initState();
    _subscribeToRequests(); // Start listening when the screen loads
  }

  @override
  void dispose() {
    _requestsSubscription
        ?.cancel(); // Clean up the listener when the screen is removed
    super.dispose();
  }

  /// Subscribes to the stream of pending walk requests for the current user (Walker).
  void _subscribeToRequests() {
    if (_currentUserId == null) {
      debugPrint(
        "[IncomingRequestsScreen] User not logged in. Cannot subscribe.",
      );
      setState(
        () => _isLoadingRequests = false,
      ); // Stop loading if not logged in
      return;
    }

    debugPrint(
      "[IncomingRequestsScreen] Subscribing to pending requests for Walker ID: $_currentUserId",
    );
    setState(() => _isLoadingRequests = true); // Indicate loading has started

    _requestsSubscription = _walkService
        .getPendingRequestsForWalker(_currentUserId!)
        .listen(
          (walkRequests) async {
            // Listen for lists of WalkRequest objects
            debugPrint(
              "[IncomingRequestsScreen] Received ${walkRequests.length} raw WalkRequest objects from stream.",
            );
            // Once requests arrive, stop the initial loading and start user data loading
            setState(() {
              _isLoadingRequests = false;
              _isLoadingUserData = true;
            });
            // Asynchronously fetch user data and update the display list
            await _fetchUserDataAndCombine(walkRequests);
          },
          onError: (error) {
            debugPrint(
              "[IncomingRequestsScreen] Error in request stream: $error",
            );
            // Handle stream errors (e.g., permissions)
            setState(() {
              _isLoadingRequests = false;
              _isLoadingUserData = false;
              _displayRequests = []; // Clear list on error
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading requests: $error'),
                backgroundColor: Colors.red,
              ),
            );
          },
        );
  }

  /// Fetches user profile data (UserModel) for the senders of the given WalkRequests.
  /// Uses a cache to avoid redundant fetches. Updates the `_displayRequests` state.
  Future<void> _fetchUserDataAndCombine(List<WalkRequest> requests) async {
    if (requests.isEmpty) {
      debugPrint(
        "[IncomingRequestsScreen] Request list is empty. Clearing display.",
      );
      // If the list is empty, update the UI immediately
      if (mounted) {
        setState(() {
          _displayRequests = [];
          _isLoadingUserData = false; // Finished loading (nothing to load)
        });
      }
      return;
    }

    // Identify unique sender IDs that are not already in our cache
    final senderIdsToFetch = requests
        .map((req) => req.senderId) // Get all sender IDs
        .where(
          (id) => !_userCache.containsKey(id),
        ) // Filter out already cached IDs
        .toSet() // Get unique IDs
        .toList();

    debugPrint(
      "[IncomingRequestsScreen] Unique Sender IDs in this batch: ${requests.map((r) => r.senderId).toSet()}",
    );
    debugPrint(
      "[IncomingRequestsScreen] Need to fetch user data for IDs: $senderIdsToFetch",
    );

    // Fetch user data from Firestore only if there are new IDs to fetch
    if (senderIdsToFetch.isNotEmpty) {
      try {
        // Create a list of Futures to fetch user documents
        final userFutures = senderIdsToFetch.map(
          (id) => _firestore.collection('users').doc(id).get().catchError((e) {
            // Handle individual fetch errors gracefully
            debugPrint("[IncomingRequestsScreen] Error fetching user $id: $e");
            return null; // Return null if a specific fetch fails
          }),
        );

        // Wait for all fetches to complete (or fail individually)
        final userSnapshots = await Future.wait(userFutures);

        // Process the results and update the cache
        for (var userDoc in userSnapshots) {
          // Check if fetch was successful and document exists
          if (userDoc != null && userDoc.exists && userDoc.data() != null) {
            final userModel = UserModel.fromMap(userDoc.data()!);
            _userCache[userDoc.id] =
                userModel; // Add successfully fetched user to cache
            debugPrint(
              "[IncomingRequestsScreen] Fetched and cached user: ${userModel.fullName} (ID: ${userDoc.id})",
            );
          } else if (userDoc != null) {
            // Document doesn't exist for a sender ID
            debugPrint(
              "[IncomingRequestsScreen] Warning: User document ${userDoc.id} not found in 'users'. Caching placeholder.",
            );
            // Add a placeholder to cache to avoid re-fetching constantly
            _userCache[userDoc.id] = UserModel(
              id: userDoc.id,
              fullName: 'Unknown User',
              age: 0,
              city: '',
              bio: 'User profile not found.',
              phone: '',
              interests: [],
              rating: 0,
              imageUrl: null,
              walks: 0,
              earnings: 0,
            ); // Placeholder
          }
          // If userDoc is null (due to catchError), it's already logged. We won't cache it.
        }
      } catch (e) {
        // Catch potential errors from Future.wait itself (less likely with individual catchError)
        debugPrint(
          "[IncomingRequestsScreen] Error during batch fetching user data: $e",
        );
        if (mounted) {
          setState(() => _isLoadingUserData = false); // Stop loading on error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error fetching some user details: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        // Decide if you want to proceed with partial data or stop
        // return; // Uncomment to stop if batch fetching fails critically
      }
    } else {
      debugPrint(
        "[IncomingRequestsScreen] All required user data is already cached for this batch.",
      );
    }

    // Now, combine the original requests with the (potentially updated) user cache data
    final List<IncomingRequestDisplay> newDisplayRequests = [];
    for (var request in requests) {
      final senderData =
          _userCache[request
              .senderId]; // Get from cache (will be placeholder if fetch failed or user not found)

      if (senderData != null) {
        // Only add if we have *some* user data (even placeholder)
        newDisplayRequests.add(
          IncomingRequestDisplay(
            walkId: request.walkId, // Crucial: pass the document ID
            senderId: request.senderId,
            recipientId: request.recipientId,
            senderName: senderData.fullName, // Use cached name
            senderImageUrl: senderData.imageUrl, // Use cached image URL
            senderBio: senderData.bio, // Use cached bio
            date: request.date,
            time: request.time,
            duration: request.duration,
            latitude: request.latitude,
            longitude: request.longitude,
            status: request.status,
            distance: request.walkerProfile.distance,
            notes: request.notes,
          ),
        );
      } else {
        // Should not happen if placeholder logic is correct, but as a fallback:
        debugPrint(
          "[IncomingRequestsScreen] Warning: Could not find cached data for sender ${request.senderId} even after fetch attempt.",
        );
      }
    }

    // Update the UI state if the screen is still mounted
    if (mounted) {
      setState(() {
        _displayRequests =
            newDisplayRequests; // Update the list shown in the UI
        _isLoadingUserData = false; // Mark user data loading as finished
        debugPrint(
          "[IncomingRequestsScreen] Updated UI. Displaying ${_displayRequests.length} requests.",
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show message if user is not logged in
    if (_currentUserId == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: Text("Please log in to view requests.")),
      );
    }

    // Main scaffold
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: _buildBody(), // Delegate body building to a separate method
    );
  }

  /// Builds the main body content based on the current loading state and data.
  Widget _buildBody() {
    // Show central loading indicator if either requests OR user data is loading
    if (_isLoadingRequests || _isLoadingUserData) {
      debugPrint(
        "[IncomingRequestsScreen] Build: Showing loading indicator (Requests: $_isLoadingRequests, UserData: $_isLoadingUserData)",
      );
      return const Center(child: CircularProgressIndicator());
    }

    // Show empty state message if loading is done and the display list is empty
    if (_displayRequests.isEmpty) {
      debugPrint("[IncomingRequestsScreen] Build: Showing empty state.");
      return _buildEmptyState();
    }

    // Build the list view with the combined data
    debugPrint(
      "[IncomingRequestsScreen] Build: Building ListView with ${_displayRequests.length} items.",
    );
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _displayRequests.length,
      itemBuilder: (context, index) {
        final displayRequest = _displayRequests[index];

        // Use RequestCard, assuming it's updated to accept IncomingRequestDisplay
        return RequestCard(
          request: displayRequest,
          onTap: () =>
              _onRequestTapped(displayRequest), // Pass display model to handler
        );
      },
    );
  }

  /// Builds the AppBar for the screen.
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF5F5F5),
      elevation: 0, // No shadow
      title: const Text(
        'Incoming Requests',
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      // Add back button if needed, depends on navigation flow
      // leading: IconButton(
      //   icon: const Icon(Icons.arrow_back, color: Colors.black),
      //   onPressed: () => Navigator.of(context).pop(),
      // ),
    );
  }

  /// Builds the widget shown when there are no pending requests.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Pending Requests',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New walk requests will appear here.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Handles navigation when a request card is tapped.
  /// Passes the necessary data to the DetailIncomeRequest screen.
  void _onRequestTapped(IncomingRequestDisplay displayRequest) {
    debugPrint(
      "[IncomingRequestsScreen] Request card tapped. Navigating to details for walkId: ${displayRequest.walkId}",
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        // IMPORTANT: Ensure DetailIncomeRequest constructor is updated
        // to accept IncomingRequestDisplay or the necessary IDs/data from it.
        builder: (_) => DetailIncomeRequest(displayRequest: displayRequest),
      ),
    );
  }
}
