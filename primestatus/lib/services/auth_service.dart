import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        await _createOrUpdateUser(userCredential.user!);
      }
      
      return userCredential;
    } catch (e) {
      print('Google Sign In Error: $e');
      return null;
    }
  }

  // Phone Number Sign In
  Future<void> signInWithPhoneNumber(String phoneNumber, Function(String) onCodeSent) async {
    print('AuthService: Starting phone number sign in for $phoneNumber');
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        print('AuthService: Auto-verification completed');
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        if (userCredential.user != null) {
          print('AuthService: User signed in via auto-verification: ${userCredential.user!.uid}');
          await _createOrUpdateUser(userCredential.user!);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        print('AuthService: Phone verification failed: ${e.message}');
      },
      codeSent: (String verificationId, int? resendToken) {
        print('AuthService: Code sent, verificationId: $verificationId');
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        print('AuthService: Code auto-retrieval timeout');
      },
    );
  }

  Future<UserCredential?> verifyOTP(String verificationId, String otp) async {
    print('AuthService: Verifying OTP');
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        print('AuthService: User signed in via OTP: ${userCredential.user!.uid}');
        await _createOrUpdateUser(userCredential.user!);
      }
      
      return userCredential;
    } catch (e) {
      print('AuthService: OTP Verification Error: $e');
      return null;
    }
  }

  Future<void> _createOrUpdateUser(User firebaseUser) async {
    print('AuthService: Creating/updating user: ${firebaseUser.uid}');
    final String fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
    
    final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
    
    if (!userDoc.exists) {
      print('AuthService: Creating new user document');
      // Create new user
      final userData = {
        'id': firebaseUser.uid,
        'mobile_number': firebaseUser.phoneNumber,
        'language': 'English',
        'usage_type': 'personal',
        'name': firebaseUser.displayName ?? '',
        'profile_photo_url': firebaseUser.photoURL,
        'religion': '',
        'state': '',
        'subscription': 'free',
        'isActive': true,
        'isAdmin': false,
        'createquotesid': [],
        'savedquotesid': [],
        'fcmToken': fcmToken,
      };
      
      await _firestore.collection('users').doc(firebaseUser.uid).set(userData);
      print('AuthService: User document created successfully');
    } else {
      print('AuthService: Updating existing user document');
      // Update FCM token
      await _firestore.collection('users').doc(firebaseUser.uid).update({
        'fcmToken': fcmToken,
      });
      print('AuthService: User document updated successfully');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
} 