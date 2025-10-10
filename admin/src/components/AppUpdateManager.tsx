import React, { useEffect, useState } from 'react';
import { Save, RefreshCw, AlertTriangle, CheckCircle, Smartphone, Globe, Cloud, CloudOff, TestTube } from 'lucide-react';
import { remoteConfigService } from '../services/remoteConfigService';
import { testRemoteConfigFunction } from '../services/testRemoteConfig';

interface AppUpdateConfig {
  minAppVersion: string;
  latestAppVersion: string;
  forceUpdateEnabled: boolean;
  updateTitle: string;
  updateMessage: string;
  playStoreUrl: string;
  appStoreUrl: string;
}

export default function AppUpdateManager() {
  const [config, setConfig] = useState<AppUpdateConfig>({
    minAppVersion: '1.0.0',
    latestAppVersion: '1.0.0',
    forceUpdateEnabled: false,
    updateTitle: 'Update Available',
    updateMessage: 'A new version of the app is available. Please update to continue using the app.',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.example.newapp',
    appStoreUrl: 'https://apps.apple.com/app/id1234567890'
  });
  
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [testing, setTesting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [syncStatus, setSyncStatus] = useState<{
    synced: boolean;
    lastSyncTime?: string;
    lastUpdated?: string;
  }>({ synced: false });

  // Load configuration from Firestore
  useEffect(() => {
    loadConfig();
  }, []);

  const loadConfig = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const loadedConfig = await remoteConfigService.loadConfig();
      
      if (loadedConfig) {
        setConfig(loadedConfig);
      }
      
      // Load sync status
      const status = await remoteConfigService.getSyncStatus();
      setSyncStatus(status);
      
      setSuccess('Configuration loaded successfully');
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      console.error('Error loading config:', err);
      setError('Failed to load configuration');
      setTimeout(() => setError(null), 5000);
    } finally {
      setLoading(false);
    }
  };

  const saveConfig = async () => {
    try {
      setSaving(true);
      setError(null);
      
      // Validate configuration
      const validation = remoteConfigService.validateConfig(config);
      if (!validation.isValid) {
        setError(`Validation failed: ${validation.errors.join(', ')}`);
        setTimeout(() => setError(null), 5000);
        return;
      }
      
      // Save to Firestore
      const success = await remoteConfigService.syncToRemoteConfig(config);
      
      if (success) {
        setSuccess('Configuration saved and synced to Remote Config successfully!');
        // Reload sync status
        const status = await remoteConfigService.getSyncStatus();
        setSyncStatus(status);
      } else {
        setError('Configuration saved locally but failed to sync to Remote Config');
      }
      
      setTimeout(() => setSuccess(null), 5000);
    } catch (err) {
      console.error('Error saving config:', err);
      setError('Failed to save configuration');
      setTimeout(() => setError(null), 5000);
    } finally {
      setSaving(false);
    }
  };

  const syncToRemoteConfig = async () => {
    try {
      setSyncing(true);
      setError(null);
      
      // Validate configuration
      const validation = remoteConfigService.validateConfig(config);
      if (!validation.isValid) {
        setError(`Validation failed: ${validation.errors.join(', ')}`);
        setTimeout(() => setError(null), 5000);
        return;
      }
      
      const success = await remoteConfigService.syncToRemoteConfig(config);
      
      if (success) {
        setSuccess('Successfully synced to Remote Config!');
        // Reload sync status
        const status = await remoteConfigService.getSyncStatus();
        setSyncStatus(status);
      } else {
        setError('Failed to sync to Remote Config');
      }
      
      setTimeout(() => setSuccess(null), 5000);
    } catch (err) {
      console.error('Error syncing to Remote Config:', err);
      setError('Failed to sync to Remote Config');
      setTimeout(() => setError(null), 5000);
    } finally {
      setSyncing(false);
    }
  };

  const testRemoteConfig = async () => {
    try {
      setTesting(true);
      setError(null);
      
      const result = await testRemoteConfigFunction();
      
      setSuccess('Test function executed successfully! Check console for details.');
      setTimeout(() => setSuccess(null), 5000);
    } catch (err) {
      console.error('Test failed:', err);
      setError(`Test failed: ${err instanceof Error ? err.message : 'Unknown error'}`);
      setTimeout(() => setError(null), 5000);
    } finally {
      setTesting(false);
    }
  };

  const handleInputChange = (field: keyof AppUpdateConfig, value: string | boolean) => {
    setConfig(prev => ({
      ...prev,
      [field]: value
    }));
  };

  const validateVersion = (version: string): boolean => {
    const versionRegex = /^\d+\.\d+\.\d+$/;
    return versionRegex.test(version);
  };

  const getUpdateType = (): string => {
    if (config.forceUpdateEnabled) {
      return 'Force Update';
    }
    if (config.minAppVersion !== config.latestAppVersion) {
      return 'Optional Update';
    }
    return 'No Update Required';
  };

  const getUpdateTypeColor = (): string => {
    if (config.forceUpdateEnabled) {
      return 'text-red-600 bg-red-50';
    }
    if (config.minAppVersion !== config.latestAppVersion) {
      return 'text-orange-600 bg-orange-50';
    }
    return 'text-green-600 bg-green-50';
  };

  return (
    <div className="p-6 max-w-4xl mx-auto">
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center space-x-3 mb-2">
          <div className="w-10 h-10 rounded-full flex items-center justify-center bg-gradient-to-r from-orange-500 to-purple-600">
            <Smartphone className="h-5 w-5 text-white" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-gray-800">App Update Manager</h1>
            <p className="text-gray-600">Manage app version updates and update prompts</p>
          </div>
        </div>
        
        {/* Status Indicator */}
        <div className="flex items-center space-x-4 mt-4">
          <div className={`px-3 py-1 rounded-full text-sm font-medium ${getUpdateTypeColor()}`}>
            {getUpdateType()}
          </div>
          <div className="text-sm text-gray-500">
            Min: {config.minAppVersion} | Latest: {config.latestAppVersion}
          </div>
          <div className={`flex items-center space-x-1 px-2 py-1 rounded-full text-xs ${
            syncStatus.synced ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'
          }`}>
            {syncStatus.synced ? <Cloud className="h-3 w-3" /> : <CloudOff className="h-3 w-3" />}
            <span>{syncStatus.synced ? 'Synced' : 'Not Synced'}</span>
          </div>
        </div>
      </div>

      {/* Error/Success Messages */}
      {error && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg flex items-center space-x-2">
          <AlertTriangle className="h-5 w-5 text-red-500" />
          <span className="text-red-700">{error}</span>
        </div>
      )}

      {success && (
        <div className="mb-6 p-4 bg-green-50 border border-green-200 rounded-lg flex items-center space-x-2">
          <CheckCircle className="h-5 w-5 text-green-500" />
          <span className="text-green-700">{success}</span>
        </div>
      )}

      {/* Configuration Form */}
      <div className="bg-white rounded-lg shadow-lg p-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Version Settings */}
          <div className="space-y-4">
            <h3 className="text-lg font-semibold text-gray-800 border-b border-gray-200 pb-2">
              Version Settings
            </h3>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Minimum Required Version *
              </label>
              <input
                type="text"
                value={config.minAppVersion}
                onChange={(e) => handleInputChange('minAppVersion', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                placeholder="1.0.0"
              />
              <p className="text-xs text-gray-500 mt-1">
                Users below this version will be forced to update
              </p>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Latest Available Version *
              </label>
              <input
                type="text"
                value={config.latestAppVersion}
                onChange={(e) => handleInputChange('latestAppVersion', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                placeholder="1.1.0"
              />
              <p className="text-xs text-gray-500 mt-1">
                Latest version available in app stores
              </p>
            </div>

            <div className="flex items-center space-x-3">
              <input
                type="checkbox"
                id="forceUpdate"
                checked={config.forceUpdateEnabled}
                onChange={(e) => handleInputChange('forceUpdateEnabled', e.target.checked)}
                className="w-4 h-4 text-orange-600 border-gray-300 rounded focus:ring-orange-500"
              />
              <label htmlFor="forceUpdate" className="text-sm font-medium text-gray-700">
                Force Update (Cannot be dismissed)
              </label>
            </div>
          </div>

          {/* Update Message Settings */}
          <div className="space-y-4">
            <h3 className="text-lg font-semibold text-gray-800 border-b border-gray-200 pb-2">
              Update Message
            </h3>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Update Title *
              </label>
              <input
                type="text"
                value={config.updateTitle}
                onChange={(e) => handleInputChange('updateTitle', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                placeholder="Update Available"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Update Message *
              </label>
              <textarea
                value={config.updateMessage}
                onChange={(e) => handleInputChange('updateMessage', e.target.value)}
                rows={4}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                placeholder="A new version of the app is available..."
              />
            </div>
          </div>
        </div>

        {/* Store URLs */}
        <div className="mt-6 pt-6 border-t border-gray-200">
          <h3 className="text-lg font-semibold text-gray-800 mb-4 flex items-center space-x-2">
            <Globe className="h-5 w-5" />
            <span>App Store URLs</span>
          </h3>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Google Play Store URL *
              </label>
              <input
                type="url"
                value={config.playStoreUrl}
                onChange={(e) => handleInputChange('playStoreUrl', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                placeholder="https://play.google.com/store/apps/details?id=..."
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Apple App Store URL *
              </label>
              <input
                type="url"
                value={config.appStoreUrl}
                onChange={(e) => handleInputChange('appStoreUrl', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                placeholder="https://apps.apple.com/app/id..."
              />
            </div>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="mt-8 flex items-center justify-between pt-6 border-t border-gray-200">
          <button
            onClick={loadConfig}
            disabled={loading}
            className="flex items-center space-x-2 px-4 py-2 text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors disabled:opacity-50"
          >
            <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
            <span>Reload</span>
          </button>

          <div className="flex items-center space-x-3">
            <button
              onClick={testRemoteConfig}
              disabled={testing}
              className="flex items-center space-x-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50"
            >
              <TestTube className={`h-4 w-4 ${testing ? 'animate-pulse' : ''}`} />
              <span>{testing ? 'Testing...' : 'Test Function'}</span>
            </button>

            <button
              onClick={syncToRemoteConfig}
              disabled={syncing || !validateVersion(config.minAppVersion) || !validateVersion(config.latestAppVersion)}
              className="flex items-center space-x-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
            >
              <Cloud className={`h-4 w-4 ${syncing ? 'animate-pulse' : ''}`} />
              <span>{syncing ? 'Syncing...' : 'Sync to Remote Config'}</span>
            </button>

            <button
              onClick={saveConfig}
              disabled={saving || !validateVersion(config.minAppVersion) || !validateVersion(config.latestAppVersion)}
              className="flex items-center space-x-2 px-6 py-2 bg-gradient-to-r from-orange-500 to-purple-600 text-white rounded-lg hover:from-orange-600 hover:to-purple-700 transition-all disabled:opacity-50"
            >
              <Save className={`h-4 w-4 ${saving ? 'animate-pulse' : ''}`} />
              <span>{saving ? 'Saving...' : 'Save & Sync'}</span>
            </button>
          </div>
        </div>
      </div>

      {/* Help Section */}
      <div className="mt-8 bg-blue-50 border border-blue-200 rounded-lg p-6">
        <h3 className="text-lg font-semibold text-blue-800 mb-3">How It Works</h3>
        <div className="space-y-2 text-sm text-blue-700">
          <p><strong>Optional Update:</strong> Users can dismiss the update and continue using the app.</p>
          <p><strong>Force Update:</strong> Users must update to continue using the app.</p>
          <p><strong>Version Format:</strong> Use semantic versioning (e.g., 1.0.0, 1.1.0, 2.0.0)</p>
          <p><strong>Store URLs:</strong> Make sure URLs point to your actual app listings.</p>
        </div>
      </div>
    </div>
  );
}
