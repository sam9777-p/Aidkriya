import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService with WidgetsBindingObserver {
  StreamSubscription<Position>? _positionStream;
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("locations");
  final userId = FirebaseAuth.instance.currentUser?.uid ?? "guest";

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  /// Start tracking location - ONLY for Walkers
  Future<void> startTracking(BuildContext context) async {
    // 🔒 Prevent starting if already tracking
    if (_isTracking) {
      print('LocationService: Already tracking, skipping...');
      return;
    }

    // 🔒 CRITICAL: Verify user is a Walker before starting
    bool isWalker = await _verifyUserIsWalker();
    if (!isWalker) {
      print('LocationService: User is not a Walker. Location tracking denied.');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location tracking is only available for Walkers'),
          ),
        );
      }
      return;
    }

    print(
      'LocationService: User verified as Walker. Starting location tracking...',
    );

    WidgetsBinding.instance.addObserver(this);

    bool hasPermission = await _handleLocationPermission(context);
    if (!hasPermission) return;

    await dbRef.child(userId).update({
      'active': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          dbRef.child(userId).update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        });

    _isTracking = true;
    print('LocationService: Location tracking started successfully');
  }

  Future<void> stopTracking() async {
    if (!_isTracking) {
      print('LocationService: Not tracking, nothing to stop');
      return;
    }

    print('LocationService: Stopping location tracking...');

    await dbRef.child(userId).update({'active': false});
    await _positionStream?.cancel();
    _positionStream = null;
    WidgetsBinding.instance.removeObserver(this);

    _isTracking = false;
    print('LocationService: Location tracking stopped');
  }

  /// 🔒 Verify the current user has Walker role
  Future<bool> _verifyUserIsWalker() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('LocationService: No authenticated user');
        return false;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        print('LocationService: User document does not exist');
        return false;
      }

      final data = doc.data();
      if (data == null) {
        print('LocationService: User document has no data');
        return false;
      }

      final userRole = data['role'];
      final isWalker =
          userRole != null &&
          (userRole.toString().toLowerCase() == 'walker' ||
              userRole.toString() == 'Walker');

      print('LocationService: User role = $userRole, isWalker = $isWalker');
      return isWalker;
    } catch (e) {
      print('LocationService: Error verifying user role: $e');
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isTracking) return; // Don't do anything if not tracking

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      dbRef.child(userId).update({'active': false});
      _positionStream?.pause();
      print('LocationService: App paused, tracking paused');
    } else if (state == AppLifecycleState.resumed) {
      dbRef.child(userId).update({'active': true});
      _positionStream?.resume();
      print('LocationService: App resumed, tracking resumed');
    }
  }

  Future<bool> _handleLocationPermission(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required')),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission permanently denied. Please enable it in settings.',
            ),
          ),
        );
      }
      return false;
    }

    return true;
  }

  /// Helper method to check if user is Walker without starting tracking
  Future<bool> checkIfUserIsWalker() async {
    return await _verifyUserIsWalker();
  }
}
