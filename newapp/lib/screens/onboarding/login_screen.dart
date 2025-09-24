import 'package:newapp/services/user_service.dart';
import 'package:newapp/services/firebase_auth_service.dart';
import 'package:flutter/material.dart';
import 'language_selection_screen.dart';
import 'package:newapp/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userService = UserService();
  final _authService = FirebaseAuthService();
  bool _isLoading = false;
  bool _isReturningUser = false;

  @override
  void initState() {
    super.initState();
    _checkIfReturningUser();
  }

  Future<void> _checkIfReturningUser() async {
    // Check if there are any previous sign-in attempts or stored data
    // This is a simple check - you might want to implement more sophisticated logic
    try {
      // Check if there's any cached user data or previous session
      final hasPreviousSession = await _userService.hasPreviousSession();
      setState(() {
        _isReturningUser = hasPreviousSession;
      });
    } catch (e) {
      // If we can't determine, assume it's a new user
      setState(() {
        _isReturningUser = false;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _authService.signInWithGoogle();
      final user = userCredential.user;

      if (user != null) {
        // Check if user exists in our database
        final userData = await _userService.getUserData(user.uid);
        final isExistingUser = userData != null;

        if (isExistingUser) {
          // User exists, go to home screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
            (route) => false,
          );
        } else {
          // New user, go to onboarding
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => LanguageSelectionScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign in failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final welcomeText = _isReturningUser
        ? 'Welcome back to Prime Status'
        : 'Welcome to Prime Status';

    final subtitleText = _isReturningUser
        ? 'Sign in with Google to continue where you left off'
        : 'Sign in with Google to continue';

    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final mainIllustrationSize = (screenWidth * 0.7).clamp(180.0, 320.0);
    final logoSize = (screenWidth * 0.22).clamp(64.0, 100.0);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.pink.shade50,
                  Colors.purple.shade50,
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/landing.gif',
                            width: mainIllustrationSize,
                            height: mainIllustrationSize,
                          ),
                        ),
                        Center(
                          child: Image.asset(
                            'assets/logo.png',
                            width: logoSize,
                            height: logoSize,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          welcomeText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          subtitleText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF2c0036), Color(0xFFd74d02)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            icon: _isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Image.network(
                                    'https://static.vecteezy.com/system/resources/previews/022/613/027/non_2x/google-icon-logo-symbol-free-png.png',
                                    height: 20,
                                    width: 20,
                                  ),
                            label: Text(
                              _isLoading
                                  ? 'Signing in...'
                                  : 'Continue with Google',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xfffaeac7),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'By continuing, you agree to our Terms of Service and Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
