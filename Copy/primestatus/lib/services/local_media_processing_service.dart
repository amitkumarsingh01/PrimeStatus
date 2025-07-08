import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:screenshot/screenshot.dart';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LocalMediaProcessingService {
  static final ScreenshotController _screenshotController = ScreenshotController();

  /// Process image with overlays using FFmpeg
  static Future<String?> processImageWithOverlays({
    required String imageUrl,
    required Map<String, dynamic> post,
    required String userUsageType,
    required String userName,
    String? userProfilePhotoUrl,
    required String userAddress,
    required String userPhoneNumber,
    required String userCity,
  }) async {
    try {
      print('=== PROCESSING IMAGE WITH OVERLAYS ===');
      print('Image URL: $imageUrl');

      // Download the original image
      final String? inputImagePath = await _downloadImage(imageUrl);
      if (inputImagePath == null) {
        print('Failed to download input image');
        return null;
      }

      // Create overlay image
      final String? overlayImagePath = await _createOverlayImage(
        post: post,
        userUsageType: userUsageType,
        userName: userName,
        userProfilePhotoUrl: userProfilePhotoUrl,
        userAddress: userAddress,
        userPhoneNumber: userPhoneNumber,
        userCity: userCity,
      );
      if (overlayImagePath == null) {
        print('Failed to create overlay image');
        return null;
      }

      // Combine image with overlay using FFmpeg
      final String? outputPath = await _combineImageWithOverlay(
        inputImagePath: inputImagePath,
        overlayImagePath: overlayImagePath,
      );

      // Clean up temporary files
      await _cleanupTempFiles([inputImagePath, overlayImagePath]);

      return outputPath;
    } catch (e) {
      print('Error processing image with overlays: $e');
      return null;
    }
  }

  /// Process video with overlays using FFmpeg
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
      print('=== PROCESSING VIDEO WITH OVERLAYS ===');
      print('Video URL: $videoUrl');

      // Download the original video
      final String? inputVideoPath = await _downloadVideo(videoUrl);
      if (inputVideoPath == null) {
        print('Failed to download input video');
        return null;
      }

      // Create overlay image
      final String? overlayImagePath = await _createOverlayImage(
        post: post,
        userUsageType: userUsageType,
        userName: userName,
        userProfilePhotoUrl: userProfilePhotoUrl,
        userAddress: userAddress,
        userPhoneNumber: userPhoneNumber,
        userCity: userCity,
        isForVideo: true,
      );
      if (overlayImagePath == null) {
        print('Failed to create overlay image');
        return null;
      }

      // Combine video with overlay using FFmpeg
      final String? outputPath = await _combineVideoWithOverlay(
        inputVideoPath: inputVideoPath,
        overlayImagePath: overlayImagePath,
      );

      // Clean up temporary files
      await _cleanupTempFiles([inputVideoPath, overlayImagePath]);

      return outputPath;
    } catch (e) {
      print('Error processing video with overlays: $e');
      return null;
    }
  }

  /// Create thumbnail with overlay for videos
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
      print('=== CREATING VIDEO THUMBNAIL WITH OVERLAY ===');
      print('Video URL: $videoUrl');

      // Download the original video
      final String? inputVideoPath = await _downloadVideo(videoUrl);
      if (inputVideoPath == null) {
        print('Failed to download input video');
        return null;
      }

      // Extract thumbnail using FFmpeg
      final String? thumbnailPath = await _extractVideoThumbnail(inputVideoPath);
      if (thumbnailPath == null) {
        print('Failed to extract thumbnail');
        return null;
      }

      // Create overlay image
      final String? overlayImagePath = await _createOverlayImage(
        post: post,
        userUsageType: userUsageType,
        userName: userName,
        userProfilePhotoUrl: userProfilePhotoUrl,
        userAddress: userAddress,
        userPhoneNumber: userPhoneNumber,
        userCity: userCity,
        isForVideo: true,
      );
      if (overlayImagePath == null) {
        print('Failed to create overlay image');
        return null;
      }

      // Combine thumbnail with overlay using FFmpeg
      final String? outputPath = await _combineImageWithOverlay(
        inputImagePath: thumbnailPath,
        overlayImagePath: overlayImagePath,
      );

      // Clean up temporary files
      await _cleanupTempFiles([inputVideoPath, thumbnailPath, overlayImagePath]);

      return outputPath;
    } catch (e) {
      print('Error creating video thumbnail with overlay: $e');
      return null;
    }
  }

  /// Download image from URL or base64
  static Future<String?> _downloadImage(String imageUrl) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'input_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = '${tempDir.path}/$fileName';

      if (imageUrl.startsWith('data:image')) {
        // Handle base64 image
        final base64Str = imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        final File imageFile = File(filePath);
        await imageFile.writeAsBytes(bytes);
        print('Base64 image saved to: $filePath');
        return filePath;
      } else {
        // Handle network image
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final File imageFile = File(filePath);
          await imageFile.writeAsBytes(response.bodyBytes);
          print('Network image saved to: $filePath');
          return filePath;
        } else {
          print('Failed to download image: ${response.statusCode}');
          return null;
        }
      }
    } catch (e) {
      print('Error downloading image: $e');
      return null;
    }
  }

  /// Download video from URL or base64
  static Future<String?> _downloadVideo(String videoUrl) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'input_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String filePath = '${tempDir.path}/$fileName';

      if (videoUrl.startsWith('data:video')) {
        // Handle base64 video
        final base64Str = videoUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        final File videoFile = File(filePath);
        await videoFile.writeAsBytes(bytes);
        print('Base64 video saved to: $filePath');
        return filePath;
      } else {
        // Handle network video
        final response = await http.get(Uri.parse(videoUrl));
        if (response.statusCode == 200) {
          final File videoFile = File(filePath);
          await videoFile.writeAsBytes(response.bodyBytes);
          print('Network video saved to: $filePath');
          return filePath;
        } else {
          print('Failed to download video: ${response.statusCode}');
          return null;
        }
      }
    } catch (e) {
      print('Error downloading video: $e');
      return null;
    }
  }

  /// Create overlay image with user information
  static Future<String?> _createOverlayImage({
    required Map<String, dynamic> post,
    required String userUsageType,
    required String userName,
    String? userProfilePhotoUrl,
    required String userAddress,
    required String userPhoneNumber,
    required String userCity,
    bool isForVideo = false,
  }) async {
    try {
      final textSettings = post['textSettings'] ?? {};
      final profileSettings = post['profileSettings'] ?? {};
      final addressSettings = post['addressSettings'] ?? {};
      final phoneSettings = post['phoneSettings'] ?? {};
      final frameSize = post['frameSize'] ?? {'width': 1080, 'height': 1920};

      // Create overlay widget with proper positioning (same as AdminPostFullScreenCard)
      final Widget overlayWidget = LayoutBuilder(
        builder: (context, constraints) {
          final double width = frameSize['width'].toDouble();
          final double height = frameSize['height'].toDouble();
          
          // Calculate positions exactly like AdminPostFullScreenCard
          final double textX = (textSettings['x'] ?? 50) / 100 * width;
          final double textY = (textSettings['y'] ?? 90) / 100 * height;
          final double profileX = (profileSettings['x'] ?? 20) / 100 * width;
          final double profileY = (profileSettings['y'] ?? 20) / 100 * height;
          final double profileSize = (profileSettings['size'] ?? 80).toDouble();
          final double addressX = (addressSettings['x'] ?? 50) / 100 * width;
          final double addressY = (addressSettings['y'] ?? 80) / 100 * height;
          final double phoneX = (phoneSettings['x'] ?? 50) / 100 * width;
          final double phoneY = (phoneSettings['y'] ?? 85) / 100 * height;

          return Container(
            width: width,
            height: height,
            color: Colors.transparent,
            child: Stack(
              children: [
                // Text overlay
                if (textSettings.isNotEmpty)
                  Positioned(
                    left: textX,
                    top: textY,
                    child: Transform.translate(
                      offset: Offset(-0.5 * (textSettings['fontSize'] ?? 24) * (userName.length / 2), -20),
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
                  ),
                // Address overlay
                if (userUsageType == 'Business' && addressSettings['enabled'] == true && userAddress.isNotEmpty)
                  Positioned(
                    left: addressX,
                    top: addressY,
                    child: Transform.translate(
                      offset: Offset(-0.5 * (addressSettings['fontSize'] ?? 18) * (userAddress.length / 2), -20),
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
                  ),
                // Phone overlay
                if (userUsageType == 'Business' && phoneSettings['enabled'] == true && userPhoneNumber.isNotEmpty)
                  Positioned(
                    left: phoneX,
                    top: phoneY,
                    child: Transform.translate(
                      offset: Offset(-0.5 * (phoneSettings['fontSize'] ?? 18) * (userPhoneNumber.length / 2), -20),
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
                  ),
                // Profile photo overlay
                if (profileSettings['enabled'] == true && userProfilePhotoUrl != null && userProfilePhotoUrl!.isNotEmpty)
                  Positioned(
                    left: profileX - profileSize / 2,
                    top: profileY - profileSize / 2,
                    child: Container(
                      width: profileSize,
                      height: profileSize,
                      decoration: BoxDecoration(
                        color: profileSettings['hasBackground'] == true
                            ? Colors.white.withOpacity(0.9)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          profileSettings['shape'] == 'circle'
                              ? profileSize / 2
                              : 8,
                        ),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          profileSettings['shape'] == 'circle'
                              ? profileSize / 2
                              : 8,
                        ),
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
        },
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

  /// Extract thumbnail from video using FFmpeg
  static Future<String?> _extractVideoThumbnail(String videoPath) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String outputPath = '${tempDir.path}/$fileName';

      // FFmpeg command to extract thumbnail at 1 second
      final String ffmpegCommand = '-i "$videoPath" -ss 00:00:01 -vframes 1 -q:v 2 "$outputPath"';

      print('Executing FFmpeg command: $ffmpegCommand');

      final Session session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();

      if (returnCode?.isValueSuccess() == true) {
        print('Thumbnail extracted successfully: $outputPath');
        return outputPath;
      } else {
        final String logs = await session.getLogsAsString();
        print('FFmpeg failed with return code: $returnCode');
        print('FFmpeg logs: $logs');
        return null;
      }
    } catch (e) {
      print('Error extracting thumbnail: $e');
      return null;
    }
  }

  /// Combine image with overlay using FFmpeg
  static Future<String?> _combineImageWithOverlay({
    required String inputImagePath,
    required String overlayImagePath,
  }) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'combined_${DateTime.now().millisecondsSinceEpoch}.png';
      final String outputPath = '${tempDir.path}/$fileName';

      // FFmpeg command to overlay image on top of input image
      final String ffmpegCommand = '-i "$inputImagePath" -i "$overlayImagePath" -filter_complex "[0][1]overlay=0:0" "$outputPath"';

      print('Executing FFmpeg command: $ffmpegCommand');

      final Session session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();

      if (returnCode?.isValueSuccess() == true) {
        print('Images combined successfully: $outputPath');
        return outputPath;
      } else {
        final String logs = await session.getLogsAsString();
        print('FFmpeg failed with return code: $returnCode');
        print('FFmpeg logs: $logs');
        return null;
      }
    } catch (e) {
      print('Error combining images: $e');
      return null;
    }
  }

  /// Combine video with overlay using FFmpeg
  static Future<String?> _combineVideoWithOverlay({
    required String inputVideoPath,
    required String overlayImagePath,
  }) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'video_with_overlay_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String outputPath = '${tempDir.path}/$fileName';

      // FFmpeg command to overlay image on video with proper scaling and positioning
      // This command ensures the overlay image is scaled to match video dimensions and covers the entire video
      final String ffmpegCommand = '-i "$inputVideoPath" -i "$overlayImagePath" -filter_complex "[1:v]scale=iw:ih[overlay];[0:v][overlay]overlay=0:0" -c:a copy -preset ultrafast "$outputPath"';

      print('Executing FFmpeg command: $ffmpegCommand');

      final Session session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();

      if (returnCode?.isValueSuccess() == true) {
        print('Video with overlay created successfully: $outputPath');
        return outputPath;
      } else {
        final String logs = await session.getLogsAsString();
        print('FFmpeg failed with return code: $returnCode');
        print('FFmpeg logs: $logs');
        
        // Try alternative command if first one fails
        print('Trying alternative FFmpeg command...');
        final String alternativeCommand = '-i "$inputVideoPath" -i "$overlayImagePath" -filter_complex "[1:v]scale=iw:ih[overlay];[0:v][overlay]overlay=0:0" -c:a copy -preset ultrafast "$outputPath"';
        
        final Session altSession = await FFmpegKit.execute(alternativeCommand);
        final altReturnCode = await altSession.getReturnCode();
        
        if (altReturnCode?.isValueSuccess() == true) {
          print('Video with overlay created successfully (alternative method): $outputPath');
          return outputPath;
        } else {
          final String altLogs = await altSession.getLogsAsString();
          print('Alternative FFmpeg also failed with return code: $altReturnCode');
          print('Alternative FFmpeg logs: $altLogs');
          
          // Try third fallback command (simplest possible)
          print('Trying third fallback FFmpeg command...');
          final String fallbackCommand = '-i "$inputVideoPath" -i "$overlayImagePath" -filter_complex "overlay=0:0" -c:a copy "$outputPath"';
          
          final Session fallbackSession = await FFmpegKit.execute(fallbackCommand);
          final fallbackReturnCode = await fallbackSession.getReturnCode();
          
          if (fallbackReturnCode?.isValueSuccess() == true) {
            print('Video with overlay created successfully (fallback method): $outputPath');
            return outputPath;
          } else {
            final String fallbackLogs = await fallbackSession.getLogsAsString();
            print('Fallback FFmpeg also failed with return code: $fallbackReturnCode');
            print('Fallback FFmpeg logs: $fallbackLogs');
            return null;
          }
        }
      }
    } catch (e) {
      print('Error combining video with overlay: $e');
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
} 