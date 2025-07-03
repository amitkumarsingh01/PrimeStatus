import 'package:primestatus/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'subscription_screen.dart';

class StateSelectionScreen extends StatefulWidget {
  const StateSelectionScreen({Key? key}) : super(key: key);

  @override
  _StateSelectionScreenState createState() => _StateSelectionScreenState();
}

class _StateSelectionScreenState extends State<StateSelectionScreen> {
  String? _selectedState;
  final _onboardingService = OnboardingService.instance;

  final List<String> states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
    'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
    'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Andaman and Nicobar Islands', 'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Jammu and Kashmir',
    'Ladakh', 'Lakshadweep', 'Puducherry'
  ];

  final List<String> statesKn = [
    'ಆಂಧ್ರ ಪ್ರದೇಶ', 'ಅರುಣಾಚಲ ಪ್ರದೇಶ', 'ಅಸ್ಸಾಂ', 'ಬಿಹಾರ', 'ಛತ್ತೀಸ್‌ಗಢ',
    'ಗೋವಾ', 'ಗುಜರಾತ್', 'ಹರಿಯಾಣಾ', 'ಹಿಮಾಚಲ ಪ್ರದೇಶ', 'ಝಾರ್ಖಂಡ್', 'ಕರ್ನಾಟಕ',
    'ಕೇರಳ', 'ಮಧ್ಯ ಪ್ರದೇಶ', 'ಮಹಾರಾಷ್ಟ್ರ', 'ಮಣಿಪುರ', 'ಮೆಘಾಲಯ', 'ಮಿಜೋರಂ',
    'ನಾಗಾಲ್ಯಾಂಡ್', 'ಒಡಿಶಾ', 'ಪಂಜಾಬ್', 'ರಾಜಸ್ಥಾನ', 'ಸಿಕ್ಕಿಂ', 'ತಮಿಳುನಾಡು',
    'ತೆಲಂಗಾಣ', 'ತ್ರಿಪುರ', 'ಉತ್ತರ ಪ್ರದೇಶ', 'ಉತ್ತರಾಖಂಡ್', 'ಪಶ್ಚಿಮ ಬಂಗಾಳ',
    'ಆಂಡಮಾನ್ ಮತ್ತು ನಿಕೋಬಾರ್ ದ್ವೀಪಗಳು', 'ಚಂಡೀಗಢ',
    'ದಾದ್ರಾ ಮತ್ತು ನಗರ ಹವೇಳಿ ಮತ್ತು ದಮನ್ ಮತ್ತು ದಿಯು', 'ದೆಹಲಿ', 'ಜಮ್ಮು ಮತ್ತು ಕಾಶ್ಮೀರ',
    'ಲಡಾಖ್', 'ಲಕ್ಷದ್ವೀಪ', 'ಪುದುಚೇರಿ'
  ];

  @override
  Widget build(BuildContext context) {
    final onboardingService = OnboardingService.instance;
    final isKannada = onboardingService.language == 'Kannada';
    final title = isKannada ? 'ನಿಮ್ಮ ರಾಜ್ಯವನ್ನು ಆಯ್ಕೆಮಾಡಿ' : 'Which state are you from?';
    final hint = isKannada ? 'ನಿಮ್ಮ ರಾಜ್ಯ/ಪ್ರದೇಶವನ್ನು ಆಯ್ಕೆಮಾಡಿ' : 'Select your state/territory';
    final continueText = isKannada ? 'ಮುಂದುವರಿಸಿ' : 'Continue';

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
                      Icons.location_on,
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
                    SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      color: Colors.white,
                      child: Stack(
                        children: [
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
                          SizedBox(height: 16),
                          Container(
                            margin: EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: DropdownButtonFormField<String>(
                                value: _selectedState,
                                hint: Text(hint, textAlign: TextAlign.center),
                                isExpanded: true,
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedState = newValue;
                                    if (isKannada) {
                                      int idx = statesKn.indexOf(newValue ?? '');
                                      if (idx != -1) {
                                        _onboardingService.state = states[idx];
                                      }
                                    } else {
                                      _onboardingService.state = newValue;
                                    }
                                  });
                                },
                                items: (isKannada ? statesKn : states).map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Center(child: Text(value, textAlign: TextAlign.center)),
                                  );
                                }).toList(),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30),
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
                      child: ElevatedButton(
                        onPressed: _selectedState != null ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubscriptionScreen(),
                            ),
                          );
                        } : null,
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