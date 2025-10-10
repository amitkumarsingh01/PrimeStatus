import { httpsCallable } from 'firebase/functions';
import { db, functions } from '../firebase';
import { doc, getDoc, setDoc } from 'firebase/firestore';

interface AppUpdateConfig {
  minAppVersion: string;
  latestAppVersion: string;
  forceUpdateEnabled: boolean;
  updateTitle: string;
  updateMessage: string;
  playStoreUrl: string;
  appStoreUrl: string;
}

export class RemoteConfigService {
  private functions = functions;

  /**
   * Sync app update configuration to Firebase Remote Config
   */
  async syncToRemoteConfig(config: AppUpdateConfig): Promise<boolean> {
    try {
      console.log('🔄 Syncing app update config to Remote Config...');
      
      // First, save to Firestore for backup and admin access
      await setDoc(doc(db, 'app_config', 'update_settings'), {
        ...config,
        lastUpdated: new Date().toISOString(),
        updatedBy: 'admin',
        syncedToRemoteConfig: false
      });

      // Prepare Remote Config parameters
      const remoteConfigParams = {
        min_app_version: config.minAppVersion,
        latest_app_version: config.latestAppVersion,
        force_update_enabled: config.forceUpdateEnabled,
        update_title: config.updateTitle,
        update_message: config.updateMessage,
        play_store_url: config.playStoreUrl,
        app_store_url: config.appStoreUrl
      };

      // Call Cloud Function to update Remote Config
      const updateRemoteConfig = httpsCallable(this.functions, 'updateRemoteConfig');
      
      console.log('Calling updateRemoteConfig with params:', remoteConfigParams);
      
      const result = await updateRemoteConfig({
        parameters: remoteConfigParams
      });

      console.log('updateRemoteConfig result:', result);

      if (result.data.success) {
        // Update Firestore to mark as synced
        await setDoc(doc(db, 'app_config', 'update_settings'), {
          ...config,
          lastUpdated: new Date().toISOString(),
          updatedBy: 'admin',
          syncedToRemoteConfig: true,
          remoteConfigSyncTime: new Date().toISOString()
        }, { merge: true });

        console.log('✅ Successfully synced to Remote Config');
        return true;
      } else {
        console.error('❌ Failed to sync to Remote Config:', result.data.error);
        return false;
      }
    } catch (error) {
      console.error('❌ Error syncing to Remote Config:', error);
      return false;
    }
  }

  /**
   * Load app update configuration from Firestore
   */
  async loadConfig(): Promise<AppUpdateConfig | null> {
    try {
      const configDoc = await getDoc(doc(db, 'app_config', 'update_settings'));
      
      if (configDoc.exists()) {
        const data = configDoc.data();
        return {
          minAppVersion: data.minAppVersion || '1.0.0',
          latestAppVersion: data.latestAppVersion || '1.0.0',
          forceUpdateEnabled: data.forceUpdateEnabled || false,
          updateTitle: data.updateTitle || 'Update Available',
          updateMessage: data.updateMessage || 'A new version of the app is available. Please update to continue using the app.',
          playStoreUrl: data.playStoreUrl || 'https://play.google.com/store/apps/details?id=com.example.newapp',
          appStoreUrl: data.appStoreUrl || 'https://apps.apple.com/app/id1234567890'
        };
      }
      
      return null;
    } catch (error) {
      console.error('❌ Error loading config:', error);
      return null;
    }
  }

  /**
   * Get sync status from Firestore
   */
  async getSyncStatus(): Promise<{
    synced: boolean;
    lastSyncTime?: string;
    lastUpdated?: string;
  }> {
    try {
      const configDoc = await getDoc(doc(db, 'app_config', 'update_settings'));
      
      if (configDoc.exists()) {
        const data = configDoc.data();
        return {
          synced: data.syncedToRemoteConfig || false,
          lastSyncTime: data.remoteConfigSyncTime,
          lastUpdated: data.lastUpdated
        };
      }
      
      return { synced: false };
    } catch (error) {
      console.error('❌ Error getting sync status:', error);
      return { synced: false };
    }
  }

  /**
   * Validate configuration before syncing
   */
  validateConfig(config: AppUpdateConfig): { isValid: boolean; errors: string[] } {
    const errors: string[] = [];

    // Validate version format
    const versionRegex = /^\d+\.\d+\.\d+$/;
    if (!versionRegex.test(config.minAppVersion)) {
      errors.push('Minimum version must be in format X.Y.Z (e.g., 1.0.0)');
    }
    if (!versionRegex.test(config.latestAppVersion)) {
      errors.push('Latest version must be in format X.Y.Z (e.g., 1.0.0)');
    }

    // Validate URLs
    try {
      new URL(config.playStoreUrl);
    } catch {
      errors.push('Google Play Store URL is not valid');
    }

    try {
      new URL(config.appStoreUrl);
    } catch {
      errors.push('Apple App Store URL is not valid');
    }

    // Validate required fields
    if (!config.updateTitle.trim()) {
      errors.push('Update title is required');
    }
    if (!config.updateMessage.trim()) {
      errors.push('Update message is required');
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }
}

export const remoteConfigService = new RemoteConfigService();
