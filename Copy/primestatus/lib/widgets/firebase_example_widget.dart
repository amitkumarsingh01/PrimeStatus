import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../services/quote_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class FirebaseExampleWidget extends StatefulWidget {
  const FirebaseExampleWidget({Key? key}) : super(key: key);

  @override
  _FirebaseExampleWidgetState createState() => _FirebaseExampleWidgetState();
}

class _FirebaseExampleWidgetState extends State<FirebaseExampleWidget> {
  final UserService _userService = UserService();
  final QuoteService _quoteService = QuoteService();
  final TextEditingController _quoteController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  
  User? _currentUser;
  List<Map<String, dynamic>> _userQuotes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
    _loadUserQuotes();
  }

  @override
  void dispose() {
    _quoteController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _checkCurrentUser() {
    _currentUser = _userService.currentUser;
    if (_currentUser != null) {
      print('Current user: ${_currentUser!.uid}');
    }
  }

  void _loadUserQuotes() {
    if (_currentUser != null) {
      _quoteService.getUserQuotes().listen((snapshot) {
        setState(() {
          _userQuotes = snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
        });
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _userService.signInWithGoogle();
      _checkCurrentUser();
      _loadUserQuotes();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signed in successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _userService.signOut();
      setState(() {
        _currentUser = null;
        _userQuotes = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signed out successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign out failed: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createQuote() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in first')),
      );
      return;
    }

    if (_quoteController.text.isEmpty || _authorController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _quoteService.createQuote(
        text: _quoteController.text,
        author: _authorController.text,
        category: 'Inspiration',
        language: 'English',
        isPublic: true,
      );

      _quoteController.clear();
      _authorController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quote created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create quote: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadProfilePhoto() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in first')),
      );
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _isLoading = true;
        });

        File imageFile = File(image.path);
        String downloadUrl = await _userService.uploadProfilePhoto(
          imageFile,
          _currentUser!.uid,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile photo uploaded!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload photo: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firebase Integration Example'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Authentication Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Authentication',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (_currentUser != null) ...[
                      Text('Signed in as: ${_currentUser!.email ?? _currentUser!.phoneNumber ?? 'Unknown'}'),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _signOut,
                        child: Text('Sign Out'),
                      ),
                    ] else ...[
                      Text('Not signed in'),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        child: Text('Sign in with Google'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Profile Photo Section
            if (_currentUser != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile Photo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _uploadProfilePhoto,
                        child: Text('Upload Profile Photo'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],

            // Create Quote Section
            if (_currentUser != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Quote',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _quoteController,
                        decoration: InputDecoration(
                          labelText: 'Quote Text',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _authorController,
                        decoration: InputDecoration(
                          labelText: 'Author',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _createQuote,
                        child: Text('Create Quote'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],

            // User Quotes Section
            if (_currentUser != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Quotes (${_userQuotes.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      if (_userQuotes.isEmpty)
                        Text('No quotes yet. Create your first quote!')
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: _userQuotes.length,
                            itemBuilder: (context, index) {
                              final quote = _userQuotes[index];
                              return Card(
                                child: ListTile(
                                  title: Text(quote['text'] ?? ''),
                                  subtitle: Text('- ${quote['author'] ?? ''}'),
                                  trailing: IconButton(
                                    icon: Icon(Icons.favorite_border),
                                    onPressed: () async {
                                      try {
                                        await _quoteService.toggleLike(quote['quoteId']);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Quote liked!')),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to like quote: $e')),
                                        );
                                      }
                                    },
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
            ],

            // Loading Indicator
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
} 