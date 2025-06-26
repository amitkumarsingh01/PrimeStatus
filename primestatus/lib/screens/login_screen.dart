import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  String _phoneNumber = '';
  PhoneNumber _initialPhone = PhoneNumber(isoCode: 'IN');
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isPhoneValid = false;
  String? _verificationId;
  bool _showOtpField = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('LoginScreen initialized');
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
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 32),
                      Text(
                        'Welcome',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Sign in to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 32),
                      InternationalPhoneNumberInput(
                        onInputChanged: (PhoneNumber number) {
                          setState(() {
                            _phoneNumber = number.phoneNumber ?? '';
                          });
                        },
                        onInputValidated: (bool value) {
                          setState(() {
                            _isPhoneValid = value;
                          });
                        },
                        selectorConfig: SelectorConfig(
                          selectorType: PhoneInputSelectorType.DROPDOWN,
                          setSelectorButtonAsPrefixIcon: true,
                          leadingPadding: 8,
                        ),
                        ignoreBlank: false,
                        autoValidateMode: AutovalidateMode.onUserInteraction,
                        initialValue: _initialPhone,
                        textFieldController: null,
                        formatInput: true,
                        keyboardType: TextInputType.phone,
                        inputDecoration: InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16),
                      if (_showOtpField)
                        TextField(
                          controller: _otpController,
                          decoration: InputDecoration(
                            labelText: 'OTP',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      SizedBox(height: 16),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _showOtpField
                                  ? _verifyOtp
                                  : (_isPhoneValid ? _sendOtp : null),
                              child: Text(_showOtpField ? 'Verify OTP' : 'Send OTP'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(double.infinity, 50),
                                backgroundColor: Colors.purple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                      SizedBox(height: 24),
                      Divider(),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        icon: Icon(Icons.login),
                        label: Text('Sign in with Google'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.purple,
                          side: BorderSide(color: Colors.purple),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _sendOtp() async {
    print('Sending OTP to: $_phoneNumber');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _authService.signInWithPhoneNumber(_phoneNumber, (String verificationId) {
        print('OTP sent successfully, verificationId: $verificationId');
        setState(() {
          _verificationId = verificationId;
          _showOtpField = true;
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error sending OTP: $e');
      setState(() {
        _errorMessage = 'Failed to send OTP. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _verifyOtp() async {
    print('Verifying OTP: ${_otpController.text}');
    if (_verificationId == null || _otpController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userCredential = await _authService.verifyOTP(_verificationId!, _otpController.text);
      if (userCredential != null) {
        print('OTP verified successfully');
        _goToOnboarding();
      } else {
        print('OTP verification failed');
        setState(() {
          _errorMessage = 'OTP verification failed.';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error verifying OTP: $e');
      setState(() {
        _errorMessage = 'OTP verification failed.';
        _isLoading = false;
      });
    }
  }

  void _goToOnboarding() async {
    print('Going to onboarding...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final user = _authService.currentUser;
    print('Current user after OTP: ${user?.uid ?? 'null'}');
    if (user != null) {
      // Let the main app handle navigation based on auth state
      // The StreamBuilder in main.dart will automatically navigate to HomeScreen
      print('User authenticated, letting main app handle navigation');
      setState(() {
        _isLoading = false;
      });
    } else {
      print('No user found after OTP verification');
      setState(() {
        _errorMessage = 'Login failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential != null) {
        // Let the main app handle navigation based on auth state
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Google sign-in failed. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google sign-in failed. Please try again.';
        _isLoading = false;
      });
    }
  }
} 