import 'package:primestatus/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'profile_setup_screen.dart';

class UsageTypeScreen extends StatelessWidget {
  const UsageTypeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final onboardingService = OnboardingService.instance;

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
                Text(
                  'How will you use P?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 32),
                _buildUsageCard(
                  context: context,
                  title: 'For Personal Use',
                  icon: Icons.person,
                  onTap: () {
                    onboardingService.usageType = 'Personal';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileSetupScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 16),
                _buildUsageCard(
                  context: context,
                  title: 'For Business Use',
                  icon: Icons.business,
                  onTap: () {
                    onboardingService.usageType = 'Business';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileSetupScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsageCard({
    required BuildContext context,
    required String title,
    required IconData icon,
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.purple),
              SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 