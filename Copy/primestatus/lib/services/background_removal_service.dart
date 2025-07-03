import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class BackgroundRemovalService {
  static const String _baseUrl = 'https://bgremoval.iaks.site';
  static const Duration _timeout = Duration(seconds: 30);
  
  /// Remove background from an image file
  Future<String?> removeBackground(File imageFile) async {
    try {
      // Validate file exists and is readable
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/remove-bg/'),
      );

      // Add the image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      // Send the request with timeout
      var response = await request.send().timeout(_timeout);
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        // Return the full URL to the processed image
        String filename = jsonResponse['filename'];
        return '$_baseUrl/download/$filename';
      } else {
        throw Exception('Background removal failed: ${jsonResponse['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error removing background: $e');
      if (e.toString().contains('timeout')) {
        throw Exception('Background removal timed out. Please try again.');
      }
      return null;
    }
  }

  /// Remove background from a network image URL
  Future<String?> removeBackgroundFromUrl(String imageUrl) async {
    try {
      // Download the image first with timeout
      var response = await http.get(Uri.parse(imageUrl)).timeout(_timeout);
      if (response.statusCode != 200) {
        throw Exception('Failed to download image: ${response.statusCode}');
      }

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(response.bodyBytes);

      // Remove background
      final result = await removeBackground(tempFile);

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return result;
    } catch (e) {
      print('Error removing background from URL: $e');
      if (e.toString().contains('timeout')) {
        throw Exception('Background removal timed out. Please try again.');
      }
      return null;
    }
  }

  /// Pick image from gallery and remove background
  Future<String?> pickImageAndRemoveBackground() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        return await removeBackground(imageFile);
      }
      return null;
    } catch (e) {
      print('Error picking image and removing background: $e');
      return null;
    }
  }

  /// Pick image from camera and remove background
  Future<String?> takePhotoAndRemoveBackground() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        return await removeBackground(imageFile);
      }
      return null;
    } catch (e) {
      print('Error taking photo and removing background: $e');
      return null;
    }
  }

  /// Check if the background removal service is available
  Future<bool> isServiceAvailable() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/')).timeout(Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('Background removal service not available: $e');
      return false;
    }
  }
} 