# Video Sharing with Overlays - Prime Status

This document explains how to implement video sharing with overlays in your Flutter app.

## Overview

The video sharing functionality allows users to share videos with their personal information (name, profile photo, address, phone number) overlaid on the video content. This is particularly useful for business users who want to brand their shared content.

## Features

- **Full Video Processing**: Process entire videos with overlays using FFmpeg
- **Thumbnail Generation**: Create thumbnails with overlays for faster sharing
- **Multiple Overlay Types**: Text, profile photos, address, and phone number overlays
- **Customizable Positioning**: Overlay positions are configurable via percentage coordinates
- **Background Support**: Optional background colors for text overlays
- **Shape Options**: Circular or rectangular profile photo overlays

## Dependencies

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  # Video Processing
  ffmpeg_kit_flutter: ^6.0.3
  video_thumbnail: ^0.5.3
  
  # Existing dependencies
  screenshot: ^3.0.0
  share_plus: ^7.2.1
  path_provider: ^2.1.1
  permission_handler: ^11.1.0
  http: ^1.1.0
```

## Implementation

### 1. Video Processing Service

The `VideoProcessingService` handles all video processing operations:

```dart
import '../services/video_processing_service.dart';

// Process full video with overlays
final String? processedVideoPath = await VideoProcessingService.processVideoWithOverlays(
  videoUrl: 'https://example.com/video.mp4',
  post: postData,
  userUsageType: 'Business',
  userName: 'John Doe',
  userProfilePhotoUrl: 'https://example.com/profile.jpg',
  userAddress: '123 Main Street',
  userPhoneNumber: '+1-234-567-8900',
  userCity: 'New York',
);

