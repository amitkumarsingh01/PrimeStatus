import 'package:flutter/material.dart';
import 'package:newapp/services/app_update_service.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final VoidCallback? onDismiss;

  const UpdateDialog({
    Key? key,
    required this.updateInfo,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent dismissing if it's a force update
        return !updateInfo.isForceUpdate;
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App icon or update icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.system_update,
                  size: 32,
                  color: Colors.deepOrange,
                ),
              ),
              const SizedBox(height: 16),
              
              // Title
              Text(
                updateInfo.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                updateInfo.message,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Version info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Current: ${updateInfo.currentVersion}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Latest: ${updateInfo.latestVersion}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  // Dismiss button (only show if not force update)
                  if (!updateInfo.isForceUpdate) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDismiss?.call();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Later',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  
                  // Update button
                  Expanded(
                    flex: updateInfo.isForceUpdate ? 1 : 1,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await AppUpdateService().launchAppStore();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Update Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to show update dialog
Future<void> showUpdateDialog(
  BuildContext context,
  UpdateInfo updateInfo, {
  VoidCallback? onDismiss,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: !updateInfo.isForceUpdate,
    builder: (BuildContext context) {
      return UpdateDialog(
        updateInfo: updateInfo,
        onDismiss: onDismiss,
      );
    },
  );
}

/// Helper function to check and show update dialog if needed
Future<void> checkAndShowUpdateDialog(BuildContext context) async {
  try {
    final updateService = AppUpdateService();
    await updateService.initialize();
    
    final updateInfo = await updateService.checkForUpdate();
    
    if (updateInfo != null) {
      final shouldShow = await updateService.shouldShowUpdate(updateInfo);
      
      if (shouldShow && context.mounted) {
        await showUpdateDialog(
          context,
          updateInfo,
          onDismiss: () async {
            await updateService.dismissUpdate(updateInfo);
          },
        );
      }
    }
  } catch (e) {
    print('❌ Error checking and showing update dialog: $e');
  }
}
