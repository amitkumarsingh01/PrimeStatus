import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseConfig {
  static const String _projectId = 'prime-status-1db09';
  static const String _storageBucket = 'prime-status-1db09.firebasestorage.app';
  static const String _apiKey = 'AIzaSyBwnSiHV5mmT0rscA47TcwRlJjU6mmwWSk';
  static const String _appId = '1:344256821707:android:3aaba441c4ce80428ade4e';
  static const String _messagingSenderId = '344256821707';

  // Firebase options for different platforms
  static FirebaseOptions get firebaseOptions => const FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );

  // Initialize Firebase
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: firebaseOptions,
      );
      
      // Configure Firestore settings
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Configure Firebase Auth settings
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: false, // Set to true for testing
        phoneNumber: null,
        smsCode: null,
      );

      print('Firebase initialized successfully');
    } catch (e) {
      print('Failed to initialize Firebase: $e');
      rethrow;
    }
  }

  // Get Firebase Auth instance
  static FirebaseAuth get auth => FirebaseAuth.instance;

  // Get Firestore instance
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  // Get Firebase Storage instance
  static FirebaseStorage get storage => FirebaseStorage.instance;

  // Check if Firebase is initialized
  static bool get isInitialized => Firebase.apps.isNotEmpty;

  // Get current Firebase app
  static FirebaseApp? get currentApp {
    try {
      return Firebase.app();
    } catch (e) {
      return null;
    }
  }

  // Enable Firestore offline persistence
  static Future<void> enableOfflinePersistence() async {
    try {
      await FirebaseFirestore.instance.enablePersistence(
        const PersistenceSettings(synchronizeTabs: true),
      );
      print('Firestore offline persistence enabled');
    } catch (e) {
      print('Failed to enable offline persistence: $e');
    }
  }

  // Clear Firestore cache
  static Future<void> clearFirestoreCache() async {
    try {
      await FirebaseFirestore.instance.clearPersistence();
      print('Firestore cache cleared');
    } catch (e) {
      print('Failed to clear Firestore cache: $e');
    }
  }

  // Get Firestore collection references
  static CollectionReference get usersCollection => 
      FirebaseFirestore.instance.collection('users');
  
  static CollectionReference get quotesCollection => 
      FirebaseFirestore.instance.collection('quotes');
  
  static CollectionReference get userQuotesCollection => 
      FirebaseFirestore.instance.collection('user_quotes');

  // Get Storage references
  static Reference get profilePhotosRef => 
      FirebaseStorage.instance.ref().child('profile_photos');
  
  static Reference get quoteImagesRef => 
      FirebaseStorage.instance.ref().child('quote_images');
  
  static Reference get backgroundImagesRef => 
      FirebaseStorage.instance.ref().child('backgrounds');

  // Configure Firestore security rules (for reference)
  static const String firestoreRules = '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read and write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Users can read and write their own quotes
    match /user_quotes/{userId}/quotes/{quoteId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Public quotes can be read by anyone, but only created by authenticated users
    match /quotes/{quoteId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
    
    // Quote likes can be managed by authenticated users
    match /quotes/{quoteId}/likes/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
''';

  // Configure Storage security rules (for reference)
  static const String storageRules = '''
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile photos: users can upload and read their own photos
    match /profile_photos/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Quote images: users can upload and read their own quote images
    match /quote_images/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Background images: anyone can read, only admins can write
    match /backgrounds/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null && 
        request.auth.token.admin == true;
    }
    
    // Temporary images: users can upload and read their own temp images
    match /temp/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
''';
} 