// Create thumbnail with overlay
final String? thumbnailPath = await VideoProcessingService.createVideoThumbnailWithOverlay(
  videoUrl: 'https://example.com/video.mp4',
  post: postData,
  userUsageType: 'Business',
  userName: 'John Doe',
  userProfilePhotoUrl: 'https://example.com/profile.jpg',
  userAddress: '123 Main Street',
  userPhoneNumber: '+1-234-567-8900',
  userCity: 'New York',
);
```

### 2. Post Data Structure

The overlay configuration is defined in the post data:

```dart
final Map<String, dynamic> post = {
  'frameSize': {'width': 1080, 'height': 1920},
  'textSettings': {
    'x': 50,           // X position (percentage)
    'y': 90,           // Y position (percentage)
    'fontSize': 24,
    'color': '#ffffff',
    'font': 'Arial',
    'hasBackground': true,
    'backgroundColor': '#000000',
  },
  'profileSettings': {
    'enabled': true,
    'x': 20,           // X position (percentage)
    'y': 20,           // Y position (percentage)
    'size': 80,        // Size in pixels
    'shape': 'circle', // 'circle' or 'rectangle'
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
```

### 3. Integration with FullscreenPostViewer

The `FullscreenPostViewer` automatically detects videos and provides sharing options:

```dart
// In your FullscreenPostViewer widget
void _showShareOptions(Map<String, dynamic> post) {
  final String imageUrl = post['mainImage'] ?? post['imageUrl'] ?? '';
  
  // Check if it's a video
  if (_isVideoUrl(imageUrl) || imageUrl.startsWith('data:video')) {
    _shareVideoWithOverlays(imageUrl, post);
  } else {
    _shareToWhatsApp(imageUrl, post);
  }
}
```

## Usage Examples

### Basic Video Sharing

```dart
// Share a video with overlays
Future<void> shareVideo() async {
  final String? processedPath = await VideoProcessingService.processVideoWithOverlays(
    videoUrl: 'https://example.com/video.mp4',
    post: postData,
    userUsageType: 'Business',
    userName: 'John Doe',
    userProfilePhotoUrl: 'https://example.com/profile.jpg',
    userAddress: '123 Main Street',
    userPhoneNumber: '+1-234-567-8900',
    userCity: 'New York',
  );

  if (processedPath != null) {
    await Share.shareXFiles([XFile(processedPath)]);
  }
}
```

### Thumbnail Sharing

```dart
// Create and share a thumbnail
Future<void> shareThumbnail() async {
  final String? thumbnailPath = await VideoProcessingService.createVideoThumbnailWithOverlay(
    videoUrl: 'https://example.com/video.mp4',
    post: postData,
    userUsageType: 'Business',
    userName: 'John Doe',
    userProfilePhotoUrl: 'https://example.com/profile.jpg',
    userAddress: '123 Main Street',
    userPhoneNumber: '+1-234-567-8900',
    userCity: 'New York',
  );

  if (thumbnailPath != null) {
    await Share.shareXFiles([XFile(thumbnailPath)]);
  }
}
```

## Configuration Options

### Overlay Positioning

All overlay positions use percentage coordinates (0-100):
- `x: 50` = center horizontally
- `y: 90` = near bottom vertically

### Text Overlay Settings

```dart
'textSettings': {
  'x': 50,                    // X position (percentage)
  'y': 90,                    // Y position (percentage)
  'fontSize': 24,             // Font size in pixels
  'color': '#ffffff',         // Text color (hex)
  'font': 'Arial',            // Font family
  'hasBackground': true,      // Show background
  'backgroundColor': '#000000', // Background color (hex)
}
```

### Profile Photo Settings

```dart
'profileSettings': {
  'enabled': true,            // Enable/disable overlay
  'x': 20,                    // X position (percentage)
  'y': 20,                    // Y position (percentage)
  'size': 80,                 // Size in pixels
  'shape': 'circle',          // 'circle' or 'rectangle'
  'hasBackground': true,      // Show white background
}
```

## Technical Details

### FFmpeg Commands Used

1. **Video Overlay**: Overlays an image on a video
```bash
ffmpeg -i input.mp4 -i overlay.png -filter_complex "[1:v]format=rgba,colorchannelmixer=aa=0.8[overlay];[0:v][overlay]overlay=0:0" -c:a copy output.mp4
```

2. **Thumbnail Extraction**: Extracts a frame from video
```bash
ffmpeg -i input.mp4 -ss 00:00:01 -vframes 1 -q:v 2 thumbnail.jpg
```

3. **Image Overlay**: Combines two images
```bash
ffmpeg -i thumbnail.jpg -i overlay.png -filter_complex "[1:v]format=rgba,colorchannelmixer=aa=0.8[overlay];[0:v][overlay]overlay=0:0" output.png
```

### File Management

- Temporary files are automatically cleaned up
- Processed files are saved to device storage
- Files are deleted after sharing to save space

### Performance Considerations

- **Full Video Processing**: Takes longer but provides complete video with overlays
- **Thumbnail Processing**: Faster alternative for quick sharing
- **Memory Usage**: Large videos may require significant memory
- **Storage**: Processed videos can be large

## Error Handling

The service includes comprehensive error handling:

```dart
try {
  final String? result = await VideoProcessingService.processVideoWithOverlays(...);
  if (result != null) {
    // Success
  } else {
    // Processing failed
  }
} catch (e) {
  // Handle specific errors
  print('Error: $e');
}
```

## Platform Support

- **Android**: Full support with FFmpeg
- **iOS**: Full support with FFmpeg
- **Web**: Limited support (may require server-side processing)

## Troubleshooting

### Common Issues

1. **FFmpeg not found**: Ensure FFmpeg is properly installed
2. **Permission denied**: Request storage permissions
3. **Large file sizes**: Consider using thumbnail option for large videos
4. **Memory issues**: Process videos in smaller chunks

### Debug Information

Enable debug logging to troubleshoot issues:

```dart
// Check FFmpeg logs
final session = await FFmpegKit.execute(command);
final logs = await session.getLogsAsString();
print('FFmpeg logs: $logs');
```

## Future Enhancements

- **Animated Overlays**: Support for animated text and graphics
- **Multiple Overlay Layers**: Support for multiple overlay images
- **Custom Fonts**: Support for custom font files
- **Video Filters**: Add video effects and filters
- **Batch Processing**: Process multiple videos at once

## Support

For issues and questions:
1. Check the example code in `lib/examples/video_sharing_example.dart`
2. Review FFmpeg documentation for advanced commands
3. Test with different video formats and sizes
4. Monitor memory usage on target devices 