import 'dart:async';

import 'package:aidkriya_walker/backend/location_service.dart';
import 'package:aidkriya_walker/incoming_requests_screen.dart';
import 'package:aidkriya_walker/payment_screen.dart';
import 'package:aidkriya_walker/profile_screen.dart';
import 'package:aidkriya_walker/screens/walk_active_screen.dart';
import 'package:aidkriya_walker/social_impact_card.dart';
import 'package:aidkriya_walker/stats_card.dart';
import 'package:aidkriya_walker/walk_history_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

import 'action_button.dart';
import 'backend/pedometer_service.dart';
import 'find_walker_screen.dart';
import 'model/incoming_request_display.dart';
import 'model/user_model.dart';
import 'screens/walk_summary_screen.dart';
import 'screens/wanderer_active_walk_screen.dart';

// [NEW] Group Walk Imports
import 'screens/group_walk/create_group_walk_screen.dart';
import 'screens/group_walk/group_walk_active_screen.dart';
import 'screens/group_walk/group_walk_summary_screen.dart';
import 'screens/group_walk/group_walk_details_screen.dart';

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

  // [CRITICAL] Payment Suspension State
  bool _isSuspiciousDialogOpen = false;

  final locationService = LocationService();
  UserModel? _user;
  bool _isWalker = false;
  bool _isLoading = true;

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // Walk States
  StreamSubscription<DocumentSnapshot>? _walkStatusSubscription;
  String? _activeWalkStatus;

  // Group Walk State
  StreamSubscription<DocumentSnapshot>? _groupWalkStatusSubscription;
  String? _activeGroupWalkStatus;

  bool _isCheckingForSummary = false;

  @override
  void initState() {
    super.initState();
    _subscribeToUserData();
    _updateFcmToken();
    _pedometerService.init();
  }

  // --- [SUSPENSION LOGIC START] ---
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
            title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text('Account Suspended', style: TextStyle(color: Colors.red))]),
            content: const Text('Your account has been suspended due to an uncompleted payment. Please complete the payment to restore access.'),
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  await _raisePaymentIssueTicket(walkId, amount);
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Issue reported. Admin will review.")));
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
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => PaymentScreen(amount: amount, walkId: walkId)));
                },
                child: const Text('Pay Now', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

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

  void _checkForSuspension() {
    if (!mounted || _isLoading || _user == null) return;
    final bool isSuspicious = _user!.isPaymentSuspicious;
    final String? walkId = _user!.suspiciousWalkId;
    final double? amount = _user!.suspiciousAmount;

    if (!_isWalker && isSuspicious && walkId != null && walkId.isNotEmpty && amount != null && (_user?.activeWalkId == null || _user!.activeWalkId!.isEmpty)) {
      _showSuspiciousDialog(walkId, amount);
    } else if (!isSuspicious && _isSuspiciousDialogOpen) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      _isSuspiciousDialogOpen = false;
    }
  }
  // --- [SUSPENSION LOGIC END] ---

  Future<void> _updateFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint("❌ Error updating FCM token: $e");
    }
  }

  // --- [MAIN SUBSCRIPTION LOGIC] ---
  Future<void> _subscribeToUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _userSubscription = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((doc) async {
      if (!mounted) return;
      if (!doc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final data = doc.data()!;
      final userModel = UserModel.fromMap(data);
      final userRole = data['role'];
      final isWalker = userRole != null && (userRole.toString().toLowerCase() == 'walker' || userRole.toString() == 'Walker');

      final newActiveWalkId = userModel.activeWalkId;
      final oldActiveWalkId = _user?.activeWalkId;
      final newActiveGroupWalkId = userModel.activeGroupWalkId;
      final oldActiveGroupWalkId = _user?.activeGroupWalkId;

      // 1. 1-on-1 Walk Finished
      if (oldActiveWalkId != null && oldActiveWalkId.isNotEmpty && (newActiveWalkId == null || newActiveWalkId.isEmpty) && !_isCheckingForSummary) {
        setState(() { _user = userModel; _isWalker = isWalker; _isLoading = false; _isCheckingForSummary = true; });
        _checkForSuspension();
        _walkStatusSubscription?.cancel(); _walkStatusSubscription = null; setState(() { _activeWalkStatus = null; });
        await _checkAndNavigateToSummary(oldActiveWalkId, isWalker);
        if (mounted) setState(() { _isCheckingForSummary = false; });
        return;
      }

      // 2. Group Walk Finished
      if (oldActiveGroupWalkId != null && oldActiveGroupWalkId.isNotEmpty && (newActiveGroupWalkId == null || newActiveGroupWalkId.isEmpty) && !_isCheckingForSummary) {
        setState(() { _user = userModel; _isWalker = isWalker; _isLoading = false; _isCheckingForSummary = true; });
        _groupWalkStatusSubscription?.cancel(); _groupWalkStatusSubscription = null; setState(() { _activeGroupWalkStatus = null; });
        await _checkAndNavigateToGroupSummary(oldActiveGroupWalkId, isWalker);
        if (mounted) setState(() { _isCheckingForSummary = false; });
        return;
      }

      setState(() { _user = userModel; _isWalker = isWalker; _isLoading = false; });
      _checkForSuspension(); // Check suspension on every update

      // 3. Manage 1-on-1 Status Listener
      if (newActiveWalkId != null && newActiveWalkId.isNotEmpty) {
        if (newActiveWalkId != oldActiveWalkId || _walkStatusSubscription == null) {
          _walkStatusSubscription?.cancel(); _walkStatusSubscription = null; setState(() { _activeWalkStatus = null; });
          _walkStatusSubscription = FirebaseFirestore.instance.collection('accepted_walks').doc(newActiveWalkId).snapshots().listen((walkDoc) {
            if (walkDoc.exists && mounted) setState(() { _activeWalkStatus = walkDoc.data()?['status'] as String?; });
            else if (mounted) setState(() { _activeWalkStatus = null; });
          });
        }
      } else {
        _walkStatusSubscription?.cancel(); _walkStatusSubscription = null; if (mounted) setState(() { _activeWalkStatus = null; });
      }

      // 4. Manage Group Status Listener
      if (newActiveGroupWalkId != null && newActiveGroupWalkId.isNotEmpty) {
        if (newActiveGroupWalkId != oldActiveGroupWalkId || _groupWalkStatusSubscription == null) {
          _groupWalkStatusSubscription?.cancel(); _groupWalkStatusSubscription = null; setState(() { _activeGroupWalkStatus = null; });
          _groupWalkStatusSubscription = FirebaseFirestore.instance.collection('group_walks').doc(newActiveGroupWalkId).snapshots().listen((walkDoc) {
            if (walkDoc.exists && mounted) setState(() { _activeGroupWalkStatus = walkDoc.data()?['status'] as String?; });
            else if (mounted) setState(() { _activeGroupWalkStatus = null; });
          });
        }
      } else {
        _groupWalkStatusSubscription?.cancel(); _groupWalkStatusSubscription = null; if (mounted) setState(() { _activeGroupWalkStatus = null; });
      }

      if (_isWalker) { if (mounted) await locationService.startTracking(context); }
      else { await locationService.stopTracking(); }
    },
      onError: (error) { if (mounted) setState(() => _isLoading = false); },
    );
  }

  // --- [SUMMARY NAVIGATION HELPERS] ---
  Future<void> _checkAndNavigateToSummary(String oldWalkId, bool isWalker) async {
    if (!mounted) return;
    try {
      final walkDoc = await FirebaseFirestore.instance.collection('accepted_walks').doc(oldWalkId).get();
      if (walkDoc.exists && walkDoc.data()?['summaryAvailable'] == true) {
        final walkData = walkDoc.data()!;
        final finalStats = walkData['finalStats'] as Map<String, dynamic>? ?? {};
        Map<String, dynamic> partnerInfo;
        String partnerName;
        String? partnerImgUrl;
        String? partnerBio;

        if (isWalker) {
          partnerInfo = walkData['senderInfo'] as Map<String, dynamic>? ?? {};
          partnerName = partnerInfo['fullName'] ?? 'Wanderer';
          partnerImgUrl = partnerInfo['imageUrl'];
          partnerBio = null;
        } else {
          partnerInfo = walkData['recipientInfo'] as Map<String, dynamic>? ?? walkData['walkerProfile'] as Map<String, dynamic>? ?? {};
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
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => WalkSummaryScreen(walkData: displayData, finalStats: finalStats)));
      }
    } catch (e) { debugPrint("Error checking for summary: $e"); }
  }

  Future<void> _checkAndNavigateToGroupSummary(String oldWalkId, bool isWalker) async {
    if (!mounted) return;
    try {
      final walkDoc = await FirebaseFirestore.instance.collection('group_walks').doc(oldWalkId).get();
      if (walkDoc.exists && walkDoc.data()?['status'] == 'Completed') {
        final walkData = walkDoc.data()!;
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => GroupWalkSummaryScreen(walkId: oldWalkId, walkData: walkData, isWalker: isWalker)));
      }
    } catch (e) { debugPrint("Error checking for group summary: $e"); }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _walkStatusSubscription?.cancel();
    _groupWalkStatusSubscription?.cancel();
    locationService.stopTracking();
    _pedometerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _user == null && FirebaseAuth.instance.currentUser != null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(body: Center(child: Text("Please log in.")));
    }

    // [SUSPENSION GUARD]
    if (!_isWalker && _user!.isPaymentSuspicious && (_user?.activeWalkId == null || _user!.activeWalkId!.isEmpty)) {
      return const Scaffold(body: Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("Account Suspended.\nPlease check the alert to complete pending payment.", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // [NEW] Floating Action Button for Walkers
      floatingActionButton: _isWalker && _currentIndex == 0
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreateGroupWalkScreen()));
        },
        icon: const Icon(Icons.group_add),
        label: const Text("Create Group Walk"),
        backgroundColor: const Color(0xFF6BCBA6),
      )
          : null,

      body: SafeArea(child: _getCurrentScreen()),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _getCurrentScreen() {
    final String? activeWalkId = _user?.activeWalkId;
    final String? status = _activeWalkStatus;
    final String? activeGroupWalkId = _user?.activeGroupWalkId;
    final String? groupStatus = _activeGroupWalkStatus;

    // 1. Check 1-on-1
    if (activeWalkId != null && activeWalkId.isNotEmpty && (status == 'Accepted' || status == 'Started')) {
      if (_isWalker) return _buildWalkerActiveScreen(activeWalkId);
      else return WandererActiveWalkScreen(walkId: activeWalkId);
    }

    // 2. Check Group
    if (activeGroupWalkId != null && activeGroupWalkId.isNotEmpty && (groupStatus == 'Scheduled' || groupStatus == 'Started')) {
      return GroupWalkActiveScreen(walkId: activeGroupWalkId, isWalker: _isWalker);
    }

    switch (_currentIndex) {
      case 0: return _buildHomeContent();
      case 1: return !_isWalker ? const FindWalkerScreen() : const IncomingRequestsScreen();
      case 2: return const ProfileScreen();
      default: return const Center(child: Text('Unknown tab'));
    }
  }

  // --- [NEW] Scheduled Group Walks List for Walker ---
  Widget _buildScheduledGroupWalks() {
    if (!_isWalker || _user?.id == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('group_walks')
          .where('walkerId', isEqualTo: _user!.id)
          .where('status', isEqualTo: 'Scheduled')
          .orderBy('scheduledTime')
          .snapshots(),
      builder: (context, snapshot) {
        // [FIX] Handle errors (Missing Index) gracefully
        if (snapshot.hasError) {
          debugPrint("Firestore Error (Likely missing index): ${snapshot.error}");
          // Return empty so it doesn't crash the UI while index builds
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
              child: Text("My Upcoming Group Walks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final Timestamp? ts = data['scheduledTime'] as Timestamp?;
                final DateTime time = ts?.toDate() ?? DateTime.now();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: const Icon(Icons.groups, color: Colors.green),
                    ),
                    title: Text(data['title'] ?? "Group Walk", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(DateFormat('MMM d, h:mm a').format(time)),
                        Text("${data['participantCount']}/${data['maxParticipants']} joined • ₹${data['price']}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6BCBA6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => GroupWalkDetailsScreen(walkId: doc.id),
                        ));
                      },
                      child: const Text("View", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // --- [EXISTING WIDGETS] ---

  Widget _buildWalkerActiveScreen(String activeWalkId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('accepted_walks').doc(activeWalkId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final senderInfo = data['senderInfo'] as Map<String, dynamic>? ?? {};
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

          // [NEW] Group Walks List is here
          _buildScheduledGroupWalks(),

          const SizedBox(height: 32),
          _buildActionButtons(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ... (Rest of the widgets: _buildHeader, _buildGreeting, _buildStatsCards, etc. are unchanged)
  Widget _buildHeader() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Flexible(child: Text('aidKRIYA Walker', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black))),
      GestureDetector(
        onTap: _navigateToProfile,
        child: CircleAvatar(radius: 20, backgroundColor: Colors.grey[300], backgroundImage: _user?.imageUrl != null && _user!.imageUrl!.isNotEmpty ? NetworkImage(_user!.imageUrl!) : null, child: (_user?.imageUrl == null || _user!.imageUrl!.isEmpty) ? Icon(Icons.person, color: Colors.grey[600]) : null),
      ),
    ]);
  }
  Widget _buildGreeting() {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(child: Text('Welcome, ${_user?.fullName.split(' ').first ?? 'User'} ', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black), overflow: TextOverflow.ellipsis, maxLines: 1)),
      const Text('👋', style: TextStyle(fontSize: 32)),
    ]);
  }
  Widget _buildStatsCards() {
    return Row(children: [
      Expanded(child: StreamBuilder<int>(stream: _pedometerService.stepsTodayStream, initialData: _user?.stepsToday ?? 0, builder: (context, snapshot) { final steps = snapshot.data ?? _user?.stepsToday ?? 0; return StatsCard(title: 'Steps Today', value: steps.toString(), onTap: () => _onStatsCardTap('Steps')); })),
      const SizedBox(width: 16),
      Expanded(child: StatsCard(title: 'Walks\nCompleted', value: (_user?.walks ?? walksCompleted).toString(), onTap: () => _onStatsCardTap('Walks'))),
    ]);
  }
  Widget _buildSocialImpactCard() { return SocialImpactCard(amount: (_user?.earnings ?? socialImpact), onTap: _onSocialImpactTap); }
  Widget _buildActionButtons() { return Column(children: [ ActionButton(text: _isWalker ? 'Incoming Requests' : 'Find a Walker', color: const Color(0xFF00E676), textColor: Colors.black, onPressed: _isWalker ? _onIncomingRequestPressed : _onFindWalkerPressed), const SizedBox(height: 16), ActionButton(text: 'My Walks', color: Colors.white, textColor: Colors.black, borderColor: Colors.grey[300], onPressed: _onViewHistoryPressed)]); }
  Widget _buildBottomNavigationBar() { return Container(decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]), child: BottomNavigationBar(currentIndex: _currentIndex, onTap: (index) => setState(() => _currentIndex = index), type: BottomNavigationBarType.fixed, backgroundColor: Colors.white, selectedItemColor: const Color(0xFF00E676), unselectedItemColor: Colors.grey[600], items: [ const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'), BottomNavigationBarItem(icon: Icon(Icons.directions_walk_outlined), activeIcon: Icon(Icons.directions_walk), label: _isWalker ? 'Requests' : 'Walks'), const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile') ])); }
  void _navigateToProfile() => setState(() => _currentIndex = 2);
  void _onStatsCardTap(String type) => debugPrint('Stats card tapped: $type');
  void _onSocialImpactTap() => debugPrint('Social impact card tapped');
  void _onFindWalkerPressed() => setState(() => _currentIndex = 1);
  void _onIncomingRequestPressed() => setState(() => _currentIndex = 1);
  void _onViewHistoryPressed() => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WalkHistoryPage()));
}