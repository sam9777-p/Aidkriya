import 'dart:async';

import 'package:aidkriya_walker/backend/location_service.dart';
import 'package:aidkriya_walker/incoming_requests_screen.dart';
import 'package:aidkriya_walker/profile_screen.dart';
import 'package:aidkriya_walker/social_impact_card.dart';
import 'package:aidkriya_walker/stats_card.dart';
import 'package:aidkriya_walker/walk_history_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'action_button.dart';
import 'find_walker_screen.dart';
import 'model/user_model.dart';
import 'screens/wanderer_active_walk_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  // Mock data - replace with data from _user if needed
  int stepsToday = 8500;
  int walksCompleted = 12;
  int socialImpact = 250;

  final locationService = LocationService();
  UserModel? _user;
  bool _isWalker = false;
  bool _isLoading = true;

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // START: New state for walk status management
  StreamSubscription<DocumentSnapshot>? _walkStatusSubscription;
  String? _activeWalkStatus; // To hold the status (e.g., 'Pending', 'Accepted')
  // END: New state for walk status management

  @override
  void initState() {
    super.initState();
    _subscribeToUserData();
    _updateFcmToken();
  }

  Future<void> _updateFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get the latest FCM token
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint("⚠️ Unable to get FCM token");
        return;
      }

      // Update token in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': token});

      debugPrint("✅ FCM token updated successfully: $token");
    } catch (e) {
      debugPrint("❌ Error updating FCM token: $e");
    }
  }

  // Streams user data, including activeWalkId
  Future<void> _subscribeToUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      // Optionally navigate to login screen if user is null
      return;
    }

    debugPrint(
      'HomeScreen: Subscribing to user profile for real-time updates...',
    );

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots() // Listen for changes
        .listen(
          (doc) async {
        if (doc.exists && mounted) {
          // Add mounted check here
          final data = doc.data()!;
          final userModel = UserModel.fromMap(data);

          final userRole = data['role'];
          final isWalker =
              userRole != null &&
                  (userRole.toString().toLowerCase() == 'walker' ||
                      userRole.toString() == 'Walker');

          final newActiveWalkId = userModel.activeWalkId;
          final oldActiveWalkId = _user?.activeWalkId; // Check previous value

          setState(() {
            _user = userModel;
            _isWalker = isWalker;
            _isLoading = false;
          });

          // --- New Logic: Manage Walk Status Subscription for Wanderer ---
          if (!isWalker && newActiveWalkId != null && newActiveWalkId.isNotEmpty) {
            // The current walk ID has changed or the subscription is missing/stale
            if (newActiveWalkId != oldActiveWalkId || _walkStatusSubscription == null) {

              _walkStatusSubscription?.cancel();
              _walkStatusSubscription = null;
              setState(() {
                _activeWalkStatus = null; // Clear old status while fetching new one
              });

              // Start listening to the accepted_walks document for the status
              _walkStatusSubscription = FirebaseFirestore.instance
                  .collection('accepted_walks')
                  .doc(newActiveWalkId)
                  .snapshots()
                  .listen((walkDoc) {
                if (walkDoc.exists && mounted) {
                  setState(() {
                    // Update the status
                    _activeWalkStatus = walkDoc.data()?['status'] as String?;
                  });
                  debugPrint('HomeScreen: Walk status updated to: $_activeWalkStatus');
                } else if (mounted) {
                  // Document missing (e.g., cancelled/completed/deleted from active_walks)
                  setState(() {
                    _activeWalkStatus = null; // Forces back to FindWalkerScreen
                  });
                }
              });
            }
          } else {
            // User is Walker, or Wanderer with no active walk ID.
            _walkStatusSubscription?.cancel();
            _walkStatusSubscription = null;
            setState(() {
              _activeWalkStatus = null;
            });
          }
          // --- End New Logic ---


          // Manage Walker location tracking
          if (_isWalker) {
            // Check context validity before using it
            if (mounted) await locationService.startTracking(context);
          } else {
            await locationService.stopTracking();
          }

          debugPrint(
            'HomeScreen: User profile updated. Role: $userRole, ActiveWalkId: ${_user?.activeWalkId}',
          );
        } else if (mounted) {
          setState(() => _isLoading = false);
          debugPrint('HomeScreen: User document does not exist.');
          // Optionally handle scenario where user doc is deleted (e.g., logout)
        }
      },
      onError: (error) {
        debugPrint('HomeScreen: Error streaming user data: $error');
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  @override
  void dispose() {
    _userSubscription?.cancel(); // Cancel the user stream
    _walkStatusSubscription?.cancel(); // Cancel the walk status stream
    locationService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null && FirebaseAuth.instance.currentUser != null) {
      // Still loading or user doc missing but auth exists - show loader
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (FirebaseAuth.instance.currentUser == null) {
      // No user logged in - perhaps show login screen or appropriate UI
      // For now, showing an empty container or login prompt might be best.
      return const Scaffold(body: Center(child: Text("Please log in.")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(child: _getCurrentScreen()),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // This function now uses the live-streamed _user object and _activeWalkStatus
  Widget _getCurrentScreen() {
    // Ensure _user is not null before accessing properties
    final String? activeWalkId = _user?.activeWalkId;
    final String? status = _activeWalkStatus; // Use the streamed status

    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1: // Walks/Requests Tab
        if (!_isWalker) {
          // User is a Wanderer

          if (activeWalkId != null && activeWalkId.isNotEmpty) {

            // 1. Check if status has loaded and indicates an active walk
            if (status == 'Accepted' || status == 'Started') {
              debugPrint(
                "HomeScreen: Wanderer has active walk ($activeWalkId) with status $status, showing WandererActiveWalkScreen.",
              );
              return WandererActiveWalkScreen(walkId: activeWalkId);
            }

            // 2. Check if status is still loading (status is null)
            else if (status == null) {
              // Show a temporary screen while waiting for the status to stream
              debugPrint(
                "HomeScreen: Wanderer waiting for walk status...",
              );
              return const Scaffold(body: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Checking walk status...")
                ],
              )));
            }
            // 3. Status loaded but is 'Pending' or some other non-active state
            // (or implicitly null/empty which is covered by the outer check)

            // Fall through to show FindWalkerScreen for 'Pending' or other non-active states.
            debugPrint(
              "HomeScreen: Wanderer has non-active walk ID $activeWalkId with status $status, showing FindWalkerScreen.",
            );
          }

          // 4. No Active Walk ID
          return const FindWalkerScreen();

        } else {
          // User is a Walker
          debugPrint(
            "HomeScreen: User is Walker, showing IncomingRequestsScreen.",
          );
          return const IncomingRequestsScreen();
        }
      case 2: // Profile Tab
        return const ProfileScreen();
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }

  // ... rest of the class methods ...
// (omitting for brevity, no other changes needed)

  Widget _buildHomeContent() {
    // Ensure _user is not null before building UI dependent on it
    if (_user == null) return const Center(child: Text("Loading user data..."));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildGreeting(),
          const SizedBox(height: 32),
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildSocialImpactCard(),
          const SizedBox(height: 32),
          _buildActionButtons(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'aidKRIYA Walker',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        GestureDetector(
          onTap: _navigateToProfile,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            backgroundImage:
            _user?.imageUrl != null && _user!.imageUrl!.isNotEmpty
                ? NetworkImage(_user!.imageUrl!)
                : null, // Use null if URL is empty or null
            child: (_user?.imageUrl == null || _user!.imageUrl!.isEmpty)
                ? Icon(Icons.person, color: Colors.grey[600])
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            // Use ?? 'User' as fallback if name is somehow null/empty
            'Welcome, ${_user?.fullName.split(' ').first ?? 'User'} ',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        const Text('👋', style: TextStyle(fontSize: 32)),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: StatsCard(
            title: 'Steps Today',
            value: stepsToday.toString(), // Replace with real data if available
            onTap: () => _onStatsCardTap('Steps'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatsCard(
            title: 'Walks\nCompleted',
            // Fetch this from _user?.walks or another source if needed
            value: (_user?.walks ?? walksCompleted).toString(),
            onTap: () => _onStatsCardTap('Walks'),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialImpactCard() {
    // Fetch this from _user?.earnings or another source if needed
    return SocialImpactCard(
      amount: (_user?.earnings ?? socialImpact),
      onTap: _onSocialImpactTap,
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ActionButton(
          text: _isWalker ? 'Incoming Requests' : 'Find a Walker',
          color: const Color(0xFF00E676),
          textColor: Colors.black,
          onPressed: _isWalker
              ? _onIncomingRequestPressed
              : _onFindWalkerPressed,
        ),
        const SizedBox(height: 16),
        ActionButton(
          text: 'My Walks',
          color: Colors.white,
          textColor: Colors.black,
          borderColor: Colors.grey[300],
          onPressed: _onViewHistoryPressed,
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF00E676),
        unselectedItemColor: Colors.grey[600],
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_walk_outlined),
            activeIcon: Icon(Icons.directions_walk),
            label: _isWalker ? 'Requests' : 'Walks',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // --- CALLBACKS ---

  void _navigateToProfile() {
    setState(() {
      _currentIndex = 2; // Navigate to Profile tab
    });
  }

  void _onStatsCardTap(String type) {
    debugPrint('Stats card tapped: $type');
    // Potentially navigate to a detailed stats screen
  }

  void _onSocialImpactTap() {
    debugPrint('Social impact card tapped');
    // Potentially navigate to a social impact details screen
  }

  void _onFindWalkerPressed() {
    setState(() {
      _currentIndex = 1; // Navigate to Walks tab (which shows FindWalkerScreen)
    });
  }

  void _onIncomingRequestPressed() {
    setState(() {
      _currentIndex = 1; // Navigate to Requests tab
    });
  }

  void _onViewHistoryPressed() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const WalkHistoryPage()));
  }

  void _onWalkerOfWeekTap() {
    debugPrint('Walker of the week tapped');
    // Potentially navigate to the Walker's profile
  }

  void _onChallengeTap() {
    debugPrint('Challenge tapped');
    // Potentially navigate to a challenge details screen
  }
}

