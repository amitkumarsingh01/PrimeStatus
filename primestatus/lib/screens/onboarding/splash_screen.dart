import 'package:flutter/material.dart';
import 'package:primestatus/services/firebase_auth_service.dart';
import 'package:primestatus/services/user_service.dart';
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
      // Check if user is currently signed in
      final currentUser = _authService.currentUser;
      
      if (currentUser != null) {
        // User is signed in, check if they exist in our database
        final userData = await _userService.getUserData(currentUser.uid);
        
        if (userData != null) {
          // Existing user with complete profile, go to home screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        } else {
          // User signed in but no profile data, go to onboarding
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LanguageSelectionScreen()),
          );
        }
      } else {
        // No user signed in, go to login screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      print('Error checking auth state: $e');
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
            Image.asset(
              'assets/logo.png',
              width: 240,
              height: 240,
            ),
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