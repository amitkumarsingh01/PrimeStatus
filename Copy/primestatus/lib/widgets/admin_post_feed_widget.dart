import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_post_service.dart';
import '../services/user_service.dart';
import '../services/background_removal_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../screens/home_screen.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart' show launchUrl, canLaunchUrl, LaunchMode;
import 'package:video_player/video_player.dart';
import 'dart:typed_data';
import '../screens/onboarding/subscription_screen.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;
import 'fullscreen_post_viewer.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/subscription_service.dart';
import '../screens/postsubscription.dart';
import '../services/local_media_processing_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Global video controller manager
class VideoControllerManager {
  static final VideoControllerManager _instance = VideoControllerManager._internal();
  factory VideoControllerManager() => _instance;
  VideoControllerManager._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  bool _isFullscreenMode = false;

  void registerController(String key, VideoPlayerController controller) {
    _controllers[key] = controller;
  }

  void unregisterController(String key) {
    _controllers.remove(key);
  }

  void pauseAllControllers() {
    for (var controller in _controllers.values) {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  void resumeAllControllers() {
    if (!_isFullscreenMode) {
      for (var controller in _controllers.values) {
        if (controller.value.isInitialized && !controller.value.isPlaying) {
          controller.play();
        }
      }
    }
  }

  void setFullscreenMode(bool isFullscreen) {
    _isFullscreenMode = isFullscreen;
    if (isFullscreen) {
      pauseAllControllers();
    }
  }

  void disposeAllControllers() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
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

class AdminPostFeedWidget extends StatefulWidget {
  final List<String> selectedCategories;
  final String? language;
  final void Function(List<Map<String, dynamic>> posts, int initialIndex)? onPostTap;

  const AdminPostFeedWidget({
    Key? key,
    required this.selectedCategories,
    this.language,
    this.onPostTap,
  }) : super(key: key);

  @override
  _AdminPostFeedWidgetState createState() => _AdminPostFeedWidgetState();
}

class _AdminPostFeedWidgetState extends State<AdminPostFeedWidget> {
  final AdminPostService _adminPostService = AdminPostService();
  final UserService _userService = UserService();
  final BackgroundRemovalService _bgRemovalService = BackgroundRemovalService();
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isLoading = false;
  bool _isProcessingShare = false;
  Map<String, String?> _processedProfilePhotos = {};
  
  // Cache for processed images to avoid reprocessing
  final Map<String, Uint8List> _imageCache = {};
  
  // Debounce timer for search/filter operations
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _imageCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeScreenState = context.findAncestorStateOfType<HomeScreenState>();
    final userUsageType = homeScreenState?.userUsageType ?? '';
    final isBusinessUser = userUsageType == 'Business';
    final hasCompleteBusinessInfo = _hasCompleteBusinessInfo();
    
    return Stack(
      children: [
        Column(
          children: [
            // Business Information Status (for Business users)
            if (isBusinessUser && 1<0)
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasCompleteBusinessInfo ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasCompleteBusinessInfo ? Colors.green.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasCompleteBusinessInfo ? Icons.check_circle : Icons.info,
                      color: hasCompleteBusinessInfo ? Colors.green.shade700 : Colors.orange.shade700,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Business Profile',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: hasCompleteBusinessInfo ? Colors.green.shade700 : Colors.orange.shade700,
                            ),
                          ),
                          Text(
                            hasCompleteBusinessInfo 
                              ? 'Your business information will be displayed on posts'
                              : 'Complete your profile to display business information on posts',
                            style: TextStyle(
                              fontSize: 12,
                              color: hasCompleteBusinessInfo ? Colors.green.shade600 : Colors.orange.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!hasCompleteBusinessInfo)
                      TextButton(
                        onPressed: _showBusinessInfoDialog,
                        child: Text(
                          'Update',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            
            // Posts feed
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getFilteredPostsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    );
                  }

                  final posts = snapshot.data?.docs ?? [];

                  if (posts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.feed_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No posts available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Check back later for new content',
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                    },
                    child: ListView.builder(
                      key: PageStorageKey('admin_posts_list'), // Add key to preserve scroll position
                      padding: EdgeInsets.all(16),
                      itemCount: posts.length,
                      // Add performance optimizations
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: false,
                      itemBuilder: (context, index) {
                        final doc = posts[index];
                        final post = doc.data() as Map<String, dynamic>;
                        post['id'] = doc.id; // Attach the Firestore document ID!
                        return GestureDetector(
                          onTap: () {
                            if (widget.onPostTap != null) {
                              widget.onPostTap!(
                                posts.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  data['id'] = doc.id; // Attach the ID for every post in the list!
                                  return data;
                                }).toList(),
                                index,
                              );
                            }
                          },
                          child: _buildPostCard(post),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        // Loading overlay for background removal
        if (_isLoading)
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
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      'Removing background...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please wait while we process your photo',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Loading overlay for share/download actions
        if (_isProcessingShare)
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
                      'Processing post for sharing or download...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please wait while we process your request',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Stream<QuerySnapshot> _getFilteredPostsStream() {
    final categories = widget.selectedCategories;
    final isAll = categories.contains('All') || categories.isEmpty;
    var query = FirebaseFirestore.instance
        .collection('admin_posts')
        .where('isPublished', isEqualTo: true);
    if (!isAll) {
      // Firestore supports up to 10 values for array-contains-any
      query = query.where('categories', arrayContainsAny: categories);
    }
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final String imageUrl = post['mainImage'] ?? post['imageUrl'] ?? '';
    final textSettings = post['textSettings'] ?? {};
    final profileSettings = post['profileSettings'] ?? {};
    final addressSettings = post['addressSettings'] ?? {};
    final phoneSettings = post['phoneSettings'] ?? {};
    final frameSize = post['frameSize'] ?? {'width': 1080, 'height': 1920};
    final String userName = (context.findAncestorStateOfType<HomeScreenState>()?.userName ?? 'User');
    final String? userProfilePhotoUrl = (context.findAncestorStateOfType<HomeScreenState>()?.userProfilePhotoUrl);
    final String userUsageType = (context.findAncestorStateOfType<HomeScreenState>()?.userUsageType ?? '');
    final String userAddress = (context.findAncestorStateOfType<HomeScreenState>()?.userAddress ?? '');
    final String userPhoneNumber = (context.findAncestorStateOfType<HomeScreenState>()?.userPhoneNumber ?? '');
    final String userCity = (context.findAncestorStateOfType<HomeScreenState>()?.userCity ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Image content
          LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final double aspectRatio = frameSize['width'] / frameSize['height'];
              final double height = width / aspectRatio;

              final double textXBase = (textSettings['x'] ?? 50) / 100 * width;
              final double textY = (textSettings['y'] ?? 90) / 100 * height;
              final double profileX = (profileSettings['x'] ?? 20) / 100 * width;
              final double profileY = (profileSettings['y'] ?? 20) / 100 * height;
              final double profileSize = (profileSettings['size'] ?? 80).toDouble();
              final double addressXBase = (addressSettings['x'] ?? 50) / 100 * width;
              final double addressY = (addressSettings['y'] ?? 80) / 100 * height;
              final double phoneX = (phoneSettings['x'] ?? 50) / 100 * width;
              final double phoneY = (phoneSettings['y'] ?? 85) / 100 * height;
              final double textX = userName.length > 15 ? textXBase + 10 : textXBase;
              // final double addressX = userAddress.length > 15 ? addressXBase + 25 : addressXBase;
              final double addressX = userAddress.length > 15 ? addressXBase + 35 : addressXBase;


              return SizedBox(
                width: width,
                height: height,
                child: Stack(
                  children: [
                    // Background fill for empty space
                    Container(
                      width: width,
                      height: height,
                      decoration: const BoxDecoration(
                        color: Colors.white, // Changed from Color(0xFFFFF3E0) to white
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                    ),
                    // Main image centered and contained
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: _buildMainImage(imageUrl, fit: BoxFit.contain),
                      ),
                    ),
                    // Username text overlay (current user)
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
                                fontFamily: getFontFamily(textSettings['font']) ?? 'Arial',
                                fontSize: (textSettings['fontSize'] ?? 24).toDouble() * (userName.length > 15 ? 0.9 : 1.0),
                                color: _parseColor(textSettings['color'] ?? '#ffffff'),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Address text overlay (for business users)
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
                                fontFamily: getFontFamily(addressSettings['font']) ?? 'Arial',
                                fontSize: (addressSettings['fontSize'] ?? 18).toDouble() * (userAddress.length > 15 ? 0.9 : 1.0),
                                color: _parseColor(addressSettings['color'] ?? '#ffffff'),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Phone number text overlay (for business users)
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
                                fontFamily: getFontFamily(phoneSettings['font']) ?? 'Arial',
                                fontSize: (phoneSettings['fontSize'] ?? 18).toDouble() * (userPhoneNumber.length > 15 ? 0.9 : 1.0),
                                color: _parseColor(phoneSettings['color'] ?? '#ffffff'),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Profile photo overlay (current user) - with background removal
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
          // Action buttons at the bottom
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xffffffff), Color(0xffffffff)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // WhatsApp Share Button - 45%
                Expanded(
                  flex: 45,
                  child: ElevatedButton.icon(
                    onPressed: () => _shareToWhatsApp(post['mainImage'] ?? post['imageUrl'] ?? '', post),
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
                // Download Button - 45%
                Expanded(
                  flex: 45,
                  child: ElevatedButton.icon(
                    onPressed: () => _downloadImage(post),
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
                // Change Profile Photo Button - 10%
                Expanded(
                  flex: 10,
                  child: ElevatedButton(
                    onPressed: () => _showProfilePhotoDialog(),
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
    );
  }

  // Helper to handle both base64 and URL images
  Widget _buildMainImage(String imageUrl, {BoxFit fit = BoxFit.cover}) {
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
          cacheWidth: 1080, // Optimize memory usage
          cacheHeight: 1920,
        );
      } catch (e) {
        return Container(
          color: Colors.grey[200],
          child: Icon(Icons.error, color: Colors.grey),
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
          color: Colors.grey[200],
          child: Center(child: CircularProgressIndicator(color: Colors.blue)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[200],
          child: Icon(Icons.error, color: Colors.grey),
        ),
        cacheManager: DefaultCacheManager(),
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

  // Helper to parse hex color strings
  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    if (hexColor.length == 6) hexColor = 'FF$hexColor';
    return Color(int.parse('0x$hexColor'));
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final postTime = timestamp.toDate();
    final difference = now.difference(postTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _toggleLike(String postId) async {
    if (_userService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to like posts')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _adminPostService.toggleLikeAdminPost(postId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like post: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sharePost(String postId) async {
    try {
      await _adminPostService.shareAdminPost(postId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post shared!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share post: $e')),
      );
    }
  }

  void _handlePostAction(String action, String postId) {
    switch (action) {
      case 'share':
        _sharePost(postId);
        break;
      case 'report':
        _showReportDialog(postId);
        break;
    }
  }

  void _showReportDialog(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report Post'),
        content: Text('Are you sure you want to report this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Post reported. Thank you for your feedback.')),
              );
            },
            child: Text('Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _createDesignFromPost(Map<String, dynamic> post) {
    // Navigate to quote editor with post content
    Navigator.pushNamed(
      context,
      '/quote-editor',
      arguments: {
        'initialQuote': post['content'] ?? '',
        'initialTitle': post['title'] ?? '',
        'initialImageUrl': post['imageUrl'] ?? '',
      },
    );
  }

  // WhatsApp specific sharing (ported from fullscreen_post_viewer.dart)
  Future<void> _shareToWhatsApp(String mediaUrl, Map<String, dynamic> post) async {
    if (mounted) {
      setState(() {
        _isProcessingShare = true;
      });
    }
    try {
      // Check if it's a video
      if (_isVideoUrl(mediaUrl) || mediaUrl.startsWith('data:video')) {
        // Always use full video for WhatsApp, skip dialog
        await _shareVideoWithOverlays(mediaUrl, post, forceFullVideo: true);
      } else {
        await _shareImageWithOverlays(mediaUrl, post);
      }
      // Increment share count in Firestore
      if (post['id'] != null) {
        await _adminPostService.shareAdminPost(post['id']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: \\${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingShare = false;
        });
      }
    }
  }

  Future<void> _shareVideoWithOverlays(String videoUrl, Map<String, dynamic> post, {bool forceFullVideo = false}) async {
    try {
      String? processingMethod;
      if (forceFullVideo) {
        processingMethod = 'full_video';
      } else {
        // Show processing options dialog (copy from fullscreen_post_viewer.dart)
        processingMethod = await _showVideoProcessingOptions();
        if (processingMethod == null) return;
      }
      String? processedFilePath;
      if (processingMethod == 'full_video') {
        processedFilePath = await LocalMediaProcessingService.processVideoWithOverlays(
          videoUrl: videoUrl,
          post: post,
          userUsageType: context.findAncestorStateOfType<HomeScreenState>()?.userUsageType ?? '',
          userName: context.findAncestorStateOfType<HomeScreenState>()?.userName ?? '',
          userProfilePhotoUrl: context.findAncestorStateOfType<HomeScreenState>()?.userProfilePhotoUrl,
          userAddress: context.findAncestorStateOfType<HomeScreenState>()?.userAddress ?? '',
          userPhoneNumber: context.findAncestorStateOfType<HomeScreenState>()?.userPhoneNumber ?? '',
          userCity: context.findAncestorStateOfType<HomeScreenState>()?.userCity ?? '',
        );
      } else {
        processedFilePath = await LocalMediaProcessingService.createVideoThumbnailWithOverlay(
          videoUrl: videoUrl,
          post: post,
          userUsageType: context.findAncestorStateOfType<HomeScreenState>()?.userUsageType ?? '',
          userName: context.findAncestorStateOfType<HomeScreenState>()?.userName ?? '',
          userProfilePhotoUrl: context.findAncestorStateOfType<HomeScreenState>()?.userProfilePhotoUrl,
          userAddress: context.findAncestorStateOfType<HomeScreenState>()?.userAddress ?? '',
          userPhoneNumber: context.findAncestorStateOfType<HomeScreenState>()?.userPhoneNumber ?? '',
          userCity: context.findAncestorStateOfType<HomeScreenState>()?.userCity ?? '',
        );
      }
      if (processedFilePath != null) {
        await Share.shareXFiles(
          [XFile(processedFilePath)],
          text: 'Check out this amazing video from Prime Status!',
          subject: 'Shared from Prime Status',
        );
        // Increment share count in Firestore
        if (post['id'] != null) {
          await _adminPostService.shareAdminPost(post['id']);
        }
        Future.delayed(Duration(seconds: 10), () {
          final file = File(processedFilePath!);
          if (file.existsSync()) file.deleteSync();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\u001b[38;5;2m${processingMethod == 'full_video' ? 'Video' : 'Thumbnail'} shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to process video for sharing');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing video: \\${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareImageWithOverlays(String imageUrl, Map<String, dynamic> post) async {
    try {
      final String? processedFilePath = await LocalMediaProcessingService.processImageWithOverlays(
        imageUrl: imageUrl,
        post: post,
        userUsageType: context.findAncestorStateOfType<HomeScreenState>()?.userUsageType ?? '',
        userName: context.findAncestorStateOfType<HomeScreenState>()?.userName ?? '',
        userProfilePhotoUrl: context.findAncestorStateOfType<HomeScreenState>()?.userProfilePhotoUrl,
        userAddress: context.findAncestorStateOfType<HomeScreenState>()?.userAddress ?? '',
        userPhoneNumber: context.findAncestorStateOfType<HomeScreenState>()?.userPhoneNumber ?? '',
        userCity: context.findAncestorStateOfType<HomeScreenState>()?.userCity ?? '',
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
          if (file.existsSync()) file.deleteSync();
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
          content: Text('Error sharing image: \\${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Download functionality (ported from fullscreen_post_viewer.dart)
  Future<void> _downloadImage(Map<String, dynamic> post) async {
    if (mounted) {
      setState(() {
        _isProcessingShare = true;
      });
    }
    try {
      final String mediaUrl = post['mainImage'] ?? post['imageUrl'] ?? '';
      if (_isVideoUrl(mediaUrl) || mediaUrl.startsWith('data:video')) {
        await _downloadVideoWithOverlays(mediaUrl, post);
      } else {
        await _downloadImageWithOverlays(mediaUrl, post);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading: \\${e}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingShare = false;
        });
      }
    }
  }

  Future<void> _downloadImageWithOverlays(String imageUrl, Map<String, dynamic> post) async {
    try {
      final String? processedFilePath = await LocalMediaProcessingService.processImageWithOverlays(
        imageUrl: imageUrl,
        post: post,
        userUsageType: context.findAncestorStateOfType<HomeScreenState>()?.userUsageType ?? '',
        userName: context.findAncestorStateOfType<HomeScreenState>()?.userName ?? '',
        userProfilePhotoUrl: context.findAncestorStateOfType<HomeScreenState>()?.userProfilePhotoUrl,
        userAddress: context.findAncestorStateOfType<HomeScreenState>()?.userAddress ?? '',
        userPhoneNumber: context.findAncestorStateOfType<HomeScreenState>()?.userPhoneNumber ?? '',
        userCity: context.findAncestorStateOfType<HomeScreenState>()?.userCity ?? '',
      );
      if (processedFilePath != null) {
        final hasPermission = await _requestStoragePermission();
        if (hasPermission) {
          final downloadsDir = await _getDownloadsDirectory();
          if (downloadsDir != null) {
            final String fileName = 'PrimeStatus_WithOverlays_${DateTime.now().millisecondsSinceEpoch}.png';
            final String filePath = '${downloadsDir.path}/$fileName';
            final File sourceFile = File(processedFilePath);
            final File destFile = File(filePath);
            await sourceFile.copy(destFile.path);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image with overlays saved successfully!'),
                duration: Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Share',
                  onPressed: () async {
                    try {
                      await Share.shareXFiles([XFile(filePath)]);
                    } catch (e) {}
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download image: \\${e}')),
      );
    }
  }

  Future<void> _downloadVideoWithOverlays(String videoUrl, Map<String, dynamic> post) async {
    try {
      // Always use full video for downloads, skip dialog
      final String processingMethod = 'full_video';
      String? processedFilePath;
      
      processedFilePath = await LocalMediaProcessingService.processVideoWithOverlays(
        videoUrl: videoUrl,
        post: post,
        userUsageType: context.findAncestorStateOfType<HomeScreenState>()?.userUsageType ?? '',
        userName: context.findAncestorStateOfType<HomeScreenState>()?.userName ?? '',
        userProfilePhotoUrl: context.findAncestorStateOfType<HomeScreenState>()?.userProfilePhotoUrl,
        userAddress: context.findAncestorStateOfType<HomeScreenState>()?.userAddress ?? '',
        userPhoneNumber: context.findAncestorStateOfType<HomeScreenState>()?.userPhoneNumber ?? '',
        userCity: context.findAncestorStateOfType<HomeScreenState>()?.userCity ?? '',
      );
      
      if (processedFilePath != null) {
        final hasPermission = await _requestStoragePermission();
        if (hasPermission) {
          final downloadsDir = await _getDownloadsDirectory();
          if (downloadsDir != null) {
            final String fileName = 'PrimeStatus_Video_${DateTime.now().millisecondsSinceEpoch}.mp4';
            final String filePath = '${downloadsDir.path}/$fileName';
            final File sourceFile = File(processedFilePath);
            final File destFile = File(filePath);
            await sourceFile.copy(destFile.path);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Video saved successfully!'),
                  duration: Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'Share',
                    onPressed: () async {
                      try {
                        await Share.shareXFiles([XFile(filePath)]);
                      } catch (e) {}
                    },
                  ),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not access downloads directory')),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Storage permission required to download videos')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to process video for download')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading video: \\${e}')),
        );
      }
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      if (sdkInt >= 33) {
        // Android 13+ uses photos permission
        var status = await Permission.photos.status;
        if (status.isDenied) {
          status = await Permission.photos.request();
        }
        if (status.isPermanentlyDenied) {
          if (mounted) {
            _showPermissionSettingsDialog('Photos');
          }
        }
        return status.isGranted;
      } else if (sdkInt >= 30) {
        // Android 11+ uses manage external storage
        var status = await Permission.manageExternalStorage.status;
        if (status.isDenied) {
          status = await Permission.manageExternalStorage.request();
        }
        if (status.isPermanentlyDenied) {
          if (mounted) {
            _showPermissionSettingsDialog('Storage');
          }
        }
        return status.isGranted;
      } else {
        // Android 10 and below uses storage permission
        var status = await Permission.storage.status;
        if (status.isDenied) {
          status = await Permission.storage.request();
        }
        if (status.isPermanentlyDenied) {
          if (mounted) {
            _showPermissionSettingsDialog('Storage');
          }
        }
        return status.isGranted;
      }
    } else {
      // iOS doesn't need explicit storage permission for app documents
      return true;
    }
  }

  void _showPermissionSettingsDialog(String permissionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Required'),
        content: Text(
          'Storage permission is required to download files. Please enable it in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<Directory?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
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
      return await getExternalStorageDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  void _showSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Download Feature'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To download images, you need a premium subscription.'),
            SizedBox(height: 16),
            Text('Premium features include:'),
            Text('• HD downloads'),
            Text('• No watermarks'),
            Text('• Unlimited downloads'),
            Text('• Priority support'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSubscriptionScreen();
            },
            child: Text('Get Premium'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionScreen(),
      ),
    );
  }

  void _showProfilePhotoDialog() {
    final homeScreenState = context.findAncestorStateOfType<HomeScreenState>();
    final userUsageType = homeScreenState?.userUsageType ?? '';
    final userAddress = homeScreenState?.userAddress ?? '';
    final userPhoneNumber = homeScreenState?.userPhoneNumber ?? '';
    final userCity = homeScreenState?.userCity ?? '';
    
    // Check if business user needs to complete profile
    if (userUsageType == 'Business' && !_hasCompleteBusinessInfo()) {
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
              // Current profile photo
              // Text(
              //   'Current Profile Photo',
              //   style: TextStyle(fontWeight: FontWeight.bold),
              // ),
              // SizedBox(height: 8),
              // CircleAvatar(
              //   radius: 40,
              //   backgroundImage: (context.findAncestorStateOfType<HomeScreenState>()?.userProfilePhotoUrl != null)
              //       ? NetworkImage(context.findAncestorStateOfType<HomeScreenState>()!.userProfilePhotoUrl!)
              //       : null,
              //   child: (context.findAncestorStateOfType<HomeScreenState>()?.userProfilePhotoUrl == null)
              //       ? Icon(Icons.person, size: 40)
              //       : null,
              // ),
              
              // Business Information (if Business user)
              // if (userUsageType == 'Business')
              //   Container(
              //     margin: EdgeInsets.only(top: 16),
              //     padding: EdgeInsets.all(12),
              //     decoration: BoxDecoration(
              //       color: Colors.blue.shade50,
              //       borderRadius: BorderRadius.circular(8),
              //       border: Border.all(color: Colors.blue.shade200),
              //     ),
              //     child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         Row(
              //           children: [
              //             Icon(Icons.business, color: Colors.blue.shade700, size: 16),
              //             SizedBox(width: 8),
              //             Text(
              //               'Business Information',
              //               style: TextStyle(
              //                 fontWeight: FontWeight.bold,
              //                 color: Colors.blue.shade700,
              //               ),
              //             ),
              //           ],
              //         ),
              //         SizedBox(height: 8),
              //         if (userAddress.isNotEmpty)
              //           Row(
              //             children: [
              //               Icon(Icons.location_on, color: Colors.grey.shade600, size: 14),
              //               SizedBox(width: 4),
              //               Expanded(
              //                 child: Text(
              //                   userAddress,
              //                   style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              //                 ),
              //               ),
              //             ],
              //           ),
              //         if (userPhoneNumber.isNotEmpty)
              //           Row(
              //             children: [
              //               Icon(Icons.phone, color: Colors.grey.shade600, size: 14),
              //               SizedBox(width: 4),
              //               Text(
              //                 userPhoneNumber,
              //                 style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              //               ),
              //             ],
              //           ),
              //         if (userCity.isNotEmpty)
              //           Row(
              //             children: [
              //               Icon(Icons.location_city, color: Colors.grey.shade600, size: 14),
              //               SizedBox(width: 4),
              //               Text(
              //                 userCity,
              //                 style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              //               ),
              //             ],
              //           ),
              //         if (userAddress.isEmpty || userPhoneNumber.isEmpty || userCity.isEmpty)
              //           Container(
              //             margin: EdgeInsets.only(top: 8),
              //             padding: EdgeInsets.all(8),
              //             decoration: BoxDecoration(
              //               color: Colors.orange.shade50,
              //               borderRadius: BorderRadius.circular(4),
              //               border: Border.all(color: Colors.orange.shade200),
              //             ),
              //             child: Row(
              //               children: [
              //                 Icon(Icons.info, color: Colors.orange.shade700, size: 14),
              //                 SizedBox(width: 4),
              //                 Expanded(
              //                   child: Text(
              //                     'Complete your business profile to display contact info on posts',
              //                     style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
              //                   ),
              //                 ),
              //               ],
              //             ),
              //           ),
              //       ],
              //     ),
              //   ),
              
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

  Widget _buildProfilePhotoGallery() {
    // Get user's profile photos from home screen state
    final homeScreenState = context.findAncestorStateOfType<HomeScreenState>();
    final userProfilePhotos = homeScreenState?.userProfilePhotos ?? [];
    
    if (userProfilePhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No profile photos yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first profile photo!',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
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
      itemCount: userProfilePhotos.length,
      itemBuilder: (context, index) {
        final photoDoc = userProfilePhotos[index];
        final photoUrl = photoDoc['photoUrl'] as String?;
        final photoUrlNoBg = photoDoc['photoUrlNoBg'] as String?;
        final isActive = photoUrl == homeScreenState?.userProfilePhotoUrl || photoUrlNoBg == homeScreenState?.userProfilePhotoUrl;
        return Row(
          children: [
            if (photoUrl != null)
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectProfilePhotoFromGallery(photoUrl),
                  onLongPress: () => _showDeletePhotoDialog(photoUrl, index),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive && homeScreenState?.userProfilePhotoUrl == photoUrl ? Colors.green : Colors.grey.shade300,
                        width: isActive && homeScreenState?.userProfilePhotoUrl == photoUrl ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            memCacheWidth: 150, // Optimize for gallery thumbnails
                            memCacheHeight: 150,
                            maxWidthDiskCache: 150,
                            maxHeightDiskCache: 150,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: Center(child: CircularProgressIndicator(color: Colors.blue)),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.person, size: 30, color: Colors.grey),
                            ),
                            cacheManager: DefaultCacheManager(),
                          ),
                          if (isActive && homeScreenState?.userProfilePhotoUrl == photoUrl)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: GestureDetector(
                              onTap: () => _showDeletePhotoDialog(photoUrl, index),
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
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
                  onLongPress: () => _showDeletePhotoDialog(photoUrlNoBg, index),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive && homeScreenState?.userProfilePhotoUrl == photoUrlNoBg ? Colors.green : Colors.grey.shade300,
                        width: isActive && homeScreenState?.userProfilePhotoUrl == photoUrlNoBg ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: photoUrlNoBg,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            memCacheWidth: 150, // Optimize for gallery thumbnails
                            memCacheHeight: 150,
                            maxWidthDiskCache: 150,
                            maxHeightDiskCache: 150,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: Center(child: CircularProgressIndicator(color: Colors.blue)),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.person, size: 30, color: Colors.grey),
                            ),
                            cacheManager: DefaultCacheManager(),
                          ),
                          if (isActive && homeScreenState?.userProfilePhotoUrl == photoUrlNoBg)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: GestureDetector(
                              onTap: () => _showDeletePhotoDialog(photoUrlNoBg, index),
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
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
    if (_userService.currentUser == null) return;
    
    try {
      // Update the profile photo URL in Firestore directly
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userService.currentUser!.uid)
          .update({
        'profilePhotoUrl': photoUrl,
      });
      
      // Update active status in profile photos collection
      final photosSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userService.currentUser!.uid)
          .collection('profilePhotos')
          .get();
      
      for (var doc in photosSnapshot.docs) {
        await doc.reference.update({
          'isActive': doc.data()['photoUrl'] == photoUrl,
        });
      }
      
      // Update Firebase Auth profile
      await _userService.updateAuthProfilePhoto(photoUrl);
      
      // Refresh the home screen state to update UI
      final homeScreenState = context.findAncestorStateOfType<HomeScreenState>();
      if (homeScreenState != null) {
        // Refresh user data to update UI
        await homeScreenState.refreshUserData();
      }
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile photo updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile photo: $e')),
      );
    }
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
      setState(() {
        _isLoading = true;
      });

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
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile photo added successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add profile photo: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickPhotoWithBgRemoval() async {
    if (_userService.currentUser == null) return;
    
    try {
      setState(() {
        _isLoading = true;
      });

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
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile photo added successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add profile photo: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  void _showDeletePhotoDialog(String photoUrl, int index) {
    final homeScreenState = context.findAncestorStateOfType<HomeScreenState>();
    final isActive = photoUrl == homeScreenState?.userProfilePhotoUrl;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Profile Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive 
                ? 'This is your current profile photo. Are you sure you want to delete it?'
                : 'Are you sure you want to delete this profile photo?',
            ),
            SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProfilePhoto(photoUrl, index);
            },
            child: Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProfilePhoto(String photoUrl, int index) async {
    if (_userService.currentUser == null) return;
    
    try {
      // Get the document ID for this photo
      final photosSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userService.currentUser!.uid)
          .collection('profilePhotos')
          .where('photoUrl', isEqualTo: photoUrl)
          .get();
      
      if (photosSnapshot.docs.isNotEmpty) {
        // Delete from Firestore
        await photosSnapshot.docs.first.reference.delete();
        
        // If this was the active photo, clear the main profile photo
        final homeScreenState = context.findAncestorStateOfType<HomeScreenState>();
        if (photoUrl == homeScreenState?.userProfilePhotoUrl) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_userService.currentUser!.uid)
              .update({
            'profilePhotoUrl': null,
          });
          
          // Clear Firebase Auth profile photo
          await _userService.updateAuthProfilePhoto('');
        }
        
        // Refresh the home screen state
        if (homeScreenState != null) {
          await homeScreenState.refreshUserData();
        }
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile photo deleted successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete profile photo: $e')),
      );
    }
  }

  // Navigate to fullscreen post viewer
  void _navigateToFullscreen(Map<String, dynamic> post, String action) {
    // Pause all video controllers before navigating
    VideoControllerManager().pauseAllControllers();
    VideoControllerManager().setFullscreenMode(true);
    
    // Get current posts list and find the index of this post
    final homeScreenState = context.findAncestorStateOfType<HomeScreenState>();
    if (homeScreenState == null) return;
    
    // Get posts from the current StreamBuilder context
    final postsSnapshot = _getFilteredPostsStream().first;
    postsSnapshot.then((snapshot) {
      final posts = snapshot.docs.map((doc) {
        Map<String, dynamic> postData = doc.data() as Map<String, dynamic>;
        postData['id'] = doc.id; // Add document ID to post data
        return postData;
      }).toList();
      if (posts.isEmpty) return;
      
      // Find the index of the current post
      final postIndex = posts.indexWhere((p) => p['id'] == post['id'] || p['mainImage'] == post['mainImage']);
      final index = postIndex >= 0 ? postIndex : 0;
      
      // Navigate to fullscreen viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullscreenPostViewer(
            posts: posts,
            initialIndex: index,
            userUsageType: homeScreenState.userUsageType ?? '',
            userName: homeScreenState.userName ?? 'User',
            userProfilePhotoUrl: homeScreenState.userProfilePhotoUrl,
            userAddress: homeScreenState.userAddress ?? '',
            userPhoneNumber: homeScreenState.userPhoneNumber ?? '',
            userCity: homeScreenState.userCity ?? '',
          ),
        ),
      ).then((_) {
        // Resume video controllers when returning from fullscreen
        VideoControllerManager().setFullscreenMode(false);
      });
    });
  }

  // Check if business user has complete information
  bool _hasCompleteBusinessInfo() {
    final homeScreenState = context.findAncestorStateOfType<HomeScreenState>();
    if (homeScreenState?.userUsageType != 'Business') return false;
    
    final hasAddress = (homeScreenState?.userAddress ?? '').isNotEmpty;
    final hasPhone = (homeScreenState?.userPhoneNumber ?? '').isNotEmpty;
    final hasCity = (homeScreenState?.userCity ?? '').isNotEmpty;
    
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
              // Navigate to profile tab
              final homeScreenState = context.findAncestorStateOfType<HomeScreenState>();
              if (homeScreenState != null) {
                Navigator.pushNamed(context, '/profile');
              }
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

  // Build profile photo with background removal for post overlays
  Widget _buildProfilePhoto(String photoUrl) {
    return CachedNetworkImage(
      imageUrl: photoUrl,
      fit: BoxFit.cover,
      memCacheWidth: 200, // Optimize for profile photos
      memCacheHeight: 200,
      maxWidthDiskCache: 200,
      maxHeightDiskCache: 200,
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
        child: Center(child: CircularProgressIndicator(color: Colors.blue)),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[200],
        child: Icon(Icons.person, color: Colors.grey),
      ),
      cacheManager: DefaultCacheManager(),
    );
  }

  // Process profile photo background removal
  Future<void> _processProfilePhotoBackground(String photoUrl) async {
    try {
      // Get the current user's profile photo without background
      String? processedUrl = await _userService.getCurrentProfilePhotoWithoutBackground();
      
      if (processedUrl != null) {
        setState(() {
          _processedProfilePhotos[photoUrl] = processedUrl;
        });
      }
    } catch (e) {
      print('Error processing profile photo background: $e');
    }
  }

  // Show video processing options dialog (copied from fullscreen_post_viewer.dart)
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
              'Choose how you want to process your video:',
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
    _controllerKey = 'base64_${DateTime.now().millisecondsSinceEpoch}_${widget.bytes.hashCode}';
    _controller = VideoPlayerController.networkUrl(Uri.parse('data:video/mp4;base64,${base64Encode(widget.bytes)}'));
    VideoControllerManager().registerController(_controllerKey, _controller);
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      _controller.setVolume(1.0); // Always sound on
      _controller.play();
      setState(() {});
    });
  }

  @override
  void dispose() {
    VideoControllerManager().unregisterController(_controllerKey);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(_controllerKey),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        if (info.visibleFraction > 0.5) {
          if (_controller.value.isInitialized && !_controller.value.isPlaying) {
            _controller.play();
          }
        } else {
          if (_controller.value.isInitialized && _controller.value.isPlaying) {
            _controller.pause();
          }
        }
      },
      child: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            );
          } else {
            return Center(child: CircularProgressIndicator(color: Colors.blue));
          }
        },
      ),
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
    _controllerKey = 'network_${DateTime.now().millisecondsSinceEpoch}_${widget.url.hashCode}';
    _controller = VideoPlayerController.network(widget.url);
    VideoControllerManager().registerController(_controllerKey, _controller);
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      _controller.setVolume(1.0); // Always sound on
      _controller.play();
      setState(() {});
    });
  }

  @override
  void dispose() {
    VideoControllerManager().unregisterController(_controllerKey);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(_controllerKey),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        if (info.visibleFraction > 0.5) {
          if (_controller.value.isInitialized && !_controller.value.isPlaying) {
            _controller.play();
          }
        } else {
          if (_controller.value.isInitialized && _controller.value.isPlaying) {
            _controller.pause();
          }
        }
      },
      child: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            );
          } else {
            return Center(child: CircularProgressIndicator(color: Colors.blue));
          }
        },
      ),
    );
  }
}

