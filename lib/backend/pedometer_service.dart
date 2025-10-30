import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class PedometerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<StepCount>? _stepCountStream;
  final StreamController<int> _stepsTodayController =
  StreamController<int>.broadcast();

  /// Public stream for UI to listen to today's step count.
  Stream<int> get stepsTodayStream => _stepsTodayController.stream;

  int _stepsAtSessionStart = 0; // Sensor steps when listener starts
  int _savedStepsToday = 0; // Steps already saved in Firestore for today

  /// Initializes the pedometer service, checks permissions, and starts listening.
  Future<void> init() async {
    final user = _auth.currentUser;
    if (user == null) return; // Not logged in

    // 1. Check Permissions
    var status = await Permission.activityRecognition.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      debugPrint("Pedometer: Activity permission denied.");
      return;
    }

    // 2. Load today's saved steps from Firestore
    await _loadAndResetSteps(user.uid);

    // 3. Get the *current* total steps from sensor to use as an offset
    try {
      // Use Pedometer.stepCountStream.first to get a single, current value
      StepCount event = await Pedometer.stepCountStream.first;
      _stepsAtSessionStart = event.steps;
    } catch (e) {
      debugPrint("Pedometer: Could not get initial step count: $e");
    }

    // 4. Start listening to the stream
    _stepCountStream = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: _onStepCountError,
    );

    // *** THIS IS THE CORRECTED LINE ***
    debugPrint(
        "Pedometer: Service initialized. Saved steps: $_savedStepsToday, Sensor offset: $_stepsAtSessionStart");
  }

  /// Called on every new event from the pedometer sensor.
  void _onStepCount(StepCount event) {
    int stepsThisSession = event.steps - _stepsAtSessionStart;
    if (stepsThisSession < 0) {
      // This can happen if the device reboots.
      // We reset the offset to the new event's steps.
      _stepsAtSessionStart = event.steps;
      stepsThisSession = 0;
    }

    int newTodaySteps = _savedStepsToday + stepsThisSession;

    // Broadcast the new total for the UI
    _stepsTodayController.add(newTodaySteps);

    // Save to Firestore (consider debouncing this if updates are too frequent)
    _saveStepsToFirestore(newTodaySteps);
  }

  void _onStepCountError(error) {
    debugPrint("Pedometer: Error in step stream: $error");
  }

  /// Loads the user's step data and resets it to 0 if it's a new day.
  Future<void> _loadAndResetSteps(String uid) async {
    final docRef = _firestore.collection('users').doc(uid);
    final snapshot = await docRef.get();

    if (!snapshot.exists) return;
    final data = snapshot.data() as Map<String, dynamic>? ?? {};

    final int stepsToday = (data['stepsToday'] ?? 0).toInt();
    final Timestamp? lastReset = data['lastStepReset'] as Timestamp?;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    if (lastReset == null || lastReset.toDate().isBefore(todayStart)) {
      // It's a new day. Reset steps to 0.
      _savedStepsToday = 0;
      await docRef.update({
        'stepsToday': 0,
        'lastStepReset': FieldValue.serverTimestamp(),
      });
      debugPrint("Pedometer: New day, steps reset to 0.");
    } else {
      // It's still the same day. Use the saved value.
      _savedStepsToday = stepsToday;
      debugPrint("Pedometer: Resuming day with $_savedStepsToday saved steps.");
    }
    _stepsTodayController.add(_savedStepsToday); // Initial broadcast
  }

  /// Saves the current step count to Firestore.
  Future<void> _saveStepsToFirestore(int steps) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set(
      {'stepsToday': steps},
      SetOptions(merge: true), // Use set with merge to avoid overwriting other data
    );
  }

  /// Stops listening to the pedometer stream.
  void dispose() {
    _stepCountStream?.cancel();
    _stepsTodayController.close();
  }
}