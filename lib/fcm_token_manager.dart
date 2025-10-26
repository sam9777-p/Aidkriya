import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMTokenManager {
  static Future<void> initializeTokenListener() async {
    final messaging = FirebaseMessaging.instance;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final token = await messaging.getToken();
    if (token != null) {
      await _updateTokenInFirestore(user.uid, token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _updateTokenInFirestore(user.uid, newToken);
    });
  }

  static Future<void> _updateTokenInFirestore(String uid, String token) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    await userDoc.set({'fcmToken': token}, SetOptions(merge: true));
  }
}
