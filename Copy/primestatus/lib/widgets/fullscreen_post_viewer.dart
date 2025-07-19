import 'package:flutter/material.dart';
import 'package:primestatus/screens/AllSubscription.dart';
import 'admin_post_feed_widget.dart';
import '../screens/onboarding/subscription_screen.dart';
import '../screens/postsubscription.dart';
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
import '../services/subscription_service.dart';
import '../services/local_media_processing_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/admin_post_service.dart';

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
  // Tab selection state
  int _selectedTabIndex = 0; // 0: All, 1: Images, 2: Videos
  List<Map<String, dynamic>> _filteredPosts = []; // Filtered posts based on tab
  final AdminPostService _adminPostService = AdminPostService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _activeProfilePhotoUrl = widget.userProfilePhotoUrl;
    _fetchUserProfilePhotos();
    
    // Initialize filtered posts
    _filteredPosts = List.from(widget.posts);
    _filterPostsByType();
    
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
        // Pause all fullscreen videos and resume feed videos when going back
        FullscreenVideoControllerManager().pauseAllControllers();
        VideoControllerManager().setFullscreenMode(false);
        VideoControllerManager().resumeAllControllers();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
        children: [
          Column(
            children: [
              // Tabs for Image/Video/All classification
              // Container(
              //   color: Colors.black,
              //   padding: EdgeInsets.only(top: 60, left: 16, right: 16, bottom: 16),
              //   child: Row(
              //     children: [
              //       Expanded(
              //         child: _buildTabButton('All', Icons.collections, _selectedTabIndex == 0, 0),
              //       ),
              //       SizedBox(width: 8),
              //       Expanded(
              //         child: _buildTabButton('Images', Icons.image, _selectedTabIndex == 1, 1),
              //       ),
              //       SizedBox(width: 8),
              //       Expanded(
              //         child: _buildTabButton('Videos', Icons.video_library, _selectedTabIndex == 2, 2),
              //       ),
              //     ],
              //   ),
              // ),
              // Content area
              Expanded(
                child: _filteredPosts.isEmpty
                    ? Center(
                        child: Text(
                          _selectedTabIndex == 1 ? 'No images found.' : _selectedTabIndex == 2 ? 'No videos found.' : 'No posts found.',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      )
                    : PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        itemCount: _filteredPosts.length,
                        onPageChanged: (index) {
                          // Pause all videos when switching posts
                          FullscreenVideoControllerManager().pauseAllControllers();
                        },
                        itemBuilder: (context, index) {
                          final post = _filteredPosts[index];
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
                                  userEmail: _userService.currentUser?.email ?? '',
                                  onShare: () => _showShareOptions(post),
                                  onDownload: () => _downloadImage(post),
                                  onEdit: () => _showProfilePhotoDialog(),
                                  onPremium: () => _showPremiumOptions(post),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
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
                  // Pause all fullscreen videos and resume feed videos when going back
                  FullscreenVideoControllerManager().pauseAllControllers();
                  VideoControllerManager().setFullscreenMode(false);
                  VideoControllerManager().resumeAllControllers();
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
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        _isProcessingShare ? 'Processing post for sharing...' : 'Processing post for download...',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please wait while we process your image',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
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
  void _showShareOptions(Map<String, dynamic> post) async {
    // Check if user has active subscription
    final currentUser = _userService.currentUser;
    if (currentUser != null) {
      final hasSubscription = await SubscriptionService().hasActiveSubscription(currentUser.uid);
      if (!hasSubscription) {
        // User is free, show subscription page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostSubscriptionScreen(
              post: post,
              userUsageType: widget.userUsageType,
              userName: widget.userName,
              userProfilePhotoUrl: widget.userProfilePhotoUrl,
              userAddress: widget.userAddress,
              userPhoneNumber: widget.userPhoneNumber,
              userCity: widget.userCity,
              userEmail: _userService.currentUser?.email ?? '',
            ),
          ),
        );
        return;
      }
    }
    
    final String mediaUrl = post['mainImage'] ?? post['imageUrl'] ?? '';
    
    // Check if it's a video
    if (_isVideoUrl(mediaUrl) || mediaUrl.startsWith('data:video')) {
      print('=== SHARING VIDEO ===');
      _shareVideoWithOverlays(mediaUrl, post);
    } else {
      print('=== SHARING IMAGE ===');
      _shareToWhatsApp(mediaUrl, post);
    }
  }

  // Video sharing with overlays
  Future<void> _shareVideoWithOverlays(String videoUrl, Map<String, dynamic> post) async {
    setState(() {
      _isProcessingShare = true;
    });

    try {
      print('Starting video share process for: $videoUrl');
      // Always use full video for WhatsApp share, skip dialog
      final String processingMethod = 'full_video';
      String? processedFilePath;
      processedFilePath = await LocalMediaProcessingService.processVideoWithOverlays(
        videoUrl: videoUrl,
        post: post,
        userUsageType: widget.userUsageType,
        userName: widget.userName,
        userProfilePhotoUrl: widget.userProfilePhotoUrl,
        userAddress: widget.userAddress,
        userPhoneNumber: widget.userPhoneNumber,
        userCity: widget.userCity,
      );
      if (processedFilePath != null) {
        await Share.shareXFiles(
          [XFile(processedFilePath!)],
          text: 'Check out this amazing video from Prime Status!',
          subject: 'Shared from Prime Status',
        );
        // Increment share count in Firestore
        if (post['id'] != null) {
          await _adminPostService.shareAdminPost(post['id']);
        }
        Future.delayed(Duration(seconds: 10), () {
          final file = File(processedFilePath!);
          if (file.existsSync()) {
            file.deleteSync();
            print('Cleaned up shared file: $processedFilePath');
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to process video for sharing');
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



  // WhatsApp specific sharing
  Future<void> _shareToWhatsApp(String imageUrl, Map<String, dynamic> post) async {
    setState(() {
      _isProcessingShare = true;
    });

    try {
      print('=== SHARING IMAGE TO WHATSAPP (FFmpeg) ===');
      print('Image URL: $imageUrl');

      // Process image with overlays using local FFmpeg
      final String? processedFilePath = await LocalMediaProcessingService.processImageWithOverlays(
        imageUrl: imageUrl,
        post: post,
        userUsageType: widget.userUsageType,
        userName: widget.userName,
        userProfilePhotoUrl: widget.userProfilePhotoUrl,
        userAddress: widget.userAddress,
        userPhoneNumber: widget.userPhoneNumber,
        userCity: widget.userCity,
      );

      if (processedFilePath != null) {
        await Share.shareXFiles(
          [XFile(processedFilePath)],
          text: 'Check out this amazing design from Prime Status!',
          subject: 'Shared from Prime Status',
        );
        // Increment share count in Firestore
        if (post['id'] != null) {
          await _adminPostService.shareAdminPost(post['id']);
        }
        Future.delayed(Duration(seconds: 10), () {
          final file = File(processedFilePath);
          if (file.existsSync()) {
            file.deleteSync();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to process image for sharing');
      }
    } catch (e) {
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
      // Process image with overlays using local FFmpeg
      final String? processedFilePath = await LocalMediaProcessingService.processImageWithOverlays(
        imageUrl: imageUrl,
        post: post,
        userUsageType: widget.userUsageType,
        userName: widget.userName,
        userProfilePhotoUrl: widget.userProfilePhotoUrl,
        userAddress: widget.userAddress,
        userPhoneNumber: widget.userPhoneNumber,
        userCity: widget.userCity,
      );

      if (processedFilePath != null) {
        await Share.shareXFiles(
          [XFile(processedFilePath)],
          text: 'Check out this amazing design!',
          subject: 'Shared from Prime Status',
        );
        Future.delayed(Duration(seconds: 5), () {
          final file = File(processedFilePath);
          if (file.existsSync()) {
            file.deleteSync();
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
    // Check if user has active subscription
    final currentUser = _userService.currentUser;
    if (currentUser != null) {
      final hasSubscription = await SubscriptionService().hasActiveSubscription(currentUser.uid);
      if (!hasSubscription) {
        // User is free, show subscription page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostSubscriptionScreen(
              post: post,
              userUsageType: widget.userUsageType,
              userName: widget.userName,
              userProfilePhotoUrl: widget.userProfilePhotoUrl,
              userAddress: widget.userAddress,
              userPhoneNumber: widget.userPhoneNumber,
              userCity: widget.userCity,
              userEmail: _userService.currentUser?.email ?? '',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _isProcessingDownload = true;
    });

    try {
      final String mediaUrl = post['mainImage'] ?? post['imageUrl'] ?? '';
      
      // Check if it's a video
      if (_isVideoUrl(mediaUrl) || mediaUrl.startsWith('data:video')) {
        print('=== DOWNLOADING VIDEO ===');
        await _downloadVideoWithOverlays(mediaUrl, post);
      } else {
        print('=== DOWNLOADING IMAGE ===');
        // Process image with overlays using local FFmpeg
        await _downloadImageWithOverlays(mediaUrl, post);
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

  // Helper function to request storage permissions based on Android version
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Check Android version
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      if (sdkInt >= 33) {
        // Android 13+ - use media permissions
        var status = await Permission.photos.status;
        if (!status.isGranted) {
          status = await Permission.photos.request();
        }
        return status.isGranted;
      } else if (sdkInt >= 30) {
        // Android 11+ - use manage external storage
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        return status.isGranted;
      } else {
        // Android 10 and below - use storage permission
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    } else {
      // iOS - no special permission needed for app documents
      return true;
    }
  }

  // Helper function to get downloads directory
  Future<Directory?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // For Android, try to use the Downloads directory
      final List<String> possiblePaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Download',
        '/sdcard/Downloads',
      ];
      
      for (String path in possiblePaths) {
        final dir = Directory(path);
        if (dir.existsSync()) {
          return dir;
        }
      }
      
      // If no download directory found, use external storage
      return await getExternalStorageDirectory();
    } else {
      // For iOS, use app documents directory
      return await getApplicationDocumentsDirectory();
    }
  }

  // Download image with overlays using local FFmpeg
  Future<void> _downloadImageWithOverlays(String imageUrl, Map<String, dynamic> post) async {
    try {
      print('=== DOWNLOADING IMAGE WITH OVERLAYS ===');
      print('Image URL: $imageUrl');
      
      // Process image with overlays using local FFmpeg
      final String? processedFilePath = await LocalMediaProcessingService.processImageWithOverlays(
        imageUrl: imageUrl,
        post: post,
        userUsageType: widget.userUsageType,
        userName: widget.userName,
        userProfilePhotoUrl: widget.userProfilePhotoUrl,
        userAddress: widget.userAddress,
        userPhoneNumber: widget.userPhoneNumber,
        userCity: widget.userCity,
      );

      if (processedFilePath != null) {
        // Request appropriate storage permission
        final hasPermission = await _requestStoragePermission();
        
        if (hasPermission) {
          // Get the downloads directory
          final downloadsDir = await _getDownloadsDirectory();
          
          if (downloadsDir != null) {
            final String fileName = 'PrimeStatus_WithOverlays_${DateTime.now().millisecondsSinceEpoch}.png';
            final String filePath = '${downloadsDir.path}/$fileName';
            
            // Copy the processed file to downloads
            final File sourceFile = File(processedFilePath);
            final File destFile = File(filePath);
            await sourceFile.copy(destFile.path);
            
            print('Image with overlays saved to: $filePath');
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image with overlays saved successfully!'),
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
    } catch (e) {
      print('Error downloading image with overlays: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download image: $e')),
      );
    }
  }

  // Direct download from URL (fallback method)
  Future<void> _downloadImageFromUrl(String imageUrl, Map<String, dynamic> post) async {
    try {
      print('=== DOWNLOADING IMAGE FROM URL ===');
      print('Image URL: $imageUrl');
      
      // Download the image from URL
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        // Request appropriate storage permission
        final hasPermission = await _requestStoragePermission();
        
        if (hasPermission) {
          // Get the downloads directory
          final downloadsDir = await _getDownloadsDirectory();
          
          if (downloadsDir != null) {
            // Determine file extension from URL or content type
            String fileExtension = 'jpg';
            if (imageUrl.contains('.png')) {
              fileExtension = 'png';
            } else if (imageUrl.contains('.gif')) {
              fileExtension = 'gif';
            } else if (imageUrl.contains('.webp')) {
              fileExtension = 'webp';
            }
            
            final String fileName = 'PrimeStatus_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
            final String filePath = '${downloadsDir.path}/$fileName';
            final File imageFile = File(filePath);
            await imageFile.writeAsBytes(response.bodyBytes);
            
            print('Image saved to: $filePath');
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image saved to gallery successfully!'),
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
        throw Exception('Failed to download image: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading image from URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download image: $e')),
      );
    }
  }

  // Download video with overlays
  Future<void> _downloadVideoWithOverlays(String videoUrl, Map<String, dynamic> post) async {
    try {
      // Always use full video for downloads, skip dialog
      final String processingMethod = 'full_video';
      String? processedFilePath;
      processedFilePath = await LocalMediaProcessingService.processVideoWithOverlays(
        videoUrl: videoUrl,
        post: post,
        userUsageType: widget.userUsageType,
        userName: widget.userName,
        userProfilePhotoUrl: widget.userProfilePhotoUrl,
        userAddress: widget.userAddress,
        userPhoneNumber: widget.userPhoneNumber,
        userCity: widget.userCity,
      );

      if (processedFilePath != null) {
        // Request appropriate storage permission
        final hasPermission = await _requestStoragePermission();
        
        if (hasPermission) {
          // Get the downloads directory
          final downloadsDir = await _getDownloadsDirectory();
          
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
        userEmail: _userService.currentUser?.email ?? '',
        onShare: () {}, // dummy
        onDownload: () {}, // dummy
        onEdit: () {}, // dummy
        onPremium: () {}, // dummy
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
          color: Colors.black,
          child: Icon(Icons.error, color: Colors.white),
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
          cacheWidth: 1080, // Optimize memory usage
          cacheHeight: 1920,
        );
      } catch (e) {
        return Container(
          color: Colors.black,
          child: Icon(Icons.error, color: Colors.white),
        );
      }
    } else if (imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        memCacheWidth: 1080, // Optimize memory usage
        memCacheHeight: 1920,
        maxWidthDiskCache: 1080,
        maxHeightDiskCache: 1920,
        placeholder: (context, url) => Container(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.black,
          child: Icon(Icons.error, color: Colors.white),
        ),
        cacheManager: DefaultCacheManager(),
      );
    } else {
      return Container(
        color: Colors.black,
        child: Center(child: Icon(Icons.image, size: 48, color: Colors.white)),
      );
    }
  }

  bool _isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.mov', '.webm', '.avi', '.mkv', '.ogg'];
    return url.startsWith('http') && videoExtensions.any((ext) => url.toLowerCase().contains(ext));
  }

  Widget _buildProfilePhoto(String photoUrl) {
    return CachedNetworkImage(
      imageUrl: photoUrl,
      fit: BoxFit.cover,
      memCacheWidth: 200, // Optimize for profile photos
      memCacheHeight: 200,
      maxWidthDiskCache: 200,
      maxHeightDiskCache: 200,
      placeholder: (context, url) => Container(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.black,
        child: Icon(Icons.person, color: Colors.white),
      ),
      cacheManager: DefaultCacheManager(),
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
      return Center(child: CircularProgressIndicator(color: Colors.white));
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
      addAutomaticKeepAlives: false, // Optimize memory usage
      addRepaintBoundaries: false, // Optimize performance
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
                          CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            memCacheWidth: 150, // Optimize for gallery thumbnails
                            memCacheHeight: 150,
                            maxWidthDiskCache: 150,
                            maxHeightDiskCache: 150,
                            placeholder: (context, url) => Container(
                              color: Colors.black,
                              child: Center(child: CircularProgressIndicator(color: Colors.white)),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.black,
                              child: Icon(Icons.person, size: 30, color: Colors.white),
                            ),
                            cacheManager: DefaultCacheManager(),
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
                          CachedNetworkImage(
                            imageUrl: photoUrlNoBg,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            memCacheWidth: 150, // Optimize for gallery thumbnails
                            memCacheHeight: 150,
                            maxWidthDiskCache: 150,
                            maxHeightDiskCache: 150,
                            placeholder: (context, url) => Container(
                              color: Colors.black,
                              child: Center(child: CircularProgressIndicator(color: Colors.white)),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.black,
                              child: Icon(Icons.person, size: 30, color: Colors.white),
                            ),
                            cacheManager: DefaultCacheManager(),
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

  // Premium functionality
  void _showPremiumOptions(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostSubscriptionScreen(
          post: post,
          userUsageType: widget.userUsageType,
          userName: widget.userName,
          userProfilePhotoUrl: widget.userProfilePhotoUrl,
          userAddress: widget.userAddress,
          userPhoneNumber: widget.userPhoneNumber,
          userCity: widget.userCity,
          userEmail: _userService.currentUser?.email ?? '',
        ),
      ),
    );
  }

  // Build tab button widget
  Widget _buildTabButton(String title, IconData icon, bool isSelected, int tabIndex) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = tabIndex;
        });
        // Filter posts based on tab
        _filterPostsByType();
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Filter posts based on current tab
  void _filterPostsByType() {
    setState(() {
      if (_selectedTabIndex == 0) {
        // All
        _filteredPosts = List.from(widget.posts);
      } else if (_selectedTabIndex == 1) {
        // Images
        _filteredPosts = widget.posts.where((post) {
          final String mediaUrl = post['mainImage'] ?? post['imageUrl'] ?? '';
          return !_isVideoUrl(mediaUrl) && !mediaUrl.startsWith('data:video');
        }).toList();
      } else {
        // Videos
        _filteredPosts = widget.posts.where((post) {
          final String mediaUrl = post['mainImage'] ?? post['imageUrl'] ?? '';
          return _isVideoUrl(mediaUrl) || mediaUrl.startsWith('data:video');
        }).toList();
      }
    });

    // Only jump if there are items and the controller is attached, after build
    if (_filteredPosts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
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
  final String userEmail;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onEdit;
  final VoidCallback onPremium;
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
    required this.userEmail,
    required this.onShare,
    required this.onDownload,
    required this.onEdit,
    required this.onPremium,
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
                          color: Colors.black,
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
                                userName.length > 15 ? userName : userName,
                                style: TextStyle(
                                  fontFamily: getFontFamily(textSettings['font']),
                                  fontSize: ((textSettings['fontSize'] ?? 24).toDouble()) * (userName.length > 15 ? 0.6 : 1.0),
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
                                userAddress.length > 15 ? userAddress : userAddress,
                                style: TextStyle(
                                  fontFamily: getFontFamily(addressSettings['font']),
                                  fontSize: ((addressSettings['fontSize'] ?? 18).toDouble()) * (userAddress.length > 15 ? 0.6 : 1.0),
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
                                userPhoneNumber.length > 15 ? userPhoneNumber : userPhoneNumber,
                                style: TextStyle(
                                  fontFamily: getFontFamily(phoneSettings['font']),
                                  fontSize: ((phoneSettings['fontSize'] ?? 18).toDouble()) * (userPhoneNumber.length > 15 ? 0.6 : 1.0),
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                profileSettings['shape'] == 'circle'
                                    ? profileSize / 2
                                    : 8,
                              ),
                              child: _buildProfilePhoto(userProfilePhotoUrl!),
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
                  // Expanded(
                  //   flex: 35,
                  //   child: ElevatedButton.icon(
                  //     onPressed: onShare,
                  //     icon: const Icon(Icons.share, color: Colors.white),
                  //     label: const Text('Whatsapp', style: TextStyle(color: Colors.white)),
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.green[600],
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(8),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  // const SizedBox(width: 8),
                  // Expanded(
                  //   flex: 35,
                  //   child: ElevatedButton.icon(
                  //     onPressed: onDownload,
                  //     icon: const Icon(Icons.download, color: Colors.white),
                  //     label: const Text('Download', style: TextStyle(color: Colors.white)),
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.blue[600],
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(8),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  Expanded(
                    flex: 35,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SubscriptionPlansScreen(
                            userUsageType: userUsageType,
                            userName: userName,
                            userEmail: userEmail,
                            userPhone: userPhoneNumber,
                          )),
                        );
                      },
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
                    flex: 35,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SubscriptionPlansScreen(
                            userUsageType: userUsageType,
                            userName: userName,
                            userEmail: userEmail,
                            userPhone: userPhoneNumber,
                          )),
                        );
                      },
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
                  // Expanded(
                  //   flex: 15,
                  //   child: ElevatedButton.icon(
                  //     onPressed: () {
                  //       Navigator.push(
                  //         context,
                  //         MaterialPageRoute(builder: (context) => SubscriptionPlansScreen(
                  //           userUsageType: userUsageType,
                  //           userName: userName,
                  //           userEmail: userEmail,
                  //           userPhone: userPhoneNumber,
                  //         )),
                  //       );
                  //     },
                  //     icon: const Icon(Icons.star, color: Colors.white),
                  //     label: const Text('', style: TextStyle(color: Colors.white, fontSize: 12)),
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.purple[600],
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(8),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 15,
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
          color: Colors.black,
          child: Icon(Icons.error, color: Colors.white),
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
          cacheWidth: 1080, // Optimize memory usage
          cacheHeight: 1920,
        );
      } catch (e) {
        return Container(
          color: Colors.black,
          child: Icon(Icons.error, color: Colors.white),
        );
      }
    } else if (imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        memCacheWidth: 1080, // Optimize memory usage
        memCacheHeight: 1920,
        maxWidthDiskCache: 1080,
        maxHeightDiskCache: 1920,
        placeholder: (context, url) => Container(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.black,
          child: Icon(Icons.error, color: Colors.white),
        ),
        cacheManager: DefaultCacheManager(),
      );
    } else {
      return Container(
        color: Colors.black,
        child: Center(child: Icon(Icons.image, size: 48, color: Colors.white)),
      );
    }
  }

  bool _isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.mov', '.webm', '.avi', '.mkv', '.ogg'];
    return url.startsWith('http') && videoExtensions.any((ext) => url.toLowerCase().contains(ext));
  }

  Widget _buildProfilePhoto(String photoUrl) {
    return CachedNetworkImage(
      imageUrl: photoUrl,
      fit: BoxFit.cover,
      memCacheWidth: 200, // Optimize for profile photos
      memCacheHeight: 200,
      maxWidthDiskCache: 200,
      maxHeightDiskCache: 200,
      placeholder: (context, url) => Container(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.black,
        child: Icon(Icons.person, color: Colors.white),
      ),
      cacheManager: DefaultCacheManager(),
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
          return Container(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
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
          return Container(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
      },
    );
  }
} 