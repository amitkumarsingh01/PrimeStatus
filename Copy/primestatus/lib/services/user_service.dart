import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_auth_service.dart';
import 'firebase_firestore_service.dart';
import 'firebase_storage_service.dart';
import 'background_removal_service.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class UserService {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final BackgroundRemovalService _bgRemovalService = BackgroundRemovalService();

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

  // Upload profile photo (normal - with background)
  Future<String> uploadProfilePhoto(File imageFile, String userId) async {
    try {
      print('UserService: Starting profile photo upload');
      print('UserService: Image file path: ${imageFile.path}');
      print('UserService: User ID: $userId');
      
      String downloadUrl = await _storageService.uploadProfilePhoto(imageFile, userId);
      print('UserService: Upload successful, download URL: $downloadUrl');
      
      // Update user document with new photo URL
      print('UserService: Updating Firestore user document');
      await _firestoreService.updateUser(userId, {
        'profilePhotoUrl': downloadUrl,
        'profilePhotoWithoutBg': false, // Mark as not processed for background removal
      });

      // Update Firebase Auth profile
      print('UserService: Updating Firebase Auth profile');
      await _authService.updateUserProfile(photoURL: downloadUrl);

      print('UserService: Profile photo upload completed successfully');
      return downloadUrl;
    } catch (e) {
      print('UserService: Error uploading profile photo: $e');
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

  // Upload profile photo with background removal (for post overlays only)
  Future<String> uploadProfilePhotoWithBgRemoval(File imageFile, String userId) async {
    try {
      // First remove background
      String? processedImageUrl = await _bgRemovalService.removeBackground(imageFile);
      
      if (processedImageUrl == null) {
        throw 'Background removal failed';
      }

      // Download the processed image
      final response = await http.get(Uri.parse(processedImageUrl));
      if (response.statusCode != 200) {
        throw 'Failed to download processed image';
      }

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/processed_profile.png');
      await tempFile.writeAsBytes(response.bodyBytes);

      // Upload to Firebase Storage
      String downloadUrl = await _storageService.uploadProfilePhoto(tempFile, userId);
      
      // Update user document with new photo URL
      await _firestoreService.updateUser(userId, {
        'profilePhotoUrl': downloadUrl,
        'profilePhotoWithoutBg': true, // Mark as processed for background removal
      });

      // Update Firebase Auth profile
      await _authService.updateUserProfile(photoURL: downloadUrl);

      // Clean up temp file
      await tempFile.delete();

      return downloadUrl;
    } catch (e) {
      throw 'Failed to upload profile photo with background removal: $e';
    }
  }

  // Get profile photo without background (process existing photo for post overlays)
  Future<String?> getProfilePhotoWithoutBackground(String userId) async {
    try {
      Map<String, dynamic>? userData = await _firestoreService.getUser(userId);
      String? currentPhotoUrl = userData?['profilePhotoUrl'];
      
      if (currentPhotoUrl == null || currentPhotoUrl.isEmpty) {
        return null;
      }

      // Check if we already have a processed version
      if (userData?['profilePhotoWithoutBg'] == true) {
        return currentPhotoUrl;
      }

      // Process the existing photo to remove background
      String? processedUrl = await _bgRemovalService.removeBackgroundFromUrl(currentPhotoUrl);
      
      if (processedUrl != null) {
        // Update the user document to mark as processed
        await _firestoreService.updateUser(userId, {
          'profilePhotoWithoutBg': true,
        });
      }

      return processedUrl;
    } catch (e) {
      print('Error getting profile photo without background: $e');
      return null;
    }
  }

  // Add profile photo to gallery (normal - with background)
  Future<String> addProfilePhotoToGallery(File imageFile, String userId) async {
    try {
      // Upload to Firebase Storage (with background)
      String downloadUrl = await _storageService.uploadProfilePhoto(imageFile, userId);
      
      // Add to user's profile photos collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('profilePhotos')
          .add({
        'photoUrl': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'isActive': false,
        'withoutBackground': false, // Mark as not processed
      });

      return downloadUrl;
    } catch (e) {
      throw 'Failed to add profile photo to gallery: $e';
    }
  }

  // Add profile photo to gallery with background removal (for post overlays only)
  Future<String> addProfilePhotoToGalleryWithBgRemoval(File imageFile, String userId) async {
    try {
      // Remove background
      String? processedImageUrl = await _bgRemovalService.removeBackground(imageFile);
      
      if (processedImageUrl == null) {
        throw 'Background removal failed';
      }

      // Download the processed image
      final response = await http.get(Uri.parse(processedImageUrl));
      if (response.statusCode != 200) {
        throw 'Failed to download processed image';
      }

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/processed_gallery.png');
      await tempFile.writeAsBytes(response.bodyBytes);

      // Upload to Firebase Storage
      String downloadUrl = await _storageService.uploadProfilePhoto(tempFile, userId);
      
      // Add to user's profile photos collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('profilePhotos')
          .add({
        'photoUrl': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'isActive': false,
        'withoutBackground': true, // Mark as processed
      });

      // Clean up temp file
      await tempFile.delete();

      return downloadUrl;
    } catch (e) {
      throw 'Failed to add profile photo with background removal: $e';
    }
  }

  // Get the current user's profile photo URL (normal version for UI)
  String? getCurrentProfilePhotoUrl() {
    return _authService.currentUser?.photoURL;
  }

  // Get the current user's profile photo URL without background (for post overlays)
  Future<String?> getCurrentProfilePhotoWithoutBackground() async {
    if (_authService.currentUser == null) return null;
    
    try {
      Map<String, dynamic>? userData = await _firestoreService.getUser(_authService.currentUser!.uid);
      String? currentPhotoUrl = userData?['profilePhotoUrl'];
      
      if (currentPhotoUrl == null || currentPhotoUrl.isEmpty) {
        return null;
      }

      // If already processed, return the URL
      if (userData?['profilePhotoWithoutBg'] == true) {
        return currentPhotoUrl;
      }

      // Process the photo to remove background
      String? processedUrl = await _bgRemovalService.removeBackgroundFromUrl(currentPhotoUrl);
      
      if (processedUrl != null) {
        // Update user document to mark as processed
        await _firestoreService.updateUser(_authService.currentUser!.uid, {
          'profilePhotoWithoutBg': true,
        });
        
        return processedUrl;
      }

      return currentPhotoUrl; // Fallback to original if processing fails
    } catch (e) {
      print('Error getting profile photo without background: $e');
      return _authService.currentUser?.photoURL; // Fallback to original
    }
  }

  // Update Firebase Auth profile photo
  Future<void> updateAuthProfilePhoto(String photoURL) async {
    try {
      await _authService.updateUserProfile(photoURL: photoURL);
    } catch (e) {
      throw 'Failed to update auth profile photo: $e';
    }
  }
} 