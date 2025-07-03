import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:primestatus/screens/onboarding/splash_screen.dart';
import 'services/firebase_config.dart';

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
  } catch (e) {
    print('Firebase initialization/App Check failed: $e');
  }

  runApp(const QuoteCraftApp());
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