import 'dart:async';
import 'dart:developer' as developer;

import 'package:aidkriya_walker/request_walk_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'components/map_view_widget.dart';
import 'components/option_chip.dart';
import 'components/view_toggle.dart';
import 'components/walker_card.dart';
import 'model/Walker.dart';
import 'model/user_model.dart';
import 'model/walker_list_early.dart';
import 'schedule_walk_screen.dart';

import 'screens/group_walk/find_group_walks_screen.dart';

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
  StreamSubscription<DatabaseEvent>? _childRemovedSub;
  Timer? _updateDebounceTimer;
  bool _isLoading = true;
  Position? myPos;
  List<Walker> walkers = [];

  bool isMapView = true;
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  bool _showGroupWalks = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      developer.log('FindWalkerScreen: Initializing...', name: 'FindWalker');

      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        setState(() => _isLoading = false);
        return;
      }

      // [OPTIMIZATION] Try to get last known position first (INSTANT)
      Position? lastKnownPos = await Geolocator.getLastKnownPosition();

      if (lastKnownPos != null) {
        setState(() {
          myPos = lastKnownPos;
          _isLoading = false; // Show UI immediately with cached location
        });
        _startListeningToWalkers(); // Start data stream immediately
      }

      // Then fetch fresh, precise location in background
      myPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5), // Don't wait forever
      );

      // Update UI with fresh location
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Re-trigger listener with new accurate position
        _startListeningToWalkers();
      }

    } catch (e) {
      developer.log('FindWalkerScreen: Error: $e', name: 'FindWalker');
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _walkerSub?.cancel();
    _childAddedSub?.cancel();
    _childChangedSub?.cancel();
    _childRemovedSub?.cancel();
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
          _buildModeToggle(),
          Expanded(
            child: _showGroupWalks
                ? const FindGroupWalksScreen()
                : Column(
              children: [
                _buildViewToggle(),
                Expanded(
                  child: isMapView
                      ? _buildMapScreen()
                      : _buildListViewOnly(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OptionChip(label: '1-on-1', isSelected: !_showGroupWalks, onTap: () => setState(() => _showGroupWalks = false)),
          const SizedBox(width: 16),
          OptionChip(label: 'Group Walks', isSelected: _showGroupWalks, onTap: () => setState(() => _showGroupWalks = true)),
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
          ElevatedButton(onPressed: () { setState(() => _isLoading = true); _initializeScreen(); }, child: const Text('Retry')),
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
                key: ValueKey(walkers.length),
                walkers: walkers,
                onMarkerTapped: _onMarkerTapped,
                initialPosition: myPos,
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, -3))]),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 8),
                    Expanded(
                      child: walkers.isEmpty
                          ? _buildNoWalkersFound()
                          : ListView.builder(controller: scrollController, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: walkers.length, itemBuilder: (context, index) { return WalkerCard(walker: walkers[index], onRequestPressed: () => _onRequestPressed(walkers[index])); }),
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
        Expanded(child: walkers.isEmpty ? _buildNoWalkersFound() : ListView.builder(padding: const EdgeInsets.all(16), itemCount: walkers.length, itemBuilder: (context, index) { return WalkerCard(walker: walkers[index], onRequestPressed: () => _onRequestPressed(walkers[index])); })),
        _buildScheduleWalkButton(),
      ],
    );
  }

  Widget _buildNoWalkersFound() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.directions_walk_outlined, size: 64, color: Colors.grey[400]), const SizedBox(height: 16), Text('No walkers nearby', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]))]));
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(backgroundColor: const Color(0xFFf5f5f5), elevation: 0, centerTitle: true, title: const Text('Find a Walk', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)));
  }

  Widget _buildViewToggle() {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: ViewToggle(isMapView: isMapView, onToggle: (value) => setState(() => isMapView = value)));
  }

  Widget _buildScheduleWalkButton() {
    return Padding(padding: const EdgeInsets.all(16.0), child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: _onScheduleWalkPressed, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: Colors.grey[300]!))), icon: const Icon(Icons.calendar_today), label: const Text('Schedule Walk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))));
  }

  void _startListeningToWalkers() {
    if (myPos == null) { setState(() => _isLoading = false); return; }
    final ref = FirebaseDatabase.instance.ref('locations');
    _childAddedSub = ref.onChildAdded.listen(_handleWalkerUpdate);
    _childChangedSub = ref.onChildChanged.listen(_handleWalkerUpdate);
    _childRemovedSub = ref.onChildRemoved.listen((event) {
      final id = event.snapshot.key;
      if (id != null) setState(() { walkers.removeWhere((w) => w.id == id); });
    });
    setState(() => _isLoading = false);
  }

  void _handleWalkerUpdate(DatabaseEvent event) {
    if (event.snapshot.value == null) return;
    final id = event.snapshot.key!;
    final value = Map<String, dynamic>.from(event.snapshot.value as Map);
    final walkerEarly = WalkerListEarly.fromMap(id, value);
    if (!walkerEarly.active) { setState(() { walkers.removeWhere((w) => w.id == id); }); return; }
    if (walkerEarly.latitude == 0.0 || walkerEarly.longitude == 0.0) return;
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = Timer(const Duration(milliseconds: 500), () async { await _updateWalkerData(walkerEarly); });
  }

  Future<void> _updateWalkerData(WalkerListEarly walkerEarly) async {
    if (myPos == null) return;
    final distance = Geolocator.distanceBetween(myPos!.latitude, myPos!.longitude, walkerEarly.latitude, walkerEarly.longitude) / 1000;
    if (distance > 5) { setState(() { walkers.removeWhere((w) => w.id == walkerEarly.id); }); return; }

    if (!_userCache.containsKey(walkerEarly.id)) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(walkerEarly.id).get();
      if (userDoc.exists) _userCache[walkerEarly.id] = UserModel.fromMap(userDoc.data()!); else return;
    }
    final userModel = _userCache[walkerEarly.id]!;
    final updatedWalker = Walker(id: walkerEarly.id, name: userModel.fullName, rating: userModel.rating.toDouble(), distance: distance.toInt(), imageUrl: userModel.imageUrl, latitude: walkerEarly.latitude, longitude: walkerEarly.longitude, age: userModel.age.toDouble(), bio: userModel.bio);

    setState(() {
      final index = walkers.indexWhere((w) => w.id == walkerEarly.id);
      if (index >= 0) walkers[index] = updatedWalker; else walkers.add(updatedWalker);
      walkers.sort((a, b) => a.distance.compareTo(b.distance));
    });
  }

  void _onMarkerTapped(String walkerId) {}
  void _onRequestPressed(Walker walker) { Navigator.push(context, MaterialPageRoute(builder: (context) => RequestWalkScreen(walker: walker))); }
  void _onScheduleWalkPressed() { Navigator.push(context, MaterialPageRoute(builder: (context) => ScheduleWalkScreen(availableWalkers: walkers))); }
}