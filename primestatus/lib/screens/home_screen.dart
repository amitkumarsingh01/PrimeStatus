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
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
  late TextEditingController _quoteController;
  String quoteOfTheDay = '';
  List<String> favoriteQuotes = [];
  
  final UserService _userService = UserService();
  final QuoteService _quoteService = QuoteService();
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
        });
      }
    } catch (e) {
      print('Error fetching user details: $e');
      // If there's an error, clear user data
      _clearUserData();
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
    });
  }

  Future<void> _updateUserDetails({
    String? name,
    String? language,
    String? usageType,
    String? religion,
    String? state,
    String? profilePhotoUrl,
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
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        File imageFile = File(picked.path);
        String downloadUrl = await _userService.uploadProfilePhoto(
          imageFile,
          _currentUser!.uid,
        );
        
        // Update user data with new photo URL
        await _updateUserDetails(profilePhotoUrl: downloadUrl);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile photo updated!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile photo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Prime Status'),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: Icon(isLoggedIn ? Icons.account_circle : Icons.login),
              onPressed: _showLoginDialog,
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeTab(),
            _buildCategoriesTab(),
            _buildFavoritesTab(),
            _buildAdminFeedTab(),
            _buildProfileTab(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.purple,
          unselectedItemColor: Colors.grey,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categories'),
            BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
            BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'Feed'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
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
          SizedBox(height: 24),
          _buildAdminPostFeed(),
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
          colors: [Colors.purple.shade400, Colors.pink.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
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
              foregroundColor: Colors.purple,
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
                Colors.purple,
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
          'Featured Categories',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            final category = QuoteData.categories[index];
            return CommonWidgets.buildCategoryCard(
              category,
              AppConstants.categoryColors[index],
              () => _showCategoryQuotes(category),
            );
          },
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
            Icon(Icons.feed, color: Colors.purple, size: 24),
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
              backgroundColor: Colors.purple.shade100,
              child: Icon(Icons.format_quote, color: Colors.purple),
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
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.feed, color: Colors.purple, size: 28),
                SizedBox(width: 12),
                Text(
                  'Admin Feed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.purple),
                  onPressed: () {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          
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
              backgroundColor: Colors.purple.shade100,
              child: Icon(
                Icons.person,
                size: 60,
                color: Colors.purple,
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
                backgroundColor: Colors.purple,
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
    
    Widget _buildUserDataCard(String title, String? value, IconData icon) {
      return Card(
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: Colors.purple, size: 20),
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
            ],
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
              backgroundColor: Colors.purple.shade100,
              backgroundImage: userProfilePhotoUrl != null
                  ? NetworkImage(userProfilePhotoUrl!)
                  : null,
              child: userProfilePhotoUrl == null
                  ? Icon(Icons.account_circle, size: 60, color: Colors.purple)
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
                      ),
                      _buildUserDataCard(
                        'Language',
                        userLanguage,
                        Icons.language,
                      ),
                      _buildUserDataCard(
                        'Usage Type',
                        userUsageType,
                        Icons.category,
                      ),
                      _buildUserDataCard(
                        'Religion',
                        userReligion,
                        Icons.church,
                      ),
                      _buildUserDataCard(
                        'State',
                        userState,
                        Icons.location_on,
                      ),
                      _buildUserDataCard(
                        'Subscription',
                        userSubscription.isNotEmpty ? userSubscription : 'Free',
                        Icons.star,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: _showEditProfileDialog,
            child: Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
          SizedBox(height: 32),
          CommonWidgets.buildProfileOption('Premium Features', Icons.star, () => _showPremiumDialog()),
          CommonWidgets.buildProfileOption('Share App', Icons.share, () => CommonWidgets.showComingSoonSnackBar(context)),
          CommonWidgets.buildProfileOption('Rate Us', Icons.thumb_up, () => CommonWidgets.showComingSoonSnackBar(context)),
          CommonWidgets.buildProfileOption('Help & Support', Icons.help, () => CommonWidgets.showComingSoonSnackBar(context)),
          CommonWidgets.buildProfileOption('About', Icons.info, () => _showAboutDialog()),
          
          // User Posts Section
          SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'My Posts & Likes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  height: 300,
                  child: UserPostsWidget(
                    userId: _currentUser!.uid,
                    userName: userName.isNotEmpty ? userName : 'User',
                    userPhotoUrl: userProfilePhotoUrl,
                  ),
                ),
              ],
            ),
          ),
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
                                  backgroundColor: Colors.purple,
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
                backgroundColor: Colors.purple,
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
                setState(() => _selectedIndex = 3);
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
              backgroundColor: Colors.purple,
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

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: userName);
    final languageController = TextEditingController(text: userLanguage);
    final usageTypeController = TextEditingController(text: userUsageType);
    final religionController = TextEditingController(text: userReligion);
    final stateController = TextEditingController(text: userState);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: languageController,
                decoration: InputDecoration(labelText: 'Language'),
              ),
              TextField(
                controller: usageTypeController,
                decoration: InputDecoration(labelText: 'Usage Type'),
              ),
              TextField(
                controller: religionController,
                decoration: InputDecoration(labelText: 'Religion'),
              ),
              TextField(
                controller: stateController,
                decoration: InputDecoration(labelText: 'State'),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: _pickProfilePhoto,
                child: Text('Change Profile Photo'),
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
              await _updateUserDetails(
                name: nameController.text,
                language: languageController.text,
                usageType: usageTypeController.text,
                religion: religionController.text,
                state: stateController.text,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Profile updated successfully')),
              );
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _quoteController.dispose();
    super.dispose();
  }
} 