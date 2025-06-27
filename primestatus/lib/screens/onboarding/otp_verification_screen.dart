import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:primestatus/services/user_service.dart';
import 'package:primestatus/services/onboarding_service.dart';
import 'package:primestatus/screens/home_screen.dart';
import 'package:primestatus/screens/onboarding/language_selection_screen.dart';
import 'package:primestatus/widgets/otp_input_widget.dart';
import 'package:lottie/lottie.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final void Function(bool isExistingUser) onVerified;

  const OtpVerificationScreen({
    Key? key,
    required this.phoneNumber,
    required this.onVerified,
  }) : super(key: key);

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final UserService _userService = UserService();
  final OnboardingService _onboardingService = OnboardingService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _isResending = false;
  String? _verificationId;
  int _resendTimer = 60;
  bool _canResend = false;
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _sendOtp();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Format phone number with country code (assuming Indian numbers)
  String _formatPhoneNumber(String phoneNumber) {
    // Remove any existing country code or special characters
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // If it starts with country code, use as is
    if (cleanNumber.startsWith('91') && cleanNumber.length == 12) {
      return '+$cleanNumber';
    }
    
    // If it's a 10-digit number, add Indian country code
    if (cleanNumber.length == 10) {
      return '+91$cleanNumber';
    }
    
    // If it already has +, return as is
    if (phoneNumber.startsWith('+')) {
      return phoneNumber;
    }
    
    // Default: add +91 for Indian numbers
    return '+91$cleanNumber';
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
      _canResend = false;
    });

    Future.delayed(Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
        _startResendTimer();
      } else if (mounted) {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  Future<void> _sendOtp() async {
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
    setState(() {
      _isLoading = true;
    });

    try {
      String formattedPhoneNumber = _formatPhoneNumber(widget.phoneNumber);
      
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed
          print('Auto verification completed');
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });
          print('Verification failed: ${e.code} - ${e.message}');
          _showError('Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isLoading = false;
          });
          print('Code sent. Verification ID: $verificationId');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('OTP sent to $formattedPhoneNumber'),
              backgroundColor: Colors.green,
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
          print('Auto retrieval timeout');
        },
        timeout: Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error sending OTP: $e');
      _showError('Failed to send OTP: $e');
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    setState(() {
      _isResending = true;
    });

    // Clear previous OTP
    for (var controller in _otpControllers) {
      controller.clear();
    }

    try {
      await _sendOtp();
      _startResendTimer();
    } catch (e) {
      _showError('Failed to resend OTP: $e');
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  String _getOtpCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOtp() async {
    String otpCode = _getOtpCode();
    
    if (otpCode.length != 6) {
      _showError('Please enter a valid 6-digit OTP');
      return;
    }

    if (_verificationId == null) {
      _showError('Verification ID not found. Please resend OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create credential with verification ID and SMS code
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpCode,
      );

      print('Attempting to sign in with credential');
      await _signInWithCredential(credential);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('OTP verification error: $e');
      
      if (e is FirebaseAuthException) {
        if (e.code == 'invalid-verification-code') {
          _showError('Invalid OTP. Please check and try again.');
        } else if (e.code == 'session-expired') {
          _showError('OTP has expired. Please request a new one.');
        } else {
          _showError('Verification failed: ${e.message}');
        }
      } else {
        _showError('Invalid OTP. Please try again.');
      }
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      print('Sign in successful: ${userCredential.user?.uid}');
      await _handleVerificationSuccess();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Sign in with credential error: $e');
      throw e;
    }
  }

  Future<void> _handleVerificationSuccess() async {
    try {
      // Check if user exists in Firestore
      bool userExists = await _userService.userExistsByPhone(widget.phoneNumber);
      
      setState(() {
        _isLoading = false;
      });
      
      print('User exists: $userExists');
      widget.onVerified(userExists);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error checking user existence: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login successful but failed to load user data: $e'),
          backgroundColor: Colors.orange,
        ),
      );
      widget.onVerified(false);
    }
  }

  Future<void> _skipVerification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Skipped verification for phone: ${widget.phoneNumber}');
      
      // For skipped verification, we need to handle the case where user is not authenticated
      // We'll pass false to indicate this is a new user, but the HomeScreen should handle
      // the case where there's no authenticated user gracefully
      
      setState(() {
        _isLoading = false;
      });
      
      // Pass false to indicate this is a new user (since they skipped verification)
      widget.onVerified(false);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error during skip: $e');
      // Still proceed with skip even if there's an error
      widget.onVerified(false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all 6 digits are entered
    if (_getOtpCode().length == 6) {
      Future.delayed(Duration(milliseconds: 100), () {
        _verifyOtp();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Lottie.network(
                  'https://assets9.lottiefiles.com/packages/lf20_ucbyrun5.json',
                  height: 200,
                ),
                SizedBox(height: 32),
                Text(
                  'Verify Your Phone',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code sent to\n${_formatPhoneNumber(widget.phoneNumber)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 32),
                
                // OTP Input Fields
                OtpInputWidget(
                  controllers: _otpControllers,
                  focusNodes: _focusNodes,
                  onChanged: _onOtpChanged,
                ),
                
                SizedBox(height: 32),
                
                // Verify Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Verify OTP',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
                
                SizedBox(height: 24),
                
                // Resend OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code? ",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (_canResend)
                      TextButton(
                        onPressed: _isResending ? null : _resendOtp,
                        child: _isResending
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Resend',
                                style: TextStyle(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      )
                    else
                      Text(
                        'Resend in $_resendTimer seconds',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Change Phone Number
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Change Phone Number',
                    style: TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Skip Verification
                TextButton(
                  onPressed: _isLoading ? null : _skipVerification,
                  child: Text(
                    'Skip Verification',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}