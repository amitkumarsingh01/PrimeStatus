import 'package:newapp/services/onboarding_service.dart';
import 'package:newapp/services/user_service.dart';
import 'package:flutter/material.dart';
import 'religion_selection_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:crop_your_image/crop_your_image.dart';
import 'dart:typed_data';

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
  final _designationController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _onboardingService = OnboardingService.instance;
  final _userService = UserService();
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  DateTime? _selectedDob;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill name if available
    if (_onboardingService.name != null) {
      _nameController.text = _onboardingService.name!;
    }
    if (_onboardingService.usageType == 'Business' ||
        _onboardingService.usageType == 'ವ್ಯಾಪಾರ') {
      // Optionally pre-fill phone and address if you store them
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _designationController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final isKannada = _onboardingService.language == 'Kannada';

    final title = isKannada ? 'ನಿಮ್ಮ ಪ್ರೊಫೈಲ್ ಸೆಟ್ ಮಾಡಿ' : 'Setup Your Profile';
    final subtitle = isKannada
        ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ಮಾಹಿತಿಯನ್ನು ಪರಿಶೀಲಿಸಿ ಮತ್ತು ಸೇರಿಸಿ'
        : 'Review your information and add your details';
    final nameLabel = isKannada ? 'ನಿಮ್ಮ ಹೆಸರು' : 'Your Name';
    final phoneLabel = isKannada ? 'ಫೋನ್ ಸಂಖ್ಯೆ' : 'Phone Number';
    final addressLabel = isKannada ? 'ವಿಳಾಸ' : 'Address';
    final cityLabel = isKannada ? 'ನಗರ' : 'City';
    final dobLabel = isKannada ? 'ಜನ್ಮ ದಿನಾಂಕ' : 'Date of Birth';
    final designationLabel = isKannada ? 'ಹುದ್ದೆ' : 'Designation';
    final businessNameLabel = isKannada ? 'ವ್ಯಾಪಾರದ ಹೆಸರು' : 'Business Name';
    final profilePicLabel = isKannada ? 'ಪ್ರೊಫೈಲ್ ಫೋಟೋ' : 'Profile Photo';
    final companyLogoLabel = isKannada ? 'ಕಂಪನಿ ಲೋಗೋ' : 'Company Logo';
    final continueText = isKannada ? 'ಮುಂದುವರಿಸಿ' : 'Continue';
    final nameEmptyMsg = isKannada
        ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ಹೆಸರನ್ನು ನಮೂದಿಸಿ'
        : 'Please enter your name';
    final phoneEmptyMsg = isKannada
        ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ'
        : 'Please enter your phone number';
    final addressEmptyMsg = isKannada
        ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ವಿಳಾಸವನ್ನು ನಮೂದಿಸಿ'
        : 'Please enter your address';
    final dobEmptyMsg = isKannada
        ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ಜನ್ಮ ದಿನಾಂಕವನ್ನು ಆಯ್ಕೆಮಾಡಿ'
        : 'Please select your date of birth';
    final designationEmptyMsg = isKannada
        ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ಹುದ್ದೆಯನ್ನು ನಮೂದಿಸಿ'
        : 'Please enter your designation';
    final businessNameEmptyMsg = isKannada
        ? 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ವ್ಯಾಪಾರದ ಹೆಸರನ್ನು ನಮೂದಿಸಿ'
        : 'Please enter your business name';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.pink.shade50, Colors.purple.shade50],
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
                      style: TextStyle(fontSize: 14, color: Color(0xFF2C0036)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Profile Photo/Company Logo Section
                      SizedBox(height: 8),
                      _buildProfilePhotoSection(
                        _onboardingService.usageType == 'Business' || _onboardingService.usageType == 'ವ್ಯಾಪಾರ' 
                          ? companyLogoLabel 
                          : profilePicLabel, 
                        isKannada
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
                            // Conditional fields based on usage type
                            if (_onboardingService.usageType == 'Personal' || _onboardingService.usageType == 'ವೈಯಕ್ತಿಕ') ...[
                              SizedBox(height: 16),
                              _buildTextField(
                                controller: _designationController,
                                label: designationLabel,
                                icon: Icons.work_outline,
                              ),
                            ],
                            if (_onboardingService.usageType == 'Business' || _onboardingService.usageType == 'ವ್ಯಾಪಾರ') ...[
                              SizedBox(height: 16),
                              _buildTextField(
                                controller: _businessNameController,
                                label: businessNameLabel,
                                icon: Icons.business,
                              ),
                            ],
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
                    onPressed: _isUploading ? null : () async {
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
                      
                      // Validate conditional fields
                      if (_onboardingService.usageType == 'Personal' || _onboardingService.usageType == 'ವೈಯಕ್ತಿಕ') {
                        if (_designationController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(designationEmptyMsg),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }
                      
                      if (_onboardingService.usageType == 'Business' || _onboardingService.usageType == 'ವ್ಯಾಪಾರ') {
                        if (_businessNameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(businessNameEmptyMsg),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }
                      
                      // Start uploading
                      setState(() {
                        _isUploading = true;
                      });
                      
                      try {
                        // Upload profile photo/company logo if selected
                        if (_profileImage != null) {
                          final currentUser = _userService.currentUser;
                          if (currentUser != null) {
                            String profilePhotoUrl = await _userService.uploadProfilePhoto(_profileImage!, currentUser.uid);
                            _onboardingService.profilePhotoUrl = profilePhotoUrl;
                            
                            // For business users, also store as business logo URL
                            if (_onboardingService.usageType == 'Business' || _onboardingService.usageType == 'ವ್ಯಾಪಾರ') {
                              _onboardingService.businessLogoUrl = profilePhotoUrl;
                            }
                          }
                        }
                        
                        _onboardingService.name = _nameController.text;
                        // Save additional details to onboarding service
                        _onboardingService.phoneNumber = _phoneController.text.trim();
                        _onboardingService.address = _addressController.text.trim();
                        _onboardingService.city = _cityController.text.trim();
                        if (_selectedDob != null) {
                          _onboardingService.dateOfBirth =
                              '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}';
                        }
                        
                        // Save conditional fields
                        if (_onboardingService.usageType == 'Personal' || _onboardingService.usageType == 'ವೈಯಕ್ತಿಕ') {
                          _onboardingService.designation = _designationController.text.trim();
                        }
                        
                        if (_onboardingService.usageType == 'Business' || _onboardingService.usageType == 'ವ್ಯಾಪಾರ') {
                          _onboardingService.businessName = _businessNameController.text.trim();
                        }
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReligionSelectionScreen(),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to upload images: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setState(() {
                          _isUploading = false;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUploading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFAEAC7)),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                isKannada ? 'ಅಪ್ಲೋಡ್ ಮಾಡಲಾಗುತ್ತಿದೆ...' : 'Uploading...',
                                style: TextStyle(fontSize: 16, color: Color(0xFFFAEAC7)),
                              ),
                            ],
                          )
                        : Text(
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
            child: Column(children: children),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(icon),
      ),
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Use crop_your_image for cropping
      final croppedFile = await _showCropDialog(File(pickedFile.path));
      if (croppedFile != null) {
        setState(() {
          _profileImage = croppedFile;
        });
      }
    }
  }


  // Custom image cropping dialog using crop_your_image
  Future<File?> _showCropDialog(File imageFile) async {
    final cropController = CropController();
    bool cropping = false;
    Uint8List? croppedData;

    return await showDialog<File?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.crop, color: Color(0xFFD74D02)),
              SizedBox(width: 8),
              Text('Crop Profile Photo'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Crop(
                        controller: cropController,
                        image: imageFile.readAsBytesSync(),
                        aspectRatio: 1.0,
                        withCircleUi: false,
                        baseColor: Color(0xFFD74D02),
                        maskColor: Colors.black.withOpacity(0.6),
                        cornerDotBuilder: (size, edgeAlignment) =>
                            const DotControl(color: Color(0xFFD74D02)),
                        interactive: true,
                        fixCropRect: true,
                        radius: 20,
                        willUpdateScale: (newScale) => newScale < 5,
                        onStatusChanged: (status) {
                          // Optional: Handle crop status changes
                        },
                        initialRectBuilder: InitialRectBuilder.withBuilder((
                          viewportRect,
                          imageRect,
                        ) {
                          // Create a perfect square in the center
                          final size = viewportRect.width < viewportRect.height
                              ? viewportRect.width - 48
                              : viewportRect.height - 48;
                          final centerX =
                              viewportRect.left + viewportRect.width / 2;
                          final centerY =
                              viewportRect.top + viewportRect.height / 2;

                          return Rect.fromCenter(
                            center: Offset(centerX, centerY),
                            width: size,
                            height: size,
                          );
                        }),
                        onCropped: (result) async {
                          try {
                            if (result is CropSuccess) {
                              croppedData = result.croppedImage;
                              final tempDir = Directory.systemTemp;
                              final tempFile = File(
                                '${tempDir.path}/cropped_profile_${DateTime.now().millisecondsSinceEpoch}.png',
                              );
                              await tempFile.writeAsBytes(croppedData!);
                              Navigator.pop(context, tempFile);
                            } else if (result is CropFailure) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Error'),
                                  content: Text(
                                    'Failed to crop image: ${result.cause}',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Error'),
                                content: Text('Failed to crop image: $e'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                          setDialogState(() => cropping = false);
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Drag to adjust crop area',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      onPressed: cropping
                          ? null
                          : () {
                              setDialogState(() => cropping = true);
                              cropController.crop();
                            },
                      icon: Icon(Icons.crop),
                      label: Text('Crop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFD74D02),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: Icon(Icons.cake),
            hintText: isKannada ? 'ದಯವಿಟ್ಟು ಆಯ್ಕೆಮಾಡಿ' : 'Please select',
          ),
          controller: TextEditingController(text: dobText ?? ''),
          readOnly: true,
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSection(String label, bool isKannada) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C0036),
            ),
          ),
          SizedBox(height: 16),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Color(0xFFD74D02).withOpacity(0.15),
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? Icon(
                          (_onboardingService.usageType == 'Business' || _onboardingService.usageType == 'ವ್ಯಾಪಾರ') 
                            ? Icons.business 
                            : Icons.person,
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
        ],
      ),
    );
  }

}
