import React, { useState, useEffect } from 'react';
import { Copy, Check, Save, Link as LinkIcon, ExternalLink, Share2 } from 'lucide-react';
import { db } from '../firebase';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

export default function ShareLink() {
  const [shareLink, setShareLink] = useState('');
  const [isCopied, setIsCopied] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');
  const [errorMessage, setErrorMessage] = useState('');

  // Default share link - you can change this to your actual app link
  const defaultShareLink = 'https://play.google.com/store/apps/details?id=com.primestatus.app';

  useEffect(() => {
    loadShareLink();
  }, []);

  const loadShareLink = async () => {
    setIsLoading(true);
    try {
      const shareLinkDoc = await getDoc(doc(db, 'settings', 'shareLink'));
      if (shareLinkDoc.exists()) {
        setShareLink(shareLinkDoc.data().url || defaultShareLink);
      } else {
        // If no share link exists, create one with default
        await setDoc(doc(db, 'settings', 'shareLink'), {
          url: defaultShareLink,
          createdAt: new Date(),
          updatedAt: new Date()
        });
        setShareLink(defaultShareLink);
      }
    } catch (error) {
      console.error('Error loading share link:', error);
      setErrorMessage('Failed to load share link');
      setShareLink(defaultShareLink);
    } finally {
      setIsLoading(false);
    }
  };

  const saveShareLink = async () => {
    if (!shareLink.trim()) {
      setErrorMessage('Please enter a valid link');
      return;
    }

    setIsSaving(true);
    setErrorMessage('');
    setSuccessMessage('');

    try {
      await updateDoc(doc(db, 'settings', 'shareLink'), {
        url: shareLink.trim(),
        updatedAt: new Date()
      });
      setSuccessMessage('Share link saved successfully!');
    } catch (error) {
      console.error('Error saving share link:', error);
      setErrorMessage('Failed to save share link');
    } finally {
      setIsSaving(false);
    }
  };

  const copyToClipboard = async () => {
    try {
      await navigator.clipboard.writeText(shareLink);
      setIsCopied(true);
      setTimeout(() => setIsCopied(false), 2000);
    } catch (error) {
      console.error('Failed to copy:', error);
      setErrorMessage('Failed to copy link to clipboard');
    }
  };

  const openLink = () => {
    window.open(shareLink, '_blank');
  };

  const resetToDefault = () => {
    setShareLink(defaultShareLink);
    setErrorMessage('');
    setSuccessMessage('');
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50 p-6">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="bg-white rounded-2xl shadow-xl p-8 mb-8">
          <div className="flex items-center space-x-4 mb-6">
            <div className="w-12 h-12 rounded-full flex items-center justify-center bg-gradient-to-r from-blue-500 to-purple-600">
              <Share2 className="h-6 w-6 text-white" />
            </div>
            <div>
              <h1 className="text-3xl font-bold text-gray-800">Share Link</h1>
              <p className="text-gray-600">Manage your app's shareable link</p>
            </div>
          </div>

          {/* Instructions */}
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
            <h3 className="text-sm font-semibold text-blue-800 mb-2 flex items-center">
              <LinkIcon className="h-4 w-4 mr-2" />
              How to use this link:
            </h3>
            <ul className="text-sm text-blue-700 space-y-1">
              <li>• Share this link with users to download your app</li>
              <li>• Use it in social media posts and marketing materials</li>
              <li>• The link will be available to all users in the app</li>
            </ul>
          </div>
        </div>

        {/* Main Content */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Link Management */}
          <div className="bg-white rounded-2xl shadow-xl p-8">
            <h2 className="text-xl font-bold text-gray-800 mb-6 flex items-center">
              <LinkIcon className="h-5 w-5 mr-2 text-blue-500" />
              Manage Share Link
            </h2>

            {isLoading ? (
              <div className="flex items-center justify-center py-8">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
                <span className="ml-3 text-gray-600">Loading...</span>
              </div>
            ) : (
              <div className="space-y-6">
                {/* Link Input */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Share Link URL
                  </label>
                  <div className="flex space-x-2">
                    <input
                      type="url"
                      value={shareLink}
                      onChange={(e) => setShareLink(e.target.value)}
                      placeholder="Enter your app's share link"
                      className="flex-1 px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                    <button
                      onClick={openLink}
                      className="px-4 py-3 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                      title="Open link"
                    >
                      <ExternalLink className="h-5 w-5" />
                    </button>
                  </div>
                </div>

                {/* Action Buttons */}
                <div className="flex space-x-3">
                  <button
                    onClick={saveShareLink}
                    disabled={isSaving}
                    className="flex-1 flex items-center justify-center space-x-2 px-6 py-3 bg-gradient-to-r from-blue-500 to-purple-600 text-white rounded-lg hover:from-blue-600 hover:to-purple-700 transition-all duration-200 disabled:opacity-50"
                  >
                    {isSaving ? (
                      <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                    ) : (
                      <Save className="h-4 w-4" />
                    )}
                    <span>{isSaving ? 'Saving...' : 'Save Link'}</span>
                  </button>
                  <button
                    onClick={resetToDefault}
                    className="px-6 py-3 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                  >
                    Reset
                  </button>
                </div>

                {/* Messages */}
                {successMessage && (
                  <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
                    <p className="text-green-700 text-sm">{successMessage}</p>
                  </div>
                )}
                {errorMessage && (
                  <div className="p-4 bg-red-50 border border-red-200 rounded-lg">
                    <p className="text-red-700 text-sm">{errorMessage}</p>
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Link Preview */}
          <div className="bg-white rounded-2xl shadow-xl p-8">
            <h2 className="text-xl font-bold text-gray-800 mb-6 flex items-center">
              <ExternalLink className="h-5 w-5 mr-2 text-green-500" />
              Link Preview
            </h2>

            <div className="space-y-4">
              {/* Current Link Display */}
              <div className="bg-gray-50 rounded-lg p-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Current Share Link:
                </label>
                <div className="flex items-center space-x-2">
                  <div className="flex-1 bg-white border border-gray-200 rounded-lg px-3 py-2">
                    <p className="text-sm text-gray-800 break-all">{shareLink || 'No link set'}</p>
                  </div>
                  <button
                    onClick={copyToClipboard}
                    className="px-3 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
                    title="Copy link"
                  >
                    {isCopied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                  </button>
                </div>
              </div>

              {/* Link Status */}
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <h3 className="text-sm font-semibold text-blue-800 mb-2">Link Status</h3>
                <div className="space-y-2 text-sm text-blue-700">
                  <div className="flex items-center space-x-2">
                    <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                    <span>Link is active and ready to share</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <div className="w-2 h-2 bg-blue-500 rounded-full"></div>
                    <span>Users can access this link from the app</span>
                  </div>
                </div>
              </div>

              {/* Quick Actions */}
              <div className="bg-gray-50 rounded-lg p-4">
                <h3 className="text-sm font-semibold text-gray-800 mb-3">Quick Actions</h3>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    onClick={copyToClipboard}
                    className="flex items-center justify-center space-x-2 px-3 py-2 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
                  >
                    <Copy className="h-4 w-4 text-gray-600" />
                    <span className="text-sm text-gray-700">Copy Link</span>
                  </button>
                  <button
                    onClick={openLink}
                    className="flex items-center justify-center space-x-2 px-3 py-2 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
                  >
                    <ExternalLink className="h-4 w-4 text-gray-600" />
                    <span className="text-sm text-gray-700">Open Link</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Usage Statistics */}
        <div className="bg-white rounded-2xl shadow-xl p-8 mt-8">
          <h2 className="text-xl font-bold text-gray-800 mb-6">Link Usage</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="text-center p-4 bg-blue-50 rounded-lg">
              <div className="text-2xl font-bold text-blue-600">Active</div>
              <div className="text-sm text-gray-600">Link Status</div>
            </div>
            <div className="text-center p-4 bg-green-50 rounded-lg">
              <div className="text-2xl font-bold text-green-600">Ready</div>
              <div className="text-sm text-gray-600">For Sharing</div>
            </div>
            <div className="text-center p-4 bg-purple-50 rounded-lg">
              <div className="text-2xl font-bold text-purple-600">24/7</div>
              <div className="text-sm text-gray-600">Available</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
