import 'package:flutter/material.dart';
import 'dart:math';
import '../data/quote_data.dart';
import '../constants/app_constants.dart';
import '../widgets/common_widgets.dart';
import '../widgets/admin_post_feed_widget.dart';
import '../widgets/user_posts_widget.dart';
import 'quote_editor_screen.dart';
import 'package:primestatus/services/user_service.dart';
import 'package:primestatus/services/quote_service.dart';
import 'package:primestatus/services/background_removal_service.dart';
import 'package:primestatus/services/category_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'onboarding/login_screen.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:primestatus/widgets/fullscreen_post_viewer.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'dart:typed_data';

class HomeScreen extends StatefulWidget {
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool isLoggedIn = false;
  String userName = '';
  String userEmail = '';
  String userLanguage = '';
  String userUsageType = '';
  String userReligion = '';
  String userState = '';
  String userSubscription = '';
  String? userProfilePhotoUrl;
  String userDob = '';
  String userPhoneNumber = '';
  String userAddress = '';
  String userCity = '';
  late TextEditingController _quoteController;
  String quoteOfTheDay = '';
  List<String> favoriteQuotes = [];
  List<Map<String, dynamic>> userProfilePhotos = []; // List to store multiple profile photos (now as maps)
  bool _isProcessingPhoto = false;
  
  final UserService _userService = UserService();
  final QuoteService _quoteService = QuoteService();
  final BackgroundRemovalService _bgRemovalService = BackgroundRemovalService();
  final CategoryService _categoryService = CategoryService();
  User? _currentUser;

  // Multi-category selection state
  Set<String> _selectedCategories = {'All'};
  // Add search query state for categories
  String _categorySearchQuery = '';
  // Firebase categories state
  List<Map<String, dynamic>> _firebaseCategories = [];
  bool _isLoadingCategories = true;
  // Search functionality state
  bool _isSearchActive = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredCategories = [];
  
  // Helper method to get category name based on user language
  String _getCategoryName(Map<String, dynamic> category) {
    // Default to English if no language is set
    if (userLanguage.isEmpty) {
      return category['nameEn'] as String? ?? 'Unknown';
    }
    
    if (userLanguage.toLowerCase() == 'kannada') {
      final kannadaName = category['nameKn'] as String?;
      if (kannadaName != null && kannadaName.isNotEmpty) {
        return kannadaName;
      }
      // Fallback to English if Kannada name is empty or null
      return category['nameEn'] as String? ?? 'Unknown';
    }
    return category['nameEn'] as String? ?? 'Unknown';
  }

  @override
  void initState() {
    super.initState();
    _quoteController = TextEditingController();
    _setQuoteOfTheDay();
    _checkAuthState();
    _fetchCategories();
  }

  void _setQuoteOfTheDay() {
    final allQuotes = QuoteData.quotes.values.expand((list) => list).toList();
    final random = Random();
    quoteOfTheDay = allQuotes[random.nextInt(allQuotes.length)];
  }

