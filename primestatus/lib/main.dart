import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FCMService.initialize();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    print('MyApp initialized');
    // Check current user immediately
    final currentUser = _authService.currentUser;
    print('Current user on init: ${currentUser?.uid ?? 'null'}');
  }

  @override
  Widget build(BuildContext context) {
    print('Building MyApp');
    return MaterialApp(
      title: 'Quote Template App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          print('Auth state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, error: ${snapshot.error}');
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('Showing loading screen');
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            print('User authenticated: ${snapshot.data?.uid}');
            return HomeScreen();
          }
          print('No user authenticated, showing login screen');
          return LoginScreen();
        },
      ),
    );
  }
}