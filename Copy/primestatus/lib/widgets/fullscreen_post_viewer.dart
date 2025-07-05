import 'package:flutter/material.dart';
import 'admin_post_feed_widget.dart';
import '../screens/onboarding/subscription_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' show launchUrl, canLaunchUrl, LaunchMode;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/background_removal_service.dart';
import 'package:screenshot/screenshot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';
import '../services/video_processing_service.dart';

// Global video controller manager for fullscreen
class FullscreenVideoControllerManager {
  static final FullscreenVideoControllerManager _instance = FullscreenVideoControllerManager._internal();
  factory FullscreenVideoControllerManager() => _instance;
  FullscreenVideoControllerManager._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  VideoPlayerController? _currentController;

  void registerController(String key, VideoPlayerController controller) {
    _controllers[key] = controller;
  }

  void unregisterController(String key) {
    _controllers.remove(key);
  }

  void setCurrentController(String key) {
    // Pause all other controllers
    for (var entry in _controllers.entries) {
      if (entry.key != key && entry.value.value.isInitialized && entry.value.value.isPlaying) {
        entry.value.pause();
      }
    }
    
    // Set current controller
    _currentController = _controllers[key];
  }

  void pauseAllControllers() {
    for (var controller in _controllers.values) {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  void disposeAllControllers() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _currentController = null;
  }
}

class FullscreenPostViewer extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final int initialIndex;
  final String userUsageType;
  final String userName;
  final String? userProfilePhotoUrl;
  final String userAddress;
  final String userPhoneNumber;
  final String userCity;

  const FullscreenPostViewer({
    Key? key,
    required this.posts,
    required this.initialIndex,
    required this.userUsageType,
    required this.userName,
    this.userProfilePhotoUrl,
    required this.userAddress,
    required this.userPhoneNumber,
    required this.userCity,
  }) : super(key: key);

  @override
  State<FullscreenPostViewer> createState() => _FullscreenPostViewerState();
}

class _FullscreenPostViewerState extends State<FullscreenPostViewer> {
  late PageController _pageController;
  final ScreenshotController _screenshotController = ScreenshotController();
  final UserService _userService = UserService();
  final BackgroundRemovalService _bgRemovalService = BackgroundRemovalService();
  bool _isProcessingShare = false;
  bool _isProcessingDownload = false;

  List<Map<String, dynamic>> _userProfilePhotos = [];
  String? _activeProfilePhotoUrl;
  bool _isLoadingProfilePhotos = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _activeProfilePhotoUrl = widget.userProfilePhotoUrl;
    _fetchUserProfilePhotos();
    
    // Add page change listener to pause videos when switching posts
    _pageController.addListener(() {
      if (_pageController.page != null) {
        // Pause all videos when page changes
        FullscreenVideoControllerManager().pauseAllControllers();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Clean up all video controllers when leaving fullscreen
    FullscreenVideoControllerManager().disposeAllControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Resume feed videos when going back
        VideoControllerManager().setFullscreenMode(false);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.posts.length,
            onPageChanged: (index) {
              // Pause all videos when switching posts
              FullscreenVideoControllerManager().pauseAllControllers();
            },
            itemBuilder: (context, index) {
              final post = widget.posts[index];
              return Center(
                child: SingleChildScrollView(
                  child: Material(
                    color: Colors.transparent,
                    child: AdminPostFullScreenCard(
                      post: post,
                      userUsageType: widget.userUsageType,
                      userName: widget.userName,
                      userProfilePhotoUrl: widget.userProfilePhotoUrl,
                      userAddress: widget.userAddress,
                      userPhoneNumber: widget.userPhoneNumber,
                      userCity: widget.userCity,
                      onShare: () => _showShareOptions(post),
                      onDownload: () => _downloadImage(post),
                      onEdit: () => _showProfilePhotoDialog(),
                    ),
                  ),
                ),
              );
            },
          ),
          // Back button
          Positioned(
            top: 40,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: IconButton(
                onPressed: () {
                  // Resume feed videos when going back
                  VideoControllerManager().setFullscreenMode(false);
                  Navigator.pop(context);
                },
                icon: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: EdgeInsets.all(12),
                ),
              ),
            ),
          ),
          // Loading overlay for processing
          if (_isProcessingShare || _isProcessingDownload)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        _isProcessingShare ? 'Processing post for sharing...' : 'Processing post for download...',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please wait while we process your image',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  // Share functionality
  void _showShareOptions(Map<String, dynamic> post) {
    final String imageUrl = post['mainImage'] ?? post['imageUrl'] ?? '';
    
    // Check if it's a video
    if (_isVideoUrl(imageUrl) || imageUrl.startsWith('data:video')) {
      _shareVideoWithOverlays(imageUrl, post);
    } else {
      _shareToWhatsApp(imageUrl, post);
    }
  }

