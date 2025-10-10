# Firebase Remote Config Setup for App Updates

This guide explains how to configure Firebase Remote Config to manage app updates for your Flutter app.

## Overview

The app update system uses Firebase Remote Config to:
- Control minimum required app version
- Set latest available app version
- Enable/disable force updates
- Customize update messages and titles
- Configure app store URLs

## Firebase Console Setup

### 1. Enable Remote Config

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`prime-status-1db09`)
3. Navigate to **Remote Config** in the left sidebar
4. Click **Get started** if not already enabled

### 2. Add Remote Config Parameters

Add the following parameters in Firebase Console:

#### Required Parameters

| Parameter Key | Value Type | Default Value | Description |
|---------------|------------|---------------|-------------|
| `min_app_version` | String | `1.0.0` | Minimum required app version |
| `latest_app_version` | String | `1.0.0` | Latest available app version |
| `force_update_enabled` | Boolean | `false` | Whether to force users to update |
| `update_title` | String | `Update Available` | Title shown in update dialog |
| `update_message` | String | `A new version of the app is available. Please update to continue using the app.` | Message shown in update dialog |

#### Store URLs (Update with your actual URLs)

| Parameter Key | Value Type | Default Value | Description |
|---------------|------------|---------------|-------------|
| `play_store_url` | String | `https://play.google.com/store/apps/details?id=com.yourcompany.newapp` | Google Play Store URL |
| `app_store_url` | String | `https://apps.apple.com/app/id1234567890` | Apple App Store URL |

### 3. Configure Values

#### For Development/Testing
```
min_app_version: 1.0.0
latest_app_version: 1.0.0
force_update_enabled: false
update_title: "Update Available"
update_message: "A new version of the app is available. Please update to continue using the app."
play_store_url: "https://play.google.com/store/apps/details?id=com.yourcompany.newapp"
app_store_url: "https://apps.apple.com/app/id1234567890"
```

#### For Production Updates
When you want to release a new version (e.g., 1.1.0):

```
min_app_version: 1.0.0  # Keep old version as minimum
latest_app_version: 1.1.0  # Set new version as latest
force_update_enabled: false  # Set to true for critical updates
update_title: "New Version Available"
update_message: "Version 1.1.0 is now available with new features and improvements!"
play_store_url: "https://play.google.com/store/apps/details?id=com.yourcompany.newapp"
app_store_url: "https://apps.apple.com/app/id1234567890"
```

#### For Force Updates
When you need to force users to update (e.g., critical security fix):

```
min_app_version: 1.1.0  # Set minimum to new version
latest_app_version: 1.1.0
force_update_enabled: true  # Force users to update
update_title: "Update Required"
update_message: "This version is no longer supported. Please update to continue using the app."
play_store_url: "https://play.google.com/store/apps/details?id=com.yourcompany.newapp"
app_store_url: "https://apps.apple.com/app/id1234567890"
```

## How It Works

### Version Comparison
The app compares the current installed version with:
1. **Minimum Version**: If current version < minimum version → Force update
2. **Latest Version**: If current version < latest version → Optional update

### Update Flow
1. **App Launch**: Checks for updates on splash screen
2. **Periodic Check**: Checks every 6 hours while app is running
3. **User Dismissal**: Users can dismiss optional updates (not force updates)
4. **Store Redirect**: Tapping "Update Now" opens the appropriate app store

### Update Types

#### Optional Update
- User can dismiss with "Later" button
- Dismissed for 24 hours
- Shown again after 24 hours

#### Force Update
- No "Later" button
- Cannot be dismissed
- User must update to continue using the app

## Testing

### Test Optional Update
1. Set `latest_app_version` to a higher version than current
2. Set `force_update_enabled` to `false`
3. Launch app → Should show optional update dialog
4. Tap "Later" → Should dismiss and not show for 24 hours

### Test Force Update
1. Set `min_app_version` to a higher version than current
2. Set `force_update_enabled` to `true`
3. Launch app → Should show force update dialog
4. No "Later" button → User must update

## Best Practices

### Version Management
- Use semantic versioning (e.g., 1.0.0, 1.1.0, 2.0.0)
- Update `pubspec.yaml` version before releasing
- Test update flow before releasing

### Update Strategy
- Use optional updates for new features
- Use force updates for critical bugs/security fixes
- Give users reasonable time to update before forcing

### Monitoring
- Monitor update adoption rates
- Track user feedback on updates
- Adjust update frequency based on user behavior

## Troubleshooting

### Common Issues

1. **Update not showing**
   - Check if version comparison is working
   - Verify Remote Config values are correct
   - Check if user dismissed update recently

2. **Store URL not working**
   - Verify URLs are correct and accessible
   - Test URLs in browser
   - Check app store listing is live

3. **Force update not working**
   - Verify `force_update_enabled` is `true`
   - Check `min_app_version` is higher than current
   - Ensure dialog cannot be dismissed

### Debug Information
The app logs detailed information about update checks:
- Current app version
- Remote Config values
- Update availability
- User dismissal status

Check console logs for debugging information.

## Security Considerations

- Remote Config values are cached locally
- Values are fetched over HTTPS
- App continues to work even if Remote Config fails
- Default values provide fallback behavior

## Support

For issues with the update system:
1. Check Firebase Console for Remote Config values
2. Verify app version in `pubspec.yaml`
3. Test with different version combinations
4. Check console logs for error messages
