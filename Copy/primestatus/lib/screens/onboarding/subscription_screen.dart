import 'package:primestatus/screens/home_screen.dart';
import 'package:primestatus/services/onboarding_service.dart';
import 'package:primestatus/services/user_service.dart';
import 'package:flutter/material.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final OnboardingService _onboardingService = OnboardingService.instance;
  final UserService _userService = UserService();
  bool _isLoading = false;

  Future<void> _registerUser(String subscriptionType) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      final currentUser = _userService.currentUser;
      if (currentUser == null) {
        throw 'No authenticated user found. Please sign in with Google first.';
      }

      // Create or update user with subscription
      await _userService.updateUserData(currentUser.uid, {
        'name': _onboardingService.name ?? currentUser.displayName ?? 'User',
        'language': _onboardingService.language ?? 'English',
        'usageType': _onboardingService.usageType ?? 'Personal',
        'religion': _onboardingService.religion ?? 'Other',
        'state': _onboardingService.state ?? 'Other',
        'profilePhotoUrl': _onboardingService.profilePhotoUrl ?? currentUser.photoURL,
        'subscription': subscriptionType,
        'subscriptionDate': DateTime.now().toIso8601String(),
        'phoneNumber': _onboardingService.phoneNumber ?? currentUser.phoneNumber ?? '',
        'address': _onboardingService.address ?? '',
        'dateOfBirth': _onboardingService.dateOfBirth ?? '',
        'city': _onboardingService.city ?? '',
        'email': currentUser.email ?? '',
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration successful!')),
      );

      // Navigate to home screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
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
    final onboardingService = OnboardingService.instance;
    final isKannada = onboardingService.language == 'Kannada';
    final title = isKannada ? 'ಎಲ್ಲಾ ವೈಶಿಷ್ಟ್ಯಗಳನ್ನು ಅನ್ಲಾಕ್ ಮಾಡಿ' : 'Unlock All Features';
    final subtitle = isKannada ? 'ಎಲ್ಲಾ ಉಲ್ಲೇಖಗಳು ಮತ್ತು ಹಿನ್ನೆಲೆಗಳಿಗೆ ಅನಿಯಮಿತ ಪ್ರವೇಶ ಪಡೆಯಲು ಯೋಜನೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ.' : 'Choose a plan to get unlimited access to all quotes and backgrounds.';
    final monthly = isKannada ? 'ಮಾಸಿಕ ಯೋಜನೆ' : 'Monthly Plan';
    final sixMonth = isKannada ? '6-ಮಾಸ ಯೋಜನೆ' : '6-Month Plan';
    final free = isKannada ? 'ಈಗ ಬಿಟ್ಟುಬಿಡಿ' : 'Skip for now';
    final priceMonthly = isKannada ? '₹99' : '₹99';
    final priceSixMonth = isKannada ? '₹299' : '₹299';
    final durationMonthly = isKannada ? '/ಮಾಸ' : '/month';
    final durationSixMonth = isKannada ? '/6 ತಿಂಗಳು' : '/6 months';

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
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.workspace_premium, size: 64, color: Color(0xFFD74D02)),
                          SizedBox(height: 16),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD74D02),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFF2C0036),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 32),
                          _buildPlanCard(
                            icon: Icons.star,
                            title: monthly,
                            price: priceMonthly,
                            duration: durationMonthly,
                            color: Colors.orange,
                            onTap: () => _registerUser('monthly'),
                          ),
                          SizedBox(height: 16),
                          _buildPlanCard(
                            icon: Icons.rocket_launch,
                            title: sixMonth,
                            price: priceSixMonth,
                            duration: durationSixMonth,
                            color: Colors.purple,
                            onTap: () => _registerUser('6-month'),
                          ),
                          SizedBox(height: 32),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFD74D02), Color(0xFF2C0036)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF2C0036).withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: TextButton.icon(
                              onPressed: () => _registerUser('free'),
                              icon: Icon(Icons.arrow_forward, color: Color(0xFFFAEAC7)),
                              label: Text(
                                free,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Color(0xFFFAEAC7),
                                  fontWeight: FontWeight.bold,
                                ),
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
    );
  }

  Widget _buildPlanCard({
    required IconData icon,
    required String title,
    required String price,
    required String duration,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Colors.white),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    duration,
                    style: TextStyle(
                      fontSize: 18,
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