  // Video sharing with overlays
  Future<void> _shareVideoWithOverlays(String videoUrl, Map<String, dynamic> post) async {
    setState(() {
      _isProcessingShare = true;
    });

    try {
      print('Starting video share process for: $videoUrl');
      
      // Show processing options dialog
      final String? processingMethod = await _showVideoProcessingOptions();
      if (processingMethod == null) {
        setState(() {
          _isProcessingShare = false;
        });
        return;
      }

      String? processedFilePath;
      
      if (processingMethod == 'full_video') {
        print('Processing full video with overlays...');
        // Process full video with overlays
        processedFilePath = await VideoProcessingService.processVideoWithOverlays(
          videoUrl: videoUrl,
          post: post,
          userUsageType: widget.userUsageType,
          userName: widget.userName,
          userProfilePhotoUrl: widget.userProfilePhotoUrl,
          userAddress: widget.userAddress,
          userPhoneNumber: widget.userPhoneNumber,
          userCity: widget.userCity,
        );
      } else {
        print('Creating thumbnail with overlay...');
        // Create thumbnail with overlay
        processedFilePath = await VideoProcessingService.createVideoThumbnailWithOverlay(
          videoUrl: videoUrl,
          post: post,
          userUsageType: widget.userUsageType,
          userName: widget.userName,
          userProfilePhotoUrl: widget.userProfilePhotoUrl,
          userAddress: widget.userAddress,
          userPhoneNumber: widget.userPhoneNumber,
          userCity: widget.userCity,
        );
      }

      if (processedFilePath != null) {
        print('File processed successfully: $processedFilePath');
        
        // Check if file exists
        final file = File(processedFilePath);
        if (!await file.exists()) {
          throw Exception('Processed file does not exist');
        }
        
        // Share the processed file
        await Share.shareXFiles(
          [XFile(processedFilePath)],
          text: 'Check out this amazing video from Prime Status!',
          subject: 'Shared from Prime Status',
        );

        // Clean up the processed file after a delay
        Future.delayed(Duration(seconds: 10), () {
          if (processedFilePath != null) {
            final file = File(processedFilePath);
            if (file.existsSync()) {
              file.deleteSync();
              print('Cleaned up shared file: $processedFilePath');
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('Failed to process video - processedFilePath is null');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process video. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error sharing video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing video: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessingShare = false;
      });
    }
  }

  // Show video processing options dialog
  Future<String?> _showVideoProcessingOptions() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.video_library, color: Colors.blue),
            SizedBox(width: 8),
            Text('Video Sharing Options'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose how you want to share your video:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            _buildProcessingOption(
              'Full Video with Overlays',
              'Process the entire video with your information overlays',
              Icons.video_file,
              Colors.green,
            ),
            SizedBox(height: 8),
            _buildProcessingOption(
              'Thumbnail with Overlays',
              'Share a thumbnail image with your information (faster)',
              Icons.image,
              Colors.orange,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOption(String title, String description, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context, title == 'Full Video with Overlays' ? 'full_video' : 'thumbnail');
      },
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // WhatsApp specific sharing
  Future<void> _shareToWhatsApp(String imageUrl, Map<String, dynamic> post) async {
    setState(() {
      _isProcessingShare = true;
    });

    try {
      final Uint8List? imageBytes = await _captureImageWithOverlays(imageUrl, post);
      
      if (imageBytes != null) {
        // Save image to temporary file
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName = 'whatsapp_share_${DateTime.now().millisecondsSinceEpoch}.png';
        final String filePath = '${tempDir.path}/$fileName';
        final File imageFile = File(filePath);
        await imageFile.writeAsBytes(imageBytes);

        // Share the image
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Check out this amazing design from Prime Status!',
          subject: 'Shared from Prime Status',
        );

        // Clean up the temporary file after a delay
        Future.delayed(Duration(seconds: 10), () {
          if (imageFile.existsSync()) {
            imageFile.deleteSync();
          }
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process image for sharing'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error sharing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessingShare = false;
      });
    }
  }

  Future<void> _shareImage(String imageUrl, Map<String, dynamic> post, String platform) async {
    setState(() {
      _isProcessingShare = true;
    });

    try {
      // Create the image with overlays
      final Uint8List? imageBytes = await _captureImageWithOverlays(imageUrl, post);
      
      if (imageBytes != null) {
        // Save image to temporary file
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName = 'shared_image_${DateTime.now().millisecondsSinceEpoch}.png';
        final String filePath = '${tempDir.path}/$fileName';
        final File imageFile = File(filePath);
        await imageFile.writeAsBytes(imageBytes);

        // Share the image
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Check out this amazing design!',
          subject: 'Shared from Prime Status',
        );

        // Clean up the temporary file after a delay
        Future.delayed(Duration(seconds: 5), () {
          if (imageFile.existsSync()) {
            imageFile.deleteSync();
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image for sharing')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing image: $e')),
      );
    } finally {
      setState(() {
        _isProcessingShare = false;
      });
    }
  }

  // Download functionality
  Future<void> _downloadImage(Map<String, dynamic> post) async {
    setState(() {
      _isProcessingDownload = true;
    });

    try {
      final String imageUrl = post['mainImage'] ?? post['imageUrl'] ?? '';
      
      // Check if it's a video
      if (_isVideoUrl(imageUrl) || imageUrl.startsWith('data:video')) {
        await _downloadVideoWithOverlays(imageUrl, post);
      } else {
        // Use the same cropping logic as sharing for images
        final Uint8List? imageBytes = await _captureImageWithOverlays(imageUrl, post);
        
        if (imageBytes != null) {
          // Request storage permission
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          
          if (status.isGranted) {
            // Get the downloads directory
            Directory? downloadsDir;
            if (Platform.isAndroid) {
              // Try multiple possible download directories
              final List<String> possiblePaths = [
                '/storage/emulated/0/Download',
                '/storage/emulated/0/Downloads',
                '/sdcard/Download',
                '/sdcard/Downloads',
              ];
              
              for (String path in possiblePaths) {
                final dir = Directory(path);
                if (dir.existsSync()) {
                  downloadsDir = dir;
                  break;
                }
              }
              
              // If no download directory found, use external storage
              if (downloadsDir == null) {
                downloadsDir = await getExternalStorageDirectory();
              }
            } else {
              downloadsDir = await getApplicationDocumentsDirectory();
            }
            
            if (downloadsDir != null) {
              final String fileName = 'PrimeStatus_${DateTime.now().millisecondsSinceEpoch}.png';
              final String filePath = '${downloadsDir.path}/$fileName';
              final File imageFile = File(filePath);
              await imageFile.writeAsBytes(imageBytes);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Image saved successfully!'),
                  duration: Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'Share',
                    onPressed: () async {
                      // Share the downloaded file
                      try {
                        await Share.shareXFiles([XFile(filePath)]);
                      } catch (e) {
                        print('Error sharing file: $e');
                      }
                    },
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not access downloads directory')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Storage permission required to download images')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to process image for download')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading image: $e')),
      );
    } finally {
      setState(() {
        _isProcessingDownload = false;
      });
    }
  }

  // Download video with overlays
  Future<void> _downloadVideoWithOverlays(String videoUrl, Map<String, dynamic> post) async {
    try {
      // Show processing options dialog
      final String? processingMethod = await _showVideoProcessingOptions();
      if (processingMethod == null) {
        return;
      }

      String? processedFilePath;
      
      if (processingMethod == 'full_video') {
        // Process full video with overlays
        processedFilePath = await VideoProcessingService.processVideoWithOverlays(
          videoUrl: videoUrl,
          post: post,
          userUsageType: widget.userUsageType,
          userName: widget.userName,
          userProfilePhotoUrl: widget.userProfilePhotoUrl,
          userAddress: widget.userAddress,
          userPhoneNumber: widget.userPhoneNumber,
          userCity: widget.userCity,
        );
      } else {
        // Create thumbnail with overlay
        processedFilePath = await VideoProcessingService.createVideoThumbnailWithOverlay(
          videoUrl: videoUrl,
          post: post,
          userUsageType: widget.userUsageType,
          userName: widget.userName,
          userProfilePhotoUrl: widget.userProfilePhotoUrl,
          userAddress: widget.userAddress,
          userPhoneNumber: widget.userPhoneNumber,
          userCity: widget.userCity,
        );
      }

      if (processedFilePath != null) {
        // Request storage permission
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        
        if (status.isGranted) {
          // Get the downloads directory
          Directory? downloadsDir;
          if (Platform.isAndroid) {
            // Try multiple possible download directories
            final List<String> possiblePaths = [
              '/storage/emulated/0/Download',
              '/storage/emulated/0/Downloads',
              '/sdcard/Download',
              '/sdcard/Downloads',
            ];
            
            for (String path in possiblePaths) {
              final dir = Directory(path);
              if (dir.existsSync()) {
                downloadsDir = dir;
                break;
              }
            }
            
            // If no download directory found, use external storage
            if (downloadsDir == null) {
              downloadsDir = await getExternalStorageDirectory();
            }
          } else {
            downloadsDir = await getApplicationDocumentsDirectory();
          }
          
          if (downloadsDir != null) {
            final String fileName = processingMethod == 'full_video' 
                ? 'PrimeStatus_Video_${DateTime.now().millisecondsSinceEpoch}.mp4'
                : 'PrimeStatus_Thumbnail_${DateTime.now().millisecondsSinceEpoch}.png';
            final String filePath = '${downloadsDir.path}/$fileName';
            
            // Copy the processed file to downloads
            final File sourceFile = File(processedFilePath);
            final File destFile = File(filePath);
            await sourceFile.copy(destFile.path);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${processingMethod == 'full_video' ? 'Video' : 'Thumbnail'} saved successfully!'),
                duration: Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Share',
                  onPressed: () async {
                    try {
                      await Share.shareXFiles([XFile(filePath)]);
                    } catch (e) {
                      print('Error sharing file: $e');
                    }
                  },
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not access downloads directory')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Storage permission required to download videos')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process video for download')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading video: $e')),
      );
    }
  }

Future<Uint8List?> _captureImageWithOverlays(String imageUrl, Map<String, dynamic> post) async {
  try {
    final frameSize = post['frameSize'] ?? {'width': 1080, 'height': 1920};
    final int cropWidth = frameSize['width'] ?? 1080;
    final int cropHeight = frameSize['height'] ?? 1920;

    final Widget imageWithOverlays = Container(
      width: cropWidth.toDouble(),
      height: cropHeight.toDouble(),
      child: AdminPostFullScreenCard(
        post: post,
        userUsageType: widget.userUsageType,
        userName: widget.userName,
        userProfilePhotoUrl: widget.userProfilePhotoUrl,
        userAddress: widget.userAddress,
        userPhoneNumber: widget.userPhoneNumber,
        userCity: widget.userCity,
        onShare: () {}, // dummy
        onDownload: () {}, // dummy
        onEdit: () {}, // dummy
        forceFrameSize: frameSize,
      ),
    );

    // Capture the widget
    final Uint8List? capturedBytes = await _screenshotController.captureFromWidget(
      Material(
        color: Colors.transparent,
        child: imageWithOverlays,
      ),
      delay: Duration(milliseconds: 1000),
      pixelRatio: 2.0,
      context: context,
    );
    if (capturedBytes == null) return null;

    // Decode the image
    final img.Image? capturedImage = img.decodeImage(capturedBytes);
    if (capturedImage == null) return null;

    // If the captured image is taller than the frame, crop with 2:5 top:bottom ratio
    if (capturedImage.height > cropHeight) {
      final int totalToRemove = capturedImage.height - cropHeight;
      final int removedTop = (totalToRemove * 0 / 5).round();
      final int cropStartY = removedTop.clamp(0, capturedImage.height - cropHeight);
      final img.Image cropped = img.copyCrop(
        capturedImage,
        x: 0,
        y: cropStartY,
        width: cropWidth,
        height: cropHeight,
      );
      final Uint8List croppedBytes = Uint8List.fromList(img.encodePng(cropped));
      return croppedBytes;
    } else {
      // No cropping needed, just return the captured bytes
      return capturedBytes;
    }
  } catch (e) {
    print('Error capturing/cropping image: $e');
    return null;
  }
}

  // Fallback method for sharing when screenshot fails
  Future<Uint8List?> _fallbackShareMethod(String imageUrl) async {
    try {
      // Download the image and share it directly
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('Fallback method failed: $e');
    }
    return null;
  }

  // Method to create a simple image with text overlay when screenshot fails
  Future<Uint8List?> _createSimpleImageWithOverlays(String imageUrl, Map<String, dynamic> post) async {
    try {
      // This is a simplified version that creates a basic image with overlays
      // In a real implementation, you might want to use a more sophisticated image processing library
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        // For now, just return the original image
        // In the future, you could add text overlays using image processing
        return response.bodyBytes;
      }
    } catch (e) {
      print('Simple image creation failed: $e');
    }
    return null;
  }

  // Helper to handle both base64 and URL images
  Widget _buildMainImage(String imageUrl, {BoxFit fit = BoxFit.contain}) {
    // Video support
    if (imageUrl.startsWith('data:video')) {
      try {
        final base64Str = imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return _Base64VideoPlayer(bytes: bytes);
      } catch (e) {
        return Container(
          color: Colors.grey[200],
          child: Icon(Icons.error, color: Colors.grey),
        );
      }
    } else if (_isVideoUrl(imageUrl)) {
      return _NetworkVideoPlayer(url: imageUrl);
    } else if (imageUrl.startsWith('data:image')) {
      try {
        final base64Str = imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: fit,
        );
      } catch (e) {
        return Container(
          color: Colors.grey[200],
          child: Icon(Icons.error, color: Colors.grey),
        );
      }
    } else if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: fit,
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
            child: Icon(Icons.error, color: Colors.grey),
          );
        },
      );
    } else {
      return Container(
        color: Colors.grey[200],
        child: Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
      );
    }
  }

  bool _isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.mov', '.webm', '.avi', '.mkv', '.ogg'];
    return url.startsWith('http') && videoExtensions.any((ext) => url.toLowerCase().contains(ext));
  }

  Widget _buildProfilePhotoWithoutBackground(String photoUrl) {
    return Image.network(
      photoUrl,
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
    );
  }

  // Helper to parse hex color strings
  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    if (hexColor.length == 6) hexColor = 'FF$hexColor';
    return Color(int.parse('0x$hexColor'));
  }

  // Edit functionality
  void _showProfilePhotoDialog() {
    if (widget.userUsageType == 'Business' && !_hasCompleteBusinessInfo()) {
      _showBusinessInfoDialog();
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Profile Photos'),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              SizedBox(height: 16),
              // Profile photo gallery
              Expanded(
                child: _buildProfilePhotoGallery(),
              ),
              SizedBox(height: 16),
              // Add new photo button
              // ElevatedButton.icon(
              //   onPressed: () => _addNewProfilePhoto(),
              //   icon: Icon(Icons.add_a_photo),
              //   label: Text('Add New Photo'),
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: Colors.orange,
              //     foregroundColor: Colors.white,
              //   ),
              // ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewProfilePhoto() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Profile Photo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPhotoOption(
                  'Camera',
                  Icons.camera_alt,
                  Colors.blue,
                  () => _takePhotoWithBgRemoval(),
                ),
                _buildPhotoOption(
                  'Gallery',
                  Icons.photo_library,
                  Colors.green,
                  () => _pickPhotoWithBgRemoval(),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Photos will automatically have backgrounds removed',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoOption(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _takePhotoWithBgRemoval() async {
    if (_userService.currentUser == null) return;
    
    try {
      // Take photo with camera (normal - with background)
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        
        // Upload to Firebase Storage (with background)
        String downloadUrl = await _userService.uploadProfilePhoto(imageFile, _userService.currentUser!.uid);
        
        // Add to user's profile photos collection
        await _addProfilePhotoToGallery(downloadUrl);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile photo added successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add profile photo: $e')),
      );
    }
  }

  Future<void> _pickPhotoWithBgRemoval() async {
    if (_userService.currentUser == null) return;
    
    try {
      // Pick image from gallery (normal - with background)
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        
        // Upload to Firebase Storage (with background)
        String downloadUrl = await _userService.uploadProfilePhoto(imageFile, _userService.currentUser!.uid);
        
        // Add to user's profile photos collection
        await _addProfilePhotoToGallery(downloadUrl);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile photo added successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add profile photo: $e')),
      );
    }
  }

  Future<void> _addProfilePhotoToGallery(String photoUrl) async {
    if (_userService.currentUser == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userService.currentUser!.uid)
          .collection('profilePhotos')
          .add({
        'photoUrl': photoUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'isActive': false,
        'withoutBackground': false, // Mark as not processed
      });
    } catch (e) {
      print('Error adding profile photo to gallery: $e');
    }
  }

  // Check if business user has complete information
  bool _hasCompleteBusinessInfo() {
    if (widget.userUsageType != 'Business') return false;
    
    final hasAddress = widget.userAddress.isNotEmpty;
    final hasPhone = widget.userPhoneNumber.isNotEmpty;
    final hasCity = widget.userCity.isNotEmpty;
    
    return hasAddress && hasPhone && hasCity;
  }

  // Show business information setup dialog
  void _showBusinessInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.business, color: Colors.blue),
            SizedBox(width: 8),
            Text('Business Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To display your business information on posts, please complete your profile:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey.shade600, size: 16),
                SizedBox(width: 8),
                Text('Address', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            Row(
              children: [
                Icon(Icons.phone, color: Colors.grey.shade600, size: 16),
                SizedBox(width: 8),
                Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            Row(
              children: [
                Icon(Icons.location_city, color: Colors.grey.shade600, size: 16),
                SizedBox(width: 8),
                Text('City', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Go to Profile tab to update your information.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate back to home screen
              Navigator.pop(context);
            },
            child: Text('Update Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchUserProfilePhotos() async {
    setState(() { _isLoadingProfilePhotos = true; });
    try {
      final user = _userService.currentUser;
      if (user == null) return;
      final photosSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('profilePhotos')
          .orderBy('uploadedAt', descending: true)
          .get();
      setState(() {
        _userProfilePhotos = photosSnapshot.docs.map((doc) => doc.data()).toList();
        _activeProfilePhotoUrl = widget.userProfilePhotoUrl;
      });
    } catch (e) {
      print('Error fetching profile photos: $e');
    } finally {
      setState(() { _isLoadingProfilePhotos = false; });
    }
  }

  Widget _buildProfilePhotoGallery() {
    if (_isLoadingProfilePhotos) {
      return Center(child: CircularProgressIndicator());
    }
    if (_userProfilePhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No profile photos yet', style: TextStyle(color: Colors.grey[600])),
            SizedBox(height: 8),
            Text('Add your first profile photo!', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      );
    }
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _userProfilePhotos.length,
      itemBuilder: (context, index) {
        final photoDoc = _userProfilePhotos[index];
        final photoUrl = photoDoc['photoUrl'] as String?;
        final photoUrlNoBg = photoDoc['photoUrlNoBg'] as String?;
        final isActive = photoUrl == _activeProfilePhotoUrl || photoUrlNoBg == _activeProfilePhotoUrl;
        return Row(
          children: [
            if (photoUrl != null)
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectProfilePhotoFromGallery(photoUrl),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive && _activeProfilePhotoUrl == photoUrl ? Colors.green : Colors.grey.shade300,
                        width: isActive && _activeProfilePhotoUrl == photoUrl ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Image.network(
                            photoUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey.shade200,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.person, size: 30, color: Colors.grey),
                            ),
                          ),
                          if (isActive && _activeProfilePhotoUrl == photoUrl)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.check, color: Colors.white, size: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (photoUrlNoBg != null)
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectProfilePhotoFromGallery(photoUrlNoBg),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive && _activeProfilePhotoUrl == photoUrlNoBg ? Colors.green : Colors.grey.shade300,
                        width: isActive && _activeProfilePhotoUrl == photoUrlNoBg ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Image.network(
                            photoUrlNoBg,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey.shade200,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.person, size: 30, color: Colors.grey),
                            ),
                          ),
                          if (isActive && _activeProfilePhotoUrl == photoUrlNoBg)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.check, color: Colors.white, size: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _selectProfilePhotoFromGallery(String photoUrl) async {
    final user = _userService.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'profilePhotoUrl': photoUrl});
      setState(() {
        _activeProfilePhotoUrl = photoUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile photo updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile photo: $e')),
      );
    }
  }

  // Test video processing (for debugging)
  Future<void> _testVideoProcessing(String videoUrl, Map<String, dynamic> post) async {
    try {
      print('=== TESTING VIDEO PROCESSING ===');
      print('Video URL: $videoUrl');
      print('Post data: $post');
      
      // Test thumbnail creation first (faster)
      print('Testing thumbnail creation...');
      final String? thumbnailPath = await VideoProcessingService.createVideoThumbnailWithOverlay(
        videoUrl: videoUrl,
        post: post,
        userUsageType: widget.userUsageType,
        userName: widget.userName,
        userProfilePhotoUrl: widget.userProfilePhotoUrl,
        userAddress: widget.userAddress,
        userPhoneNumber: widget.userPhoneNumber,
        userCity: widget.userCity,
      );
      
      if (thumbnailPath != null) {
        print('✅ Thumbnail created successfully: $thumbnailPath');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thumbnail test successful!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('❌ Thumbnail creation failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thumbnail test failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Test failed with error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class AdminPostFullScreenCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final String userUsageType;
  final String userName;
  final String? userProfilePhotoUrl;
  final String userAddress;
  final String userPhoneNumber;
  final String userCity;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onEdit;
  final Map<String, dynamic>? forceFrameSize;
  
  const AdminPostFullScreenCard({
    Key? key, 
    required this.post,
    required this.userUsageType,
    required this.userName,
    this.userProfilePhotoUrl,
    required this.userAddress,
    required this.userPhoneNumber,
    required this.userCity,
    required this.onShare,
    required this.onDownload,
    required this.onEdit,
    this.forceFrameSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String imageUrl = post['mainImage'] ?? post['imageUrl'] ?? '';
    final textSettings = post['textSettings'] ?? {};
    final profileSettings = post['profileSettings'] ?? {};
    final addressSettings = post['addressSettings'] ?? {};
    final phoneSettings = post['phoneSettings'] ?? {};
    final frameSize = forceFrameSize ?? post['frameSize'] ?? {'width': 1080, 'height': 1920};

    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final double aspectRatio = frameSize['width'] / frameSize['height'];
                final double height = width / aspectRatio;

                final double textX = (textSettings['x'] ?? 50) / 100 * width;
                final double textY = (textSettings['y'] ?? 90) / 100 * height;
                final double profileX = (profileSettings['x'] ?? 20) / 100 * width;
                final double profileY = (profileSettings['y'] ?? 20) / 100 * height;
                final double profileSize = (profileSettings['size'] ?? 80).toDouble();
                final double addressX = (addressSettings['x'] ?? 50) / 100 * width;
                final double addressY = (addressSettings['y'] ?? 80) / 100 * height;
                final double phoneX = (phoneSettings['x'] ?? 50) / 100 * width;
                final double phoneY = (phoneSettings['y'] ?? 85) / 100 * height;

                return SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    children: [
                      Container(
                        width: width,
                        height: height,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          child: _buildMainImage(imageUrl, fit: BoxFit.contain),
                        ),
                      ),
                      if (textSettings.isNotEmpty)
                        Positioned(
                          left: textX,
                          top: textY,
                          child: Transform.translate(
                            offset: Offset(-0.5 * (textSettings['fontSize'] ?? 24) * (userName.length / 2), -20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      if (userUsageType == 'Business' && addressSettings['enabled'] == true && userAddress.isNotEmpty)
                        Positioned(
                          left: addressX,
                          top: addressY,
                          child: Transform.translate(
                            offset: Offset(-0.5 * (addressSettings['fontSize'] ?? 18) * (userAddress.length / 2), -20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      if (userUsageType == 'Business' && phoneSettings['enabled'] == true && userPhoneNumber.isNotEmpty)
                        Positioned(
                          left: phoneX,
                          top: phoneY,
                          child: Transform.translate(
                            offset: Offset(-0.5 * (phoneSettings['fontSize'] ?? 18) * (userPhoneNumber.length / 2), -20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              child: _buildProfilePhotoWithoutBackground(userProfilePhotoUrl!),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0),
              child: Row(
                children: [
                  Expanded(
                    flex: 45,
                    child: ElevatedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: const Text('Whatsapp', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 45,
                    child: ElevatedButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text('Download', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 10,
                    child: ElevatedButton(
                      onPressed: onEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white),
                    ),
                  ),

                ],
              ),
            ),
          ],
        ),
        // Positioned(
        //   top: 8,
        //   left: 8,
        //   child: InkWell(
        //     onTap: () {
        //       Navigator.pop(context);
        //     },
        //     child: Container(
        //       padding: const EdgeInsets.all(14),
        //       child: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
        //     ),
        //   ),
        // ),
      ],
    );
  }

  // Helper to handle both base64 and URL images
  Widget _buildMainImage(String imageUrl, {BoxFit fit = BoxFit.contain}) {
    // Video support
    if (imageUrl.startsWith('data:video')) {
      try {
        final base64Str = imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return _Base64VideoPlayer(bytes: bytes);
      } catch (e) {
        return Container(
          color: Colors.grey[200],
          child: Icon(Icons.error, color: Colors.grey),
        );
      }
    } else if (_isVideoUrl(imageUrl)) {
      return _NetworkVideoPlayer(url: imageUrl);
    } else if (imageUrl.startsWith('data:image')) {
      try {
        final base64Str = imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: fit,
        );
      } catch (e) {
        return Container(
          color: Colors.grey[200],
          child: Icon(Icons.error, color: Colors.grey),
        );
      }
    } else if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: fit,
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
            child: Icon(Icons.error, color: Colors.grey),
          );
        },
      );
    } else {
      return Container(
        color: Colors.grey[200],
        child: Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
      );
    }
  }

  bool _isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.mov', '.webm', '.avi', '.mkv', '.ogg'];
    return url.startsWith('http') && videoExtensions.any((ext) => url.toLowerCase().contains(ext));
  }

  Widget _buildProfilePhotoWithoutBackground(String photoUrl) {
    return Image.network(
      photoUrl,
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
    );
  }

  // Helper to parse hex color strings
  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    if (hexColor.length == 6) hexColor = 'FF$hexColor';
    return Color(int.parse('0x$hexColor'));
  }


}

// Base64 video player widget
class _Base64VideoPlayer extends StatefulWidget {
  final List<int> bytes;
  const _Base64VideoPlayer({required this.bytes});

  @override
  State<_Base64VideoPlayer> createState() => _Base64VideoPlayerState();
}

class _Base64VideoPlayerState extends State<_Base64VideoPlayer> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  late String _controllerKey;

  @override
  void initState() {
    super.initState();
    _controllerKey = 'fullscreen_base64_${DateTime.now().millisecondsSinceEpoch}_${widget.bytes.hashCode}';
    _controller = VideoPlayerController.networkUrl(Uri.parse('data:video/mp4;base64,${base64Encode(widget.bytes)}'));
    FullscreenVideoControllerManager().registerController(_controllerKey, _controller);
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      _controller.setVolume(1.0);
      _controller.play();
      FullscreenVideoControllerManager().setCurrentController(_controllerKey);
      setState(() {});
    });
  }

  @override
  void dispose() {
    FullscreenVideoControllerManager().unregisterController(_controllerKey);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          );
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}

// Network video player widget
class _NetworkVideoPlayer extends StatefulWidget {
  final String url;
  const _NetworkVideoPlayer({required this.url});

  @override
  State<_NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<_NetworkVideoPlayer> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  late String _controllerKey;

  @override
  void initState() {
    super.initState();
    _controllerKey = 'fullscreen_network_${DateTime.now().millisecondsSinceEpoch}_${widget.url.hashCode}';
    _controller = VideoPlayerController.network(widget.url);
    FullscreenVideoControllerManager().registerController(_controllerKey, _controller);
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      _controller.setVolume(1.0);
      _controller.play();
      FullscreenVideoControllerManager().setCurrentController(_controllerKey);
      setState(() {});
    });
  }

  @override
  void dispose() {
    FullscreenVideoControllerManager().unregisterController(_controllerKey);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          );
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
} 