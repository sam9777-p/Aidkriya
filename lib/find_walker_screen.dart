import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'backend/location_service.dart';
import 'components/map_view_widget.dart';
import 'components/view_toggle.dart';
import 'components/walker_card.dart';
import 'model/walker_list_early.dart';

class FindWalkerScreen extends StatefulWidget {
  const FindWalkerScreen({super.key});

  @override
  State<FindWalkerScreen> createState() => _FindWalkerScreenState();
}

class _FindWalkerScreenState extends State<FindWalkerScreen> {
  StreamSubscription? _walkerSub;
  Position? myPos;
  Set<Marker> _markers = {};
  List<WalkerListEarly> walkers = [];

  bool isMapView = true;
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // final List<Walker> walkers = [
  //   Walker(
  //     id: '1',
  //     name: 'Riya S.',
  //     rating: 4.8,
  //     distance: 0.8,
  //     imageUrl: null,
  //     latitude: 37.7749,
  //     longitude: -122.4194,
  //   ),
  //   Walker(
  //     id: '2',
  //     name: 'Ken T.',
  //     rating: 4.9,
  //     distance: 1.2,
  //     imageUrl: null,
  //     latitude: 37.7849,
  //     longitude: -122.4094,
  //   ),
  //   Walker(
  //     id: '3',
  //     name: 'Kdds T.',
  //     rating: 4.6,
  //     distance: 3.2,
  //     imageUrl: null,
  //     latitude: 37.7649,
  //     longitude: -122.4294,
  //   ),
  // ];

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
  void setState(VoidCallback fn) {
    // TODO: implement setState
    super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: Column(
        children: [
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
    myPos = await Geolocator.getCurrentPosition();

    _walkerSub = listenToActiveWalkers().listen((activeWalkers) async {
      // Filter nearby (<= 5 km)
      final nearbyWalkers = await getNearbyWalkers(myPos!, activeWalkers);

      // Update map markers
      _updateMarkers(nearbyWalkers);
    });
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

  void _updateMarkers(List<WalkerListEarly> nearbyWalkers) {
    final newMarkers = <Marker>{};
    for (var walker in nearbyWalkers) {
      newMarkers.add(
        Marker(
          markerId: MarkerId(walker.id),
          position: LatLng(walker.latitude, walker.longitude),
          infoWindow: InfoWindow(title: 'Walker: ${walker.id}'),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
      walkers = nearbyWalkers;
      print(nearbyWalkers);
    });
  }

  // 🔹 Callbacks / Logic Hooks
  void _onFilterPressed() => print('Filter pressed');
  void _onSearchChanged(String value) => print('Search: $value');
  void _onMarkerTapped(String walkerId) => print('Marker tapped: $walkerId');
  void _onRequestPressed(WalkerListEarly walker) =>
      print('Request walker: ${walker.id}');
  void _onInstantWalkPressed(WalkerListEarly walker) =>
      print('Instant walk with: ${walker.id}');
  void _onScheduleWalkPressed() => print('Schedule walk pressed');
}
