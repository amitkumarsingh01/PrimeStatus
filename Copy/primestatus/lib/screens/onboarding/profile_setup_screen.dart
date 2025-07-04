import 'package:primestatus/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'religion_selection_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({Key? key}) : super(key: key);

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _onboardingService = OnboardingService.instance;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  DateTime? _selectedDob;

  @override
  void initState() {
    super.initState();
    // Pre-fill name if available
    if (_onboardingService.name != null) {
      _nameController.text = _onboardingService.name!;
    }
    if (_onboardingService.usageType == 'Business' || _onboardingService.usageType == 'ವ್ಯಾಪಾರ') {
      // Optionally pre-fill phone and address if you store them
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Widget _buildDataCard(String title, String? value, IconData icon) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.purple, size: 24),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value ?? 'Not set',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: value != null ? Colors.black87 : Colors.grey[400],
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

  @override
  Widget build(BuildContext context) {
    final isKannada = _onboardingService.language == 'Kannada';

    final title = isKannada ? 'ನಿಮ್ಮ ಪ್ರೊಫೈಲ್ ಸೆಟ್ ಮಾಡಿ' : 'Setup Your Profile';
    final subtitle = isKannada ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ಮಾಹಿತಿಯನ್ನು ಪರಿಶೀಲಿಸಿ ಮತ್ತು ಸೇರಿಸಿ' : 'Review your information and add your details';
    final nameLabel = isKannada ? 'ನಿಮ್ಮ ಹೆಸರು' : 'Your Name';
    final phoneLabel = isKannada ? 'ಫೋನ್ ಸಂಖ್ಯೆ' : 'Phone Number';
    final addressLabel = isKannada ? 'ವಿಳಾಸ' : 'Address';
    final cityLabel = isKannada ? 'ನಗರ' : 'City';
    final dobLabel = isKannada ? 'ಜನ್ಮ ದಿನಾಂಕ' : 'Date of Birth';
    final continueText = isKannada ? 'ಮುಂದುವರಿಸಿ' : 'Continue';
    final nameEmptyMsg = isKannada ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ಹೆಸರನ್ನು ನಮೂದಿಸಿ' : 'Please enter your name';
    final phoneEmptyMsg = isKannada ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ' : 'Please enter your phone number';
    final addressEmptyMsg = isKannada ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ವಿಳಾಸವನ್ನು ನಮೂದಿಸಿ' : 'Please enter your address';
    final dobEmptyMsg = isKannada ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ಜನ್ಮ ದಿನಾಂಕವನ್ನು ಆಯ್ಕೆಮಾಡಿ' : 'Please select your date of birth';

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
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
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
                    SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2C0036),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Profile Photo Section
                      SizedBox(height: 8),
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Color(0xFFD74D02).withOpacity(0.15),
                              backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                              child: _profileImage == null
                                  ? Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Color(0xFF2C0036),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFD74D02), Color(0xFF2C0036)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      // Name/Phone/Address Input Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: _buildInputCard(
                          children: [
                            _buildTextField(
                              controller: _nameController,
                              label: nameLabel,
                              icon: Icons.person_outline,
                            ),
                            SizedBox(height: 16),
                            _buildDobField(context, dobLabel, isKannada),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _phoneController,
                              label: phoneLabel,
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _addressController,
                              label: addressLabel,
                              icon: Icons.home,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _cityController,
                              label: cityLabel,
                              icon: Icons.location_on,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Continue Button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFD74D02), Color(0xFF2C0036)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      if (_nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(nameEmptyMsg),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (_selectedDob == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(dobEmptyMsg),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (_phoneController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(phoneEmptyMsg),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (_addressController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(addressEmptyMsg),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      _onboardingService.name = _nameController.text;
                      // Save additional details to onboarding service
                      _onboardingService.phoneNumber = _phoneController.text.trim();
                      _onboardingService.address = _addressController.text.trim();
                      _onboardingService.city = _cityController.text.trim();
                      if (_selectedDob != null) {
                        _onboardingService.dateOfBirth = '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}';
                      }
                      // Optionally save phone, address, and dob to onboardingService if needed
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReligionSelectionScreen(),
                        ),
                      );
                    },
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
        ),
      ),
    );
  }

  Widget _buildInputCard({required List<Widget> children}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      color: Colors.white,
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
            padding: EdgeInsets.all(18),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(icon),
      ),
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Crop the image before further processing
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
      );
      if (croppedFile != null) {
        setState(() {
          _profileImage = File(croppedFile.path);
        });
      }
    }
  }

  Widget _buildDobField(BuildContext context, String label, bool isKannada) {
    String? dobText;
    if (_selectedDob != null) {
      dobText = isKannada
          ? '${_selectedDob!.day}-${_selectedDob!.month}-${_selectedDob!.year}'
          : '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}';
    }
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(2000, 1, 1),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Color(0xFFD74D02),
                  onPrimary: Colors.white,
                  onSurface: Color(0xFF2C0036),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: Color(0xFFD74D02),
                  ),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            _selectedDob = picked;
          });
        }
      },
      child: AbsorbPointer(
        child: TextField(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: Icon(Icons.cake),
            hintText: isKannada ? 'ದಯವಿಟ್ಟು ಆಯ್ಕೆಮಾಡಿ' : 'Please select',
          ),
          controller: TextEditingController(text: dobText ?? ''),
          readOnly: true,
        ),
      ),
    );
  }
} 