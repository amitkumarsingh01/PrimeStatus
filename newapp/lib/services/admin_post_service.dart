import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference for admin posts
  CollectionReference get _adminPostsCollection => _firestore.collection('admin_posts');

  // Get all admin posts for feed
  Stream<QuerySnapshot> getAdminPostsFeed() {
    return _adminPostsCollection
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get admin posts by category
  Stream<QuerySnapshot> getAdminPostsByCategory(String category) {
    return _adminPostsCollection
        .where('isPublished', isEqualTo: true)
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get admin posts by language
  Stream<QuerySnapshot> getAdminPostsByLanguage(String language) {
    return _adminPostsCollection
        .where('isPublished', isEqualTo: true)
        .where('language', isEqualTo: language)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get trending admin posts (most liked)
  Future<QuerySnapshot> getTrendingAdminPosts({int limit = 10}) async {
    try {
      return await _adminPostsCollection
          .where('isPublished', isEqualTo: true)
          .orderBy('likes', descending: true)
          .limit(limit)
          .get();
    } catch (e) {
      throw 'Failed to get trending admin posts: $e';
    }
  }

  // Get recent admin posts
  Future<QuerySnapshot> getRecentAdminPosts({int limit = 10}) async {
    try {
      return await _adminPostsCollection
          .where('isPublished', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
    } catch (e) {
      throw 'Failed to get recent admin posts: $e';
    }
  }

  // Get a specific admin post
  Future<Map<String, dynamic>?> getAdminPost(String postId) async {
    try {
      DocumentSnapshot doc = await _adminPostsCollection.doc(postId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw 'Failed to get admin post: $e';
    }
  }

  // Like/Unlike admin post
  Future<void> toggleLikeAdminPost(String postId) async {
    try {
      String userId = _auth.currentUser!.uid;
      DocumentReference postRef = _adminPostsCollection.doc(postId);
      DocumentReference likeRef = postRef.collection('likes').doc(userId);

      DocumentSnapshot likeDoc = await likeRef.get();
      
      if (likeDoc.exists) {
        // Unlike
        await likeRef.delete();
        await postRef.update({
          'likes': FieldValue.increment(-1),
        });
      } else {
        // Like
        await likeRef.set({
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await postRef.update({
          'likes': FieldValue.increment(1),
        });
      }
    } catch (e) {
      throw 'Failed to toggle like: $e';
    }
  }

  // Check if user liked an admin post
  Future<bool> isLikedByUser(String postId) async {
    try {
      String userId = _auth.currentUser!.uid;
      DocumentSnapshot doc = await _adminPostsCollection
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Share admin post (increment share count)
  Future<void> shareAdminPost(String postId) async {
    try {
      await _adminPostsCollection.doc(postId).update({
        'shares': FieldValue.increment(1),
      });
    } catch (e) {
      throw 'Failed to share admin post: $e';
    }
  }

  // Get admin post statistics
  Future<Map<String, int>> getAdminPostStats(String postId) async {
    try {
      DocumentSnapshot postDoc = await _adminPostsCollection.doc(postId).get();
      QuerySnapshot likesSnapshot = await _adminPostsCollection
          .doc(postId)
          .collection('likes')
          .get();

      Map<String, dynamic> postData = postDoc.data() as Map<String, dynamic>;
      
      return {
        'likes': likesSnapshot.docs.length,
        'shares': postData['shares'] ?? 0,
      };
    } catch (e) {
      throw 'Failed to get admin post stats: $e';
    }
  }

  // Search admin posts
  Future<QuerySnapshot> searchAdminPosts(String searchTerm) async {
    try {
      return await _adminPostsCollection
          .where('isPublished', isEqualTo: true)
          .where('title', isGreaterThanOrEqualTo: searchTerm)
          .where('title', isLessThan: searchTerm + '\uf8ff')
          .get();
    } catch (e) {
      throw 'Failed to search admin posts: $e';
    }
  }

  // Get user's favorite admin posts (liked posts)
  Future<QuerySnapshot> getFavoriteAdminPosts() async {
    try {
      String userId = _auth.currentUser!.uid;
      
      // Get all admin posts that the user has liked
      QuerySnapshot likedPosts = await _firestore
          .collectionGroup('likes')
          .where('userId', isEqualTo: userId)
          .get();

      // Extract post IDs
      List<String> postIds = likedPosts.docs
          .map((doc) => doc.reference.parent.parent!.id)
          .toList();

      if (postIds.isEmpty) {
        // Return empty query snapshot
        return await _adminPostsCollection.limit(0).get();
      }

      // Get the actual admin posts
      return await _adminPostsCollection
          .where(FieldPath.documentId, whereIn: postIds)
          .where('isPublished', isEqualTo: true)
          .get();
    } catch (e) {
      throw 'Failed to get favorite admin posts: $e';
    }
  }

  // Get admin posts with user interaction data
  Stream<List<Map<String, dynamic>>> getAdminPostsWithUserData() {
    return _adminPostsCollection
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> posts = [];
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> postData = doc.data() as Map<String, dynamic>;
        postData['id'] = doc.id;
        
        // Add user interaction data if user is logged in
        if (_auth.currentUser != null) {
          bool isLiked = await isLikedByUser(doc.id);
          postData['isLiked'] = isLiked;
        }
        
        posts.add(postData);
      }
      
      return posts;
    });
  }

  // Get admin posts created by a specific user
  Stream<List<Map<String, dynamic>>> getUserAdminPosts(String userId) {
    return _adminPostsCollection
        .where('isPublished', isEqualTo: true)
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      List<Map<String, dynamic>> posts = [];
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> postData = doc.data() as Map<String, dynamic>;
        postData['id'] = doc.id;
        posts.add(postData);
      }
      
      return posts;
    });
  }

  // Get user's liked admin posts
  Stream<List<Map<String, dynamic>>> getUserLikedAdminPosts(String userId) {
    return _firestore
        .collectionGroup('likes')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      List<String> postIds = snapshot.docs
          .map((doc) => doc.reference.parent.parent!.id)
          .toList();

      if (postIds.isEmpty) {
        return [];
      }

      // Get the actual admin posts
      QuerySnapshot postsSnapshot = await _adminPostsCollection
          .where(FieldPath.documentId, whereIn: postIds)
          .where('isPublished', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> posts = [];
      for (var doc in postsSnapshot.docs) {
        Map<String, dynamic> postData = doc.data() as Map<String, dynamic>;
        postData['id'] = doc.id;
        posts.add(postData);
      }

      return posts;
    });
  }
} 