import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _quotesCollection => _firestore.collection('quotes');
  CollectionReference get _userQuotesCollection => _firestore.collection('user_quotes');
  CollectionReference get _loginTypeCollection => _firestore.collection('login_types');

  // User operations
  Future<void> createUser({
    required String uid,
    required String mobileNumber,
    required String name,
    required String language,
    required String usageType,
    required String religion,
    required String state,
    String? profilePhotoUrl,
    String subscription = 'free',
    String? email,
    String? phoneNumber,
    String? address,
    String? dateOfBirth,
    String? city,
    String? designation,
    String? businessName,
    String? businessLogoUrl,
    String? businessCategory,
  }) async {
    try {
      await _usersCollection.doc(uid).set({
        'mobileNumber': mobileNumber,
        'name': name,
        'language': language,
        'usageType': usageType,
        'religion': religion,
        'state': state,
        'profilePhotoUrl': profilePhotoUrl,
        'subscription': subscription,
        'email': email,
        'phoneNumber': phoneNumber,
        'address': address,
        'dateOfBirth': dateOfBirth,
        'city': city,
        'designation': designation,
        'businessName': businessName,
        'businessLogoUrl': businessLogoUrl,
        'businessCategory': businessCategory,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to create user: $e';
    }
  }

  Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw 'Failed to get user: $e';
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _usersCollection.doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      throw 'Failed to update user: $e';
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _usersCollection.doc(uid).delete();
    } catch (e) {
      throw 'Failed to delete user: $e';
    }
  }

  // Quote operations
  Future<String> createQuote({
    required String userId,
    required String text,
    required String author,
    String? category,
    String? language,
    String? imageUrl,
    bool isPublic = false,
  }) async {
    try {
      DocumentReference docRef = await _quotesCollection.add({
        'userId': userId,
        'text': text,
        'author': author,
        'category': category,
        'language': language,
        'imageUrl': imageUrl,
        'isPublic': isPublic,
        'likes': 0,
        'shares': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also add to user's quotes collection
      await _userQuotesCollection.doc(userId).collection('quotes').doc(docRef.id).set({
        'quoteId': docRef.id,
        'text': text,
        'author': author,
        'category': category,
        'language': language,
        'imageUrl': imageUrl,
        'isPublic': isPublic,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      throw 'Failed to create quote: $e';
    }
  }

  Future<Map<String, dynamic>?> getQuote(String quoteId) async {
    try {
      DocumentSnapshot doc = await _quotesCollection.doc(quoteId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw 'Failed to get quote: $e';
    }
  }

  Future<void> updateQuote(String quoteId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _quotesCollection.doc(quoteId).update(data);
    } catch (e) {
      throw 'Failed to update quote: $e';
    }
  }

  Future<void> deleteQuote(String quoteId, String userId) async {
    try {
      await _quotesCollection.doc(quoteId).delete();
      await _userQuotesCollection.doc(userId).collection('quotes').doc(quoteId).delete();
    } catch (e) {
      throw 'Failed to delete quote: $e';
    }
  }

  // Get user's quotes
  Stream<QuerySnapshot> getUserQuotes(String userId) {
    return _userQuotesCollection
        .doc(userId)
        .collection('quotes')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get public quotes
  Stream<QuerySnapshot> getPublicQuotes({String? category, String? language}) {
    Query query = _quotesCollection.where('isPublic', isEqualTo: true);
    
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    
    if (language != null) {
      query = query.where('language', isEqualTo: language);
    }
    
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  // Search quotes
  Future<QuerySnapshot> searchQuotes(String searchTerm) async {
    try {
      return await _quotesCollection
          .where('isPublic', isEqualTo: true)
          .where('text', isGreaterThanOrEqualTo: searchTerm)
          .where('text', isLessThan: searchTerm + '\uf8ff')
          .get();
    } catch (e) {
      throw 'Failed to search quotes: $e';
    }
  }

  // Like/Unlike quote
  Future<void> toggleLike(String quoteId, String userId) async {
    try {
      DocumentReference quoteRef = _quotesCollection.doc(quoteId);
      DocumentReference likeRef = quoteRef.collection('likes').doc(userId);

      DocumentSnapshot likeDoc = await likeRef.get();
      
      if (likeDoc.exists) {
        // Unlike
        await likeRef.delete();
        await quoteRef.update({
          'likes': FieldValue.increment(-1),
        });
      } else {
        // Like
        await likeRef.set({
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await quoteRef.update({
          'likes': FieldValue.increment(1),
        });
      }
    } catch (e) {
      throw 'Failed to toggle like: $e';
    }
  }

  // Check if user liked a quote
  Future<bool> isLikedByUser(String quoteId, String userId) async {
    try {
      DocumentSnapshot doc = await _quotesCollection
          .doc(quoteId)
          .collection('likes')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get quote statistics
  Future<Map<String, int>> getQuoteStats(String quoteId) async {
    try {
      DocumentSnapshot quoteDoc = await _quotesCollection.doc(quoteId).get();
      QuerySnapshot likesSnapshot = await _quotesCollection
          .doc(quoteId)
          .collection('likes')
          .get();

      Map<String, dynamic> quoteData = quoteDoc.data() as Map<String, dynamic>;
      
      return {
        'likes': likesSnapshot.docs.length,
        'shares': quoteData['shares'] ?? 0,
      };
    } catch (e) {
      throw 'Failed to get quote stats: $e';
    }
  }

  // Get user statistics
  Future<Map<String, int>> getUserStats(String userId) async {
    try {
      QuerySnapshot userQuotes = await _userQuotesCollection
          .doc(userId)
          .collection('quotes')
          .get();

      int totalLikes = 0;
      int totalShares = 0;

      for (var doc in userQuotes.docs) {
        Map<String, dynamic> quoteData = doc.data() as Map<String, dynamic>;
        String quoteId = quoteData['quoteId'];
        
        DocumentSnapshot quoteDoc = await _quotesCollection.doc(quoteId).get();
        if (quoteDoc.exists) {
          Map<String, dynamic> fullQuoteData = quoteDoc.data() as Map<String, dynamic>;
          totalLikes += (fullQuoteData['likes'] ?? 0) as int;
          totalShares += (fullQuoteData['shares'] ?? 0) as int;
        }
      }

      return {
        'totalQuotes': userQuotes.docs.length,
        'totalLikes': totalLikes,
        'totalShares': totalShares,
      };
    } catch (e) {
      throw 'Failed to get user stats: $e';
    }
  }

  // Simple LoginType operations
  Future<void> setLoginType(bool loginType) async {
    try {
      await _loginTypeCollection.doc('loginType').set({
        'loginType': loginType,
      });
      print('🔧 LoginType set to: ${loginType ? "✅ TRUE" : "❌ FALSE"}');
    } catch (e) {
      print('💥 Failed to set loginType: $e');
      throw 'Failed to set loginType: $e';
    }
  }

  Future<bool> getLoginType() async {
    try {
      DocumentSnapshot doc = await _loginTypeCollection.doc('loginType').get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        bool value = data['loginType'] ?? true;
        print('📖 LoginType found in Firestore: ${value ? "✅ TRUE" : "❌ FALSE"}');
        return value;
      }
      // If document doesn't exist, create it with default value true and return true
      print('🆕 LoginType document not found, creating with default value TRUE');
      await setLoginType(true);
      return true;
    } catch (e) {
      print('💥 Error getting loginType: $e');
      print('🔄 Defaulting to TRUE (normal auth flow)');
      // On error, default to true (normal auth flow)
      return true;
    }
  }
} 