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
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'onboarding/login_screen.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

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
  List<String> userProfilePhotos = []; // List to store multiple profile photos
  bool _isProcessingPhoto = false;
  
  final UserService _userService = UserService();
  final QuoteService _quoteService = QuoteService();
  final BackgroundRemovalService _bgRemovalService = BackgroundRemovalService();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _quoteController = TextEditingController();
    _setQuoteOfTheDay();
    _checkAuthState();
  }

  void _setQuoteOfTheDay() {
    final allQuotes = QuoteData.quotes.values.expand((list) => list).toList();
    final random = Random();
    quoteOfTheDay = allQuotes[random.nextInt(allQuotes.length)];
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
          userUsageType = userData['usageType'] ?? '';
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
    if (_currentUser == null) return;
    
    try {
      final photosSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('profilePhotos')
          .orderBy('uploadedAt', descending: true)
          .get();
      
      setState(() {
        userProfilePhotos = photosSnapshot.docs
            .map((doc) => doc.data()['photoUrl'] as String)
            .toList();
      });
    } catch (e) {
      print('Error fetching profile photos: $e');
    }
  }

  void _clearUserData() {
    setState(() {
      userName = '';
      userEmail = '';
      userLanguage = '';
      userUsageType = '';
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
      await _userService.updateProfile(
        uid: _currentUser!.uid,
        name: name,
        language: language,
        usageType: usageType,
        religion: religion,
        state: state,
        phoneNumber: phoneNumber,
        address: address,
        dateOfBirth: dateOfBirth,
        city: city,
      );
      
      // Refresh user data
      await _fetchUserDetails();
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

      // Pick image from gallery (normal - with background)
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        
        // Upload to Firebase Storage (with background)
        String downloadUrl = await _userService.uploadProfilePhoto(imageFile, _currentUser!.uid);
        
        // Add to user's profile photos collection
        await _addProfilePhotoToGallery(downloadUrl);
        
        // Refresh profile photos
        await _fetchUserProfilePhotos();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile photo added to gallery!')),
        );
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

      // Take photo with camera (normal - with background)
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        
        // Upload to Firebase Storage (with background)
        String downloadUrl = await _userService.uploadProfilePhoto(imageFile, _currentUser!.uid);
        
        // Add to user's profile photos collection
        await _addProfilePhotoToGallery(downloadUrl);
        
        // Refresh profile photos
        await _fetchUserProfilePhotos();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile photo added to gallery!')),
        );
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

  Future<void> _addProfilePhotoToGallery(String photoUrl) async {
    if (_currentUser == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('profilePhotos')
          .add({
        'photoUrl': photoUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'isActive': false,
        'withoutBackground': false, // Mark as not processed
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
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              // title: Text('Prime Status'),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(30),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                  child: Row(
                    children: [
                      // 60% Search Bar
                      Expanded(
                        flex: 6,
                        child: Container(
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
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                prefixIcon: Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.transparent,
                                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),


                      SizedBox(width: 12),

                      // 30% Create Button
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF2c0036), Color(0xFFd74d02)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() => _selectedIndex = 0);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.all(12), 
                            ),
                            child: Icon(
                              Icons.home,
                              color: Color(0xfffaeac7),
                              size: 32,
                            ),
                          ),
                        ),
                      ),


                      SizedBox(width: 12),

                      // 10% Profile/Login Icon
                      Expanded(
                        flex: 1,
                        child: isLoggedIn && userProfilePhotoUrl != null
                            ? GestureDetector(
                                onTap: () => setState(() => _selectedIndex = 4),
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundImage: NetworkImage(userProfilePhotoUrl!),
                                  backgroundColor: Colors.grey.shade200,
                                ),
                              )
                            : IconButton(
                                icon: Icon(Icons.login),
                                onPressed: _showLoginDialog,
                                color: Colors.white,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            body: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildAdminFeedTab(),
                _buildCategoriesTab(),
                _buildFavoritesTab(),
                _buildHomeTab(),
                _buildProfileTab(),
              ],
            ),
            // bottomNavigationBar: BottomNavigationBar(
            //   currentIndex: _selectedIndex,
            //   onTap: (index) => setState(() => _selectedIndex = index),
            //   type: BottomNavigationBarType.fixed,
            //   selectedItemColor: Colors.deepOrange,
            //   unselectedItemColor: Colors.grey,
            //   items: [
            //     BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            //     BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categories'),
            //     BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
            //     BottomNavigationBarItem(icon: Icon(Icons.create), label: 'Create'),
            //     BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            //   ],
            // ),
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Removing background and uploading',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
    return SingleChildScrollView(
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
            itemCount: QuoteData.categories.length,
            itemBuilder: (context, index) {
              final category = QuoteData.categories[index];
              return Container(
                width: MediaQuery.of(context).size.width / 5.5, // Show 5 categories at a time
                margin: EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => _showCategoryQuotes(category),
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
                          _getCategoryIcon(category),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        category,
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
          child: AdminPostFeedWidget(),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: QuoteData.categories.length,
      itemBuilder: (context, index) {
        final category = QuoteData.categories[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepOrange.shade100,
              child: Icon(Icons.format_quote, color: Colors.deepOrange),
            ),
            title: Text(
              category,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${QuoteData.quotes[category]?.length ?? 0} quotes'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showCategoryQuotes(category),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    return favoriteQuotes.isEmpty
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
          );
  }

  Widget _buildAdminFeedTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header
          // Container(
          //   padding: EdgeInsets.all(16),
          //   decoration: BoxDecoration(
          //     color: Colors.white.withOpacity(0.9),
          //     borderRadius: BorderRadius.only(
          //       bottomLeft: Radius.circular(20),
          //       bottomRight: Radius.circular(20),
          //     ),
          //   ),
          //   child: Row(
          //     children: [
          //       Icon(Icons.feed, color: Colors.purple, size: 28),
          //       SizedBox(width: 12),
          //       Text(
          //         'Latest Posts',
          //         style: TextStyle(
          //           fontSize: 24,
          //           fontWeight: FontWeight.bold,
          //           color: Colors.black87,
          //         ),
          //       ),
          //       Spacer(),
          //       IconButton(
          //         icon: Icon(Icons.refresh, color: Colors.deepOrange),
          //         onPressed: () {
          //           setState(() {});
          //         },
          //       ),
          //     ],
          //   ),
          // ),
          SizedBox(height: 16),
          
          // Horizontal Categories Scroll
          Container(
            height: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: QuoteData.categories.length,
                    itemBuilder: (context, index) {
                      final category = QuoteData.categories[index];
                      return Container(
                        width: MediaQuery.of(context).size.width / 5.5, // Show 5 categories at a time
                        margin: EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => _showCategoryQuotes(category),
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
                                  _getCategoryIcon(category),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                category,
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
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // SizedBox(height: 16),
          
          // Feed content
          Expanded(
            child: AdminPostFeedWidget(),
          ),
        ],
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
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 32),
            CommonWidgets.buildProfileOption('Premium Features', Icons.star, () => _showPremiumDialog()),
            CommonWidgets.buildProfileOption('Share App', Icons.share, () => CommonWidgets.showComingSoonSnackBar(context)),
            CommonWidgets.buildProfileOption('Rate Us', Icons.thumb_up, () => CommonWidgets.showComingSoonSnackBar(context)),
            CommonWidgets.buildProfileOption('Help & Support', Icons.help, () => CommonWidgets.showComingSoonSnackBar(context)),
            CommonWidgets.buildProfileOption('About', Icons.info, () => _showAboutDialog()),
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
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickProfilePhoto,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepOrange.shade100,
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Tap photo to change',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
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
                                color: Colors.black87,
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
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.photo_library_outlined, size: 32, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text(
                                      'No profile photos yet',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                itemCount: userProfilePhotos.length,
                                itemBuilder: (context, index) {
                                  final photoUrl = userProfilePhotos[index];
                                  final isActive = photoUrl == userProfilePhotoUrl;
                                  
                                  return Container(
                                    margin: EdgeInsets.only(right: 12),
                                    child: GestureDetector(
                                      onTap: () => _selectProfilePhoto(photoUrl),
                                      onLongPress: () => _showDeletePhotoDialog(photoUrl, index),
                                      child: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 40,
                                            backgroundImage: NetworkImage(photoUrl),
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
                                          // Delete button
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            child: GestureDetector(
                                              onTap: () => _showDeletePhotoDialog(photoUrl, index),
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
                      color: Colors.black87,
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
          
          SizedBox(height: 24),
          
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
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: QuoteData.categories.length,
            itemBuilder: (context, index) {
              final category = QuoteData.categories[index];
              return ListTile(
                title: Text(category),
                onTap: () {
                  Navigator.pop(context);
                  _showCategoryQuotes(category);
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
        title: Text('About Prime Status'),
        content: Text(
          'Prime Status v1.0\n\nCreate beautiful quote designs with stunning backgrounds. Share your inspiration with the world.\n\nDeveloped with ❤️ using Flutter',
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
    switch (category) {
      case 'Morning':
        return Icons.wb_sunny;
      case 'Motivational':
        return Icons.trending_up;
      case 'Love':
        return Icons.favorite;
      case 'Festival':
        return Icons.celebration;
      case 'Success':
        return Icons.star;
      case 'Inspiration':
        return Icons.lightbulb;
      case 'Life':
        return Icons.psychology;
      case 'Friendship':
        return Icons.people;
      default:
        return Icons.format_quote;
    }
  }

  // Public method to refresh user data (can be called from other widgets)
  Future<void> refreshUserData() async {
    await _fetchUserDetails();
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

} 