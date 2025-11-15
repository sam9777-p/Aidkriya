// lib/home_screen.dart
import 'dart:async';

import 'package:aidkriya_walker/backend/location_service.dart';
import 'package:aidkriya_walker/incoming_requests_screen.dart';
import 'package:aidkriya_walker/payment_screen.dart'; // Ensure this is imported
import 'package:aidkriya_walker/profile_screen.dart';
import 'package:aidkriya_walker/screens/walk_active_screen.dart';
import 'package:aidkriya_walker/social_impact_card.dart';
import 'package:aidkriya_walker/stats_card.dart';
import 'package:aidkriya_walker/walk_history_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'action_button.dart';
import 'backend/pedometer_service.dart';
import 'find_walker_screen.dart';
import 'model/incoming_request_display.dart';
import 'model/user_model.dart';
import 'screens/walk_summary_screen.dart';
import 'screens/wanderer_active_walk_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PedometerService _pedometerService = PedometerService();
  int walksCompleted = 12;
  int socialImpact = 250;
  bool _isSuspiciousDialogOpen = false; // State to manage dialog display

  final locationService = LocationService();
  UserModel? _user;
  bool _isWalker = false;
  bool _isLoading = true;

  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<DocumentSnapshot>? _walkStatusSubscription;
  String? _activeWalkStatus;
  bool _isCheckingForSummary = false;

  @override
  void initState() {
    super.initState();
    _subscribeToUserData();
    _updateFcmToken();
    _pedometerService.init();
    // No need for post-frame callback, _subscribeToUserData handles the check
  }

  /// Displays the unremovable dialog when a payment is suspected as fraudulent.
  void _showSuspiciousDialog(String walkId, double amount) {
    if (_isSuspiciousDialogOpen) return;

    _isSuspiciousDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('Account Suspended', style: TextStyle(color: Colors.red)),
              ],
            ),
            content: const Text(
              'Your account has been suspended due to an uncompleted payment for a previous walk. Please complete the payment to restore access to the app.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  await _raisePaymentIssueTicket(walkId, amount);
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("✅ Issue reported. Admin will review."),
                      ),
                    );
                    _isSuspiciousDialogOpen = false;
                  }
                },
                child: const Text("I have done payment! Help"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                onPressed: () {
                  Navigator.of(context).pop();
                  _isSuspiciousDialogOpen = false;

                  // Navigate to PaymentScreen with the actual details
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PaymentScreen(
                        amount: amount,
                        walkId: walkId,
                      ),
                    ),
                  );
                },
                child: const Text('Pay Now', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Sends a ticket to a new Firestore collection for admin review.
  Future<void> _raisePaymentIssueTicket(String walkId, double amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('admin_tickets').add({
      'userId': user.uid,
      'userName': _user?.fullName,
      'walkId': walkId,
      'amountDue': amount,
      'issueType': 'Uncompleted Payment Dispute',
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Checks the user model for payment suspicion status and shows/hides the dialog.
  void _checkForSuspension() {
    if (!mounted || _isLoading || _user == null) return;

    final bool isSuspicious = _user!.isPaymentSuspicious;
    final String? walkId = _user!.suspiciousWalkId;
    final double? amount = _user!.suspiciousAmount;

    // Condition for showing the dialog:
    // 1. Is a Wanderer
    // 2. Is marked as suspicious
    // 3. Has the required walk details
    // 4. Is not currently in an active walk
    if (!_isWalker && isSuspicious && walkId != null && walkId.isNotEmpty && amount != null &&
        (_user?.activeWalkId == null || _user!.activeWalkId!.isEmpty)) {

      _showSuspiciousDialog(walkId, amount);

    } else if (!isSuspicious && _isSuspiciousDialogOpen) {
      // Condition for dismissing the dialog (e.g., payment succeeded on another device or admin cleared it)
      // Safely dismiss the dialog if it's currently showing and the suspicion flag is cleared.
      Navigator.of(context).popUntil((route) => route.isFirst);
      _isSuspiciousDialogOpen = false;
      debugPrint("✅ Suspension lifted and dialog dismissed.");
    }
  }

  Future<void> _updateFcmToken() async {
    // ... (existing implementation)
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'fcmToken': token},
      );

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
          final data = doc.data()!;
          final userModel = UserModel.fromMap(data);

          final userRole = data['role'];
          final isWalker =
              userRole != null &&
                  (userRole.toString().toLowerCase() == 'walker' ||
                      userRole.toString() == 'Walker');

          final newActiveWalkId = userModel.activeWalkId;
          final oldActiveWalkId = _user?.activeWalkId;

          // --- [START OF WALK FINISH LOGIC] ---
          if (oldActiveWalkId != null &&
              oldActiveWalkId.isNotEmpty &&
              (newActiveWalkId == null || newActiveWalkId.isEmpty) &&
              !_isCheckingForSummary) {

            debugPrint("HomeScreen: Detected activeWalkId removed. A walk has finished.");

            setState(() {
              _user = userModel;
              _isWalker = isWalker;
              _isLoading = false;
              _isCheckingForSummary = true;
            });

            // Check suspension state immediately
            _checkForSuspension();

            _walkStatusSubscription?.cancel();
            _walkStatusSubscription = null;
            setState(() { _activeWalkStatus = null; });

            await _checkAndNavigateToSummary(oldActiveWalkId, isWalker);

            setState(() {
              _isCheckingForSummary = false;
            });

            return; // Exit early
          }
          // --- [END OF WALK FINISH LOGIC] ---

          // This code runs on every update if a walk hasn't just finished
          setState(() {
            _user = userModel;
            _isWalker = isWalker;
            _isLoading = false;
          });

          // [CRITICAL: REAL-TIME SUSPENSION CHECK]
          _checkForSuspension();

          // [MODIFIED] Manage Walk Status Subscription for ANY user
          if (newActiveWalkId != null && newActiveWalkId.isNotEmpty) {
            if (newActiveWalkId != oldActiveWalkId ||
                _walkStatusSubscription == null) {
              _walkStatusSubscription?.cancel();
              _walkStatusSubscription = null;
              setState(() {
                _activeWalkStatus = null;
              });

              _walkStatusSubscription = FirebaseFirestore.instance
                  .collection('accepted_walks')
                  .doc(newActiveWalkId)
                  .snapshots()
                  .listen((walkDoc) {
                if (walkDoc.exists && mounted) {
                  setState(() {
                    _activeWalkStatus =
                    walkDoc.data()?['status'] as String?;
                  });
                  debugPrint(
                    'HomeScreen: Walk status updated to: $_activeWalkStatus',
                  );
                } else if (mounted) {
                  setState(() {
                    _activeWalkStatus = null;
                  });
                }
              });
            }
          } else {
            _walkStatusSubscription?.cancel();
            _walkStatusSubscription = null;
            if (mounted) {
              setState(() {
                _activeWalkStatus = null;
              });
            }
          }

          // Manage Walker location tracking
          if (_isWalker) {
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
        }
      },
      onError: (error) {
        debugPrint('HomeScreen: Error streaming user data: $error');
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  // [NEW] Method to handle navigation to summary
  Future<void> _checkAndNavigateToSummary(String oldWalkId, bool isWalker) async {
    if (!mounted) return;
    debugPrint("HomeScreen: Checking for summary for walk $oldWalkId...");

    try {
      final walkDoc = await FirebaseFirestore.instance
          .collection('accepted_walks')
          .doc(oldWalkId)
          .get();

      if (walkDoc.exists && walkDoc.data()?['summaryAvailable'] == true) {
        debugPrint("HomeScreen: Summary found. Navigating to WalkSummaryScreen.");

        final walkData = walkDoc.data()!;
        final finalStats = walkData['finalStats'] as Map<String, dynamic>? ?? {};

        // Reconstruct the display data needed by the summary screen
        Map<String, dynamic> partnerInfo;
        String partnerName;
        String? partnerImgUrl;
        String? partnerBio;

        // Determine who the partner was
        if (isWalker) {
          partnerInfo = walkData['senderInfo'] as Map<String, dynamic>? ?? {};
          partnerName = partnerInfo['fullName'] ?? 'Wanderer';
          partnerImgUrl = partnerInfo['imageUrl'];
          partnerBio = null;
        } else {
          partnerInfo = walkData['recipientInfo'] as Map<String, dynamic>? ??
              walkData['walkerProfile'] as Map<String, dynamic>? ?? {};
          partnerName = partnerInfo['name'] ?? 'Walker';
          partnerImgUrl = partnerInfo['imageUrl'];
          partnerBio = partnerInfo['bio'];
        }

        final displayData = IncomingRequestDisplay(
          walkId: oldWalkId,
          senderId: walkData['senderId'] ?? '',
          recipientId: walkData['recipientId'] ?? '',
          senderName: partnerName,
          senderImageUrl: partnerImgUrl,
          senderBio: partnerBio,
          date: walkData['date'] ?? '',
          time: walkData['time'] ?? '',
          duration: walkData['duration'] ?? '',
          latitude: (walkData['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (walkData['longitude'] as num?)?.toDouble() ?? 0.0,
          status: walkData['status'] ?? 'Completed',
          distance: (finalStats['finalDistanceKm'] as num?)?.toInt() ?? 0,
          notes: walkData['notes'],
        );

        if (!mounted) return;

        // Navigate to the summary screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WalkSummaryScreen(
              walkData: displayData,
              finalStats: finalStats,
            ),
          ),
        );

      } else {
        debugPrint("HomeScreen: No summary found or doc missing. Just refreshing home.");
      }
    } catch (e) {
      debugPrint("HomeScreen: Error checking for summary: $e");
    }
  }


  @override
  void dispose() {
    _userSubscription?.cancel();
    _walkStatusSubscription?.cancel();
    locationService.stopTracking();
    _pedometerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null && FirebaseAuth.instance.currentUser != null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(body: Center(child: Text("Please log in.")));
    }

    // [SUSPENSION GUARD]: Prevent building the main UI if suspended and not in a walk.
    if (!_isWalker && _user!.isPaymentSuspicious && (_user?.activeWalkId == null || _user!.activeWalkId!.isEmpty)) {
      return const Scaffold(
        body: Center(
          child: Text("Account Suspended. Please complete the payment."),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(child: _getCurrentScreen()),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _getCurrentScreen() {
    final String? activeWalkId = _user?.activeWalkId;
    final String? status = _activeWalkStatus;

    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1: // Walks/Requests Tab
        if (!_isWalker) {
          // Wanderer Logic
          if (activeWalkId != null && activeWalkId.isNotEmpty) {
            if (status == 'Accepted' || status == 'Started') {
              debugPrint(
                "HomeScreen: Wanderer has active walk ($activeWalkId) with status $status, showing WandererActiveWalkScreen.",
              );
              return WandererActiveWalkScreen(walkId: activeWalkId);
            } else if (status == null) {
              debugPrint("HomeScreen: Wanderer waiting for walk status...");
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Checking walk status..."),
                    ],
                  ),
                ),
              );
            }
            debugPrint(
              "HomeScreen: Wanderer has non-active walk ID $activeWalkId with status $status, showing FindWalkerScreen.",
            );
          }
          return const FindWalkerScreen();
        } else {
          // Walker Logic
          if (activeWalkId != null && activeWalkId.isNotEmpty) {
            if (status == 'Accepted' || status == 'Started') {
              debugPrint(
                "HomeScreen: Walker has active walk ($activeWalkId) with status $status, showing WalkActiveScreen.",
              );

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('accepted_walks')
                    .doc(activeWalkId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting ||
                      !snapshot.hasData ||
                      !snapshot.data!.exists) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final senderInfo =
                      data['senderInfo'] as Map<String, dynamic>? ?? {};
                  final walkerProfile = data['walkerProfile'] as Map<String, dynamic>? ?? {};

                  final displayData = IncomingRequestDisplay(
                    walkId: activeWalkId,
                    senderId: data['senderId'] ?? '',
                    recipientId: data['recipientId'] ?? '',
                    senderName: senderInfo['fullName'] ?? 'Wanderer',
                    senderImageUrl: senderInfo['imageUrl'],
                    senderBio: senderInfo['bio'],
                    date: data['date'] ?? '',
                    time: data['time'] ?? '',
                    duration: data['duration'] ?? '',
                    latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
                    longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
                    status: data['status'] ?? 'Accepted',
                    distance: (walkerProfile['distance'] as num?)?.toInt() ?? 0,
                    notes: data['notes'],
                  );

                  return WalkActiveScreen(walkData: displayData);
                },
              );
            }
          }
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

  Widget _buildHomeContent() {
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
                : null,
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
          child: StreamBuilder<int>(
            stream: _pedometerService.stepsTodayStream,
            initialData: _user?.stepsToday ?? 0,
            builder: (context, snapshot) {
              final steps = snapshot.data ?? _user?.stepsToday ?? 0;
              return StatsCard(
                title: 'Steps Today',
                value: steps.toString(),
                onTap: () => _onStatsCardTap('Steps'),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatsCard(
            title: 'Walks\nCompleted',
            value: (_user?.walks ?? walksCompleted).toString(),
            onTap: () => _onStatsCardTap('Walks'),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialImpactCard() {
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
      _currentIndex = 2;
    });
  }

  void _onStatsCardTap(String type) {
    debugPrint('Stats card tapped: $type');
  }

  void _onSocialImpactTap() {
    debugPrint('Social impact card tapped');
  }

  void _onFindWalkerPressed() {
    setState(() {
      _currentIndex = 1;
    });
  }

  void _onIncomingRequestPressed() {
    setState(() {
      _currentIndex = 1;
    });
  }

  void _onViewHistoryPressed() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const WalkHistoryPage()));
  }

  void _onWalkerOfWeekTap() {
    debugPrint('Walker of the week tapped');
  }

  void _onChallengeTap() {
    debugPrint('Challenge tapped');
  }
}