import 'package:aidkriya_walker/sign_in_screen.dart';
import 'package:aidkriya_walker/sign_up_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'home_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await messaging.requestPermission();

  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    _updateFcmToken(user.uid);
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _updateFcmToken(user.uid, newToken);
    }
  });

  runApp(const MyApp());
}

Future<void> _updateFcmToken(String uid, [String? token]) async {
  try {
    final fcmToken = token ?? await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': fcmToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      debugPrint(" FCM token updated for $uid");
    }
  } catch (e) {
    debugPrint("Error updating FCM token: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return MaterialApp(
      title: 'aidKRIYA Walker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF00E676),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'SF Pro',
      ),
        routes: {
          '/login': (context) => const SignInScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/home': (context) => const HomeScreen(),
        },
      home: user != null ? const HomeScreen() : const SignUpScreen(),
      // home: IncomingRequestsScreen(),
    );
  }
}
