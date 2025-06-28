import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_post_service.dart';
import '../services/user_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../screens/home_screen.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart' show launchUrl, canLaunchUrl, LaunchMode;
import 'package:video_player/video_player.dart';
import 'dart:typed_data';

class AdminPostFeedWidget extends StatefulWidget {
  final String? category;
  final String? language;

  const AdminPostFeedWidget({
    Key? key,
    this.category,
    this.language,
  }) : super(key: key);

  @override
  _AdminPostFeedWidgetState createState() => _AdminPostFeedWidgetState();
}

class _AdminPostFeedWidgetState extends State<AdminPostFeedWidget> {
  final AdminPostService _adminPostService = AdminPostService();
  final UserService _userService = UserService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _adminPostService.getAdminPostsWithUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Error loading posts',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        List<Map<String, dynamic>> posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.feed_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No posts available',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  'Check back later for new content',
                  style: TextStyle(color: Colors.grey[500]),
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
            padding: EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _buildPostCard(post);
            },
          ),
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final String imageUrl = post['mainImage'] ?? post['imageUrl'] ?? '';
    final textSettings = post['textSettings'] ?? {};
    final profileSettings = post['profileSettings'] ?? {};
    final String userName = (context.findAncestorStateOfType<HomeScreenState>()?.userName ?? 'User');
    final String? userProfilePhotoUrl = (context.findAncestorStateOfType<HomeScreenState>()?.userProfilePhotoUrl);

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          // Set height to 1.777 * width (16:9 aspect ratio)
          final double height = width * 1.777;

          // Calculate overlay positions in pixels
          final double textX = (textSettings['x'] ?? 50) / 100 * width;
          final double textY = (textSettings['y'] ?? 90) / 100 * height;
          final double profileX = (profileSettings['x'] ?? 20) / 100 * width;
          final double profileY = (profileSettings['y'] ?? 20) / 100 * height;
          final double profileSize = (profileSettings['size'] ?? 80).toDouble();

          return SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                // Background fill for empty space
                Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF3E0), // Light orange
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                // Main image centered and contained
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildMainImage(imageUrl, fit: BoxFit.contain),
                  ),
                ),
                // Share and Download buttons (top right)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.share, color: Colors.green[800]),
                        tooltip: 'Share to WhatsApp',
                        onPressed: () => _shareToWhatsApp(imageUrl, post),
                      ),
                      IconButton(
                        icon: Icon(Icons.download, color: Colors.green[800]),
                        tooltip: 'Download & Share to WhatsApp',
                        onPressed: () => _downloadAndShareToWhatsApp(imageUrl, post),
                      ),
                    ],
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
                // Profile photo overlay (current user)
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
                        child: CachedNetworkImage(
                          imageUrl: userProfilePhotoUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
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
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[200],
          child: Icon(Icons.error, color: Colors.grey),
        ),
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

  // Share to WhatsApp (just send image URL or a message)
  Future<void> _shareToWhatsApp(String imageUrl, Map<String, dynamic> post) async {
    String message = 'Check out this post!';
    if (imageUrl.isNotEmpty) {
      message += '\n';
      if (imageUrl.startsWith('data:image')) {
        message += '[Image attached]';
      } else {
        message += imageUrl;
      }
    }
    final whatsappUrl = Uri.parse('https://wa.me/?text=' + Uri.encodeComponent(message));
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open WhatsApp.')),
      );
    }
  }

  // Download (simulate) and share to WhatsApp
  Future<void> _downloadAndShareToWhatsApp(String imageUrl, Map<String, dynamic> post) async {
    // For simplicity, just share as above (downloading to gallery requires more permissions and plugins)
    await _shareToWhatsApp(imageUrl, post);
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

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse('data:video/mp4;base64,${widget.bytes}'));
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      _controller.setVolume(1.0); // Always sound on
      _controller.play();
      setState(() {});
    });
  }

  @override
  void dispose() {
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

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url);
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      _controller.setVolume(1.0); // Always sound on
      _controller.play();
      setState(() {});
    });
  }

  @override
  void dispose() {
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