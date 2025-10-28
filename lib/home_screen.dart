import 'package:aidkriya_walker/backend/location_service.dart';
import 'package:aidkriya_walker/incoming_requests_screen.dart';
import 'package:aidkriya_walker/profile_screen.dart';
import 'package:aidkriya_walker/social_impact_card.dart';
import 'package:aidkriya_walker/stats_card.dart';
import 'package:aidkriya_walker/walker_of_the_week_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'action_button.dart';
import 'challenge_card.dart';
import 'find_walker_screen.dart';
import 'model/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int stepsToday = 8500;
  int walksCompleted = 12;
  int socialImpact = 250;

  final locationService = LocationService();
  UserModel? _user;
  bool _isWalker = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final userModel = UserModel.fromMap(data);

        // Check role
        final userRole = data['role'];
        final isWalker =
            userRole != null &&
            (userRole.toString().toLowerCase() == 'walker' ||
                userRole.toString() == 'Walker');

        print('HomeScreen: User role from Firestore: $userRole');
        print('HomeScreen: Is Walker: $isWalker');

        setState(() {
          _user = userModel;
          _isWalker = isWalker;
        });

        // ✅ Start location tracking if Walker
        // LocationService now handles role verification internally as well
        if (_isWalker && mounted) {
          print('HomeScreen: Starting location tracking for Walker');
          await locationService.startTracking(context);
        } else {
          print('HomeScreen: Not starting tracking - User is not a Walker');
          // Ensure tracking is stopped for non-walkers
          await locationService.stopTracking();
        }
      }
    } catch (e) {
      print('HomeScreen: Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    // Always stop tracking when screen is disposed
    locationService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(child: _getCurrentScreen()),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _isWalker
            ? const IncomingRequestsScreen()
            : const FindWalkerScreen();
      case 2:
        return const Center(
          child: Text('Community coming soon!', style: TextStyle(fontSize: 24)),
        );
      case 3:
        return const ProfileScreen();
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }

  Widget _buildHomeContent() {
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
          _buildCommunityHighlights(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'aidKRIYA Walker',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        GestureDetector(
          onTap: _navigateToProfile,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            backgroundImage: _user?.imageUrl != null
                ? NetworkImage(_user!.imageUrl!)
                : null,
            child: _user?.imageUrl == null
                ? Icon(Icons.person, color: Colors.grey[600])
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Row(
      children: [
        Text(
          'Good morning, ${_user?.fullName.split(' ').first ?? 'User'} ',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black,
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
            value: stepsToday.toString(),
            onTap: () => _onStatsCardTap('Steps'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatsCard(
            title: 'Walks\nCompleted',
            value: walksCompleted.toString(),
            onTap: () => _onStatsCardTap('Walks'),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialImpactCard() {
    return SocialImpactCard(amount: socialImpact, onTap: _onSocialImpactTap);
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
          text: 'View History',
          color: Colors.white,
          textColor: Colors.black,
          borderColor: Colors.grey[300],
          onPressed: _onViewHistoryPressed,
        ),
      ],
    );
  }

  Widget _buildCommunityHighlights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Community Highlights',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              WalkerOfTheWeekCard(
                name: 'Sarah L.',
                steps: '25,000 steps',
                imageUrl: null,
                onTap: _onWalkerOfWeekTap,
              ),
              const SizedBox(width: 16),
              ChallengeCard(
                title: 'Weekend Walk',
                description: 'Walk 15km this weekend to earn a badge!',
                onTap: _onChallengeTap,
              ),
            ],
          ),
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
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Community',
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
    print('Navigate to profile');
  }

  void _onStatsCardTap(String type) {
    print('Stats card tapped: $type');
  }

  void _onSocialImpactTap() {
    print('Social impact card tapped');
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
    print('View history pressed');
  }

  void _onWalkerOfWeekTap() {
    print('Walker of the week tapped');
  }

  void _onChallengeTap() {
    print('Challenge tapped');
  }
}
