import 'package:craftoapp/services/onboarding_service.dart';
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
                  'Select Your Preference',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 32),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: religions.length,
                    itemBuilder: (context, index) {
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            onboardingService.religion = religions[index];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StateSelectionScreen(),
                              ),
                            );
                          },
                          child: Center(
                            child: Text(
                              religions[index],
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
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
    );
  }
} 