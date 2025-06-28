import 'package:primestatus/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'subscription_screen.dart';

class AdditionalDetailsScreen extends StatefulWidget {
  const AdditionalDetailsScreen({Key? key}) : super(key: key);

  @override
  _AdditionalDetailsScreenState createState() => _AdditionalDetailsScreenState();
}

class _AdditionalDetailsScreenState extends State<AdditionalDetailsScreen> {
  final _onboardingService = OnboardingService.instance;
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();
  final _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing data if available
    _phoneController.text = _onboardingService.phoneNumber ?? '';
    _addressController.text = _onboardingService.address ?? '';
    _dobController.text = _onboardingService.dateOfBirth ?? '';
    _cityController.text = _onboardingService.city ?? '';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _saveAndContinue() {
    // Save data to onboarding service
    _onboardingService.phoneNumber = _phoneController.text.trim();
    _onboardingService.address = _addressController.text.trim();
    _onboardingService.dateOfBirth = _dobController.text.trim();
    _onboardingService.city = _cityController.text.trim();

    // Navigate to subscription screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SubscriptionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingService = OnboardingService.instance;
    final isKannada = onboardingService.language == 'Kannada';
    final title = isKannada ? 'ಹೆಚ್ಚುವರಿ ವಿವರಗಳು' : 'Additional Details';
    final subtitle = isKannada ? 'ನಿಮ್ಮ ಬಗ್ಗೆ ಹೆಚ್ಚು ತಿಳಿಯಲು ಸಹಾಯ ಮಾಡಿ' : 'Help us know more about you';
    final continueText = isKannada ? 'ಮುಂದುವರಿಸಿ' : 'Continue';
    final skipText = isKannada ? 'ಬಿಟ್ಟುಬಿಡಿ' : 'Skip for now';

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
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add,
                      size: 48,
                      color: Color(0xFFD74D02),
                    ),
                    SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD74D02),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 32),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: isKannada ? 'ಫೋನ್ ಸಂಖ್ಯೆ' : 'Phone Number',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: _cityController,
                              decoration: InputDecoration(
                                labelText: isKannada ? 'ನಗರ' : 'City',
                                prefixIcon: Icon(Icons.location_city),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: _dobController,
                              decoration: InputDecoration(
                                labelText: isKannada ? 'ಜನ್ಮ ದಿನಾಂಕ (DD/MM/YYYY)' : 'Date of Birth (DD/MM/YYYY)',
                                prefixIcon: Icon(Icons.calendar_today),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().subtract(Duration(days: 6570)), // 18 years ago
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  _dobController.text = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                                }
                              },
                              readOnly: true,
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: _addressController,
                              decoration: InputDecoration(
                                labelText: isKannada ? 'ವಿಳಾಸ' : 'Address',
                                prefixIcon: Icon(Icons.location_on),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Color(0xFFD74D02)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextButton(
                              onPressed: () {
                                // Skip and go to subscription screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SubscriptionScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                skipText,
                                style: TextStyle(fontSize: 16, color: Color(0xFFD74D02)),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Container(
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
                            child: ElevatedButton(
                              onPressed: _saveAndContinue,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                continueText,
                                style: TextStyle(fontSize: 16, color: Color(0xFFFAEAC7)),
                              ),
                            ),
                          ),
                        ),
                      ],
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
} 