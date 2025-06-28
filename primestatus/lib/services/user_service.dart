import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_auth_service.dart';
import 'firebase_firestore_service.dart';
import 'firebase_storage_service.dart';
import 'dart:io';

class UserService {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();
  final FirebaseStorageService _storageService = FirebaseStorageService();

  // Get current user
  User? get currentUser => _authService.currentUser;

  // Auth state changes
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      UserCredential userCredential = await _authService.signInWithGoogle();
      
      // Check if user exists in Firestore
      Map<String, dynamic>? userData = await _firestoreService.getUser(userCredential.user!.uid);
      
      if (userData == null) {
        // Create user document if it doesn't exist
        await _firestoreService.createUser(
          uid: userCredential.user!.uid,
          mobileNumber: userCredential.user!.phoneNumber ?? '',
          name: userCredential.user!.displayName ?? 'User',
          language: 'English', // Default
          usageType: 'Personal', // Default
          religion: 'Other', // Default
          state: 'Other', // Default
          profilePhotoUrl: userCredential.user!.photoURL,
          subscription: 'free',
          email: userCredential.user!.email ?? '',
          phoneNumber: userCredential.user!.phoneNumber ?? '',
          address: '',
          dateOfBirth: '',
          city: '',
        );
      }

      return userCredential;
    } catch (e) {
      throw 'Google sign in failed: $e';
    }
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      return await _firestoreService.getUser(uid);
    } catch (e) {
      throw 'Failed to get user data: $e';
    }
  }

  // Update user data
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _firestoreService.updateUser(uid, data);
    } catch (e) {
      throw 'Failed to update user data: $e';
    }
  }

  // Upload profile photo
  Future<String> uploadProfilePhoto(File imageFile, String userId) async {
    try {
      String downloadUrl = await _storageService.uploadProfilePhoto(imageFile, userId);
      
      // Update user document with new photo URL
      await _firestoreService.updateUser(userId, {
        'profilePhotoUrl': downloadUrl,
      });

      // Update Firebase Auth profile
      await _authService.updateUserProfile(photoURL: downloadUrl);

      return downloadUrl;
    } catch (e) {
      throw 'Failed to upload profile photo: $e';
    }
  }

  // Update user profile
  Future<void> updateProfile({
    required String uid,
    String? name,
    String? language,
    String? usageType,
    String? religion,
    String? state,
    String? subscription,
    String? phoneNumber,
    String? address,
    String? dateOfBirth,
    String? city,
  }) async {
    try {
      Map<String, dynamic> updateData = {};
      
      if (name != null) updateData['name'] = name;
      if (language != null) updateData['language'] = language;
      if (usageType != null) updateData['usageType'] = usageType;
      if (religion != null) updateData['religion'] = religion;
      if (state != null) updateData['state'] = state;
      if (subscription != null) updateData['subscription'] = subscription;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (address != null) updateData['address'] = address;
      if (dateOfBirth != null) updateData['dateOfBirth'] = dateOfBirth;
      if (city != null) updateData['city'] = city;

      await _firestoreService.updateUser(uid, updateData);

      // Update Firebase Auth display name if provided
      if (name != null) {
        await _authService.updateUserProfile(displayName: name);
      }
    } catch (e) {
      throw 'Failed to update profile: $e';
    }
  }

  // Delete user account
  Future<void> deleteAccount(String uid) async {
    try {
      // Delete user data from Firestore
      await _firestoreService.deleteUser(uid);
      
      // Delete user from Firebase Auth
      await _authService.deleteUser();
    } catch (e) {
      throw 'Failed to delete account: $e';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      throw 'Sign out failed: $e';
    }
  }

  // Check if user is premium
  Future<bool> isPremiumUser(String uid) async {
    try {
      Map<String, dynamic>? userData = await _firestoreService.getUser(uid);
      return userData?['subscription'] == 'premium';
    } catch (e) {
      return false;
    }
  }

  // Upgrade to premium
  Future<void> upgradeToPremium(String uid) async {
    try {
      await _firestoreService.updateUser(uid, {
        'subscription': 'premium',
        'premiumUpgradedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to upgrade to premium: $e';
    }
  }

  // Get user statistics
  Future<Map<String, int>> getUserStats(String uid) async {
    try {
      return await _firestoreService.getUserStats(uid);
    } catch (e) {
      throw 'Failed to get user stats: $e';
    }
  }

  // Check if user has previous session
  Future<bool> hasPreviousSession() async {
    try {
      // Check if there's a current user (even if not fully authenticated)
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        return true;
      }
      
      // Check if there's any cached user data in Firestore
      // This is a simple implementation - you might want to use SharedPreferences
      // or other local storage for a more robust solution
      return false;
    } catch (e) {
      return false;
    }
  }
} 