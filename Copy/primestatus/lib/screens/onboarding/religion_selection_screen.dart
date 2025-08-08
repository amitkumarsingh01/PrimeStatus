import 'package:primestatus/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'state_selection_screen.dart';

class ReligionSelectionScreen extends StatelessWidget {
  const ReligionSelectionScreen({Key? key}) : super(key: key);

  final List<String> religions = const [
    'Hindu',
    'Muslim',
    'Christian',
    'Jain',
    'Buddhist',
    'Sikh',
    'Other'
  ];

  @override
  Widget build(BuildContext context) {
    final onboardingService = OnboardingService.instance;
    final isKannada = onboardingService.language == 'Kannada';
    final title = isKannada ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ಧರ್ಮವನ್ನು ಆಯ್ಕೆಮಾಡಿ' : 'Please select your religion';
    final religionsKn = const [
      'ಹಿಂದೂ', 'ಮುಸ್ಲಿಂ', 'ಕ್ರಿಶ್ಚಿಯನ್', 'ಜೈನ್', 'ಬೌದ್ಧ', 'ಸಿಖ್', 'ಇತರೆ'
    ];
    final religionsList = isKannada ? religionsKn : religions;
    final icons = [
      Icons.emoji_emotions, // Hindu (Om is not in Material Icons)
      Icons.star, // Muslim (fallback)
      Icons.church, // Christian
      Icons.spa, // Jain
      Icons.self_improvement, // Buddhist
      Icons.temple_hindu, // Sikh (closest available)
      Icons.help_outline, // Other
    ];

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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD74D02),
                    ),
                  ),
                  SizedBox(height: 32),
                  SizedBox(
                    width: 300,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: religionsList.length,
                      itemBuilder: (context, index) {
                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          color: Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              onboardingService.religion = religionsList[index];
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StateSelectionScreen(),
                                ),
                              );
                            },
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    icons[index],
                                    size: 36,
                                    color: Color(0xFFD74D02),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    religionsList[index],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2C0036),
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 