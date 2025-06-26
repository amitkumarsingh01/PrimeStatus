import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/quote_service.dart';
import '../models/user_model.dart';
import '../models/quote_template.dart';
import '../widgets/quote_renderer.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final QuoteService _quoteService = QuoteService();
  
  UserModel? _currentUser;
  List<QuoteTemplate> _quotes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    print('HomeScreen initialized');
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    print('Loading user data...');
    final user = _authService.currentUser;
    print('Current user in HomeScreen: ${user?.uid ?? 'null'}');
    if (user != null) {
      final userData = await _userService.getUserById(user.uid);
      print('User data loaded: ${userData?.name ?? 'null'}');
      if (userData != null) {
        final quotes = await _quoteService.getQuotesForUser(userData);
        print('Quotes loaded: ${quotes.length}');
        setState(() {
          _currentUser = userData;
          _quotes = quotes;
          _loading = false;
        });
      } else {
        print('User data not found, setting loading to false');
        setState(() {
          _loading = false;
        });
      }
    } else {
      print('No user found, setting loading to false');
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Quote Templates'),
        actions: [
          IconButton(
            onPressed: _authService.signOut,
            icon: Icon(Icons.logout),
          ),
        ],
      ),
      body: _currentUser == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('User data not found'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      print('Test button pressed');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Test button works!')),
                      );
                    },
                    child: Text('Test Button'),
                  ),
                ],
              ),
            )
          : _quotes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('No quotes available'),
                      SizedBox(height: 16),
                      Text('User: ${_currentUser!.name}'),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          print('Test button pressed');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Test button works!')),
                          );
                        },
                        child: Text('Test Button'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _quotes.length,
                  itemBuilder: (context, index) {
                    final quote = _quotes[index];
                    return GestureDetector(
                      onTap: () => _showQuotePreview(quote),
                      child: Card(
                        elevation: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: CachedNetworkImage(
                                imageUrl: quote.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => 
                                    Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) => 
                                    Icon(Icons.error),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    quote.title,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    quote.category,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (!quote.isFree)
                                    Icon(Icons.star, color: Colors.amber, size: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showQuotePreview(QuoteTemplate template) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                template.title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              QuoteRenderer(
                template: template,
                user: _currentUser!,
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'),
                  ),
                  ElevatedButton(
                    onPressed: () => _saveQuote(template.quotesId),
                    child: Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveQuote(String quoteId) async {
    if (_currentUser != null) {
      await _userService.saveQuote(_currentUser!.id, quoteId);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quote saved successfully!')),
      );
    }
  }
} 