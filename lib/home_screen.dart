import 'package:aidkriya_walker/backend/location_service.dart';
import 'package:aidkriya_walker/social_impact_card.dart';
import 'package:aidkriya_walker/stats_card.dart';
import 'package:aidkriya_walker/walker_of_the_week_card.dart';
import 'package:flutter/material.dart';

import 'action_button.dart';
import 'challenge_card.dart';

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

  @override
  void initState() {
    locationService.startTracking(context);
    super.initState();
  }

  @override
  void dispose() {
    locationService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: _currentIndex == 0 ? _buildHomeContent() : _buildPlaceholder(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
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
          onTap: () => _navigateToProfile(),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Row(
      children: [
        const Text(
          'Good morning, Alex ',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text('👋', style: TextStyle(fontSize: 32)),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: StatsCard(
            title: 'Steps Today',
            value: stepsToday.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            ),
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
    return SocialImpactCard(
      amount: socialImpact,
      onTap: () => _onSocialImpactTap(),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ActionButton(
          text: 'Find a Walker',
          color: const Color(0xFF00E676),
          textColor: Colors.black,
          onPressed: () => _onFindWalkerPressed(),
        ),
        const SizedBox(height: 16),
        ActionButton(
          text: 'Schedule a Walk',
          color: const Color(0xFFB2F5D9),
          textColor: Colors.black,
          onPressed: () => _onScheduleWalkPressed(),
        ),
        const SizedBox(height: 16),
        ActionButton(
          text: 'View History',
          color: Colors.white,
          textColor: Colors.black,
          borderColor: Colors.grey[300],
          onPressed: () => _onViewHistoryPressed(),
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
                onTap: () => _onWalkerOfWeekTap(),
              ),
              const SizedBox(width: 16),
              ChallengeCard(
                title: 'Weekend Walk',
                description: 'Walk 15km this weekend to earn a badge!',
                onTap: () => _onChallengeTap(),
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
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_walk_outlined),
            activeIcon: Icon(Icons.directions_walk),
            label: 'Walks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        'Tab ${_currentIndex + 1} Content',
        style: const TextStyle(fontSize: 24),
      ),
    );
  }

  // Callback methods - Add your functionality here
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
    print('Find walker pressed');
  }

  void _onScheduleWalkPressed() {
    print('Schedule walk pressed');
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
