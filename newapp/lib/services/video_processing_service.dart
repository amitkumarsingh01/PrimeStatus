import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:screenshot/screenshot.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideoProcessingService {
  static final ScreenshotController _screenshotController = ScreenshotController();

  /// Simple video processing with overlays (simplified without FFmpeg)
  static Future<String?> processVideoWithOverlays({
    required String videoUrl,
    required Map<String, dynamic> post,
    required String userUsageType,
    required String userName,
    String? userProfilePhotoUrl,
    required String userAddress,
    required String userPhoneNumber,
    required String userCity,
    required String userBusinessName,
    required String userDesignation,
  }) async {
    try {
      print('Starting video processing for: $videoUrl');
      
      // For now, we'll create a thumbnail with overlay instead of full video processing
      // since FFmpeg is not available
      final String? processedImagePath = await createVideoThumbnailWithOverlay(
        videoUrl: videoUrl,
        post: post,
        userUsageType: userUsageType,
        userName: userName,
        userProfilePhotoUrl: userProfilePhotoUrl,
        userAddress: userAddress,
        userPhoneNumber: userPhoneNumber,
        userCity: userCity,
        userBusinessName: userBusinessName,
        userDesignation: userDesignation,
      );

      if (processedImagePath != null) {
        print('Video thumbnail processed successfully: $processedImagePath');
        return processedImagePath;
      } else {
        print('Video processing failed');
        return null;
      }
    } catch (e) {
      print('Error processing video: $e');
      return null;
    }
  }

  /// Download video from URL
  static Future<String?> _downloadVideo(String videoUrl) async {
    try {
      print('Downloading video from: $videoUrl');
      
      // Handle base64 videos
      if (videoUrl.startsWith('data:video')) {
        final base64Str = videoUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName = 'input_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final String filePath = '${tempDir.path}/$fileName';
        final File videoFile = File(filePath);
        await videoFile.writeAsBytes(bytes);
        
        print('Base64 video saved to: $filePath');
        return filePath;
      }
      
      // Handle network videos
      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode == 200) {
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName = 'input_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final String filePath = '${tempDir.path}/$fileName';
        final File videoFile = File(filePath);
        await videoFile.writeAsBytes(response.bodyBytes);
        
        print('Network video saved to: $filePath');
        return filePath;
      } else {
        print('Failed to download video: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error downloading video: $e');
      return null;
    }
  }

  /// Create simple overlay image
  static Future<String?> _createSimpleOverlay({
    required Map<String, dynamic> post,
    required String userUsageType,
    required String userName,
    String? userProfilePhotoUrl,
    required String userAddress,
    required String userPhoneNumber,
    required String userCity,
    required String userBusinessName,
    required String userDesignation,
  }) async {
    try {
      final textSettings = post['textSettings'] ?? {};
      final profileSettings = post['profileSettings'] ?? {};
      final addressSettings = post['addressSettings'] ?? {};
      final phoneSettings = post['phoneSettings'] ?? {};
      final businessNameSettings = post['businessNameSettings'] ?? {};
      final designationSettings = post['designationSettings'] ?? {};
      final frameSize = post['frameSize'] ?? {'width': 720, 'height': 1280};

      // Create simple overlay widget
      final Widget overlayWidget = Container(
        width: frameSize['width'].toDouble(),
        height: frameSize['height'].toDouble(),
        color: Colors.transparent,
        child: Stack(
          children: [
            // Text overlay
            if (textSettings.isNotEmpty)
              Positioned(
                left: (textSettings['x'] ?? 50) / 100 * frameSize['width'],
                top: (textSettings['y'] ?? 90) / 100 * frameSize['height'],
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: textSettings['hasBackground'] == true
                      ? BoxDecoration(
                          color: _parseColor(textSettings['backgroundColor'] ?? '#000000'),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Text(
                    userName.length > 15 ? userName : userName,
                    style: TextStyle(
                      fontFamily: textSettings['font'] ?? 'Arial',
                      fontSize: (textSettings['fontSize'] ?? 24).toDouble() * (userName.length > 15 ? 0.6 : 1.0) * 0.65,
                      color: _parseColor(textSettings['color'] ?? '#ffffff'),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Address overlay
            if (userUsageType == 'Business' && addressSettings['enabled'] == true && userAddress.isNotEmpty)
              Positioned(
                left: ((addressSettings['x'] ?? 50) / 100 * frameSize['width']) - 20,
                top: (addressSettings['y'] ?? 80) / 100 * frameSize['height'],
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: addressSettings['hasBackground'] == true
                      ? BoxDecoration(
                          color: _parseColor(addressSettings['backgroundColor'] ?? '#000000'),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Text(
                    userAddress.length > 15 ? userAddress : userAddress,
                    style: TextStyle(
                      fontFamily: addressSettings['font'] ?? 'Arial',
                      fontSize: (addressSettings['fontSize'] ?? 18).toDouble() * (userAddress.length > 15 ? 0.6 : 1.0) * 0.65,
                      color: _parseColor(addressSettings['color'] ?? '#ffffff'),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Phone overlay
            if (userUsageType == 'Business' && phoneSettings['enabled'] == true && userPhoneNumber.isNotEmpty)
              Positioned(
                left: (phoneSettings['x'] ?? 50) / 100 * frameSize['width'],
                top: (phoneSettings['y'] ?? 85) / 100 * frameSize['height'],
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: phoneSettings['hasBackground'] == true
                      ? BoxDecoration(
                          color: _parseColor(phoneSettings['backgroundColor'] ?? '#000000'),
                          borderRadius: BorderRadius.circular(8), 
                        )
                      : null,
                  child: Text(
                    userPhoneNumber.length > 15 ? userPhoneNumber : userPhoneNumber,
                    style: TextStyle(
                      fontFamily: phoneSettings['font'] ?? 'Arial',
                      fontSize: (phoneSettings['fontSize'] ?? 18).toDouble() * (userPhoneNumber.length > 15 ? 0.6 : 1.0) * 0.65,
                      color: _parseColor(phoneSettings['color'] ?? '#ffffff'),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Business Name overlay
            if (userUsageType == 'Business' && businessNameSettings['enabled'] == true && userBusinessName.isNotEmpty)
              Positioned(
                left: ((businessNameSettings['x'] ?? 50) / 100 * frameSize['width']) - 20,
                top: (businessNameSettings['y'] ?? 20) / 100 * frameSize['height'],
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: businessNameSettings['hasBackground'] == true
                      ? BoxDecoration(
                          color: _parseColor(businessNameSettings['backgroundColor'] ?? '#000000'),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Text(
                    userBusinessName.length > 15 ? userBusinessName : userBusinessName,
                    style: TextStyle(
                      fontFamily: businessNameSettings['font'] ?? 'Arial',
                      fontSize: (businessNameSettings['fontSize'] ?? 14).toDouble() * (userBusinessName.length > 15 ? 0.6 : 1.0) * 0.65,
                      color: _parseColor(businessNameSettings['color'] ?? '#ffffff'),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Designation overlay
            if (userUsageType == 'Personal' && designationSettings['enabled'] == true && userDesignation.isNotEmpty)
              Positioned(
                left: ((designationSettings['x'] ?? 50) / 100 * frameSize['width']) - 20,
                top: (designationSettings['y'] ?? 25) / 100 * frameSize['height'],
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: designationSettings['hasBackground'] == true
                      ? BoxDecoration(
                          color: _parseColor(designationSettings['backgroundColor'] ?? '#000000'),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Text(
                    userDesignation.length > 15 ? userDesignation : userDesignation,
                    style: TextStyle(
                      fontFamily: designationSettings['font'] ?? 'Arial',
                      fontSize: (designationSettings['fontSize'] ?? 16).toDouble() * (userDesignation.length > 15 ? 0.6 : 1.0) * 0.65,
                      color: _parseColor(designationSettings['color'] ?? '#ffffff'),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Profile photo overlay
            if (profileSettings['enabled'] == true && userProfilePhotoUrl != null)
              Positioned(
                left: (profileSettings['x'] ?? 50) / 100 * frameSize['width'],
                top: (profileSettings['y'] ?? 70) / 100 * frameSize['height'],
                child: Container(
                  width: (profileSettings['size'] ?? 60).toDouble(),
                  height: (profileSettings['size'] ?? 60).toDouble(),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: userProfilePhotoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.person, color: Colors.grey),
                      ),
                      errorWidget: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.person, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

      // Capture overlay as image
      final Uint8List? overlayBytes = await _screenshotController.captureFromWidget(
        Material(
          color: Colors.transparent,
          child: overlayWidget,
        ),
        delay: Duration(milliseconds: 1000),
        pixelRatio: 2.0,
      );

      if (overlayBytes != null) {
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName = 'overlay_${DateTime.now().millisecondsSinceEpoch}.png';
        final String filePath = '${tempDir.path}/$fileName';
        final File overlayFile = File(filePath);
        await overlayFile.writeAsBytes(overlayBytes);
        print('Overlay image saved to: $filePath');
        return filePath;
      } else {
        print('Failed to capture overlay widget');
        return null;
      }
    } catch (e) {
      print('Error creating overlay: $e');
      return null;
    }
  }

  /// Clean up temporary files
  static Future<void> _cleanupTempFiles(List<String> filePaths) async {
    for (String path in filePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          print('Cleaned up: $path');
        }
      } catch (e) {
        print('Error cleaning up file $path: $e');
      }
    }
  }

  /// Parse hex color string to Color
  static Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    if (hexColor.length == 6) hexColor = 'FF$hexColor';
    return Color(int.parse('0x$hexColor'));
  }

  /// Create thumbnail with overlay (alternative to FFmpeg video processing)
  static Future<String?> createVideoThumbnailWithOverlay({
    required String videoUrl,
    required Map<String, dynamic> post,
    required String userUsageType,
    required String userName,
    String? userProfilePhotoUrl,
    required String userAddress,
    required String userPhoneNumber,
    required String userCity,
    required String userBusinessName,
    required String userDesignation,
  }) async {
    try {
      print('Creating thumbnail with overlay...');
      
      // Create overlay image
      final String? overlayImagePath = await _createSimpleOverlay(
        post: post,
        userUsageType: userUsageType,
        userName: userName,
        userProfilePhotoUrl: userProfilePhotoUrl,
        userAddress: userAddress,
        userPhoneNumber: userPhoneNumber,
        userCity: userCity,
        userBusinessName: userBusinessName,
        userDesignation: userDesignation,
      );
      if (overlayImagePath == null) return null;

      // Extract thumbnail from video using video_thumbnail package
      final String? thumbnailPath = await _extractVideoThumbnail(videoUrl);
      if (thumbnailPath == null) return null;

      // Combine thumbnail with overlay using image package
      final String? combinedImagePath = await _combineImages(thumbnailPath, overlayImagePath);

      // Clean up
      await _cleanupTempFiles([overlayImagePath, thumbnailPath]);

      return combinedImagePath;
    } catch (e) {
      print('Error creating thumbnail with overlay: $e');
      return null;
    }
  }

  /// Extract thumbnail from video using video_thumbnail package
  static Future<String?> _extractVideoThumbnail(String videoUrl) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = '${tempDir.path}/$fileName';

      // Use video_thumbnail package to extract thumbnail
      final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        timeMs: 1000, // Extract at 1 second
      );

      if (thumbnailPath != null) {
        print('Thumbnail extracted: $thumbnailPath');
        return thumbnailPath;
      } else {
        print('Failed to extract thumbnail');
        return null;
      }
    } catch (e) {
      print('Error extracting thumbnail: $e');
      return null;
    }
  }

  /// Combine two images using image package (alternative to FFmpeg)
  static Future<String?> _combineImages(String thumbnailPath, String overlayPath) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'combined_${DateTime.now().millisecondsSinceEpoch}.png';
      final String outputPath = '${tempDir.path}/$fileName';

      // Load images using image package
      final File thumbnailFile = File(thumbnailPath);
      final File overlayFile = File(overlayPath);
      
      if (!await thumbnailFile.exists() || !await overlayFile.exists()) {
        print('One or both image files do not exist');
        return null;
      }

      final Uint8List thumbnailBytes = await thumbnailFile.readAsBytes();
      final Uint8List overlayBytes = await overlayFile.readAsBytes();

      final img.Image? thumbnail = img.decodeImage(thumbnailBytes);
      final img.Image? overlay = img.decodeImage(overlayBytes);

      if (thumbnail == null || overlay == null) {
        print('Failed to decode images');
        return null;
      }

      // Resize overlay to match thumbnail dimensions if needed
      img.Image resizedOverlay = overlay;
      if (overlay.width != thumbnail.width || overlay.height != thumbnail.height) {
        resizedOverlay = img.copyResize(overlay, width: thumbnail.width, height: thumbnail.height);
      }

      // Composite overlay onto thumbnail with transparency
      final img.Image combined = img.compositeImage(thumbnail, resizedOverlay, dstX: 0, dstY: 0);

      // Save combined image
      final File outputFile = File(outputPath);
      await outputFile.writeAsBytes(img.encodePng(combined));

      print('Images combined: $outputPath');
      return outputPath;
    } catch (e) {
      print('Error combining images: $e');
      return null;
    }
  }
}