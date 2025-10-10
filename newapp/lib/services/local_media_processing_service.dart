import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
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
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'dart:ui';

// List of supported Kannada fonts
const List<String> kannadaFonts = [
  'AnekKannada',
  'BalooTamma2',
  'NotoSansKannada',
];

String? getFontFamily(String? font) {
  if (font != null && kannadaFonts.contains(font)) {
    return font;
  }
  return null; // fallback to default
}

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
    required String userBusinessName,
    required String userDesignation,
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
        userBusinessName: userBusinessName,
        userDesignation: userDesignation,
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
    required String userBusinessName,
    required String userDesignation,
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

      // Get video dimensions
      final Size? videoSize = await getVideoDimensions(inputVideoPath);
      if (videoSize == null) {
        print('Failed to get video dimensions');
        return null;
      }
      final frameSize = {'width': videoSize.width.toInt(), 'height': videoSize.height.toInt()};

      // Create overlay image with correct frameSize
      final String? overlayImagePath = await _createOverlayImage(
        post: {...post, 'frameSize': frameSize}, // override frameSize
        userUsageType: userUsageType,
        userName: userName,
        userProfilePhotoUrl: userProfilePhotoUrl,
        userAddress: userAddress,
        userPhoneNumber: userPhoneNumber,
        userCity: userCity,
        userBusinessName: userBusinessName,
        userDesignation: userDesignation,
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
    required String userBusinessName,
    required String userDesignation,
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
        userBusinessName: userBusinessName,
        userDesignation: userDesignation,
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
    required String userBusinessName,
    required String userDesignation,
    bool isForVideo = false,
  }) async {
    try {
      final textSettings = post['textSettings'] ?? {};
      final profileSettings = post['profileSettings'] ?? {};
      final addressSettings = post['addressSettings'] ?? {};
      final phoneSettings = post['phoneSettings'] ?? {};
      final businessNameSettings = post['businessNameSettings'] ?? {};
      final designationSettings = post['designationSettings'] ?? {};
      final frameSize = post['frameSize'] ?? {'width': 1080, 'height': 1920};

      // Debug prints for overlay data
      print('--- Overlay Debug Info ---');
      print('userName: $userName');
      print('textSettings: $textSettings');
      print('userUsageType: $userUsageType');
      print('userAddress: $userAddress');
      print('addressSettings: $addressSettings');
      print('userPhoneNumber: $userPhoneNumber');
      print('phoneSettings: $phoneSettings');
      print('userBusinessName: $userBusinessName');
      print('businessNameSettings: $businessNameSettings');
      print('userDesignation: $userDesignation');
      print('designationSettings: $designationSettings');
      print('userProfilePhotoUrl: $userProfilePhotoUrl');
      print('frameSize: $frameSize');
      print('--------------------------');

      // Create overlay widget with proper positioning (same as AdminPostFullScreenCard)
      final Widget overlayWidget = LayoutBuilder(
        builder: (context, constraints) {
          
          final double width = frameSize['width'].toDouble();
          final double height = frameSize['height'].toDouble();

          // Use different formulas for 1080x1080 vs others
          bool isSquare = width == 1080 && height == 1080;
          // 1080x1080: use original, else use alternate
           final double textXBase = isSquare
               ? (((textSettings['x'] ?? 50) / 100 * width) / 1.96) + (isForVideo ? 28 : 8)
               : ((((textSettings['x'] ?? 50) / 100 * width) + 50) / 1.96) + (isForVideo ? 10 : 0);
          final double textX = userName.length > 15 ? textXBase + 6 : textXBase;
          final double textY = isSquare
              ? (((textSettings['y'] ?? 90) / 100 * height) / 1.96) - 10
              : (((textSettings['y'] ?? 90) / 100 * height) / 1.96) - 10;
          final double profileX = isSquare
              ? (((profileSettings['x'] ?? 20) / 100 * width) / 1.96) + 22
              : (((profileSettings['x'] ?? 20) / 100 * width) / 1.96) + 15;
          final double profileY = isSquare
              ? (((profileSettings['y'] ?? 20) / 100 * height) / 1.96) + 22
              : (((profileSettings['y'] ?? 20) / 100 * height) / 1.96) - 0;
           final double profileSize = ((profileSettings['size'] ?? 80).toDouble()) * (isForVideo ? 0.8 : 1.0);
          final double addressXBase = isSquare
              ? (((addressSettings['x'] ?? 50) / 100 * width) / 1.96) - 34
              : (((addressSettings['x'] ?? 50) / 100 * width) / 1.96) - 30;
          final double addressX = userAddress.length > 15 ? addressXBase + 49 : addressXBase;
          final double addressY = isSquare
              ? (((addressSettings['y'] ?? 80) / 100 * height) / 1.96) - 11
              : (((addressSettings['y'] ?? 80) / 100 * height) / 1.96) - 12;
          final double phoneX = isSquare
              ? (((phoneSettings['x'] ?? 50) / 100 * width) / 1.96) + 5
              : (((phoneSettings['x'] ?? 50) / 100 * width) / 1.96);
          final double phoneY = isSquare
              ? ((((phoneSettings['y'] ?? 85) / 100 * height) / 1.96)) - 8
              : ((((phoneSettings['y'] ?? 85) / 100 * height) / 1.96)) - 13;
          final double businessNameXBase = isSquare
              ? (((businessNameSettings['x'] ?? 50) / 100 * width) / 1.96) - 12
              : (((businessNameSettings['x'] ?? 50) / 100 * width) / 1.96) - 20;
          final double businessNameX = userBusinessName.length > 15 ? businessNameXBase + 6 : businessNameXBase;
          final double businessNameY = isSquare
              ? (((businessNameSettings['y'] ?? 20) / 100 * height) / 1.96) - 10
              : (((businessNameSettings['y'] ?? 20) / 100 * height) / 1.96) - 10;
           final double designationXBase = isSquare
               ? (((designationSettings['x'] ?? 50) / 100 * width) / 1.96) + (isForVideo ? 28 : -12)
               : ((((designationSettings['x'] ?? 50) / 100 * width) + 130) / 1.96) + (isForVideo ? 0 : -20);
          final double designationX = userDesignation.length > 15 ? designationXBase + 6 : designationXBase;
          final double designationY = isSquare
              ? (((designationSettings['y'] ?? 25) / 100 * height) / 1.96) - 10 
              : (((designationSettings['y'] ?? 25) / 100 * height) / 1.96) - 10;
          
          // For video overlays, move the profile image 10px left and up
          final double imageOffsetX = isForVideo ? 6.0 : 7.0;
          final double imageOffsetY = isForVideo ? 4.0 : 7.0;


          return SizedBox(
            width: width,
            height: height,
            child: Container(
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
                        offset: Offset(-0.5 * (((textSettings['fontSize'] ?? 24) * 1.35) * 0.98) * (userName.length / 2), -20),
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
                              fontFamily: getFontFamily(textSettings['font']),
                              fontSize: ((textSettings['fontSize'] ?? 24).toDouble() * 1.35) * (userName.length > 15 ? 0.9 : 1.0) * (isForVideo ? 0.65 : 1.0),
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
                        offset: Offset(-0.5 * (((addressSettings['fontSize'] ?? 18) * 1.35)) * (userAddress.length / 2), -20),
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
                              fontFamily: getFontFamily(addressSettings['font']),
                              fontSize: ((addressSettings['fontSize'] ?? 18).toDouble() * 1.35) * (userAddress.length > 15 ? 0.9 : 1.0) * (isForVideo ? 0.65 : 1.0),
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
                        offset: Offset(-0.5 * (((phoneSettings['fontSize'] ?? 18) * 1.35) * 0.98) * (userPhoneNumber.length / 2), -20),
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
                              fontFamily: getFontFamily(phoneSettings['font']),
                              fontSize: ((phoneSettings['fontSize'] ?? 18).toDouble() * 1.35) * (userPhoneNumber.length > 15 ? 0.9 : 1.0) * (isForVideo ? 0.65 : 1.0),
                              color: _parseColor(phoneSettings['color'] ?? '#ffffff'),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Business Name overlay
                  if (userUsageType == 'Business' && businessNameSettings['enabled'] == true && userBusinessName.isNotEmpty)
                    Positioned(
                      left: businessNameX,
                      top: businessNameY,
                      child: Transform.translate(
                        offset: Offset(-0.5 * (((businessNameSettings['fontSize'] ?? 14) * 1.35) * 0.98) * (userBusinessName.length / 2), -20),
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
                              fontFamily: getFontFamily(businessNameSettings['font']),
                              fontSize: ((businessNameSettings['fontSize'] ?? 14).toDouble() * 1.35) * (userBusinessName.length > 15 ? 0.9 : 1.0) * (isForVideo ? 0.65 : 1.0),
                              color: _parseColor(businessNameSettings['color'] ?? '#ffffff'),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Designation overlay
                  if (userUsageType == 'Personal' && designationSettings['enabled'] == true && userDesignation.isNotEmpty)
                    Positioned(
                      left: designationX,
                      top: designationY,
                      child: Transform.translate(
                        offset: Offset(-0.5 * (((designationSettings['fontSize'] ?? 16) * 1.35) * 0.98) * (userDesignation.length / 2), -20),
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
                              fontFamily: getFontFamily(designationSettings['font']),
                              fontSize: ((designationSettings['fontSize'] ?? 16).toDouble() * 1.35) * (userDesignation.length > 15 ? 0.9 : 1.0) * (isForVideo ? 0.65 : 1.0),
                              color: _parseColor(designationSettings['color'] ?? '#ffffff'),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Profile photo overlay
                  if (profileSettings['enabled'] == true && userProfilePhotoUrl != null && userProfilePhotoUrl!.isNotEmpty)
                    Positioned(
                      left: profileX - (profileSize * 1.1) / 2 - 48 + imageOffsetX,
                      top: profileY - (profileSize * 1.1) / 2 - 47 + imageOffsetY,
                      child: Container(
                        width: profileSize * 1.37,
                        height: profileSize * 1.37,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            profileSettings['shape'] == 'circle'
                                ? (profileSize * 1.37) / 2
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
            ),
          );
        },
      );

      // Capture overlay as image
      // final Uint8List? overlayBytes = await _screenshotController.captureFromWidget(
      //   Material(
      //     color: Colors.transparent,
      //     child: overlayWidget,
      //   ),
      //   delay: Duration(milliseconds: 1000),
      //   pixelRatio: 2.0,
      // );

      // Capture overlay as image with forced 1080 width
      // final double targetWidth = 2160.0;
      // final double currentWidth = frameSize['width'].toDouble();
      // final double scaleFactor = targetWidth / currentWidth;

      // final Uint8List? overlayBytes = await _screenshotController.captureFromWidget(
      //   Material(
      //     color: Colors.transparent,
      //     child: overlayWidget,
      //   ),
      //   delay: Duration(milliseconds: 1000),
      //   pixelRatio: scaleFactor,
      // );

      // Capture overlay as image with forced dimensions
      final Uint8List? overlayBytes = await _screenshotController.captureFromWidget(
        Material(
          color: Colors.transparent,
          child: overlayWidget,
        ),
        delay: Duration(milliseconds: 1000),
        pixelRatio: 2.0, // Use 1.0 to capture at exact widget size
        targetSize: Size(frameSize['width'].toDouble(), frameSize['height'].toDouble()),
      );

      if (overlayBytes != null) {
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName = 'overlay_${DateTime.now().millisecondsSinceEpoch}.png';
        final String filePath = '${tempDir.path}/$fileName';
        final File overlayFile = File(filePath);
        await overlayFile.writeAsBytes(overlayBytes);
        print('Overlay image saved to: $filePath');
        // Debug: print actual overlay PNG size
        try {
          final img.Image? overlayImg = img.decodeImage(overlayBytes);
          if (overlayImg != null) {
            print('Actual overlay PNG size: \\${overlayImg.width}x\\${overlayImg.height}');
          } else {
            print('Could not decode overlay PNG for size check');
          }
        } catch (e) {
          print('Error decoding overlay PNG for size check: $e');
        }
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

  static Future<Size?> getVideoDimensions(String videoPath) async {
    final session = await FFprobeKit.getMediaInformation(videoPath);
    final info = session.getMediaInformation();
    if (info == null) return null;
    final streams = info.getStreams();
    if (streams == null || streams.isEmpty) return null;
    final videoStream = streams.firstWhere((s) => s.getType() == 'video', orElse: () => null as dynamic);
    if (videoStream == null) return null;
    final width = videoStream.getWidth();
    final height = videoStream.getHeight();
    if (width != null && height != null) {
      return Size(width.toDouble(), height.toDouble());
    }
    return null;
  }
} 