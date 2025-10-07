import 'package:newapp/screens/home_screen.dart';
import 'package:newapp/services/onboarding_service.dart';
import 'package:newapp/services/user_service.dart';
import 'package:newapp/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final OnboardingService _onboardingService = OnboardingService.instance;
  final UserService _userService = UserService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isLoading = false;
  List<SubscriptionPlan> _plans = [];
  bool _isLoadingPlans = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionPlans();
  }

  Future<void> _loadSubscriptionPlans() async {
    try {
      final usageType = _onboardingService.usageType ?? 'Personal';
      final plans = await _subscriptionService.getActivePlans(usageType);
      setState(() {
        _plans = plans;
        _isLoadingPlans = false;
      });
    } catch (e) {
      print('Error loading subscription plans: $e');
      setState(() {
        _isLoadingPlans = false;
      });
    }
  }

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

      // If it's a free subscription, register directly
      if (subscriptionType == 'free') {
        await _registerFreeUser(currentUser);
        return;
      }

      // For paid subscriptions, find the plan and create payment link
      final plan = _plans.firstWhere(
        (p) => p.id == subscriptionType,
        orElse: () => throw 'Selected plan not found',
      );

      // Create payment link
      final paymentResult = await _subscriptionService.createPaymentLink(
        userId: currentUser.uid,
        userName: _onboardingService.name ?? currentUser.displayName ?? 'User',
        userEmail: currentUser.email ?? '',
        userPhone:
            _onboardingService.phoneNumber ?? currentUser.phoneNumber ?? '',
        plan: plan,
      );

      if (paymentResult != null && paymentResult['success'] == true) {
        // Show payment link dialog
        _showPaymentLinkDialog(paymentResult['paymentLink'], plan.title);
      } else {
        throw paymentResult?['error'] ?? 'Failed to create payment link';
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _registerFreeUser(dynamic currentUser) async {
    try {
      // Create or update user with free subscription
      await _userService.updateUserData(currentUser.uid, {
        'name': _onboardingService.name ?? currentUser.displayName ?? 'User',
        'language': _onboardingService.language ?? 'English',
        'usageType': _onboardingService.usageType ?? 'Personal',
        'religion': _onboardingService.religion ?? 'Other',
        'state': _onboardingService.state ?? 'Other',
        'profilePhotoUrl':
            _onboardingService.profilePhotoUrl ?? currentUser.photoURL,
        'subscription': 'free',
        'subscriptionDate': DateTime.now().toIso8601String(),
        'phoneNumber':
            _onboardingService.phoneNumber ?? currentUser.phoneNumber ?? '',
        'address': _onboardingService.address ?? '',
        'dateOfBirth': _onboardingService.dateOfBirth ?? '',
        'city': _onboardingService.city ?? '',
        'email': currentUser.email ?? '',
        'designation': _onboardingService.designation ?? '',
        'businessName': _onboardingService.businessName ?? '',
        'businessLogoUrl': _onboardingService.businessLogoUrl ?? '',
        'businessCategory': _onboardingService.businessCategory ?? '',
      });

      // Show success message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration successful!')));

      // Navigate to home screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
        (route) => false,
      );

      _onboardingService.reset(); // Clear data after successful registration
    } catch (e) {
      throw 'Failed to register free user: $e';
    }
  }

  void _showPaymentLinkDialog(String paymentLink, String planTitle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.blue),
            SizedBox(width: 8),
            Text('Payment Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To complete your subscription for "$planTitle", please click the button below to proceed with payment.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will be redirected to a secure payment page. After successful payment, your subscription will be activated.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onboardingService.reset();
            },
            child: Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              // Launch payment link in browser
              try {
                final Uri url = Uri.parse(paymentLink);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  throw 'Could not launch payment link';
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error opening payment link: $e')),
                );
              }
            },
            icon: Icon(Icons.payment),
            label: Text('Proceed to Payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingService = OnboardingService.instance;
    final isKannada = onboardingService.language == 'Kannada';
    final title = isKannada
        ? 'ಎಲ್ಲಾ ವೈಶಿಷ್ಟ್ಯಗಳನ್ನು ಅನ್ಲಾಕ್ ಮಾಡಿ'
        : 'Unlock All Features';
    final subtitle = isKannada
        ? 'ಎಲ್ಲಾ ಉಲ್ಲೇಖಗಳು ಮತ್ತು ಹಿನ್ನೆಲೆಗಳಿಗೆ ಅನಿಯಮಿತ ಪ್ರವೇಶ ಪಡೆಯಲು ಯೋಜನೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ.'
        : 'Choose a plan to get unlimited access to all quotes and backgrounds.';
    final free = isKannada ? 'ಈಗ ಬಿಟ್ಟುಬಿಡಿ' : 'Skip for now';

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
                          Icon(
                            Icons.workspace_premium,
                            size: 64,
                            color: Color(0xFFD74D02),
                          ),
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
                          // Display dynamic plans from Firebase
                          if (_isLoadingPlans)
                            Center(child: CircularProgressIndicator())
                          else if (_plans.isEmpty)
                            Container(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                isKannada
                                    ? 'ಯೋಜನೆಗಳು ಲಭ್ಯವಿಲ್ಲ'
                                    : 'No plans available',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          else
                            ..._plans
                                .map(
                                  (plan) => Column(
                                    children: [
                                      _buildPlanCard(
                                        icon:
                                            plan.title.toLowerCase().contains(
                                              'month',
                                            )
                                            ? Icons.star
                                            : Icons.rocket_launch,
                                        title: plan.title,
                                        price:
                                            '₹${plan.price.toStringAsFixed(0)}',
                                        duration: '/${plan.duration}',
                                        color:
                                            plan.title.toLowerCase().contains(
                                              'month',
                                            )
                                            ? Colors.orange
                                            : Colors.purple,
                                        onTap: () => _registerUser(plan.id),
                                      ),
                                      SizedBox(height: 16),
                                    ],
                                  ),
                                )
                                .toList(),
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
                              icon: Icon(
                                Icons.arrow_forward,
                                color: Color(0xFFFAEAC7),
                              ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                    style: TextStyle(fontSize: 18, color: Colors.white70),
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
