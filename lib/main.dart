import 'package:aidkriya_walker/role_setup_screen.dart';
import 'package:aidkriya_walker/setup_flow_screen.dart';
import 'package:aidkriya_walker/sign_in_screen.dart';
import 'package:aidkriya_walker/profile_setup_screen.dart';
import 'package:aidkriya_walker/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'aidKRIYA Walker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF00E676),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'SF Pro',
      ),
      home: SetupFlowScreen(),
    );
  }
}
