# App Update Management - Admin Panel Setup

This guide explains how to use the new App Update Management section in the admin panel to control app updates for your Flutter app.

## Overview

The App Update Manager allows administrators to:
- Set minimum required app version
- Set latest available app version
- Enable/disable force updates
- Customize update messages and titles
- Configure app store URLs
- Sync settings to Firebase Remote Config

## Accessing the App Update Manager

1. Log in to the admin panel
2. Navigate to **App Updates** in the sidebar
3. The App Update Manager interface will load

## Configuration Options

### Version Settings

#### Minimum Required Version
- **Purpose**: Users below this version will be forced to update
- **Format**: Semantic versioning (e.g., 1.0.0, 1.1.0, 2.0.0)
- **Example**: If set to `1.1.0`, users with version 1.0.0 or lower must update

#### Latest Available Version
- **Purpose**: Latest version available in app stores
- **Format**: Semantic versioning (e.g., 1.0.0, 1.1.0, 2.0.0)
- **Example**: If set to `1.2.0`, users with version 1.1.0 will see optional update

#### Force Update Enabled
- **Purpose**: Makes updates mandatory (cannot be dismissed)
- **When to use**: Critical security fixes, breaking changes
- **Effect**: Removes "Later" button from update dialog

### Update Message Settings

#### Update Title
- **Purpose**: Title shown in the update dialog
- **Examples**: 
  - "Update Available"
  - "New Version Required"
  - "Critical Update"

#### Update Message
- **Purpose**: Detailed message explaining the update
- **Examples**:
  - "A new version with exciting features is available!"
  - "This update includes important security improvements."
  - "Please update to continue using the app."

### App Store URLs

#### Google Play Store URL
- **Purpose**: Direct link to your app on Google Play Store
- **Format**: `https://play.google.com/store/apps/details?id=com.yourcompany.yourapp`
- **Required**: For Android users

#### Apple App Store URL
- **Purpose**: Direct link to your app on Apple App Store
- **Format**: `https://apps.apple.com/app/id1234567890`
- **Required**: For iOS users

## Update Types

### Optional Update
- **Trigger**: Current version < Latest version
- **Behavior**: User can dismiss with "Later" button
- **Frequency**: Shown again after 24 hours
- **Use case**: New features, minor improvements

### Force Update
- **Trigger**: Current version < Minimum required version
- **Behavior**: Cannot be dismissed, must update
- **Frequency**: Shown every time app opens
- **Use case**: Critical bugs, security fixes

### No Update Required
- **Trigger**: Current version >= Latest version
- **Behavior**: No update dialog shown
- **Use case**: User has latest version

## Sync Status

The admin panel shows sync status with Firebase Remote Config:

- **Synced**: Settings are live in Remote Config
- **Not Synced**: Settings are saved locally but not pushed to Remote Config

## How to Use

### 1. Set Up Initial Configuration
1. Enter your current app version in both fields
2. Set appropriate store URLs
3. Write a friendly update message
4. Click **Save & Sync**

### 2. Release a New Version
1. Update **Latest Available Version** to new version (e.g., 1.1.0)
2. Keep **Minimum Required Version** at current version (e.g., 1.0.0)
3. Update the message to highlight new features
4. Click **Save & Sync**

### 3. Force Critical Update
1. Update **Minimum Required Version** to new version (e.g., 1.1.0)
2. Enable **Force Update Enabled**
3. Update message to explain urgency
4. Click **Save & Sync**

### 4. Monitor and Adjust
1. Check sync status regularly
2. Monitor user feedback
3. Adjust update frequency as needed
4. Disable force updates when adoption is high

## Best Practices

### Version Management
- Use semantic versioning consistently
- Test update flow before releasing
- Document changes in update messages

### Update Strategy
- Start with optional updates for new features
- Use force updates sparingly for critical issues
- Give users reasonable time to update

### Communication
- Write clear, friendly update messages
- Explain benefits of updating
- Use appropriate urgency levels

### Monitoring
- Track update adoption rates
- Monitor user feedback
- Adjust strategy based on data

## Troubleshooting

### Common Issues

#### Update Not Showing
- Check if version comparison is correct
- Verify Remote Config sync status
- Ensure app is checking for updates

#### Force Update Not Working
- Verify minimum version is higher than current
- Check if force update is enabled
- Ensure dialog cannot be dismissed

#### Store URLs Not Working
- Test URLs in browser
- Verify app store listings are live
- Check URL format is correct

### Debug Information
- Check browser console for errors
- Verify Firebase Cloud Function logs
- Test with different version combinations

## Security Considerations

- Only authenticated admins can modify settings
- Changes are logged with timestamps
- Remote Config provides additional security layer
- Sensitive data is not exposed to clients

## Support

For issues with the App Update Manager:
1. Check sync status
2. Verify configuration values
3. Test with different versions
4. Check Firebase console logs
5. Contact development team if needed

## Technical Details

### Data Storage
- Settings stored in Firestore (`app_config/update_settings`)
- Synced to Firebase Remote Config
- Backup and audit trail maintained

### Update Flow
1. Admin updates settings in panel
2. Settings saved to Firestore
3. Cloud Function updates Remote Config
4. Flutter app fetches new settings
5. Update dialog shown to users

### Sync Process
1. Validate configuration
2. Save to Firestore
3. Call Cloud Function
4. Update Remote Config template
5. Publish new version
6. Update sync status

This system provides a robust, user-friendly way to manage app updates while maintaining control over the update process.
