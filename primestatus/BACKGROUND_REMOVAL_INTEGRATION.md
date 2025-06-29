# Background Removal Integration

This document explains the integration of background removal functionality into the PrimeStatus Flutter app.

## Overview

The app now includes automatic background removal for profile photos using the hosted API at `https://bgremoval.iaks.site`. This allows users to have profile pictures without backgrounds that blend seamlessly with the app's design.

## Features

### 1. Automatic Background Removal
- Profile photos are automatically processed to remove backgrounds
- Uses the `rembg` library via the hosted API
- Supports both gallery and camera photo capture

### 2. Profile Photo Gallery
- Users can have multiple profile photos
- Each photo is processed with background removal
- Easy switching between different profile photos

### 3. Real-time Processing
- Background removal happens in real-time when adding new photos
- Loading indicators show processing status
- Fallback to original photo if processing fails

## Implementation Details

### Services

#### BackgroundRemovalService (`lib/services/background_removal_service.dart`)
- Handles all API calls to the background removal service
- Supports file upload and URL processing
- Includes timeout handling and error management
- Methods:
  - `removeBackground(File imageFile)` - Process local file
  - `removeBackgroundFromUrl(String imageUrl)` - Process network image
  - `pickImageAndRemoveBackground()` - Pick from gallery and process
  - `takePhotoAndRemoveBackground()` - Take photo and process
  - `isServiceAvailable()` - Check service status

#### UserService (`lib/services/user_service.dart`)
- Enhanced with background removal functionality
- New methods:
  - `uploadProfilePhotoWithBgRemoval()` - Upload with background removal
  - `getProfilePhotoWithoutBackground()` - Get processed profile photo
  - `addProfilePhotoToGalleryWithBgRemoval()` - Add to gallery with processing

### Widgets

#### AdminPostFeedWidget (`lib/widgets/admin_post_feed_widget.dart`)
- Displays profile photos without backgrounds in post overlays
- Caches processed photos for better performance
- Shows loading indicators during processing
- Enhanced profile photo management with background removal

#### HomeScreen (`lib/screens/home_screen.dart`)
- Updated profile photo handling
- Loading overlays during processing
- Enhanced user experience with background removal

## API Integration

### Endpoint
- **Base URL**: `https://bgremoval.iaks.site`
- **Remove Background**: `POST /remove-bg/`
- **Download Processed**: `GET /download/{filename}`

### Request Format
```http
POST /remove-bg/
Content-Type: multipart/form-data

file: [image file]
```

### Response Format
```json
{
  "success": true,
  "message": "Background removed successfully",
  "download_url": "/download/filename.png",
  "filename": "filename.png"
}
```

## Usage

### Adding Profile Photos
1. User taps "Profile" button in post feed
2. Selects "Add New Photo" option
3. Chooses between camera or gallery
4. Photo is automatically processed to remove background
5. Processed photo is uploaded to Firebase Storage
6. Photo is added to user's profile photo gallery

### Displaying Profile Photos
1. Profile photos are displayed without backgrounds in post overlays
2. If a photo hasn't been processed yet, it's processed on-demand
3. Processed photos are cached for better performance
4. Fallback to original photo if processing fails

## Error Handling

- **Network Timeouts**: 30-second timeout for API calls
- **Service Unavailable**: Graceful fallback to original photos
- **Processing Failures**: User-friendly error messages
- **File Validation**: Checks for file existence and readability

## Dependencies

Added to `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.1.0
```

## Performance Considerations

- **Caching**: Processed photos are cached to avoid re-processing
- **Image Optimization**: Photos are resized to 1024x1024 max before processing
- **Temporary Files**: Proper cleanup of temporary files
- **Async Processing**: Non-blocking background removal

## Future Enhancements

1. **Batch Processing**: Process multiple photos at once
2. **Quality Settings**: Allow users to choose processing quality
3. **Offline Support**: Cache processed photos for offline use
4. **Custom Backgrounds**: Allow users to add custom backgrounds
5. **AI Enhancement**: Additional AI-powered photo enhancements

## Troubleshooting

### Common Issues

1. **Service Not Available**
   - Check network connectivity
   - Verify API endpoint is accessible
   - Check service status

2. **Processing Timeout**
   - Reduce image size before processing
   - Check network speed
   - Retry the operation

3. **Upload Failures**
   - Check Firebase Storage permissions
   - Verify user authentication
   - Check storage quota

### Debug Information

Enable debug logging by checking console output for:
- API request/response logs
- File processing status
- Error messages and stack traces 