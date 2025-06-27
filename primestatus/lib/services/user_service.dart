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

  // Register user with phone number (Phone Auth only)
  Future<void> registerUserWithPhone({
    required String phoneNumber,
    required String name,
    required String language,
    required String usageType,
    required String religion,
    required String state,
    String? profilePhotoUrl,
    String subscription = 'free',
  }) async {
    try {
      // Check if user already exists
      bool userExists = await userExistsByPhone(phoneNumber);
      if (userExists) {
        throw 'User with this phone number already exists. Please sign in instead.';
      }

      // Store user data in Firestore with a temporary UID
      // This will be linked to the actual Firebase Auth user after phone verification
      String tempUid = 'pending_${DateTime.now().millisecondsSinceEpoch}';
      
      await _firestoreService.createUser(
        uid: tempUid,
        mobileNumber: phoneNumber,
        name: name,
        language: language,
        usageType: usageType,
        religion: religion,
        state: state,
        profilePhotoUrl: profilePhotoUrl,
        subscription: subscription,
      );

      // Store pending registration data for later completion
      await FirebaseFirestore.instance
          .collection('pending_registrations')
          .doc(phoneNumber)
          .set({
        'tempUid': tempUid,
        'phoneNumber': phoneNumber,
        'name': name,
        'language': language,
        'usageType': usageType,
        'religion': religion,
        'state': state,
        'profilePhotoUrl': profilePhotoUrl,
        'subscription': subscription,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Registration failed: $e';
    }
  }

  // Complete registration after phone verification
  Future<void> completeRegistration(String phoneNumber) async {
    try {
      // Get pending registration data
      DocumentSnapshot pendingDoc = await FirebaseFirestore.instance
          .collection('pending_registrations')
          .doc(phoneNumber)
          .get();

      if (!pendingDoc.exists) {
        throw 'No pending registration found for this phone number';
      }

      Map<String, dynamic> pendingData = pendingDoc.data() as Map<String, dynamic>;
      
      // Get the current authenticated user
      User? currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw 'No authenticated user found';
      }

      // Update the user document with the real UID
      await _firestoreService.updateUser(pendingData['tempUid'], {
        'uid': currentUser.uid,
        'mobileNumber': phoneNumber,
      });

      // Create a new document with the real UID
      await _firestoreService.createUser(
        uid: currentUser.uid,
        mobileNumber: pendingData['mobileNumber'],
        name: pendingData['name'],
        language: pendingData['language'],
        usageType: pendingData['usageType'],
        religion: pendingData['religion'],
        state: pendingData['state'],
        profilePhotoUrl: pendingData['profilePhotoUrl'],
        subscription: pendingData['subscription'],
      );

      // Delete the pending registration
      await FirebaseFirestore.instance
          .collection('pending_registrations')
          .doc(phoneNumber)
          .delete();

      // Delete the temporary user document
      await _firestoreService.deleteUser(pendingData['tempUid']);
    } catch (e) {
      throw 'Failed to complete registration: $e';
    }
  }

  // Sign in with phone number
  Future<UserCredential> signInWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      return await _authService.signInWithPhoneCredential(credential);
    } catch (e) {
      throw 'Phone sign in failed: $e';
    }
  }

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
  }) async {
    try {
      Map<String, dynamic> updateData = {};
      
      if (name != null) updateData['name'] = name;
      if (language != null) updateData['language'] = language;
      if (usageType != null) updateData['usageType'] = usageType;
      if (religion != null) updateData['religion'] = religion;
      if (state != null) updateData['state'] = state;
      if (subscription != null) updateData['subscription'] = subscription;

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

  // Verify phone number
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String) onCodeAutoRetrievalTimeout,
  }) async {
    await _authService.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onVerificationCompleted: onVerificationCompleted,
      onVerificationFailed: onVerificationFailed,
      onCodeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
    );
  }

  // Check if user exists by phone number
  Future<bool> userExistsByPhone(String phoneNumber) async {
    try {
      // Query Firestore for user with this phone number
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection('users')
          .where('mobileNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get user by phone number
  Future<Map<String, dynamic>?> getUserByPhone(String phoneNumber) async {
    try {
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection('users')
          .where('mobileNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return query.docs.first.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw 'Failed to get user by phone: $e';
    }
  }
} 