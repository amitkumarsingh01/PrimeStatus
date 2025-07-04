import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:screenshot/screenshot.dart';
import 'package:flutter/material.dart';

class VideoProcessingService {
  static final ScreenshotController _screenshotController = ScreenshotController();

  /// Simple video processing with overlays
  static Future<String?> processVideoWithOverlays({
    required String videoUrl,
    required Map<String, dynamic> post,
    required String userUsageType,
    required String userName,
    String? userProfilePhotoUrl,
    required String userAddress,
    required String userPhoneNumber,
    required String userCity,
  }) async {
    try {
      print('Starting video processing for: $videoUrl');
      
      // Step 1: Download video to local storage
      final String? localVideoPath = await _downloadVideo(videoUrl);
      if (localVideoPath == null) {
        print('Failed to download video');
        return null;
      }
      print('Video downloaded to: $localVideoPath');

      // Step 2: Create overlay image
      final String? overlayImagePath = await _createSimpleOverlay(
        post: post,
        userUsageType: userUsageType,
        userName: userName,
        userProfilePhotoUrl: userProfilePhotoUrl,
        userAddress: userAddress,
        userPhoneNumber: userPhoneNumber,
        userCity: userCity,
      );
      if (overlayImagePath == null) {
        print('Failed to create overlay');
        return null;
      }
      print('Overlay created at: $overlayImagePath');

      // Step 3: Process video with FFmpeg
      final String? processedVideoPath = await _processVideoWithFFmpeg(
        inputVideoPath: localVideoPath,
        overlayImagePath: overlayImagePath,
      );

      // Clean up temporary files
      await _cleanupTempFiles([localVideoPath, overlayImagePath]);

      if (processedVideoPath != null) {
        print('Video processed successfully: $processedVideoPath');
        return processedVideoPath;
      } else {
        print('FFmpeg processing failed');
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
  }) async {
    try {
      final textSettings = post['textSettings'] ?? {};
      final profileSettings = post['profileSettings'] ?? {};
      final addressSettings = post['addressSettings'] ?? {};
      final phoneSettings = post['phoneSettings'] ?? {};
      final frameSize = post['frameSize'] ?? {'width': 1080, 'height': 1920};

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
                    userName,
                    style: TextStyle(
                      fontFamily: textSettings['font'] ?? 'Arial',
                      fontSize: (textSettings['fontSize'] ?? 24).toDouble(),
                      color: _parseColor(textSettings['color'] ?? '#ffffff'),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Address overlay
            if (userUsageType == 'Business' && addressSettings['enabled'] == true && userAddress.isNotEmpty)
              Positioned(
                left: (addressSettings['x'] ?? 50) / 100 * frameSize['width'],
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
                    userAddress,
                    style: TextStyle(
                      fontFamily: addressSettings['font'] ?? 'Arial',
                      fontSize: (addressSettings['fontSize'] ?? 18).toDouble(),
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
                    userPhoneNumber,
                    style: TextStyle(
                      fontFamily: phoneSettings['font'] ?? 'Arial',
                      fontSize: (phoneSettings['fontSize'] ?? 18).toDouble(),
                      color: _parseColor(phoneSettings['color'] ?? '#ffffff'),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Profile photo overlay
            if (profileSettings['enabled'] == true && userProfilePhotoUrl != null && userProfilePhotoUrl!.isNotEmpty)
              Positioned(
                left: (profileSettings['x'] ?? 20) / 100 * frameSize['width'] - (profileSettings['size'] ?? 80) / 2,
                top: (profileSettings['y'] ?? 20) / 100 * frameSize['height'] - (profileSettings['size'] ?? 80) / 2,
                child: Container(
                  width: (profileSettings['size'] ?? 80).toDouble(),
                  height: (profileSettings['size'] ?? 80).toDouble(),
                  decoration: BoxDecoration(
                    color: profileSettings['hasBackground'] == true
                        ? Colors.white.withOpacity(0.9)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      profileSettings['shape'] == 'circle'
                          ? (profileSettings['size'] ?? 80) / 2
                          : 8,
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      profileSettings['shape'] == 'circle'
                          ? (profileSettings['size'] ?? 80) / 2
                          : 8,
                    ),
                    child: Image.network(
                      userProfilePhotoUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
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

  /// Process video with FFmpeg
  static Future<String?> _processVideoWithFFmpeg({
    required String inputVideoPath,
    required String overlayImagePath,
  }) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String outputFileName = 'processed_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String outputPath = '${tempDir.path}/$outputFileName';

      print('Processing video with FFmpeg...');
      print('Input: $inputVideoPath');
      print('Overlay: $overlayImagePath');
      print('Output: $outputPath');

      // Simple FFmpeg command to overlay image on video
      final String ffmpegCommand = '-i "$inputVideoPath" -i "$overlayImagePath" -filter_complex "[1:v]format=rgba,colorchannelmixer=aa=0.8[overlay];[0:v][overlay]overlay=0:0" -c:a copy "$outputPath"';

      print('FFmpeg command: $ffmpegCommand');

      final session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();
      final logs = await session.getLogsAsString();

      print('FFmpeg logs: $logs');

      if (ReturnCode.isSuccess(returnCode)) {
        print('FFmpeg processing successful');
        return outputPath;
      } else {
        print('FFmpeg processing failed with return code: $returnCode');
        return null;
      }
    } catch (e) {
      print('Error in FFmpeg processing: $e');
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

  /// Alternative: Create thumbnail with overlay (faster option)
  static Future<String?> createVideoThumbnailWithOverlay({
    required String videoUrl,
    required Map<String, dynamic> post,
    required String userUsageType,
    required String userName,
    String? userProfilePhotoUrl,
    required String userAddress,
    required String userPhoneNumber,
    required String userCity,
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
      );
      if (overlayImagePath == null) return null;

      // Extract thumbnail from video
      final String? thumbnailPath = await _extractVideoThumbnail(videoUrl);
      if (thumbnailPath == null) return null;

      // Combine thumbnail with overlay
      final String? combinedImagePath = await _combineImages(thumbnailPath, overlayImagePath);

      // Clean up
      await _cleanupTempFiles([overlayImagePath, thumbnailPath]);

      return combinedImagePath;
    } catch (e) {
      print('Error creating thumbnail with overlay: $e');
      return null;
    }
  }

  /// Extract thumbnail from video
  static Future<String?> _extractVideoThumbnail(String videoUrl) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = '${tempDir.path}/$fileName';

      // Use FFmpeg to extract thumbnail
      final String ffmpegCommand = '-i "$videoUrl" -ss 00:00:01 -vframes 1 -q:v 2 "$filePath"';
      
      final session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('Thumbnail extracted: $filePath');
        return filePath;
      } else {
        print('Failed to extract thumbnail');
        return null;
      }
    } catch (e) {
      print('Error extracting thumbnail: $e');
      return null;
    }
  }

  /// Combine two images
  static Future<String?> _combineImages(String thumbnailPath, String overlayPath) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'combined_${DateTime.now().millisecondsSinceEpoch}.png';
      final String outputPath = '${tempDir.path}/$fileName';

      // Use FFmpeg to overlay images
      final String ffmpegCommand = '-i "$thumbnailPath" -i "$overlayPath" -filter_complex "[1:v]format=rgba,colorchannelmixer=aa=0.8[overlay];[0:v][overlay]overlay=0:0" "$outputPath"';
      
      final session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('Images combined: $outputPath');
        return outputPath;
      } else {
        print('Failed to combine images');
        return null;
      }
    } catch (e) {
      print('Error combining images: $e');
      return null;
    }
  }
} 