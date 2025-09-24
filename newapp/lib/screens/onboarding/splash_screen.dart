import 'package:flutter/material.dart';
import 'package:newapp/services/firebase_auth_service.dart';
import 'package:newapp/services/user_service.dart';
import 'package:newapp/services/firebase_firestore_service.dart';
import 'login_screen.dart';
import '../home_screen.dart';
import 'language_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final UserService _userService = UserService();
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Wait for 3 seconds to show splash screen
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    try {
      // First check the loginType from Firestore
      print('🔍 Checking loginType from Firestore...');
      bool loginType = await _firestoreService.getLoginType();

      if (!loginType) {
        // If loginType is false, go directly to home screen
        print(
          '🏠 LoginType is FALSE → Going directly to HomeScreen (Skip Auth)',
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
        return;
      }

      print('🔐 LoginType is TRUE → Following normal auth flow');

      // If loginType is true, follow the normal auth flow
      final currentUser = _authService.currentUser;

      if (currentUser != null) {
        // User is signed in, check if they exist in our database
        final userData = await _userService.getUserData(currentUser.uid);

        if (userData != null) {
          // Existing user with complete profile, go to home screen
          print(
            '✅ User authenticated & profile complete → Going to HomeScreen',
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        } else {
          // User signed in but no profile data, go to onboarding
          print(
            '⚠️ User authenticated but no profile → Going to LanguageSelection',
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LanguageSelectionScreen()),
          );
        }
      } else {
        // No user signed in, go to login screen
        print('🔑 No user signed in → Going to LoginScreen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      print('💥 Error checking auth state: $e');
      print('🔄 Fallback → Going to LoginScreen');
      // On error, go to login screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', width: 240, height: 240),
            const SizedBox(height: 16),
            const Text(
              'Prime Status',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD74D02)),
            ),
          ],
        ),
      ),
    );
  }
}
