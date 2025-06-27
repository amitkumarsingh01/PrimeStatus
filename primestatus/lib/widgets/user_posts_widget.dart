import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_post_service.dart';
import '../services/user_service.dart';

class UserPostsWidget extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userPhotoUrl;

  const UserPostsWidget({
    Key? key,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
  }) : super(key: key);

  @override
  _UserPostsWidgetState createState() => _UserPostsWidgetState();
}

class _UserPostsWidgetState extends State<UserPostsWidget>
    with SingleTickerProviderStateMixin {
  final AdminPostService _adminPostService = AdminPostService();
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(25),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(25),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[600],
            tabs: [
              Tab(text: 'My Posts'),
              Tab(text: 'Liked Posts'),
            ],
          ),
        ),
        
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUserPosts(),
              _buildLikedPosts(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserPosts() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _adminPostService.getUserAdminPosts(widget.userId),
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
                Icon(Icons.post_add, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  'Start creating posts to see them here',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildPostCard(post, true);
          },
        );
      },
    );
  }

  Widget _buildLikedPosts() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _adminPostService.getUserLikedAdminPosts(widget.userId),
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
                  'Error loading liked posts',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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
                Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No liked posts yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  'Like posts to see them here',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildPostCard(post, false);
          },
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, bool isUserPost) {
    final String imageUrl = post['imageUrl'] ?? '';
    final String title = post['title'] ?? '';
    final String content = post['content'] ?? '';
    final int likes = post['likes'] ?? 0;
    final int shares = post['shares'] ?? 0;
    final Timestamp? createdAt = post['createdAt'];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[200],
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(Icons.error, color: Colors.grey),
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.image, size: 48, color: Colors.grey),
                    ),
            ),
          ),
          
          // Content
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty) ...[
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                  ],
                  Text(
                    content,
                    style: TextStyle(fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Spacer(),
                  
                  // Stats
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 12, color: Colors.red),
                      SizedBox(width: 2),
                      Text(
                        likes.toString(),
                        style: TextStyle(fontSize: 10),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.share, size: 12, color: Colors.grey),
                      SizedBox(width: 2),
                      Text(
                        shares.toString(),
                        style: TextStyle(fontSize: 10),
                      ),
                      Spacer(),
                      if (isUserPost)
                        Icon(Icons.edit, size: 12, color: Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 