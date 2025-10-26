import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService with WidgetsBindingObserver {
  StreamSubscription<Position>? _positionStream;
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("locations");
  final userId = FirebaseAuth.instance.currentUser?.uid ?? "guest";

  Future<void> startTracking(BuildContext context) async {
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
          });
        });
  }

  Future<void> stopTracking() async {
    await dbRef.child(userId).update({'active': false});
    _positionStream?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      dbRef.child(userId).update({'active': false});
      _positionStream?.pause();
    } else if (state == AppLifecycleState.resumed) {
      dbRef.child(userId).update({'active': false});
      _positionStream?.resume();
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<bool> _handleLocationPermission(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services')),
      );
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required')),
        );
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission permanently denied. Please enable it in settings.',
          ),
        ),
      );
      return false;
    }

    return true;
  }
}
