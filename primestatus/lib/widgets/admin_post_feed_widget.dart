import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_post_service.dart';
import '../services/user_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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
    final String postId = post['id'] ?? '';
    final String title = post['title'] ?? '';
    final String content = post['content'] ?? '';
    final String imageUrl = post['imageUrl'] ?? '';
    final String category = post['category'] ?? '';
    final String language = post['language'] ?? '';
    final int likes = post['likes'] ?? 0;
    final int shares = post['shares'] ?? 0;
    final bool isLiked = post['isLiked'] ?? false;
    final Timestamp? createdAt = post['createdAt'];
    final String? adminName = post['adminName'] ?? 'Admin';
    final String? adminPhotoUrl = post['adminPhotoUrl'];

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Admin info header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.purple.shade100,
                  backgroundImage: adminPhotoUrl != null
                      ? CachedNetworkImageProvider(adminPhotoUrl)
                      : null,
                  child: adminPhotoUrl == null
                      ? Icon(Icons.admin_panel_settings, color: Colors.purple)
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminName ?? 'Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          _formatTimestamp(createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handlePostAction(value, postId),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share, size: 20),
                          SizedBox(width: 8),
                          Text('Share'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.report, size: 20),
                          SizedBox(width: 8),
                          Text('Report'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Post image
          if (imageUrl.isNotEmpty)
            Container(
              width: double.infinity,
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
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
                ),
              ),
            ),

          // Post content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                ],
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 12),
                
                // Category and language tags
                Row(
                  children: [
                    if (category.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: Colors.purple,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (category.isNotEmpty && language.isNotEmpty)
                      SizedBox(width: 8),
                    if (language.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          language,
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Like button
                InkWell(
                  onTap: () => _toggleLike(postId),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.grey,
                        size: 24,
                      ),
                      SizedBox(width: 4),
                      Text(
                        likes.toString(),
                        style: TextStyle(
                          color: isLiked ? Colors.red : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 24),
                
                // Share button
                InkWell(
                  onTap: () => _sharePost(postId),
                  child: Row(
                    children: [
                      Icon(Icons.share, color: Colors.grey, size: 24),
                      SizedBox(width: 4),
                      Text(
                        shares.toString(),
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(),
                
                // Create design button
                ElevatedButton.icon(
                  onPressed: () => _createDesignFromPost(post),
                  icon: Icon(Icons.create, size: 18),
                  label: Text('Create Design'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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