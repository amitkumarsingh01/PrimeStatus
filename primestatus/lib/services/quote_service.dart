import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_firestore_service.dart';
import 'firebase_storage_service.dart';
import 'dart:io';

class QuoteService {
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new quote
  Future<String> createQuote({
    required String text,
    required String author,
    String? category,
    String? language,
    File? imageFile,
    bool isPublic = false,
  }) async {
    try {
      String? imageUrl;
      
      // Upload image if provided
      if (imageFile != null) {
        String userId = _auth.currentUser!.uid;
        String tempQuoteId = DateTime.now().millisecondsSinceEpoch.toString();
        imageUrl = await _storageService.uploadQuoteImage(imageFile, userId, tempQuoteId);
      }

      // Create quote in Firestore
      String quoteId = await _firestoreService.createQuote(
        userId: _auth.currentUser!.uid,
        text: text,
        author: author,
        category: category,
        language: language,
        imageUrl: imageUrl,
        isPublic: isPublic,
      );

      // If we uploaded an image with a temp ID, update it with the real quote ID
      if (imageFile != null && imageUrl != null) {
        String userId = _auth.currentUser!.uid;
        String newImageUrl = await _storageService.uploadQuoteImage(imageFile, userId, quoteId);
        
        // Update quote with correct image URL
        await _firestoreService.updateQuote(quoteId, {
          'imageUrl': newImageUrl,
        });

        // Delete the temporary image
        await _storageService.deleteImage(imageUrl);
      }

      return quoteId;
    } catch (e) {
      throw 'Failed to create quote: $e';
    }
  }

  // Get user's quotes
  Stream<QuerySnapshot> getUserQuotes() {
    return _firestoreService.getUserQuotes(_auth.currentUser!.uid);
  }

  // Get public quotes
  Stream<QuerySnapshot> getPublicQuotes({String? category, String? language}) {
    return _firestoreService.getPublicQuotes(category: category, language: language);
  }

  // Get a specific quote
  Future<Map<String, dynamic>?> getQuote(String quoteId) async {
    try {
      return await _firestoreService.getQuote(quoteId);
    } catch (e) {
      throw 'Failed to get quote: $e';
    }
  }

  // Update a quote
  Future<void> updateQuote({
    required String quoteId,
    String? text,
    String? author,
    String? category,
    String? language,
    File? imageFile,
    bool? isPublic,
  }) async {
    try {
      Map<String, dynamic> updateData = {};
      
      if (text != null) updateData['text'] = text;
      if (author != null) updateData['author'] = author;
      if (category != null) updateData['category'] = category;
      if (language != null) updateData['language'] = language;
      if (isPublic != null) updateData['isPublic'] = isPublic;

      // Upload new image if provided
      if (imageFile != null) {
        String userId = _auth.currentUser!.uid;
        String imageUrl = await _storageService.uploadQuoteImage(imageFile, userId, quoteId);
        updateData['imageUrl'] = imageUrl;
      }

      await _firestoreService.updateQuote(quoteId, updateData);
    } catch (e) {
      throw 'Failed to update quote: $e';
    }
  }

  // Delete a quote
  Future<void> deleteQuote(String quoteId) async {
    try {
      // Get quote data to check if it has an image
      Map<String, dynamic>? quoteData = await _firestoreService.getQuote(quoteId);
      
      // Delete image if it exists
      if (quoteData != null && quoteData['imageUrl'] != null) {
        await _storageService.deleteImage(quoteData['imageUrl']);
      }

      // Delete quote from Firestore
      await _firestoreService.deleteQuote(quoteId, _auth.currentUser!.uid);
    } catch (e) {
      throw 'Failed to delete quote: $e';
    }
  }

  // Search quotes
  Future<QuerySnapshot> searchQuotes(String searchTerm) async {
    try {
      return await _firestoreService.searchQuotes(searchTerm);
    } catch (e) {
      throw 'Failed to search quotes: $e';
    }
  }

  // Like/Unlike a quote
  Future<void> toggleLike(String quoteId) async {
    try {
      await _firestoreService.toggleLike(quoteId, _auth.currentUser!.uid);
    } catch (e) {
      throw 'Failed to toggle like: $e';
    }
  }

