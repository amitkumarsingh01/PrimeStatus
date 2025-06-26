import 'package:flutter/material.dart';
import 'dart:math';
import '../data/quote_data.dart';
import '../constants/app_constants.dart';
import '../widgets/common_widgets.dart';
import 'quote_editor_screen.dart';
import 'package:craftoapp/screens/onboarding/login_screen.dart';
import 'package:craftoapp/services/onboarding_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool isLoggedIn = false;
  String userName = '';
  String userMobile = '';
  String userLanguage = '';
  String userUsageType = '';
  String userReligion = '';
  String userState = '';
  String userSubscription = '';
  String? userProfilePhotoUrl;
  late TextEditingController _quoteController;
  String quoteOfTheDay = '';
  List<String> favoriteQuotes = [];

  @override
  void initState() {
    super.initState();
    _quoteController = TextEditingController();
    _setQuoteOfTheDay();
  }

  void _setQuoteOfTheDay() {
    final allQuotes = QuoteData.quotes.values.expand((list) => list).toList();
    final random = Random();
    quoteOfTheDay = allQuotes[random.nextInt(allQuotes.length)];
  }

  Future<void> fetchUserDetails(String mobile) async {
    try {
      final url = Uri.parse('https://bharatchat.iaks.site/user/$mobile');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          isLoggedIn = true;
          userName = data['name'] ?? '';
          userMobile = data['mobile_number'] ?? '';
          userLanguage = data['language'] ?? '';
          userUsageType = data['usage_type'] ?? '';
          userReligion = data['religion'] ?? '';
          userState = data['state'] ?? '';
          userSubscription = data['subscription'] ?? '';
          userProfilePhotoUrl = data['profile_photo_url'];
        });
      }
    } catch (e) {
      // ignore error
    }
  }

  Future<void> updateUserDetails({
    String? name,
    String? language,
    String? usageType,
    String? religion,
    String? state,
    String? profilePhotoUrl,
  }) async {
    if (userMobile.isEmpty) return;
    final url = Uri.parse('https://bharatchat.iaks.site/user/$userMobile');
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (language != null) body['language'] = language;
    if (usageType != null) body['usage_type'] = usageType;
    if (religion != null) body['religion'] = religion;
    if (state != null) body['state'] = state;
    if (profilePhotoUrl != null) body['profile_photo_url'] = profilePhotoUrl;
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode == 200) {
      await fetchUserDetails(userMobile);
    }
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);
      await updateUserDetails(profilePhotoUrl: base64Image);
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
          title: Text('QuoteCraft'),
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickProfilePhoto,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.purple.shade100,
              backgroundImage: (userProfilePhotoUrl != null && userProfilePhotoUrl!.isNotEmpty)
                  ? MemoryImage(base64Decode(userProfilePhotoUrl!))
                  : null,
              child: (userProfilePhotoUrl == null || userProfilePhotoUrl!.isEmpty)
                  ? Icon(Icons.account_circle, size: 60, color: Colors.purple)
                  : null,
            ),
          ),
          SizedBox(height: 16),
          Text(
            userName,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Mobile: $userMobile'),
          Text('Language: $userLanguage'),
          Text('Usage: $userUsageType'),
          Text('Religion: $userReligion'),
          Text('State: $userState'),
          Text('Subscription: $userSubscription'),
          SizedBox(height: 16),
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

    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign In'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
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
            onPressed: () async {
              // For demo, treat mobile as login
              await fetchUserDetails(emailController.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Welcome back, $userName!')),
              );
            },
            child: Text('Sign In'),
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
              onTap: () {
                OnboardingService.instance.reset();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
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
        title: Text('About QuoteCraft'),
        content: Text(
          'QuoteCraft v1.0\n\nCreate beautiful quote designs with stunning backgrounds. Share your inspiration with the world.\n\nDeveloped with ❤️ using Flutter',
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
              await updateUserDetails(
                name: nameController.text,
                language: languageController.text,
                usageType: usageTypeController.text,
                religion: religionController.text,
                state: stateController.text,
              );
              Navigator.pop(context);
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