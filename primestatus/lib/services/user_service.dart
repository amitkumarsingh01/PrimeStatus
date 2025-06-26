import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(userId).update(updates);
    } catch (e) {
      print('Error updating user: $e');
    }
  }

  Future<String?> uploadProfilePhoto(String userId, File imageFile) async {
    try {
      final ref = _storage.ref().child('profile_photos/$userId.jpg');
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      await updateUser(userId, {'profile_photo_url': downloadUrl});
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile photo: $e');
      return null;
    }
  }

  Future<void> saveQuote(String userId, String quoteId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'savedquotesid': FieldValue.arrayUnion([quoteId])
      });
    } catch (e) {
      print('Error saving quote: $e');
    }
  }
} 