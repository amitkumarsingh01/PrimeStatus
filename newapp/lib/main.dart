import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:newapp/Auth/SecurityWrapper.dart';
import 'package:newapp/screens/onboarding/splash_screen.dart';

// Assuming your FirebaseConfig is just a wrapper for Firebase.initializeApp()
// import 'services/firebase_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';

// ✅ This must be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, make sure you call initializeApp again.
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Step 1: Initialize Firebase
    await Firebase.initializeApp();
    print('Firebase initialized successfully');

    // Step 2: Activate App Check for Release
    // This uses Play Integrity. Make sure you've configured it in Firebase.
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          AndroidProvider.playIntegrity, // ✅ Use playIntegrity for release
      appleProvider: AppleProvider.appAttest, // ✅ Use appAttest for release
    );
    print('Firebase App Check activated for release');

    // Step 3: Initialize Firebase Messaging
    await _initFirebaseMessaging();
  } catch (e) {
    print('Firebase initialization/setup failed: $e');
  }

  runApp(const QuoteCraftApp());
}

Future<void> _initFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request notification permissions
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission');
  } else {
    print('User declined or has not accepted permission');
  }

  // Get and print FCM token
  String? token = await messaging.getToken();
  print('FCM Token: $token');

  // Subscribe to 'all_users' topic to receive notifications from admin
  try {
    await messaging.subscribeToTopic('all_users');
    print('Subscribed to all_users topic');

    // Also call the Cloud Function to register the subscription
    if (token != null) {
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('subscribeUserToTopic').call({
        'fcmToken': token,
        'userId':
            'anonymous', // You can replace this with actual user ID when available
      });
      print('Registered subscription with Cloud Function');
    }
  } catch (e) {
    print('Error subscribing to topic: $e');
  }

  // Listen for token refresh
  messaging.onTokenRefresh.listen((String newToken) async {
    print('FCM Token refreshed: $newToken');

    // Update subscription with new token
    try {
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('subscribeUserToTopic').call({
        'fcmToken': newToken,
        'userId':
            'anonymous', // You can replace this with actual user ID when available
      });
      print('Updated subscription with new token');
    } catch (e) {
      print('Error updating subscription: $e');
    }
  });

  // Set up handlers
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Received a message in the foreground!');
    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      // Here you can use a package like `flutter_local_notifications`
      // to show a heads-up notification while the app is in the foreground.
    }
  });
}

class QuoteCraftApp extends StatelessWidget {
  const QuoteCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SecurityWrapper(
      child: MaterialApp(
        title: 'Prime Status',
        theme: ThemeData(
          primarySwatch: Colors.deepOrange,
          scaffoldBackgroundColor: Colors.white,
        ),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   return MaterialApp(
  //     title: 'Prime Status',
  //     theme: ThemeData(
  //       primarySwatch: Colors.deepOrange,
  //       scaffoldBackgroundColor: Colors.white,
  //     ),
  //     home: const SplashScreen(),
  //     debugShowCheckedModeBanner: false,
  //   );
  // }
}