  Future<void> _fetchCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
      });
      
      final categories = await _categoryService.getCategories();
      setState(() {
        _firebaseCategories = categories;
        _filteredCategories = categories; // Initialize filtered categories
        _isLoadingCategories = false;
      });
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() {
        _isLoadingCategories = false;
      });
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories. Using default categories.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _checkAuthState() {
    _userService.authStateChanges.listen((User? user) {
      setState(() {
        _currentUser = user;
        isLoggedIn = user != null;
      });
      
      if (user != null) {
        _fetchUserDetails();
      } else {
        _clearUserData();
      }
    });
  }

  Future<void> _fetchUserDetails() async {
    if (_currentUser == null) {
      // If no authenticated user, clear user data and return
      _clearUserData();
      return;
    }
    
    try {
      Map<String, dynamic>? userData = await _userService.getUserData(_currentUser!.uid);
      if (userData != null) {
        setState(() {
          userName = userData['name'] ?? '';
          userEmail = userData['email'] ?? '';
          userLanguage = userData['language'] ?? '';
          userUsageType = userData['usageType'] ?? 'Personal'; // Default to Personal if not set
          userReligion = userData['religion'] ?? '';
          userState = userData['state'] ?? '';
          userSubscription = userData['subscription'] ?? '';
          userProfilePhotoUrl = userData['profilePhotoUrl'];
          userPhoneNumber = userData['phoneNumber'] ?? '';
          userAddress = userData['address'] ?? '';
          userDob = userData['dateOfBirth'] ?? '';
          userCity = userData['city'] ?? '';
        });
        
        // Fetch user's profile photos
        await _fetchUserProfilePhotos();
      }
    } catch (e) {
      print('Error fetching user details: $e');
      // If there's an error, clear user data
      _clearUserData();
    }
  }

  Future<void> _fetchUserProfilePhotos() async {
    if (_currentUser == null) {
      print('_fetchUserProfilePhotos: No current user');
      return;
    }
    try {
      print('_fetchUserProfilePhotos: Fetching photos from Firestore');
      final photosSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('profilePhotos')
          .orderBy('uploadedAt', descending: true)
          .get();
      print('_fetchUserProfilePhotos: Found ${photosSnapshot.docs.length} photos');
      setState(() {
        userProfilePhotos = photosSnapshot.docs
            .map((doc) => doc.data())
            .toList();
      });
      print('_fetchUserProfilePhotos: Updated state with ${userProfilePhotos.length} photos');
    } catch (e) {
      print('Error fetching profile photos: $e');
    }
  }

  void _clearUserData() {
    setState(() {
      userName = '';
      userEmail = '';
      userLanguage = '';
      userUsageType = 'Personal'; // Default to Personal
      userReligion = '';
      userState = '';
      userSubscription = '';
      userProfilePhotoUrl = null;
      userPhoneNumber = '';
      userAddress = '';
      userDob = '';
      userCity = '';
      userProfilePhotos = []; // Clear profile photos list
    });
  }



  // Custom image cropping dialog using crop_your_image
  Future<File?> _showCropDialog(File imageFile) async {
    final cropController = CropController();
    bool cropping = false;
    
    return await showDialog<File?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.crop, color: Colors.deepOrange),
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
                        onCropped: (data) async {
                          // data can be Uint8List or CropResult depending on crop_your_image version
                          final bytes = (data is Uint8List)
                              ? data
                              : (data as dynamic).bytes as Object;
                          if (bytes is List<int>) {
                            final tempDir = Directory.systemTemp;
                            final tempFile = File('${tempDir.path}/cropped_profile_${DateTime.now().millisecondsSinceEpoch}.png');
                            await tempFile.writeAsBytes(bytes);
                            Navigator.pop(context, tempFile);
                          } else {
                            Navigator.pop(context, null);
                          }
                        },
                        withCircleUi: false,
                        baseColor: Colors.deepOrange,
                        maskColor: Colors.black.withOpacity(0.6),
                        cornerDotBuilder: (size, edgeAlignment) => const DotControl(color: Colors.deepOrange),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Drag to adjust crop area',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Done'),
                    ),
                    ElevatedButton.icon(
                      onPressed: cropping
                        ? null
                        : () {
                            setState(() => cropping = true);
                            cropController.crop();
                          },
                      icon: Icon(Icons.crop),
                      label: Text('Crop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
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
    // This return is not used, as the dialog returns the file
  }

  // Search functionality methods
  void _showSearchDialog() {
    _searchQuery = '';
    _filteredCategories = _firebaseCategories;
    _isSearchActive = true;

    final TextEditingController searchController = TextEditingController();
    final FocusNode searchFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Request focus after the first frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!searchFocusNode.hasFocus) {
              searchFocusNode.requestFocus();
            }
          });
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.search, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text('Search Categories'),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Type to search categories...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        _searchQuery = value;
                        _filterCategories(value);
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: _isLoadingCategories
                        ? Center(child: CircularProgressIndicator())
                        : _filteredCategories.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off, size: 48, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text(
                                      _searchQuery.isEmpty 
                                          ? 'No categories available'
                                          : 'No categories found for "$_searchQuery"',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredCategories.length,
                                itemBuilder: (context, index) {
                                  final category = _filteredCategories[index];
                                  final categoryName = _getCategoryName(category);
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.deepOrange.shade100,
                                      child: Icon(
                                        _getCategoryIcon(categoryName),
                                        color: Colors.deepOrange,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      categoryName,
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    // subtitle: Text('${QuoteData.quotes[categoryName]?.length ?? 0} quotes'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _selectCategoryFromSearch(categoryName);
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _isSearchActive = false;
                },
                child: Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _filterCategories(String query) {
    if (query.isEmpty) {
      _filteredCategories = _firebaseCategories;
    } else {
      _filteredCategories = _firebaseCategories.where((category) {
        final categoryName = _getCategoryName(category);
        return categoryName.toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
  }

  void _selectCategoryFromSearch(String categoryName) {
    setState(() {
      _selectedCategories = {categoryName};
      _isSearchActive = false;
    });
    
    // Switch to admin feed tab to show the selected category posts
    _selectedIndex = 0;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing posts from "$categoryName"'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updateUserDetails({
    String? name,
    String? language,
    String? usageType,
    String? religion,
    String? state,
    String? profilePhotoUrl,
    String? phoneNumber,
    String? address,
    String? dateOfBirth,
    String? city,
  }) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to update your profile')),
      );
      return;
    }
    
    try {
      // Update the specific field in Firebase
      Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (language != null) updateData['language'] = language;
      if (usageType != null) updateData['usageType'] = usageType;
      if (religion != null) updateData['religion'] = religion;
      if (state != null) updateData['state'] = state;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (address != null) updateData['address'] = address;
      if (dateOfBirth != null) updateData['dateOfBirth'] = dateOfBirth;
      if (city != null) updateData['city'] = city;
      
      await _userService.updateUserData(_currentUser!.uid, updateData);
      
      // Also update the profile if name is provided
      if (name != null) {
        await _userService.updateProfile(uid: _currentUser!.uid, name: name);
      }
      
      // Refresh user data to update UI
      await _fetchUserDetails();
      
      // Refresh categories if language changed to update UI
      if (language != null) {
        // Trigger UI rebuild with new language
        setState(() {});
      }
      
      // Show success message for usage type change
      if (usageType != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usage type changed to $usageType')),
        );
      }
      
      // Show success message for language change
      if (language != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Language changed to $language')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  Future<void> _pickProfilePhoto() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to update your profile photo')),
      );
      return;
    }
    try {
      setState(() {
        _isProcessingPhoto = true;
      });
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        
        // Use the new crop_your_image dialog
        File? croppedImageFile;
        final croppedFile = await _showCropDialog(imageFile);
        if (croppedFile != null) {
          croppedImageFile = croppedFile;
        } else {
          // User cancelled cropping, use original image
          croppedImageFile = imageFile;
        }
        
        if (croppedImageFile != null) {
          // Upload original
          String downloadUrl = await _userService.uploadProfilePhoto(croppedImageFile, _currentUser!.uid);
          // Remove background and upload processed image
          String? processedUrl = await _bgRemovalService.removeBackground(croppedImageFile);
          String? downloadUrlNoBg;
          if (processedUrl != null) {
            // Download processed image and upload to Firebase Storage
            final response = await http.get(Uri.parse(processedUrl));
            if (response.statusCode == 200) {
              final tempDir = Directory.systemTemp;
              final tempFile = File('${tempDir.path}/profile_nobg_${DateTime.now().millisecondsSinceEpoch}.png');
              await tempFile.writeAsBytes(response.bodyBytes);
              downloadUrlNoBg = await _userService.uploadProfilePhoto(tempFile, _currentUser!.uid);
              await tempFile.delete();
            }
          }
          // Add both to Firestore
          await _addProfilePhotoToGallery(downloadUrl, photoUrlNoBg: downloadUrlNoBg);
          await _fetchUserProfilePhotos();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile photo added to gallery!')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add profile photo: $e')),
      );
    } finally {
      setState(() {
        _isProcessingPhoto = false;
      });
    }
  }

  Future<void> _takeProfilePhoto() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to update your profile photo')),
      );
      return;
    }
    try {
      setState(() {
        _isProcessingPhoto = true;
      });
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        
        // Use the new crop_your_image dialog
        File? croppedImageFile;
        final croppedFile = await _showCropDialog(imageFile);
        if (croppedFile != null) {
          croppedImageFile = croppedFile;
        } else {
          // User cancelled cropping, use original image
          croppedImageFile = imageFile;
        }
        
        if (croppedImageFile != null) {
          // Upload original
          String downloadUrl = await _userService.uploadProfilePhoto(croppedImageFile, _currentUser!.uid);
          // Remove background and upload processed image
          String? processedUrl = await _bgRemovalService.removeBackground(croppedImageFile);
          String? downloadUrlNoBg;
          if (processedUrl != null) {
            final response = await http.get(Uri.parse(processedUrl));
            if (response.statusCode == 200) {
              final tempDir = Directory.systemTemp;
              final tempFile = File('${tempDir.path}/profile_nobg_${DateTime.now().millisecondsSinceEpoch}.png');
              await tempFile.writeAsBytes(response.bodyBytes);
              downloadUrlNoBg = await _userService.uploadProfilePhoto(tempFile, _currentUser!.uid);
              await tempFile.delete();
            }
          }
          await _addProfilePhotoToGallery(downloadUrl, photoUrlNoBg: downloadUrlNoBg);
          await _fetchUserProfilePhotos();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile photo added to gallery!')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add profile photo: $e')),
      );
    } finally {
      setState(() {
        _isProcessingPhoto = false;
      });
    }
  }

  Future<void> _addProfilePhotoToGallery(String photoUrl, {String? photoUrlNoBg}) async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('profilePhotos')
          .add({
        'photoUrl': photoUrl,
        'photoUrlNoBg': photoUrlNoBg,
        'uploadedAt': FieldValue.serverTimestamp(),
        'isActive': false,
        'withoutBackground': photoUrlNoBg != null, // Mark as processed if available
      });
    } catch (e) {
      print('Error adding profile photo to gallery: $e');
    }
  }

  Future<void> _selectProfilePhoto(String photoUrl) async {
    if (_currentUser == null) return;
    
    try {
      // Update user's main profile photo in Firestore
      await _userService.updateUserData(_currentUser!.uid, {
        'profilePhotoUrl': photoUrl,
      });
      
      // Update Firebase Auth profile
      await _userService.updateProfile(uid: _currentUser!.uid);
      
      // Update active status in profile photos collection
      final photosSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('profilePhotos')
          .get();
      
      for (var doc in photosSnapshot.docs) {
        await doc.reference.update({
          'isActive': doc.data()['photoUrl'] == photoUrl,
        });
      }
      
      // Refresh user data to update UI
      await _fetchUserDetails();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile photo updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile photo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color.fromARGB(255, 255, 250, 247),
                const Color.fromARGB(255, 255, 252, 248),
              ],
            ),
          ),
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildAdminFeedTab(),
              _buildCategoriesTab(),
              _buildFavoritesTab(),
              _buildHomeTab(),
              _buildProfileTab(),
            ],
          ),
        ),
        // Loading overlay for profile photo processing
        if (_isProcessingPhoto)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Processing photo...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black, decoration: TextDecoration.none, fontFamily: 'Roboto'),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Removing background and uploading',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12, decoration: TextDecoration.none, fontFamily: 'Roboto'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
