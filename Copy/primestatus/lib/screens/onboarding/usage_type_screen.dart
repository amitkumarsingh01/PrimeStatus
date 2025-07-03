import 'package:primestatus/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'profile_setup_screen.dart';

class UsageTypeScreen extends StatelessWidget {
  const UsageTypeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final onboardingService = OnboardingService.instance;
    final isKannada = onboardingService.language == 'Kannada';

    final title = isKannada ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ಉದ್ದೇಶವನ್ನು ಆಯ್ಕೆಮಾಡಿ' : 'Please select your purpose';
    final personalText = isKannada ? 'ವೈಯಕ್ತಿಕ ಬಳಕೆಗಾಗಿ' : 'For Personal Use';
    final businessText = isKannada ? 'ವ್ಯಾಪಾರ ಬಳಕೆಗಾಗಿ' : 'For Business Use';

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
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    color: Color(0xFFd74d02),
                  ),
                ),
                SizedBox(height: 32),
                _buildUsageCard(
                  context: context,
                  title: personalText,
                  onTap: () {
                    onboardingService.usageType = isKannada ? 'ವೈಯಕ್ತಿಕ' : 'Personal';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileSetupScreen(),
                      ),
                    );
                  },
                  icon: Icons.person,
                ),
                SizedBox(height: 20),
                _buildUsageCard(
                  context: context,
                  title: businessText,
                  onTap: () {
                    onboardingService.usageType = isKannada ? 'ವ್ಯಾಪಾರ' : 'Business';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileSetupScreen(),
                      ),
                    );
                  },
                  icon: Icons.business_center,
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
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Gradient border layer
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD74D02), Color(0xFF2C0036)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            // White background with padding to reveal border
            Container(
              margin: EdgeInsets.all(3), // Border thickness
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 40,
                    color: Color(0xFFD74D02),
                  ),
                  SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFF2C0036),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 