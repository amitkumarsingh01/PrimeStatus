import 'package:flutter/material.dart';
import 'admin_post_feed_widget.dart';

class FullscreenPostViewer extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final int initialIndex;

  const FullscreenPostViewer({
    Key? key,
    required this.posts,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<FullscreenPostViewer> createState() => _FullscreenPostViewerState();
}

class _FullscreenPostViewerState extends State<FullscreenPostViewer> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.posts.length,
        itemBuilder: (context, index) {
          final post = widget.posts[index];
          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Material(
                  color: Colors.transparent,
                  child: AdminPostFullScreenCard(post: post),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdminPostFullScreenCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const AdminPostFullScreenCard({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use the same _buildPostCard logic but without Card and margin, and with full width/height
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 9 / 16,
          child: AdminPostFeedWidgetHelpers.buildPostCardStatic(context, post),
        ),
      ],
    );
  }
} 