import 'package:primestatus/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'usage_type_screen.dart';
import 'package:lottie/lottie.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  final List<String> languages = const ['English', 'Hindi', 'Telugu', 'Kannada'];

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
                SizedBox(height: 38),
                Text(
                  'Choose Your Language',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFd74d02),
                  ),
                ),
                Text(
                  'ನಿಮ್ಮ ಭಾಷೆಯನ್ನು ಆರಿಸಿ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    // fontWeight: FontWeight.bold,
                    color: Color(0xFFd74d02),
                  ),
                ),
                SizedBox(height: 32),
                _buildLanguageCard(
                  context: context,
                  language: 'English',
                  nativeScript: 'English',
                  onTap: () {
                    onboardingService.language = 'English';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UsageTypeScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 20),
                _buildLanguageCard(
                  context: context,
                  language: 'Kannada',
                  nativeScript: 'ಕನ್ನಡ',
                  onTap: () {
                    onboardingService.language = 'Kannada';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UsageTypeScreen(),
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

  Widget _buildLanguageCard({
    required BuildContext context,
    required String language,
    required String nativeScript,
    required VoidCallback onTap,
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
                  Text(
                    language,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C0036),
                      fontFamily: 'Serif',
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    nativeScript,
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFF2C0036),
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