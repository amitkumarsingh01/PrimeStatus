import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:primestatus/screens/onboarding/splash_screen.dart';
import 'services/firebase_config.dart';

// ✅ This must be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, make sure you call initializeApp again.
  await FirebaseConfig.initializeFirebase();
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Step 1: Initialize Firebase
    await FirebaseConfig.initializeFirebase();
    await FirebaseConfig.enableOfflinePersistence();
    print('Firebase initialized successfully');

    // Step 2: Enable App Check (debug only for development)
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug, // ✅ Debug for development only
      appleProvider: AppleProvider.debug,     // Optional for iOS
    );
    print('Firebase App Check activated');

    // Step 3: Initialize Firebase Messaging
    await _initFirebaseMessaging();
  } catch (e) {
    print('Firebase initialization/App Check failed: $e');
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
  await messaging.subscribeToTopic('all_users');
  print('Subscribed to all_users topic');
  
  // Listen for token refresh
  messaging.onTokenRefresh.listen((String newToken) {
    print('FCM Token refreshed: $newToken');
    // TODO: Send this new token to your server
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
  const QuoteCraftApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prime Status',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}