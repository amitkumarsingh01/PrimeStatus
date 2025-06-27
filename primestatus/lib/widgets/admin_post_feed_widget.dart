import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_post_service.dart';
import '../services/user_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../screens/home_screen.dart';

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
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final double height = constraints.maxHeight;

            // Calculate overlay positions in pixels
            final double textX = (textSettings['x'] ?? 50) / 100 * width;
            final double textY = (textSettings['y'] ?? 90) / 100 * height;
            final double profileX = (profileSettings['x'] ?? 20) / 100 * width;
            final double profileY = (profileSettings['y'] ?? 20) / 100 * height;
            final double profileSize = (profileSettings['size'] ?? 80).toDouble();

            return Stack(
              children: [
                // Main image fills the card
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: Icon(Icons.error, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
                          ),
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
            );
          },
        ),
      ),
    );
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
} 