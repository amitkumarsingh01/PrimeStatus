import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all categories from Firebase ordered by position
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('categories')
          .orderBy('position', descending: false)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'nameEn': data['nameEn'] ?? '',
          'nameKn': data['nameKn'] ?? '',
          'position': data['position'] ?? 0,
        };
      }).toList();
    } catch (e) {
      print('Error fetching categories: $e');
      // Return fallback categories if Firebase fails
      return [
        {'id': '1', 'nameEn': 'Morning', 'nameKn': 'ಮುಂಜಾನೆ', 'position': 0},
        {'id': '2', 'nameEn': 'Motivational', 'nameKn': 'ಪ್ರೇರಕ', 'position': 1},
        {'id': '3', 'nameEn': 'Love', 'nameKn': 'ಪ್ರೀತಿ', 'position': 2},
        {'id': '4', 'nameEn': 'Festival', 'nameKn': 'ಹಬ್ಬ', 'position': 3},
        {'id': '5', 'nameEn': 'Success', 'nameKn': 'ಯಶಸ್ಸು', 'position': 4},
        {'id': '6', 'nameEn': 'Inspiration', 'nameKn': 'ಸ್ಫೂರ್ತಿ', 'position': 5},
        {'id': '7', 'nameEn': 'Life', 'nameKn': 'ಜೀವನ', 'position': 6},
        {'id': '8', 'nameEn': 'Friendship', 'nameKn': 'ಸ್ನೇಹ', 'position': 7},
        {'id': '9', 'nameEn': 'Good Morning', 'nameKn': 'ಶುಭೋದಯ', 'position': 8},
        {'id': '10', 'nameEn': 'Good Night', 'nameKn': 'ಶುಭ ರಾತ್ರಿ', 'position': 9},
        {'id': '11', 'nameEn': 'Happy Sunday', 'nameKn': 'ಶುಭ ಭಾನುವಾರ', 'position': 10},
        {'id': '12', 'nameEn': 'Political', 'nameKn': 'ರಾಜಕೀಯ', 'position': 11},
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
          'position': data['position'] ?? 0,
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
      // Get the highest position to add new category at the end
      final existingCategories = await getCategories();
      final newPosition = existingCategories.isNotEmpty 
          ? existingCategories.map((cat) => cat['position'] as int).reduce((a, b) => a > b ? a : b) + 1 
          : 0;
      
      await _firestore.collection('categories').add({
        'nameEn': nameEn.trim(),
        'nameKn': nameKn.trim(),
        'position': newPosition,
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

  // Update category position
  Future<void> updateCategoryPosition(String id, int position) async {
    try {
      await _firestore.collection('categories').doc(id).update({
        'position': position,
      });
    } catch (e) {
      throw 'Failed to update category position: $e';
    }
  }

  // Update multiple category positions (for reordering)
  Future<void> updateCategoryPositions(List<Map<String, dynamic>> categories) async {
    try {
      final batch = _firestore.batch();
      
      for (final category in categories) {
        final docRef = _firestore.collection('categories').doc(category['id']);
        batch.update(docRef, {'position': category['position']});
      }
      
      await batch.commit();
    } catch (e) {
      throw 'Failed to update category positions: $e';
    }
  }
} 