import 'dart:async';
import 'dart:developer' as developer;

import 'package:aidkriya_walker/request_walk_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'backend/location_service.dart';
import 'components/map_view_widget.dart';
import 'components/view_toggle.dart';
import 'components/walker_card.dart';
import 'model/Walker.dart';
import 'model/user_model.dart';
import 'model/walker_list_early.dart';

class FindWalkerScreen extends StatefulWidget {
  const FindWalkerScreen({super.key});

  @override
  State<FindWalkerScreen> createState() => _FindWalkerScreenState();
}

class _FindWalkerScreenState extends State<FindWalkerScreen> {
  StreamSubscription? _walkerSub;
  bool _isLoading = true;
  Position? myPos;
  Set<Marker> _markers = {};
  List<Walker> walkers = [];

  bool isMapView = true;
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  final locationService = LocationService();

  @override
  void initState() {
    locationService.startTracking(context);
    _startListeningToWalkers();
    super.initState();
  }

  @override
  void dispose() {
    locationService.stopTracking();
    _searchController.dispose();
    _walkerSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildViewToggle(),
                Expanded(
                  child: isMapView ? _buildMapScreen() : _buildListViewOnly(),
                ),
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
      centerTitle: true,
      title: const Text(
        'Find a Walker',
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
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

  Stream<List<WalkerListEarly>> listenToActiveWalkers() async* {
    final ref = FirebaseDatabase.instance.ref('locations');

    await for (final event in ref.onValue) {
      final data = event.snapshot.value as Map?;
      developer.log("Raw snapshot: $data", name: "FirebaseListener");

      if (data == null) {
        developer.log("No data found.", name: "FirebaseListener");
        yield [];
        continue;
      }

      List<WalkerListEarly> activeWalkers = [];

      data.forEach((key, value) {
        developer.log("Walker node $key: $value", name: "FirebaseListener");

        final walker = WalkerListEarly.fromMap(
          key,
          Map<String, dynamic>.from(value),
        );

        if (walker.active) {
          activeWalkers.add(walker);
        }
      });

      developer.log(
        "Active walkers: ${activeWalkers.length}",
        name: "FirebaseListener",
      );
      yield activeWalkers;
    }
  }

  void _startListeningToWalkers() async {
    setState(() => _isLoading = true);

    myPos = await Geolocator.getCurrentPosition();

    _walkerSub = listenToActiveWalkers().listen((activeWalkers) async {
      if (!mounted) return;

      // Filter nearby walkers
      final nearbyWalkers = await getNearbyWalkers(myPos!, activeWalkers);

      // Sort by distance (if not already)
      nearbyWalkers.sort((a, b) => a.distance!.compareTo(b.distance!));

      // Fetch user profiles from Firestore
      final walkersWithProfiles = await _attachUserData(nearbyWalkers);

      if (!mounted) return;

      // Update map markers
      _updateMarkers(walkersWithProfiles);

      // ✅ Hide loader after first successful fetch
      setState(() => _isLoading = false);
    });
  }

  Future<List<Walker>> _attachUserData(List<WalkerListEarly> walkers) async {
    final firestore = FirebaseFirestore.instance;

    // Run all Firestore fetches in parallel
    final futures = walkers.map((w) async {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(w.id)
          .get();
      debugPrint("Doc exists: ${doc.exists}");
      debugPrint("Doc data: ${doc.data()}");

      if (!doc.exists) return Future.value(); // skip silently

      final userModel = UserModel.fromMap(doc.data()!);
      return Walker(
        id: w.id,
        name: userModel.fullName,
        rating: userModel.rating.toDouble(),
        distance: w.distance ?? 0.0,
        imageUrl: userModel.imageUrl,
        latitude: w.latitude,
        longitude: w.longitude,
        age: userModel.age.toDouble(),
        bio: userModel.bio,
      );
    });

    final result = await Future.wait(futures);
    return result.whereType<Walker>().toList();
  }

  Future<List<WalkerListEarly>> getNearbyWalkers(
    Position myPos,
    List<WalkerListEarly> allWalkers,
  ) async {
    const double maxDistanceKm = 5;

    List<WalkerListEarly> nearby = [];

    for (var walker in allWalkers) {
      double distance =
          Geolocator.distanceBetween(
            myPos.latitude,
            myPos.longitude,
            walker.latitude,
            walker.longitude,
          ) /
          1000;

      if (distance <= maxDistanceKm) {
        walker.distance = distance; // attach distance
        nearby.add(walker);
      }
    }

    nearby.sort((a, b) => a.distance!.compareTo(b.distance!));

    return nearby;
  }

  void _updateMarkers(List<Walker> nearbyWalkers) {
    final newMarkers = <Marker>{};
    for (var walker in nearbyWalkers) {
      newMarkers.add(
        Marker(
          markerId: MarkerId(walker.name ?? 'guest'),
          position: LatLng(walker.latitude, walker.longitude),
          infoWindow: InfoWindow(title: 'Walker: ${walker.name}'),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
      walkers = nearbyWalkers;
      print(nearbyWalkers);
    });
  }

  void _onMarkerTapped(String walkerId) => print('Marker tapped: $walkerId');
  void _onRequestPressed(Walker walker) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestWalkScreen(walker: walker),
      ),
    );
  }

  void _onInstantWalkPressed(Walker walker) =>
      print('Instant walk with: ${walker.id}');
  void _onScheduleWalkPressed() => print('Schedule walk pressed');
}
