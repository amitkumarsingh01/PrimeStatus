import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all categories from Firebase
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final QuerySnapshot querySnapshot = await _firestore.collection('categories').get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'nameEn': data['nameEn'] ?? '',
          'nameKn': data['nameKn'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error fetching categories: $e');
      // Return fallback categories if Firebase fails
      return [
        {'id': '1', 'nameEn': 'Morning', 'nameKn': 'ಮುಂಜಾನೆ'},
        {'id': '2', 'nameEn': 'Motivational', 'nameKn': 'ಪ್ರೇರಕ'},
        {'id': '3', 'nameEn': 'Love', 'nameKn': 'ಪ್ರೀತಿ'},
        {'id': '4', 'nameEn': 'Festival', 'nameKn': 'ಹಬ್ಬ'},
        {'id': '5', 'nameEn': 'Success', 'nameKn': 'ಯಶಸ್ಸು'},
        {'id': '6', 'nameEn': 'Inspiration', 'nameKn': 'ಸ್ಫೂರ್ತಿ'},
        {'id': '7', 'nameEn': 'Life', 'nameKn': 'ಜೀವನ'},
        {'id': '8', 'nameEn': 'Friendship', 'nameKn': 'ಸ್ನೇಹ'},
        {'id': '9', 'nameEn': 'Good Morning', 'nameKn': 'ಶುಭೋದಯ'},
        {'id': '10', 'nameEn': 'Good Night', 'nameKn': 'ಶುಭ ರಾತ್ರಿ'},
        {'id': '11', 'nameEn': 'Happy Sunday', 'nameKn': 'ಶುಭ ಭಾನುವಾರ'},
        {'id': '12', 'nameEn': 'Political', 'nameKn': 'ರಾಜಕೀಯ'},
      ];
    }
  }

  // Get category names in English
  Future<List<String>> getCategoryNames() async {
    final categories = await getCategories();
    return categories.map((cat) => cat['nameEn'] as String).toList();
  }

  // Get category names in Kannada
  Future<List<String>> getCategoryNamesKn() async {
    final categories = await getCategories();
    return categories.map((cat) => cat['nameKn'] as String).toList();
  }

  // Get category by ID
  Future<Map<String, dynamic>?> getCategoryById(String id) async {
    try {
      final doc = await _firestore.collection('categories').doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'nameEn': data['nameEn'] ?? '',
          'nameKn': data['nameKn'] ?? '',
        };
      }
      return null;
    } catch (e) {
      print('Error fetching category by ID: $e');
      return null;
    }
  }

  // Add new category
  Future<void> addCategory(String nameEn, String nameKn) async {
    try {
      await _firestore.collection('categories').add({
        'nameEn': nameEn.trim(),
        'nameKn': nameKn.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to add category: $e';
    }
  }

  // Delete category
  Future<void> deleteCategory(String id) async {
    try {
      await _firestore.collection('categories').doc(id).delete();
    } catch (e) {
      throw 'Failed to delete category: $e';
    }
  }
} 