import 'package:flutter/material.dart';
import '../services/video_processing_service.dart';

/// Example demonstrating how to use video sharing with overlays
class VideoSharingExample extends StatefulWidget {
  @override
  _VideoSharingExampleState createState() => _VideoSharingExampleState();
}

class _VideoSharingExampleState extends State<VideoSharingExample> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Sharing Example'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Video Sharing with Overlays',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'This example shows how to share videos with user information overlays.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 30),
            
            // Example 1: Full Video Processing
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _processFullVideo(),
              icon: Icon(Icons.video_file),
              label: Text('Process Full Video with Overlays'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.all(16),
              ),
            ),
            SizedBox(height: 16),
            
            // Example 2: Thumbnail Processing
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _processThumbnail(),
              icon: Icon(Icons.image),
              label: Text('Create Thumbnail with Overlays'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.all(16),
              ),
            ),
            SizedBox(height: 30),
            
            if (_isProcessing)
              Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing video... Please wait'),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _processFullVideo() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Example video URL (replace with your actual video URL)
      final String videoUrl = 'https://example.com/sample-video.mp4';
      
      // Example post data with overlay settings
      final Map<String, dynamic> post = {
        'frameSize': {'width': 1080, 'height': 1920},
        'textSettings': {
          'x': 50,
          'y': 90,
          'fontSize': 24,
          'color': '#ffffff',
          'font': 'Arial',
          'hasBackground': true,
          'backgroundColor': '#000000',
        },
        'profileSettings': {
          'enabled': true,
          'x': 20,
          'y': 20,
          'size': 80,
          'shape': 'circle',
          'hasBackground': true,
        },
        'addressSettings': {
          'enabled': true,
          'x': 50,
          'y': 80,
          'fontSize': 18,
          'color': '#ffffff',
          'hasBackground': true,
          'backgroundColor': '#000000',
        },
        'phoneSettings': {
          'enabled': true,
          'x': 50,
          'y': 85,
          'fontSize': 18,
          'color': '#ffffff',
          'hasBackground': true,
          'backgroundColor': '#000000',
        },
      };

      // Process the video
      final String? processedVideoPath = await VideoProcessingService.processVideoWithOverlays(
        videoUrl: videoUrl,
        post: post,
        userUsageType: 'Business',
        userName: 'John Doe',
        userProfilePhotoUrl: 'https://example.com/profile.jpg',
        userAddress: '123 Main Street, City',
        userPhoneNumber: '+1-234-567-8900',
        userCity: 'New York',
      );

      if (processedVideoPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video processed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        print('Processed video saved at: $processedVideoPath');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process video'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processThumbnail() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Example video URL (replace with your actual video URL)
      final String videoUrl = 'https://example.com/sample-video.mp4';
      
      // Example post data with overlay settings
      final Map<String, dynamic> post = {
        'frameSize': {'width': 1080, 'height': 1920},
        'textSettings': {
          'x': 50,
          'y': 90,
          'fontSize': 24,
          'color': '#ffffff',
          'font': 'Arial',
          'hasBackground': true,
          'backgroundColor': '#000000',
        },
        'profileSettings': {
          'enabled': true,
          'x': 20,
          'y': 20,
          'size': 80,
          'shape': 'circle',
          'hasBackground': true,
        },
        'addressSettings': {
          'enabled': true,
          'x': 50,
          'y': 80,
          'fontSize': 18,
          'color': '#ffffff',
          'hasBackground': true,
          'backgroundColor': '#000000',
        },
        'phoneSettings': {
          'enabled': true,
          'x': 50,
          'y': 85,
          'fontSize': 18,
          'color': '#ffffff',
          'hasBackground': true,
          'backgroundColor': '#000000',
        },
      };

      // Create thumbnail with overlay
      final String? thumbnailPath = await VideoProcessingService.createVideoThumbnailWithOverlay(
        videoUrl: videoUrl,
        post: post,
        userUsageType: 'Business',
        userName: 'John Doe',
        userProfilePhotoUrl: 'https://example.com/profile.jpg',
        userAddress: '123 Main Street, City',
        userPhoneNumber: '+1-234-567-8900',
        userCity: 'New York',
      );

      if (thumbnailPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thumbnail created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        print('Thumbnail saved at: $thumbnailPath');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create thumbnail'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
} 