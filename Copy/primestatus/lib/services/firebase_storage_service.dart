import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = Uuid();

  // Upload profile photo
  Future<String> uploadProfilePhoto(File imageFile, String userId) async {
    try {
      print('FirebaseStorageService: Starting profile photo upload');
      print('FirebaseStorageService: Image file path: ${imageFile.path}');
      print('FirebaseStorageService: User ID: $userId');
      
      String fileName = 'profile_photos/$userId/${_uuid.v4()}.jpg';
      print('FirebaseStorageService: File name: $fileName');
      
      Reference ref = _storage.ref().child(fileName);
      print('FirebaseStorageService: Created storage reference');
      
      print('FirebaseStorageService: Starting upload task...');
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      print('FirebaseStorageService: Upload task completed');
      
      print('FirebaseStorageService: Getting download URL...');
      String downloadUrl = await snapshot.ref.getDownloadURL();
      print('FirebaseStorageService: Download URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      print('FirebaseStorageService: Error uploading profile photo: $e');
      throw 'Failed to upload profile photo: $e';
    }
  }

  // Upload quote image
  Future<String> uploadQuoteImage(File imageFile, String userId, String quoteId) async {
    try {
      String fileName = 'quote_images/$userId/$quoteId/${_uuid.v4()}.jpg';
      Reference ref = _storage.ref().child(fileName);
      
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw 'Failed to upload quote image: $e';
    }
  }

  // Upload image from bytes (for web)
  Future<String> uploadImageFromBytes(Uint8List imageBytes, String path) async {
    try {
      String fileName = '$path/${_uuid.v4()}.jpg';
      Reference ref = _storage.ref().child(fileName);
      
      UploadTask uploadTask = ref.putData(imageBytes);
      TaskSnapshot snapshot = await uploadTask;
      
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw 'Failed to upload image: $e';
    }
  }

  // Delete image
  Future<void> deleteImage(String imageUrl) async {
    try {
      Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw 'Failed to delete image: $e';
    }
  }

  // Get image download URL
  Future<String> getImageDownloadUrl(String imagePath) async {
    try {
      Reference ref = _storage.ref().child(imagePath);
      return await ref.getDownloadURL();
    } catch (e) {
      throw 'Failed to get image download URL: $e';
    }
  }

  // Upload background image for quotes
  Future<String> uploadBackgroundImage(File imageFile, String category) async {
    try {
      String fileName = 'backgrounds/$category/${_uuid.v4()}.jpg';
      Reference ref = _storage.ref().child(fileName);
      
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw 'Failed to upload background image: $e';
    }
  }

  // Get background images for a category
  Future<List<String>> getBackgroundImages(String category) async {
    try {
      Reference ref = _storage.ref().child('backgrounds/$category');
      ListResult result = await ref.listAll();
      
      List<String> imageUrls = [];
      for (Reference item in result.items) {
        String downloadUrl = await item.getDownloadURL();
        imageUrls.add(downloadUrl);
      }
      
      return imageUrls;
    } catch (e) {
      throw 'Failed to get background images: $e';
    }
  }

  // Upload temporary image (for preview)
  Future<String> uploadTemporaryImage(File imageFile) async {
    try {
      String fileName = 'temp/${_uuid.v4()}.jpg';
      Reference ref = _storage.ref().child(fileName);
      
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw 'Failed to upload temporary image: $e';
    }
  }

  // Clean up temporary images (call this periodically)
  Future<void> cleanupTemporaryImages() async {
    try {
      Reference tempRef = _storage.ref().child('temp');
      ListResult result = await tempRef.listAll();
      
      // Delete files older than 24 hours
      DateTime cutoffTime = DateTime.now().subtract(Duration(hours: 24));
      
      for (Reference item in result.items) {
        try {
          // Get metadata to check creation time
          FullMetadata metadata = await item.getMetadata();
          DateTime creationTime = metadata.timeCreated ?? DateTime.now();
          
          if (creationTime.isBefore(cutoffTime)) {
            await item.delete();
          }
        } catch (e) {
          // Skip if we can't get metadata or delete
          continue;
        }
      }
    } catch (e) {
      // Don't throw error for cleanup failures
      print('Cleanup failed: $e');
    }
  }
} 