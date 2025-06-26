import 'dart:convert';
import 'package:craftoapp/screens/home_screen.dart';
import 'package:craftoapp/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _onboardingService = OnboardingService.instance;
  bool _isLoading = false;

  Future<void> _registerUser(String subscriptionType) async {
    setState(() {
      _isLoading = true;
    });

    _onboardingService.subscription = subscriptionType;

    // NOTE: For Android emulator, use 10.0.2.2 to connect to localhost
    final url = Uri.parse('https://bharatchat.iaks.site/register/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'mobile_number': _onboardingService.mobileNumber,
          'language': _onboardingService.language,
          'usage_type': _onboardingService.usageType,
          'name': _onboardingService.name,
          'profile_photo_url': _onboardingService.profilePhotoUrl,
          'religion': _onboardingService.religion,
          'state': _onboardingService.state,
          'subscription': _onboardingService.subscription,
        }),
      );

      if (response.statusCode == 200) {
        // Navigate to home screen on success
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
          (route) => false,
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      _onboardingService.reset(); // Clear data after attempting registration
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Container(
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
                      Text(
                        'Unlock All Features',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Choose a plan to get unlimited access to all quotes and backgrounds.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 32),
                      _buildPlanCard(
                        title: 'Monthly Plan',
                        price: '₹99',
                        duration: '/month',
                        color: Colors.orange,
                        onTap: () => _registerUser('monthly'),
                      ),
                      SizedBox(height: 16),
                      _buildPlanCard(
                        title: '6-Month Plan',
                        price: '₹299',
                        duration: '/6 months',
                        color: Colors.purple,
                        onTap: () => _registerUser('6-month'),
                      ),
                      Spacer(),
                      TextButton(
                        onPressed: () => _registerUser('free'),
                        child: Text(
                          'Skip for now',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String duration,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    duration,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 