Widget _buildHomeTab() {
  return Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2c0036), Color(0xFFd74d02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Column(
            children: [
              // First row: Business/Personal toggle, Search, Profile
              Row(
                children: [
                  // Business/Personal Toggle
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            if (isLoggedIn) {
                              await _updateUserDetails(usageType: 'Personal');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Please sign in to change usage type')),
                              );
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: userUsageType == 'Personal'
                                  ? LinearGradient(colors: [Color(0xFF2c0036), Color(0xFFd74d02)])
                                  : null,
                              color: userUsageType == 'Personal' ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'Personal',
                              style: TextStyle(
                                color: userUsageType == 'Personal' ? Colors.white : Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            if (isLoggedIn) {
                              await _updateUserDetails(usageType: 'Business');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Please sign in to change usage type')),
                              );
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: userUsageType == 'Business'
                                  ? LinearGradient(colors: [Color(0xFF2c0036), Color(0xFFd74d02)])
                                  : null,
                              color: userUsageType == 'Business' ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'Business',
                              style: TextStyle(
                                color: userUsageType == 'Business' ? Colors.white : Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Spacer(),
                  
                  // Search Button
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _showSearchDialog,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search, size: 18, color: Colors.black87),
                              SizedBox(width: 8),
                              Text(
                                'Search',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 12),
                  
                  // Profile/Login
                  isLoggedIn && userProfilePhotoUrl != null
                      ? GestureDetector(
                          onTap: () => setState(() => _selectedIndex = 4),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(userProfilePhotoUrl!),
                            backgroundColor: Colors.grey.shade200,
                          ),
                        )
                      : GestureDetector(
                          onTap: _showLoginDialog,
                          child: Container(
                            height: 36,
                            width: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.person_outline,
                              size: 20,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Second row: Category chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip('All', true),
                    SizedBox(width: 8),
                    _buildCategoryChip('Today Special', false),
                    SizedBox(width: 8),
                    _buildCategoryChip('Good Morning', false),
                    SizedBox(width: 8),
                    _buildCategoryChip('My Business', false, icon: Icons.business_center),
                    SizedBox(width: 8),
                    _buildCategoryChip('Good Night', false),
                    SizedBox(width: 8),
                    _buildCategoryChip('Political', false, icon: Icons.flag),
                    SizedBox(width: 8),
                    _buildCategoryChip('Happy Sunday', false),
                    SizedBox(width: 8),
                    _buildCategoryChip('Love ❤️', false),
                    SizedBox(width: 8),
                    _buildCategoryChip('More (8)', false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
        body: RefreshIndicator(
          onRefresh: _fetchCategories,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuoteOfTheDay(),
                SizedBox(height: 24),
                _buildQuickActions(),
                SizedBox(height: 24),
                _buildFeaturedCategories(),
                // SizedBox(height: 24),
                // _buildAdminPostFeed(),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected, {IconData? icon}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: isSelected ? Color(0xFF1976D2) : Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isSelected ? Color(0xFF1976D2) : Colors.grey.shade300,
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.black87,
          ),
          SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildQuoteOfTheDay() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Quote of the Day',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            quoteOfTheDay,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _createQuote(quoteOfTheDay),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.deepOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Create Design'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CommonWidgets.buildActionCard(
                'Create Quote',
                Icons.create,
                Colors.deepOrange,
                () => _showQuoteSelectionDialog(),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: CommonWidgets.buildActionCard(
                'My Designs',
                Icons.folder,
                Colors.pink,
                () => CommonWidgets.showComingSoonSnackBar(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturedCategories() {
    if (_isLoadingCategories) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          Container(
            height: 100,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 4),
            itemCount: _firebaseCategories.length,
            itemBuilder: (context, index) {
              final category = _firebaseCategories[index];
              final categoryName = _getCategoryName(category);
              return Container(
                width: MediaQuery.of(context).size.width / 5.5, // Show 5 categories at a time
                margin: EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: AppConstants.categoryColors[index % AppConstants.categoryColors.length],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.categoryColors[index % AppConstants.categoryColors.length][0].withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _getCategoryIcon(categoryName),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdminPostFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.feed, color: Colors.deepOrange, size: 24),
            SizedBox(width: 8),
            Text(
              'Latest Posts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          height: 400, // Fixed height for the feed
          child: AdminPostFeedWidget(
            selectedCategories: _selectedCategories.toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2c0036), Color(0xFFd74d02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
            child: Row(
              children: [
                SizedBox(width: 8),
                //30% Create Button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: 32,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: userUsageType == 'Business'
                                  ? LinearGradient(colors: [Color(0xFF2c0036), Color(0xFFd74d02)])
                                  : null,
                              color: userUsageType == 'Business' ? null : Colors.grey.shade200,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(6),
                                bottomLeft: Radius.circular(6),
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                if (isLoggedIn) {
                                  await _updateUserDetails(usageType: 'Business');
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Please sign in to change usage type')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    bottomLeft: Radius.circular(6),
                                  ),
                                ),
                                padding: EdgeInsets.zero,
                                minimumSize: Size(0, 32),
                              ),
                              child: Text(
                                'Business',
                                style: TextStyle(
                                  color: userUsageType == 'Business' ? Color(0xfffaeac7) : Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: userUsageType == 'Personal'
                                  ? LinearGradient(colors: [Color(0xFF2c0036), Color(0xFFd74d02)])
                                  : null,
                              color: userUsageType == 'Personal' ? null : Colors.grey.shade200,
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(6),
                                bottomRight: Radius.circular(6),
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                if (isLoggedIn) {
                                  await _updateUserDetails(usageType: 'Personal');
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Please sign in to change usage type')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(6),
                                    bottomRight: Radius.circular(6),
                                  ),
                                ),
                                padding: EdgeInsets.zero,
                                minimumSize: Size(0, 32),
                              ),
                              child: Text(
                                'Personal',
                                style: TextStyle(
                                  color: userUsageType == 'Personal' ? Color(0xfffaeac7) : Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 8),
                // 20% Search Bar
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2c0036), Color(0xFFd74d02)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.all(2), // Border thickness
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _categorySearchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // 10% Profile/Login Icon
                Expanded(
                  flex: 1,
                  child: isLoggedIn && userProfilePhotoUrl != null
                      ? GestureDetector(
                          onTap: () => setState(() => _selectedIndex = 4),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(userProfilePhotoUrl!),
                            backgroundColor: Colors.grey.shade200,
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.login, size: 20),
                          onPressed: _showLoginDialog,
                          color: Colors.white,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoadingCategories
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              // padding: EdgeInsets.all(16),
              itemCount: _firebaseCategories
                  .where((category) =>
                      _categorySearchQuery.isEmpty ||
                      _getCategoryName(category).toLowerCase().contains(_categorySearchQuery.toLowerCase()))
                  .toList()
                  .length,
              itemBuilder: (context, index) {
                final filteredCategories = _firebaseCategories
                    .where((category) =>
                        _categorySearchQuery.isEmpty ||
                        _getCategoryName(category).toLowerCase().contains(_categorySearchQuery.toLowerCase()))
                    .toList();
                final category = filteredCategories[index];
                final categoryName = _getCategoryName(category);
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepOrange.shade100,
                      child: Icon(Icons.format_quote, color: Colors.deepOrange),
                    ),
                    title: Text(
                      categoryName,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    // subtitle: Text('${QuoteData.quotes[categoryName]?.length ?? 0} quotes'),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFavoritesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2c0036), Color(0xFFd74d02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
            child: Row(
              children: [
                SizedBox(width: 8),
                //30% Create Button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: 32,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: userUsageType == 'Business'
                                  ? LinearGradient(colors: [Color(0xFF2c0036), Color(0xFFd74d02)])
                                  : null,
                              color: userUsageType == 'Business' ? null : Colors.grey.shade200,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(6),
                                bottomLeft: Radius.circular(6),
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                if (isLoggedIn) {
                                  await _updateUserDetails(usageType: 'Business');
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Please sign in to change usage type')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    bottomLeft: Radius.circular(6),
                                  ),
                                ),
                                padding: EdgeInsets.zero,
                                minimumSize: Size(0, 32),
                              ),
                              child: Text(
                                'Business',
                                style: TextStyle(
                                  color: userUsageType == 'Business' ? Color(0xfffaeac7) : Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: userUsageType == 'Personal'
                                  ? LinearGradient(colors: [Color(0xFF2c0036), Color(0xFFd74d02)])
                                  : null,
                              color: userUsageType == 'Personal' ? null : Colors.grey.shade200,
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(6),
                                bottomRight: Radius.circular(6),
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                if (isLoggedIn) {
                                  await _updateUserDetails(usageType: 'Personal');
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Please sign in to change usage type')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(6),
                                    bottomRight: Radius.circular(6),
                                  ),
                                ),
                                padding: EdgeInsets.zero,
                                minimumSize: Size(0, 32),
                              ),
                              child: Text(
                                'Personal',
                                style: TextStyle(
                                  color: userUsageType == 'Personal' ? Color(0xfffaeac7) : Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 8),
                // 20% Search Bar
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2c0036), Color(0xFFd74d02)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.all(2), // Border thickness
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _categorySearchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // 10% Profile/Login Icon
                Expanded(
                  flex: 1,
                  child: isLoggedIn && userProfilePhotoUrl != null
                      ? GestureDetector(
                          onTap: () => setState(() => _selectedIndex = 4),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(userProfilePhotoUrl!),
                            backgroundColor: Colors.grey.shade200,
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.login, size: 20),
                          onPressed: _showLoginDialog,
                          color: Colors.white,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: favoriteQuotes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No favorite quotes yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start adding quotes to your favorites',
                    style: TextStyle(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: favoriteQuotes.length,
              itemBuilder: (context, index) {
                final quote = favoriteQuotes[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(quote),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.favorite, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              favoriteQuotes.remove(quote);
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.create),
                          onPressed: () => _createQuote(quote),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
Widget _buildAdminFeedTab() {
  return Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2c0036), Color(0xFFd74d02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Column(
            children: [
              // First row: Business/Personal toggle, Search, Profile
              Row(
                children: [
                  // Business/Personal Toggle
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            if (isLoggedIn) {
                              await _updateUserDetails(usageType: 'Personal');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Please sign in to change usage type')),
                              );
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: userUsageType == 'Personal'
                                  ? LinearGradient(colors: [Color(0xFFd74d02), Color(0xFFd74d02)])
                                  : null,
                              color: userUsageType == 'Personal' ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'Personal',
                              style: TextStyle(
                                color: userUsageType == 'Personal' ? Colors.white : Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            if (isLoggedIn) {
                              await _updateUserDetails(usageType: 'Business');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Please sign in to change usage type')),
                              );
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: userUsageType == 'Business'
                                  ? LinearGradient(colors: [Color(0xFFd74d02), Color(0xFFd74d02)])
                                  : null,
                              color: userUsageType == 'Business' ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'Business',
                              style: TextStyle(
                                color: userUsageType == 'Business' ? Colors.white : Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Spacer(),
                  
                  // Search Button
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _showSearchDialog,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search, size: 18, color: Colors.black87),
                              SizedBox(width: 8),
                              Text(
                                'Search',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 12),
                  
                  // Profile/Login
                  isLoggedIn && userProfilePhotoUrl != null
                      ? GestureDetector(
                          onTap: () => setState(() => _selectedIndex = 4),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(userProfilePhotoUrl!),
                            backgroundColor: Colors.grey.shade200,
                          ),
                        )
                      : GestureDetector(
                          onTap: _showLoginDialog,
                          child: Container(
                            height: 36,
                            width: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.person_outline,
                              size: 20,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Second row: Admin Feed specific category chips
              // SingleChildScrollView(
              //   scrollDirection: Axis.horizontal,
              //   child: Row(
              //     children: [
              //       _buildAdminCategoryChip('All', true),
              //       SizedBox(width: 8),
              //       _buildAdminCategoryChip('Pending', false, icon: Icons.pending_actions),
              //       SizedBox(width: 8),
              //       _buildAdminCategoryChip('Approved', false, icon: Icons.check_circle),
              //       SizedBox(width: 8),
              //       _buildAdminCategoryChip('Rejected', false, icon: Icons.cancel),
              //       SizedBox(width: 8),
              //       _buildAdminCategoryChip('Reported', false, icon: Icons.report),
              //       SizedBox(width: 8),
              //       _buildAdminCategoryChip('Featured', false, icon: Icons.star),
              //       SizedBox(width: 8),
              //       _buildAdminCategoryChip('Analytics', false, icon: Icons.analytics),
              //       SizedBox(width: 8),
              //       _buildAdminCategoryChip('Settings', false, icon: Icons.settings),
              //     ],
              //   ),
              // ),
            ],
          ),
        ),
      ),
    ),
      body: Column(
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff2c0036), Color(0xffd74d02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: _isLoadingCategories
                      ? Center(child: CircularProgressIndicator(color: Colors.white))
                      : Wrap(
                          spacing: 4,
                          runSpacing: 6,
                          children: [
                            // Always show "All" option
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategories = {'All'};
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _selectedCategories.contains('All') ? const Color(0xffd74d02) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(width: 0.5, color: const Color.fromARGB(255, 255, 119, 34)),
                                ),
                                child: Text(
                                  'All',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedCategories.contains('All') ? Colors.white : Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            // Show Firebase categories
                            ..._firebaseCategories.map((category) {
                              final categoryName = _getCategoryName(category);
                              final isSelected = _selectedCategories.contains(categoryName);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    // Single select: always replace the selection with the tapped category
                                    _selectedCategories = {categoryName};
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xffd74d02) : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(width: 0.5, color: const Color.fromARGB(255, 255, 119, 34)),
                                  ),
                                  child: Text(
                                    categoryName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AdminPostFeedWidget(
              selectedCategories: _selectedCategories.toList(),
              onPostTap: (posts, initialIndex) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullscreenPostViewer(
                      posts: posts,
                      initialIndex: initialIndex,
                      userUsageType: userUsageType,
                      userName: userName,
                      userProfilePhotoUrl: userProfilePhotoUrl,
                      userAddress: userAddress,
                      userPhoneNumber: userPhoneNumber,
                      userCity: userCity,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCategoryChip(String label, bool isSelected, {IconData? icon}) {
  return GestureDetector(
    onTap: () {
      // Handle category selection
      setState(() {
        // Update your selected admin category state here
      });
    },
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Color(0xFF1976D2) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Color(0xFF1976D2) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.black87,
            ),
            SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildProfileTab() {
    if (!isLoggedIn) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepOrange.shade100,
              child: Icon(
                Icons.person,
                size: 60,
                color: Colors.deepOrange,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Guest User',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Sign in to save your designs',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showLoginDialog,
              child: Text('Sign In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xffd74d02),
                foregroundColor: Colors.white,
              ),
            ),
            Text('More', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),

            SizedBox(height: 32),
            // CommonWidgets.buildProfileOption('Premium Features', Icons.star, () => _showPremiumDialog()),
            // CommonWidgets.buildProfileOption('Share App', Icons.share, () => CommonWidgets.showComingSoonSnackBar(context)),
            // CommonWidgets.buildProfileOption('Rate Us', Icons.thumb_up, () => CommonWidgets.showComingSoonSnackBar(context)),
            // CommonWidgets.buildProfileOption('Help & Support', Icons.help, () => CommonWidgets.showComingSoonSnackBar(context)),
            CommonWidgets.buildProfileOption('About', Icons.info, () => _showAboutDialog()),
            CommonWidgets.buildProfileOption('Contact Us', Icons.contact_mail, () => _showContactUsDialog()),
            CommonWidgets.buildProfileOption('Privacy Policy', Icons.privacy_tip, () => _showPrivacyPolicyDialog()),
            CommonWidgets.buildProfileOption('Terms and Conditions', Icons.description, () => _showTermsDialog()),
            CommonWidgets.buildProfileOption('Refund Policy', Icons.monetization_on, () => _showRefundDialog()),
          ],
        ),
      );
    }
    
    Widget _buildUserDataCard(String title, String? value, IconData icon, {VoidCallback? onTap, bool isEditable = true}) {
      return Card(
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isEditable ? onTap : null,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: Colors.deepOrange, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        value ?? 'Not set',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: value != null ? Colors.black87 : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isEditable)
                  Icon(
                    Icons.edit,
                    color: Colors.grey[400],
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      );
    }
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Add a button to top left corner to go back to the home screen
          SizedBox(height: 26),
          Container(
            alignment: Alignment.topLeft,
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _selectedIndex = 0),
                ),
                Text(
                  'Go to Home Screen',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black, // Normal color
                    decoration: TextDecoration.none, // Remove underline
                    fontFamily: 'Roboto', // Force normal font
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _pickProfilePhoto,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: const Color.fromARGB(255, 209, 207, 207),
              backgroundImage: userProfilePhotoUrl != null
                  ? NetworkImage(userProfilePhotoUrl!)
                  : null,
              child: userProfilePhotoUrl == null
                  ? Icon(Icons.account_circle, size: 60, color: Colors.deepOrange)
                  : null,
            ),
          ),
          SizedBox(height: 16),
          Text(
            userName.isNotEmpty ? userName : 'User',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black, decoration: TextDecoration.none, fontFamily: 'Roboto'),
          ),
          SizedBox(height: 8),
          Text(
            'Tap photo to change',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black, // Normal color
              decoration: TextDecoration.none, // Remove underline
              fontFamily: 'Roboto', // Force normal font
            ),
          ),
          SizedBox(height: 24),
          // User Details Section
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Profile Photos Section
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.photo_library, color: Colors.deepOrange, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Profile Photos',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black, // Normal color
                                decoration: TextDecoration.none, // Remove underline
                                fontFamily: 'Roboto', // Force normal font
                              ),
                            ),
                            Spacer(),
                            TextButton.icon(
                              onPressed: _pickProfilePhoto,
                              icon: Icon(Icons.add_a_photo, size: 16),
                              label: Text('Add'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 120,
                        child: userProfilePhotos.isEmpty
                            ? Container()
                              //   child: Column(
                              //     mainAxisAlignment: MainAxisAlignment.center,
                              //     children: [
                              //       Icon(Icons.photo_library_outlined, size: 32, color: Colors.grey),
                              //       SizedBox(height: 8),
                              //       // Text(
                              //       //   'No profile photos yet',
                              //       //   style: TextStyle(color: Colors.grey[600]),
                              //       // ),
                              //     ],
                              //   ),
                              // )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                itemCount: userProfilePhotos.length,
                                itemBuilder: (context, index) {
                                  final photoDoc = userProfilePhotos[index];
                                  final photoUrl = photoDoc is String ? photoDoc : photoDoc['photoUrl'] as String?;
                                  final photoUrlNoBg = photoDoc is String ? null : photoDoc['photoUrlNoBg'] as String?;
                                  final isActive = photoUrl == userProfilePhotoUrl;
                                  return Row(
                                    children: [
                                      if (photoUrl != null)
                                        GestureDetector(
                                          onTap: () => _selectProfilePhoto(photoUrl as String),
                                          onLongPress: () => _showDeletePhotoDialog(photoUrl as String, index),
                                          child: Stack(
                                            children: [
                                              CircleAvatar(
                                                radius: 40,
                                                backgroundImage: NetworkImage(photoUrl as String),
                                                backgroundColor: Colors.grey.shade200,
                                              ),
                                              if (isActive)
                                                Positioned(
                                                  right: 0,
                                                  bottom: 0,
                                                  child: Container(
                                                    padding: EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.check,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                              Positioned(
                                                top: 0,
                                                left: 0,
                                                child: GestureDetector(
                                                  onTap: () => _showDeletePhotoDialog(photoUrl as String, index),
                                                  child: Container(
                                                    padding: EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.delete,
                                                      color: Colors.white,
                                                      size: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (photoUrlNoBg != null)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8.0),
                                          child: GestureDetector(
                                            onTap: () => _selectProfilePhoto(photoUrlNoBg as String),
                                            onLongPress: () => _showDeletePhotoDialog(photoUrlNoBg as String, index),
                                            child: Stack(
                                              children: [
                                                CircleAvatar(
                                                  radius: 40,
                                                  backgroundImage: NetworkImage(photoUrlNoBg as String),
                                                  backgroundColor: Colors.grey.shade200,
                                                ),
                                                if (photoUrlNoBg == userProfilePhotoUrl)
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      padding: EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.check,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                Positioned(
                                                  top: 0,
                                                  left: 0,
                                                  child: GestureDetector(
                                                    onTap: () => _showDeletePhotoDialog(photoUrlNoBg as String, index),
                                                    child: Container(
                                                      padding: EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.delete,
                                                        color: Colors.white,
                                                        size: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Your Profile Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Normal color
                      decoration: TextDecoration.none, // Remove underline
                      fontFamily: 'Roboto', // Force normal font
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      _buildUserDataCard(
                        'Email',
                        userEmail,
                        Icons.email,
                        isEditable: false, // Email cannot be changed
                      ),
                      _buildUserDataCard(
                        'Name',
                        userName,
                        Icons.person,
                        onTap: () => _showEditFieldDialog('Name', userName, 'name'),
                      ),
                      _buildUserDataCard(
                        'Language',
                        userLanguage,
                        Icons.language,
                        onTap: () => _showLanguageSelectionDialog(),
                      ),
                      _buildUserDataCard(
                        'Usage Type',
                        userUsageType,
                        Icons.category,
                        onTap: () => _showUsageTypeSelectionDialog(),
                      ),
                      _buildUserDataCard(
                        'Phone Number',
                        userPhoneNumber,
                        Icons.phone,
                        onTap: () => _showEditFieldDialog('Phone Number', userPhoneNumber, 'phoneNumber', isPhone: true),
                      ),
                      _buildUserDataCard(
                        'Address',
                        userAddress,
                        Icons.location_on,
                        onTap: () => _showEditFieldDialog('Address', userAddress, 'address', isMultiline: true),
                      ),
                      _buildUserDataCard(
                        'City',
                        userCity,
                        Icons.location_city,
                        onTap: () => _showEditFieldDialog('City', userCity, 'city'),
                      ),
                      _buildUserDataCard(
                        'D.O.B',
                        userDob,
                        Icons.calendar_today,
                        onTap: () => _showEditFieldDialog('Date of Birth', userDob, 'dateOfBirth', isDate: true),
                      ),
                      _buildUserDataCard(
                        'Religion',
                        userReligion,
                        Icons.church,
                        onTap: () => _showReligionSelectionDialog(),
                      ),
                      _buildUserDataCard(
                        'State',
                        userState,
                        Icons.location_on,
                        onTap: () => _showStateSelectionDialog(),
                      ),
                      _buildUserDataCard(
                        'Subscription',
                        userSubscription.isNotEmpty ? userSubscription : 'Free',
                        Icons.star,
                        isEditable: false, // Subscription cannot be changed
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text('More', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black, decoration: TextDecoration.none, fontFamily: 'Roboto'),),
          SizedBox(height: 24),
          // Action Buttons Row
          // SizedBox(height: 32),
          CommonWidgets.buildProfileOption('About', Icons.info, () => _showAboutDialog()),
          CommonWidgets.buildProfileOption('Contact Us', Icons.contact_mail, () => _showContactUsDialog()),
          CommonWidgets.buildProfileOption('Privacy Policy', Icons.privacy_tip, () => _showPrivacyPolicyDialog()),
          CommonWidgets.buildProfileOption('Terms and Conditions', Icons.description, () => _showTermsDialog()),
          CommonWidgets.buildProfileOption('Refund Policy', Icons.monetization_on, () => _showRefundDialog()),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade600, Colors.red.shade800],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: Icon(Icons.logout, color: Colors.white),
                      label: Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 54),
          // Profile Options (always visible and scrollable)
        ],
        
      ),
    );
  }

  void _showQuoteSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Category'),
        content: Container(
          width: double.maxFinite,
          child: _isLoadingCategories
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _firebaseCategories.length,
                  itemBuilder: (context, index) {
                    final category = _firebaseCategories[index];
                    final categoryName = _getCategoryName(category);
                    return ListTile(
                      title: Text(categoryName),
                      onTap: () {
                        Navigator.pop(context);
                        _showCategoryQuotes(categoryName);
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showCategoryQuotes(String category) {
    final categoryQuotes = QuoteData.quotes[category] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: categoryQuotes.length,
                itemBuilder: (context, index) {
                  final quote = categoryQuotes[index];
                  final isFavorite = favoriteQuotes.contains(quote);
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quote,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: isFavorite ? Colors.red : Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (isFavorite) {
                                      favoriteQuotes.remove(quote);
                                    } else {
                                      favoriteQuotes.add(quote);
                                    }
                                  });
                                },
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _createQuote(quote);
                                },
                                child: Text('Create'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepOrange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createQuote(String quote) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuoteEditorScreen(initialQuote: quote),
      ),
    );
  }

  void _showLoginDialog() {
    if (isLoggedIn) {
      _showUserMenu();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign In'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sign in with Google to continue',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _userService.signInWithGoogle();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sign in successful!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sign in failed: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: Image.network(
                'https://developers.google.com/identity/images/g-logo.png',
                height: 20,
                width: 20,
              ),
              label: Text('Continue with Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showUserMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 4);
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Sign Out'),
              onTap: () async {
                try {
                  await _userService.signOut();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Signed out successfully')),
                  );
                  // Navigate to login screen after signing out
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sign out failed: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Premium Features'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Ad-free experience'),
            Text('• HD downloads'),
            Text('• Premium fonts & templates'),
            Text('• Remove watermark'),
            Text('• Unlimited designs'),
            Text('• Priority support'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              CommonWidgets.showComingSoonSnackBar(context);
            },
            child: Text('Upgrade Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🧾 About Us – Prime Status'),
        content: SingleChildScrollView(
          child: Text(
            'Prime Status is your ultimate platform for creating, customizing, and sharing motivational, devotional, trending, and festive videos and images — tailored for WhatsApp, Instagram, and other social media platforms. Designed with simplicity and creativity in mind, our app empowers users to express themselves with custom overlays, personalized text, and easy download/share options.\n\n'
            'Whether you want to create daily quotes, festival wishes, birthday greetings, or business promotional content — Prime Status offers all tools in one place. With intuitive design, a massive content library, and creative freedom, Prime Status is your go-to app for all status-related needs.\n\n'
            'Features:\n'
            '• Trending and motivational content\n'
            '• Personalized profile overlays (name, photo, city, etc.)\n'
            '• Video/image download and sharing\n'
            '• Real-time previews\n'
            '• Business card-like visual content\n'
            '• Lightweight, fast, and easy to use\n\n'
            'Our goal is to empower creators and businesses to connect with their audience through beautiful content — effortlessly.'
          ),
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

  void _showEditFieldDialog(String title, String currentValue, String fieldName, {bool isPhone = false, bool isMultiline = false, bool isDate = false}) {
    final controller = TextEditingController(text: currentValue);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: title,
                  hintText: isPhone ? 'Enter 10 digit number' : null,
                ),
                keyboardType: isPhone ? TextInputType.phone : null,
                maxLines: isMultiline ? 3 : 1,
                inputFormatters: isPhone ? [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ] : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate phone number
              if (isPhone && controller.text.length != 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Phone number must be 10 digits')),
                );
                return;
              }
              
              // Update specific field
              switch (fieldName) {
                case 'name':
                  await _updateUserDetails(name: controller.text);
                  break;
                case 'phoneNumber':
                  await _updateUserDetails(phoneNumber: controller.text);
                  break;
                case 'address':
                  await _updateUserDetails(address: controller.text);
                  break;
                case 'city':
                  await _updateUserDetails(city: controller.text);
                  break;
                case 'dateOfBirth':
                  await _updateUserDetails(dateOfBirth: controller.text);
                  break;
              }
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title updated successfully')),
              );
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelectionDialog() {
    final languages = ['English', 'Kannada'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Language'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: languages.length,
            itemBuilder: (context, index) {
              final language = languages[index];
              return ListTile(
                title: Text(language),
                onTap: () {
                  Navigator.pop(context);
                  _updateUserDetails(language: language);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Language updated successfully')),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showUsageTypeSelectionDialog() {
    final usageTypes = ['Personal', 'Business'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Usage Type'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: usageTypes.length,
            itemBuilder: (context, index) {
              final usageType = usageTypes[index];
              return ListTile(
                title: Text(usageType),
                onTap: () {
                  Navigator.pop(context);
                  _updateUserDetails(usageType: usageType);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Usage type updated successfully')),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showReligionSelectionDialog() {
    final religions = [
      'Hindu',
      'Muslim',
      'Christian',
      'Jain',
      'Buddhist',
      'Sikh',
      'Other'
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Religion'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: religions.length,
            itemBuilder: (context, index) {
              final religion = religions[index];
              return ListTile(
                title: Text(religion),
                onTap: () {
                  Navigator.pop(context);
                  _updateUserDetails(religion: religion);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Religion updated successfully')),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showStateSelectionDialog() {
    final states = [
      'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
      'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
      'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
      'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
      'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
      'Andaman and Nicobar Islands', 'Chandigarh',
      'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Jammu and Kashmir',
      'Ladakh', 'Lakshadweep', 'Puducherry'
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select State'),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: states.length,
            itemBuilder: (context, index) {
              final state = states[index];
              return ListTile(
                title: Text(state),
                onTap: () {
                  Navigator.pop(context);
                  _updateUserDetails(state: state);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('State updated successfully')),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _quoteController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'morning':
      case 'good morning':
      case 'ಮುಂಜಾನೆ':
      case 'ಶುಭೋದಯ':
        return Icons.wb_sunny;
      case 'motivational':
      case 'ಪ್ರೇರಕ':
        return Icons.trending_up;
      case 'love':
      case 'ಪ್ರೀತಿ':
        return Icons.favorite;
      case 'festival':
      case 'ಹಬ್ಬ':
        return Icons.celebration;
      case 'success':
      case 'ಯಶಸ್ಸು':
        return Icons.star;
      case 'inspiration':
      case 'ಸ್ಫೂರ್ತಿ':
        return Icons.lightbulb;
      case 'life':
      case 'ಜೀವನ':
        return Icons.psychology;
      case 'friendship':
      case 'ಸ್ನೇಹ':
        return Icons.people;
      case 'good night':
      case 'ಶುಭ ರಾತ್ರಿ':
        return Icons.nightlight;
      case 'happy sunday':
      case 'ಶುಭ ಭಾನುವಾರ':
        return Icons.weekend;
      case 'political':
      case 'ರಾಜಕೀಯ':
        return Icons.flag;
      default:
        return Icons.format_quote;
    }
  }

  // Public method to refresh user data (can be called from other widgets)
  Future<void> refreshUserData() async {
    await _fetchUserDetails();
  }

  // Public method to refresh categories (can be called from other widgets)
  Future<void> refreshCategories() async {
    await _fetchCategories();
  }

  void _showDeletePhotoDialog(String photoUrl, int index) {
    final isActive = photoUrl == userProfilePhotoUrl;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Profile Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive 
                ? 'This is your current profile photo. Are you sure you want to delete it?'
                : 'Are you sure you want to delete this profile photo?',
            ),
            SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProfilePhoto(photoUrl, index);
            },
            child: Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProfilePhoto(String photoUrl, int index) async {
    if (_currentUser == null) return;
    
    try {
      // Get the document ID for this photo
      final photosSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('profilePhotos')
          .where('photoUrl', isEqualTo: photoUrl)
          .get();
      
      if (photosSnapshot.docs.isNotEmpty) {
        // Delete from Firestore
        await photosSnapshot.docs.first.reference.delete();
        
        // If this was the active photo, clear the main profile photo
        if (photoUrl == userProfilePhotoUrl) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.uid)
              .update({
            'profilePhotoUrl': null,
          });
          
          // Clear Firebase Auth profile photo
          await _userService.updateAuthProfilePhoto('');
        }
        
        // Refresh user data
        await _fetchUserDetails();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile photo deleted successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete profile photo: $e')),
      );
    }
  }

  void _handleLogout() async {
    try {
      // Show confirmation dialog
      bool shouldLogout = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ) ?? false;

      if (shouldLogout) {
        // Sign out from Firebase
        await _userService.signOut();
        
        // Clear user data
        _clearUserData();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged out successfully')),
        );
        
        // Navigate to login screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showContactUsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact Us'),
        content: Text('For any queries, email us at support@primestatusapp.com'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🔒 Privacy Policy'),
        content: SingleChildScrollView(
          child: Text(
            'Last Updated: [Insert Date]\n\n'
            'Prime Status is committed to protecting your privacy. This Privacy Policy outlines how we collect, use, and protect your personal data.\n\n'
            '1. Data We Collect:\n'
            '• Personal Info: Name, email, phone number, location (city)\n'
            '• Media Files: Uploaded images/videos for customization\n'
            '• Device Info: Device ID, OS version, app usage logs (for analytics)\n\n'
            '2. How We Use Your Data:\n'
            '• To provide customized overlays and content\n'
            '• To improve app functionality and user experience\n'
            '• To notify users about updates and features\n'
            '• For analytics and performance monitoring\n\n'
            '3. Sharing of Data:\n'
            'We do not sell or rent your personal information. Data may be shared:\n'
            '• With trusted third-party services (e.g., Firebase, analytics tools)\n'
            '• To comply with legal obligations\n\n'
            '4. Storage & Security:\n'
            '• Your data is securely stored in encrypted servers.\n'
            '• We use Firebase & other secure platforms.\n\n'
            '5. Your Rights:\n'
            '• You can request deletion or correction of your data.\n'
            '• You may revoke consent anytime by uninstalling the app.\n\n'
            'For any privacy-related concerns, contact us at: support@primestatus.app'
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('✅ Terms & Conditions'),
        content: SingleChildScrollView(
          child: Text(
            'Welcome to Prime Status. By using our app, you agree to the following terms:\n\n'
            '1. Usage:\n'
            '• You must be 13 years or older to use this app.\n'
            '• You agree to use the app for lawful purposes only.\n'
            '• You are responsible for the content you upload or generate.\n\n'
            '2. Intellectual Property:\n'
            '• All default templates and assets are property of Prime Status.\n'
            '• User-generated content remains owned by the respective user.\n\n'
            '3. Prohibited Actions:\n'
            '• Misusing the app for hate, violence, or illegal promotions\n'
            '• Attempting to hack or modify the app\n'
            '• Uploading offensive, abusive, or copyrighted material\n\n'
            '4. Limitation of Liability:\n'
            '• We are not liable for any content misuse or data loss.\n'
            '• The app is provided "as-is" without warranties.\n\n'
            '5. Modifications:\n'
            '• We reserve the right to update these terms anytime.\n'
            '• Continued usage after updates implies acceptance.'
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRefundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('💰 Refund Policy'),
        content: SingleChildScrollView(
          child: Text(
            'All purchases made on Prime Status are final and non-refundable.\n\n'
            'As Prime Status deals with digital content (such as images, videos, overlays), we do not offer refunds for any reason once content is downloaded, processed, or accessed.\n\n'
            'Please review your order carefully before completing your purchase.'
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

} 

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  void _showPolicyDialog({
    required BuildContext context,
    required String title,
    required String content,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    _showPolicyDialog(
      context: context,
      title: '🧾 About Us – Prime Status',
      content: '''
Prime Status is your ultimate platform for creating, customizing, and sharing motivational, devotional, trending, and festive videos and images — tailored for WhatsApp, Instagram, and other social media platforms. Designed with simplicity and creativity in mind, our app empowers users to express themselves with custom overlays, personalized text, and easy download/share options.

Whether you want to create daily quotes, festival wishes, birthday greetings, or business promotional content — Prime Status offers all tools in one place. With intuitive design, a massive content library, and creative freedom, Prime Status is your go-to app for all status-related needs.

Features:
• Trending and motivational content
• Personalized profile overlays (name, photo, city, etc.)
• Video/image download and sharing
• Real-time previews
• Business card-like visual content
• Lightweight, fast, and easy to use

Our goal is to empower creators and businesses to connect with their audience through beautiful content — effortlessly.
''',
    );
  }

  void _showContactUsDialog(BuildContext context) {
    _showPolicyDialog(
      context: context,
      title: 'Contact Us',
      content: '''
Need help? Reach out to us:

support@primestatus.app
''',
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    _showPolicyDialog(
      context: context,
      title: '🔒 Privacy Policy',
      content: '''
Last Updated: [Insert Date]

Prime Status is committed to protecting your privacy. This Privacy Policy outlines how we collect, use, and protect your personal data.

1. Data We Collect:
• Personal Info: Name, email, phone number, location (city)
• Media Files: Uploaded images/videos for customization
• Device Info: Device ID, OS version, app usage logs (for analytics)

2. How We Use Your Data:
• To provide customized overlays and content
• To improve app functionality and user experience
• To notify users about updates and features
• For analytics and performance monitoring

3. Sharing of Data:
We do not sell or rent your personal information. Data may be shared:
• With trusted third-party services (e.g., Firebase, analytics tools)
• To comply with legal obligations

4. Storage & Security:
• Your data is securely stored in encrypted servers.
• We use Firebase & other secure platforms.

5. Your Rights:
• You can request deletion or correction of your data.
• You may revoke consent anytime by uninstalling the app.

For any privacy-related concerns, contact us at: support@primestatus.app
''',
    );
  }

  void _showTermsDialog(BuildContext context) {
    _showPolicyDialog(
      context: context,
      title: '✅ Terms & Conditions',
      content: '''
Welcome to Prime Status. By using our app, you agree to the following terms:

1. Usage:
• You must be 13 years or older to use this app.
• You agree to use the app for lawful purposes only.
• You are responsible for the content you upload or generate.

2. Intellectual Property:
• All default templates and assets are property of Prime Status.
• User-generated content remains owned by the respective user.

3. Prohibited Actions:
• Misusing the app for hate, violence, or illegal promotions
• Attempting to hack or modify the app
• Uploading offensive, abusive, or copyrighted material

4. Limitation of Liability:
• We are not liable for any content misuse or data loss.
• The app is provided "as-is" without warranties.

5. Modifications:
• We reserve the right to update these terms anytime.
• Continued usage after updates implies acceptance.
''',
    );
  }

  void _showRefundDialog(BuildContext context) {
    _showPolicyDialog(
      context: context,
      title: '💰 Refund Policy',
      content: '''
Digital Content Policy:
As Prime Status deals with digital content (e.g., images, videos, overlays), all purchases are considered final and non-refundable once content is downloaded or processed.

However, in rare cases such as:
• Duplicate payments
• Transaction failures with confirmed deduction
You may contact our support team within 7 days of the transaction for resolution.

Refund Eligibility:
• Must provide transaction ID or payment proof
• Refund will be processed to the original payment method (if approved)

Contact:
Email us at support@primestatus.app for refund queries or complaints.
''',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Info & Policies')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('About'),
            onTap: () => _showAboutDialog(context),
          ),
          ListTile(
            title: const Text('Contact Us'),
            onTap: () => _showContactUsDialog(context),
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            onTap: () => _showPrivacyPolicyDialog(context),
          ),
          ListTile(
            title: const Text('Terms & Conditions'),
            onTap: () => _showTermsDialog(context),
          ),
          ListTile(
            title: const Text('Refund Policy'),
            onTap: () => _showRefundDialog(context),
          ),
        ],
      ),
    );
  }
} 