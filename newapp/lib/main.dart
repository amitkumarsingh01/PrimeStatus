import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:newapp/Auth/SecurityWrapper.dart';
import 'package:newapp/screens/onboarding/splash_screen.dart';

// Assuming your FirebaseConfig is just a wrapper for Firebase.initializeApp()
// import 'services/firebase_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

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

    // Step 4: Initialize Firebase Remote Config
    await _initFirebaseRemoteConfig();
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

Future<void> _initFirebaseRemoteConfig() async {
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    
    // Set default values for app update configuration
    await remoteConfig.setDefaults({
      'min_app_version': '1.0.0',
      'latest_app_version': '1.0.0',
      'force_update_enabled': false,
      'update_title': 'Update Available',
      'update_message': 'A new version of the app is available. Please update to continue using the app.',
      'play_store_url': 'https://play.google.com/store/apps/details?id=com.example.newapp',
      'app_store_url': 'https://apps.apple.com/app/id1234567890',
    });

    // Set fetch timeout and minimum fetch interval
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    // Fetch and activate
    await remoteConfig.fetchAndActivate();
    
    print('✅ Firebase Remote Config initialized successfully');
  } catch (e) {
    print('❌ Error initializing Firebase Remote Config: $e');
  }
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
