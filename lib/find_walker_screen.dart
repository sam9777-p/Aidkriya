import 'package:flutter/material.dart';

import 'components/map_view_widget.dart';
import 'components/search_bar_widget.dart';
import 'components/view_toggle.dart';
import 'components/walker_card.dart';
import 'model/Walker.dart';

class FindWalkerScreen extends StatefulWidget {
  const FindWalkerScreen({super.key});

  @override
  State<FindWalkerScreen> createState() => _FindWalkerScreenState();
}

class _FindWalkerScreenState extends State<FindWalkerScreen> {
  bool isMapView = true;
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  final List<Walker> walkers = [
    Walker(
      id: '1',
      name: 'Riya S.',
      rating: 4.8,
      distance: 0.8,
      imageUrl: null,
      latitude: 37.7749,
      longitude: -122.4194,
    ),
    Walker(
      id: '2',
      name: 'Ken T.',
      rating: 4.9,
      distance: 1.2,
      imageUrl: null,
      latitude: 37.7849,
      longitude: -122.4094,
    ),
    Walker(
      id: '3',
      name: 'Kdds T.',
      rating: 4.6,
      distance: 3.2,
      imageUrl: null,
      latitude: 37.7649,
      longitude: -122.4294,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildViewToggle(),
          Expanded(child: isMapView ? _buildMapScreen() : _buildListViewOnly()),
        ],
      ),
    );
  }

  Widget _buildMapScreen() {
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      children: [
        // ✅ Map with vertical margins
        // ✅ Smaller map with more space around it
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.33, // reduced height
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: MapViewWidget(
                walkers: walkers,
                onMarkerTapped: _onMarkerTapped,
              ),
            ),
          ),
        ),

        // ✅ Draggable Bottom Sheet (not overlaying map)
        Expanded(
          child: DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.98,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: walkers.length,
                        itemBuilder: (context, index) {
                          return WalkerCard(
                            walker: walkers[index],
                            showInstantWalk: index == 1,
                            onRequestPressed: () =>
                                _onRequestPressed(walkers[index]),
                            onInstantWalkPressed: () =>
                                _onInstantWalkPressed(walkers[index]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ✅ List-only view
  Widget _buildListViewOnly() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: walkers.length,
            itemBuilder: (context, index) {
              return WalkerCard(
                walker: walkers[index],
                showInstantWalk: index == 1,
                onRequestPressed: () => _onRequestPressed(walkers[index]),
                onInstantWalkPressed: () =>
                    _onInstantWalkPressed(walkers[index]),
              );
            },
          ),
        ),
        _buildScheduleWalkButton(),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFf5f5f5),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Find a Walker',
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.tune, color: Colors.black),
          onPressed: _onFilterPressed,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SearchBarWidget(
        controller: _searchController,
        hintText: 'Search by name or interest',
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ViewToggle(
        isMapView: isMapView,
        onToggle: (value) => setState(() => isMapView = value),
      ),
    );
  }

  Widget _buildScheduleWalkButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _onScheduleWalkPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          icon: const Icon(Icons.calendar_today),
          label: const Text(
            'Schedule Walk',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // 🔹 Callbacks / Logic Hooks
  void _onFilterPressed() => print('Filter pressed');
  void _onSearchChanged(String value) => print('Search: $value');
  void _onMarkerTapped(String walkerId) => print('Marker tapped: $walkerId');
  void _onRequestPressed(Walker walker) =>
      print('Request walker: ${walker.name}');
  void _onInstantWalkPressed(Walker walker) =>
      print('Instant walk with: ${walker.name}');
  void _onScheduleWalkPressed() => print('Schedule walk pressed');
}