class AdminPostFeedWidgetHelpers {
  static Widget buildMainImage(String imageUrl, {BoxFit fit = BoxFit.cover}) {
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
    } else if (isVideoUrl(imageUrl)) {
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
          color: Colors.grey[200],
          child: Icon(Icons.error, color: Colors.grey),
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
          color: Colors.grey[200],
          child: Center(child: CircularProgressIndicator(color: Colors.blue)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[200],
          child: Icon(Icons.error, color: Colors.grey),
        ),
        cacheManager: DefaultCacheManager(),
      );
    } else {
      return Container(
        color: Colors.grey[200],
        child: Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
      );
    }
  }

  static bool isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.mov', '.webm', '.avi', '.mkv', '.ogg'];
    return url.startsWith('http') && videoExtensions.any((ext) => url.toLowerCase().contains(ext));
  }

  static Color parseColor(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    if (hexColor.length == 6) hexColor = 'FF$hexColor';
    return Color(int.parse('0x$hexColor'));
  }

  static Widget buildProfilePhotoWithoutBackground(String photoUrl) {
    return CachedNetworkImage(
      imageUrl: photoUrl,
      fit: BoxFit.cover,
      memCacheWidth: 200, // Optimize for profile photos
      memCacheHeight: 200,
      maxWidthDiskCache: 200,
      maxHeightDiskCache: 200,
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
        child: Center(child: CircularProgressIndicator(color: Colors.blue)),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[200],
        child: Icon(Icons.person, color: Colors.grey),
      ),
      cacheManager: DefaultCacheManager(),
    );
  }

  static void showShareOptions(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Not available in preview mode')),
    );
  }
  static void showSubscriptionDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Not available in preview mode')),
    );
  }
  static void showProfilePhotoDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Not available in preview mode')),
    );
  }

  static Widget buildPostCardStatic(BuildContext context, Map<String, dynamic> post) {
    final String imageUrl = post['mainImage'] ?? post['imageUrl'] ?? '';
    final textSettings = post['textSettings'] ?? {};
    final profileSettings = post['profileSettings'] ?? {};
    final addressSettings = post['addressSettings'] ?? {};
    final phoneSettings = post['phoneSettings'] ?? {};
    final frameSize = post['frameSize'] ?? {'width': 1080, 'height': 1920};
    final String userName = (context.findAncestorStateOfType<HomeScreenState>()?.userName ?? 'User');
    final String? userProfilePhotoUrl = (context.findAncestorStateOfType<HomeScreenState>()?.userProfilePhotoUrl);
    final String userUsageType = (context.findAncestorStateOfType<HomeScreenState>()?.userUsageType ?? '');
    final String userAddress = (context.findAncestorStateOfType<HomeScreenState>()?.userAddress ?? '');
    final String userPhoneNumber = (context.findAncestorStateOfType<HomeScreenState>()?.userPhoneNumber ?? '');
    final String userCity = (context.findAncestorStateOfType<HomeScreenState>()?.userCity ?? '');

    return _buildPostCardStaticInternal(
      context, 
      post, 
      imageUrl, 
      textSettings, 
      profileSettings, 
      addressSettings, 
      phoneSettings,
      userName,
      userProfilePhotoUrl,
      userUsageType,
      userAddress,
      userPhoneNumber,
      userCity,
      frameSize,
    );
  }

  static Widget buildPostCardStaticWithUserData(
    BuildContext context, 
    Map<String, dynamic> post, {
    required String userUsageType,
    required String userName,
    String? userProfilePhotoUrl,
    required String userAddress,
    required String userPhoneNumber,
    required String userCity,
  }) {
    final String imageUrl = post['mainImage'] ?? post['imageUrl'] ?? '';
    final textSettings = post['textSettings'] ?? {};
    final profileSettings = post['profileSettings'] ?? {};
    final addressSettings = post['addressSettings'] ?? {};
    final phoneSettings = post['phoneSettings'] ?? {};
    final frameSize = post['frameSize'] ?? {'width': 1080, 'height': 1920};

    return _buildPostCardStaticInternal(
      context, 
      post, 
      imageUrl, 
      textSettings, 
      profileSettings, 
      addressSettings, 
      phoneSettings,
      userName,
      userProfilePhotoUrl,
      userUsageType,
      userAddress,
      userPhoneNumber,
      userCity,
      frameSize,
    );
  }

  static Widget _buildPostCardStaticInternal(
    BuildContext context,
    Map<String, dynamic> post,
    String imageUrl,
    Map<String, dynamic> textSettings,
    Map<String, dynamic> profileSettings,
    Map<String, dynamic> addressSettings,
    Map<String, dynamic> phoneSettings,
    String userName,
    String? userProfilePhotoUrl,
    String userUsageType,
    String userAddress,
    String userPhoneNumber,
    String userCity,
    Map<String, dynamic> frameSize,
  ) {

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final double aspectRatio = frameSize['width'] / frameSize['height'];
            final double height = width / aspectRatio;

            final double textXBase = (textSettings['x'] ?? 50) / 100 * width;
            final double textY = (textSettings['y'] ?? 90) / 100 * height;
            final double profileX = (profileSettings['x'] ?? 20) / 100 * width;
            final double profileY = (profileSettings['y'] ?? 20) / 100 * height;
            final double profileSize = (profileSettings['size'] ?? 80).toDouble();
            final double addressXBase = (addressSettings['x'] ?? 50) / 100 * width;
            final double addressY = (addressSettings['y'] ?? 80) / 100 * height;
            final double phoneX = (phoneSettings['x'] ?? 50) / 100 * width;
            final double phoneY = (phoneSettings['y'] ?? 85) / 100 * height;
            final double textX = userName.length > 15 ? textXBase + 30 : textXBase;
            final double addressX = userAddress.length > 15 ? addressXBase + 45 : addressXBase;

            return SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: buildMainImage(imageUrl, fit: BoxFit.contain),
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
                                  color: parseColor(textSettings['backgroundColor'] ?? '#000000'),
                                  borderRadius: BorderRadius.circular(8),
                                )
                              : null,
                          child: Text(
                            userName.length > 15 ? userName : userName,
                            style: TextStyle(
                              fontFamily: textSettings['font'] ?? 'Arial',
                              fontSize: (textSettings['fontSize'] ?? 24).toDouble() * (userName.length > 15 ? 1 : 1.0),
                              color: parseColor(textSettings['color'] ?? '#ffffff'),
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
                                  color: parseColor(addressSettings['backgroundColor'] ?? '#000000'),
                                  borderRadius: BorderRadius.circular(8),
                                )
                              : null,
                          child: Text(
                            userAddress.length > 15 ? userAddress : userAddress,
                            style: TextStyle(
                              fontFamily: addressSettings['font'] ?? 'Arial',
                              fontSize: (addressSettings['fontSize'] ?? 18).toDouble() * (userAddress.length > 15 ? 1 : 1.0),
                              color: parseColor(addressSettings['color'] ?? '#ffffff'),
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
                                  color: parseColor(phoneSettings['backgroundColor'] ?? '#000000'),
                                  borderRadius: BorderRadius.circular(8),
                                )
                              : null,
                          child: Text(  
                            userPhoneNumber.length > 15 ? userPhoneNumber : userPhoneNumber,
                            style: TextStyle(
                              fontFamily: phoneSettings['font'] ?? 'Arial',
                              fontSize: (phoneSettings['fontSize'] ?? 18).toDouble() * (userPhoneNumber.length > 15 ? 1 : 1.0),
                              color: parseColor(phoneSettings['color'] ?? '#ffffff'),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (profileSettings['enabled'] == true && userProfilePhotoUrl != null && userProfilePhotoUrl.isNotEmpty)
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
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            profileSettings['shape'] == 'circle'
                                ? profileSize / 2
                                : 8,
                          ),
                          child: buildProfilePhotoWithoutBackground(userProfilePhotoUrl),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        Container(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                flex: 45,
                child: ElevatedButton.icon(
                  onPressed: () => showShareOptions(context),
                  icon: Icon(Icons.share, color: Colors.white),
                  label: Text('Share', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 45,
                child: ElevatedButton.icon(
                  onPressed: () => showSubscriptionDialog(context),
                  icon: Icon(Icons.download, color: Colors.white),
                  label: Text('Download', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 19,
                child: ElevatedButton(
                  onPressed: () => showProfilePhotoDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Center(child: Icon(Icons.person, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 