  // Check if user liked a quote
  Future<bool> isLikedByUser(String quoteId) async {
    try {
      return await _firestoreService.isLikedByUser(quoteId, _auth.currentUser!.uid);
    } catch (e) {
      return false;
    }
  }

  // Get quote statistics
  Future<Map<String, int>> getQuoteStats(String quoteId) async {
    try {
      return await _firestoreService.getQuoteStats(quoteId);
    } catch (e) {
      throw 'Failed to get quote stats: $e';
    }
  }

  // Get user statistics
  Future<Map<String, int>> getUserStats() async {
    try {
      return await _firestoreService.getUserStats(_auth.currentUser!.uid);
    } catch (e) {
      throw 'Failed to get user stats: $e';
    }
  }

  // Get background images for a category
  Future<List<String>> getBackgroundImages(String category) async {
    try {
      return await _storageService.getBackgroundImages(category);
    } catch (e) {
      throw 'Failed to get background images: $e';
    }
  }

  // Upload background image
  Future<String> uploadBackgroundImage(File imageFile, String category) async {
    try {
      return await _storageService.uploadBackgroundImage(imageFile, category);
    } catch (e) {
      throw 'Failed to upload background image: $e';
    }
  }

  // Get quotes by category
  Stream<QuerySnapshot> getQuotesByCategory(String category) {
    return _firestoreService.getPublicQuotes(category: category);
  }

  // Get quotes by language
  Stream<QuerySnapshot> getQuotesByLanguage(String language) {
    return _firestoreService.getPublicQuotes(language: language);
  }

  // Get trending quotes (most liked)
  Future<QuerySnapshot> getTrendingQuotes({int limit = 10}) async {
    try {
      return await FirebaseFirestore.instance
          .collection('quotes')
          .where('isPublic', isEqualTo: true)
          .orderBy('likes', descending: true)
          .limit(limit)
          .get();
    } catch (e) {
      throw 'Failed to get trending quotes: $e';
    }
  }

  // Get recent quotes
  Future<QuerySnapshot> getRecentQuotes({int limit = 10}) async {
    try {
      return await FirebaseFirestore.instance
          .collection('quotes')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
    } catch (e) {
      throw 'Failed to get recent quotes: $e';
    }
  }

  // Share quote (increment share count)
  Future<void> shareQuote(String quoteId) async {
    try {
      await FirebaseFirestore.instance
          .collection('quotes')
          .doc(quoteId)
          .update({
        'shares': FieldValue.increment(1),
      });
    } catch (e) {
      throw 'Failed to share quote: $e';
    }
  }

  // Get user's favorite quotes (liked quotes)
  Future<QuerySnapshot> getFavoriteQuotes() async {
    try {
      String userId = _auth.currentUser!.uid;
      
      // Get all quotes that the user has liked
      QuerySnapshot likedQuotes = await FirebaseFirestore.instance
          .collectionGroup('likes')
          .where('userId', isEqualTo: userId)
          .get();

      List<String> quoteIds = likedQuotes.docs
          .map((doc) => doc.reference.parent.parent!.id)
          .toList();

      if (quoteIds.isEmpty) {
        // Return empty result by throwing an exception that will be caught
        throw 'No favorite quotes found';
      }

      // Get the actual quote documents
      return await FirebaseFirestore.instance
          .collection('quotes')
          .where(FieldPath.documentId, whereIn: quoteIds)
          .get();
    } catch (e) {
      throw 'Failed to get favorite quotes: $e';
    }
  }

  // Duplicate a quote (create a copy)
  Future<String> duplicateQuote(String originalQuoteId) async {
    try {
      Map<String, dynamic>? originalQuote = await _firestoreService.getQuote(originalQuoteId);
      
      if (originalQuote == null) {
        throw 'Original quote not found';
      }

      // Create a new quote based on the original
      return await createQuote(
        text: originalQuote['text'],
        author: originalQuote['author'],
        category: originalQuote['category'],
        language: originalQuote['language'],
        isPublic: false, // Always private when duplicating
      );
    } catch (e) {
      throw 'Failed to duplicate quote: $e';
    }
  }
} 