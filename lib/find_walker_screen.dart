import 'dart:async';
import 'dart:developer' as developer;

import 'package:aidkriya_walker/request_walk_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'components/map_view_widget.dart';
import 'components/view_toggle.dart';
import 'components/walker_card.dart';
import 'model/Walker.dart';
import 'model/schedule_walk_screen.dart';
import 'model/user_model.dart';
import 'model/walker_list_early.dart';

class FindWalkerScreen extends StatefulWidget {
  const FindWalkerScreen({super.key});

  @override
  State<FindWalkerScreen> createState() => _FindWalkerScreenState();
}

class _FindWalkerScreenState extends State<FindWalkerScreen> {
  StreamSubscription? _walkerSub;
  Map<String, UserModel> _userCache = {};
  StreamSubscription<DatabaseEvent>? _childAddedSub;
  StreamSubscription<DatabaseEvent>? _childChangedSub;
  Timer? _updateDebounceTimer;
  bool _isLoading = true;
  Position? myPos;
  Set<Marker> _markers = {};
  List<Walker> walkers = [];

  bool isMapView = true;
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  // ✅ Fixed initialization - get location first, then listen
  Future<void> _initializeScreen() async {
    try {
      developer.log('FindWalkerScreen: Initializing...', name: 'FindWalker');

      // Check location permission
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        developer.log(
          'FindWalkerScreen: No location permission',
          name: 'FindWalker',
        );
        setState(() => _isLoading = false);
        return;
      }

      // Get current position (one-time, no tracking needed)
      developer.log(
        'FindWalkerScreen: Getting current position...',
        name: 'FindWalker',
      );
      myPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      developer.log(
        'FindWalkerScreen: Got position: ${myPos?.latitude}, ${myPos?.longitude}',
        name: 'FindWalker',
      );

      // Now start listening to walkers
      _startListeningToWalkers();
    } catch (e) {
      developer.log(
        'FindWalkerScreen: Error initializing: $e',
        name: 'FindWalker',
      );
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required')),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission permanently denied'),
          ),
        );
      }
      return false;
    }

    return true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _walkerSub?.cancel();
    _childAddedSub?.cancel();
    _childChangedSub?.cancel();
    _updateDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : myPos == null
          ? _buildLocationError()
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

  Widget _buildLocationError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Unable to get your location',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please enable location services',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _initializeScreen();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMapScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.33,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: MapViewWidget(
                walkers: walkers,
                onMarkerTapped: _onMarkerTapped,
              ),
            ),
          ),
        ),
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
                      child: walkers.isEmpty
                          ? _buildNoWalkersFound()
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: walkers.length,
                              itemBuilder: (context, index) {
                                return WalkerCard(
                                  walker: walkers[index],
                                  onRequestPressed: () =>
                                      _onRequestPressed(walkers[index]),
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

  Widget _buildListViewOnly() {
    return Column(
      children: [
        Expanded(
          child: walkers.isEmpty
              ? _buildNoWalkersFound()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: walkers.length,
                  itemBuilder: (context, index) {
                    return WalkerCard(
                      walker: walkers[index],
                      onRequestPressed: () => _onRequestPressed(walkers[index]),
                    );
                  },
                ),
        ),
        _buildScheduleWalkButton(),
      ],
    );
  }

  Widget _buildNoWalkersFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_walk_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No walkers nearby',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try again later or schedule a walk',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
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

  void _startListeningToWalkers() {
    developer.log(
      'FindWalkerScreen: Starting to listen to walkers',
      name: 'FindWalker',
    );

    if (myPos == null) {
      developer.log(
        'FindWalkerScreen: Cannot listen - no position',
        name: 'FindWalker',
      );
      setState(() => _isLoading = false);
      return;
    }

    final ref = FirebaseDatabase.instance.ref('locations');

    // Listen to new walkers being added
    _childAddedSub = ref.onChildAdded.listen((event) {
      _handleWalkerUpdate(event);
    });

    // Listen to location updates for existing walkers
    _childChangedSub = ref.onChildChanged.listen((event) {
      _handleWalkerUpdate(event);
    });

    setState(() => _isLoading = false);
    developer.log('FindWalkerScreen: Started listening', name: 'FindWalker');
  }

  void _handleWalkerUpdate(DatabaseEvent event) {
    if (event.snapshot.value == null) return;

    final id = event.snapshot.key!;
    final value = Map<String, dynamic>.from(event.snapshot.value as Map);

    final walkerEarly = WalkerListEarly.fromMap(id, value);
    developer.log(
      'FindWalkerScreen: Received update for walker $id',
      name: 'FindWalker',
    );

    // Only handle active walkers
    if (!walkerEarly.active) {
      developer.log(
        'FindWalkerScreen: Walker $id is not active',
        name: 'FindWalker',
      );
      return;
    }

    // Throttle updates to prevent rebuilding too often
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _updateWalkerData(walkerEarly);
    });
  }

  Future<void> _updateWalkerData(WalkerListEarly walkerEarly) async {
    if (myPos == null) {
      developer.log(
        'My position is null. Skipping update.',
        name: 'WalkerFilter',
      );
      return;
    }

    final distance =
        Geolocator.distanceBetween(
          myPos!.latitude,
          myPos!.longitude,
          walkerEarly.latitude,
          walkerEarly.longitude,
        ) /
        1000;

    developer.log(
      'Processing ${walkerEarly.id}. Distance: ${distance.toStringAsFixed(2)} km.',
      name: 'WalkerFilter',
    );

    // // Filter walkers by distance
    // if (distance > 5) {
    //   developer.log(
    //     'Walker ${walkerEarly.id} is too far (${distance.toStringAsFixed(2)} km)',
    //     name: 'WalkerFilter',
    //   );
    //   return;
    // }

    // Fetch cached user profile if not already loaded
    if (!_userCache.containsKey(walkerEarly.id)) {
      developer.log(
        'Cache miss for ${walkerEarly.id}. Fetching from Firestore...',
        name: 'WalkerFilter',
      );

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(walkerEarly.id)
          .get();

      if (userDoc.exists) {
        _userCache[walkerEarly.id] = UserModel.fromMap(userDoc.data()!);
        developer.log(
          'Successfully cached ${walkerEarly.id}',
          name: 'WalkerFilter',
        );
      } else {
        developer.log(
          'Walker ${walkerEarly.id} not found in Firestore. Skipping.',
          name: 'WalkerFilter',
        );
        return;
      }
    }

    final userModel = _userCache[walkerEarly.id]!;

    final updatedWalker = Walker(
      id: walkerEarly.id,
      name: userModel.fullName,
      rating: userModel.rating.toDouble(),
      distance: distance.toInt(),
      imageUrl: userModel.imageUrl,
      latitude: walkerEarly.latitude,
      longitude: walkerEarly.longitude,
      age: userModel.age.toDouble(),
      bio: userModel.bio,
    );

    // Merge or update in the local list
    final index = walkers.indexWhere((w) => w.id == walkerEarly.id);
    if (index >= 0) {
      walkers[index] = updatedWalker;
    } else {
      walkers.add(updatedWalker);
    }

    walkers.sort((a, b) => a.distance.compareTo(b.distance));

    if (mounted) {
      setState(() {
        _updateMarkers(walkers);
      });
    }
  }

  void _updateMarkers(List<Walker> nearbyWalkers) {
    final newMarkers = <Marker>{};
    for (var walker in nearbyWalkers) {
      newMarkers.add(
        Marker(
          markerId: MarkerId(walker.id),
          position: LatLng(walker.latitude, walker.longitude),
          infoWindow: InfoWindow(title: walker.name ?? 'Walker'),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _onMarkerTapped(String walkerId) {
    developer.log('Marker tapped: $walkerId', name: 'FindWalker');
  }

  void _onRequestPressed(Walker walker) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestWalkScreen(walker: walker),
      ),
    );
  }

  void _onScheduleWalkPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleWalkScreen(availableWalkers: walkers),
      ),
    );
  }
}
