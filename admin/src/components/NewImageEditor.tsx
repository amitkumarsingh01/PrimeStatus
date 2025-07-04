import React, { useState, useEffect } from 'react';
import { Plus, Upload, Type, Move, Settings, Save, Eye, Trash2, X } from 'lucide-react';
import { useApp } from '../contexts/AppContext';
import { Post } from '../types';
import { uploadMediaFile } from '../firebase';
import { db } from '../firebase';
import { collection, getDocs, query, orderBy, deleteDoc, doc } from 'firebase/firestore';

interface NewImageEditorProps {
  onOpenEditor: (props: {
    media: string;
    frameSize: { width: number; height: number };
    mediaType: 'image';
    language: 'english' | 'kannada';
    userName: string;
  }) => void;
}

export default function NewImageEditor({ onOpenEditor }: NewImageEditorProps) {
  const { state, addPost } = useApp();
  const [showExisting, setShowExisting] = useState(false);
  const [language, setLanguage] = useState<'english' | 'kannada'>('english');
  const [existingPosts, setExistingPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(false);
  const [frameSize, setFrameSize] = useState({ label: 'Tall Portrait (1920x1080)', width: 1080, height: 1920 });
  const [showFrameSelector, setShowFrameSelector] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [pendingMedia, setPendingMedia] = useState<string | null>(null);

  // Fetch existing posts
  const fetchExistingPosts = async () => {
    setLoading(true);
    try {
      const postsQuery = query(collection(db, 'admin_posts'), orderBy('createdAt', 'desc'));
      const querySnapshot = await getDocs(postsQuery);
      const fetchedPosts: Post[] = [];
      
      querySnapshot.forEach((docSnapshot) => {
        const data = docSnapshot.data();
        fetchedPosts.push({
          id: docSnapshot.id,
          userId: data.createdBy || 'admin',
          userName: data.adminName || 'Admin',
          userPhoto: data.adminPhotoUrl || 'https://api.dicebear.com/7.x/avataaars/svg?seed=admin',
          mainImage: data.mainImage,
          category: Array.isArray(data.categories) ? data.categories.join(', ') : data.category || '',
          region: Array.isArray(data.regions) ? data.regions.join(', ') : data.region || '',
          language: data.language,
          textSettings: data.textSettings,
          addressSettings: data.addressSettings || {
            text: '',
            x: 50,
            y: 80,
            font: 'Arial',
            fontSize: 18,
            color: '#ffffff',
            hasBackground: true,
            backgroundColor: '#000000',
            enabled: false,
          },
          phoneSettings: data.phoneSettings || {
            text: '',
            x: 50,
            y: 85,
            font: 'Arial',
            fontSize: 18,
            color: '#ffffff',
            hasBackground: true,
            backgroundColor: '#000000',
            enabled: false,
          },
          profileSettings: data.profileSettings,
          createdAt: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
        });
      });
      
      setExistingPosts(fetchedPosts);
    } catch (error) {
      console.error('Error fetching posts:', error);
      alert('Error loading existing posts');
    } finally {
      setLoading(false);
    }
  };

  // Delete post from Firebase
  const handleDeletePost = async (postId: string) => {
    if (window.confirm('Are you sure you want to delete this post? This action cannot be undone.')) {
      try {
        await deleteDoc(doc(db, 'admin_posts', postId));
        setExistingPosts(prev => prev.filter(post => post.id !== postId));
        alert('Post deleted successfully!');
      } catch (error) {
        console.error('Error deleting post:', error);
        alert('Error deleting post');
      }
    }
  };

  function readFileAsDataURL(file: File): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (event) => resolve(event.target?.result as string);
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  }

  const handleMediaUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      if (!file.type.startsWith('image/')) {
        setUploadError('Only image files are allowed.');
        return;
      }
      setUploadError(null);
      let mediaUrl = await readFileAsDataURL(file);
      setShowFrameSelector(true);
      setPendingMedia(mediaUrl);
    }
  };

  const handleFrameSelect = (size: typeof FRAME_SIZES[0]) => {
    setFrameSize(size);
    setShowFrameSelector(false);
    if (pendingMedia) {
      onOpenEditor({
        media: pendingMedia,
        frameSize: size,
        mediaType: 'image',
        language,
        userName: state.currentUser?.name || '',
      });
      setPendingMedia(null);
    }
  };

  const handlePostSave = (postData: Omit<Post, 'id' | 'userId' | 'userName' | 'userPhoto' | 'createdAt'>) => {
    if (!state.currentUser) return;
    
    const newPost: Post = {
      ...postData,
      id: Date.now().toString(),
      userId: state.currentUser.id,
      userName: state.currentUser.name,
      userPhoto: state.currentUser.photo,
      category: Array.isArray(postData.category) ? postData.category.join(', ') : postData.category,
      region: Array.isArray(postData.region) ? postData.region.join(', ') : postData.region,
      language,
      createdAt: new Date().toISOString(),
    };
    
    addPost(newPost);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const isVideo = (mediaUrl: string) => {
    return mediaUrl.startsWith('data:video/') || mediaUrl.startsWith('http') && mediaUrl.includes('video');
  };

  const FONT_OPTIONS = [
    'Arial',
    'Roboto',
    'Montserrat',
    'Lato',
    'Times New Roman',
    'Georgia',
    'Courier New',
    'Verdana',
    'Tahoma',
  ];

  const FRAME_SIZES = [
    { label: 'Square (1080x1080)', width: 1080, height: 1080 },
    { label: 'Portrait (1350x1080)', width: 1080, height: 1350 },
    { label: 'Tall Portrait (1920x1080)', width: 1080, height: 1920 },
  ];

  if (showExisting) {
    return (
      <div className="min-h-screen p-6" style={{ background: 'linear-gradient(135deg, #fff5f0 0%, #f8f4ff 50%, #fff0e6 100%)' }}>
        <div className="max-w-7xl mx-auto">
          <div className="bg-white/80 backdrop-blur-lg rounded-2xl shadow-xl p-6 border border-white/20">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h1 className="text-3xl font-bold text-gray-800 mb-2">Existing Posts</h1>
                <p className="text-gray-600">Manage your published posts</p>
              </div>
              <button
                onClick={() => setShowExisting(false)}
                className="px-4 py-2 bg-gray-500 text-white rounded-lg hover:bg-gray-600 transition-colors flex items-center space-x-2"
              >
                <X className="h-4 w-4" />
                <span>Back to Dashboard</span>
              </button>
            </div>

            {loading ? (
              <div className="text-center py-12">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 mx-auto mb-4" style={{ borderColor: '#d74d02' }}></div>
                <p className="text-gray-600">Loading posts...</p>
              </div>
            ) : existingPosts.length === 0 ? (
              <div className="text-center py-12">
                <div className="text-gray-400 mb-4">
                  <Settings className="h-16 w-16 mx-auto" />
                </div>
                <h3 className="text-xl font-semibold text-gray-600 mb-2">No posts found</h3>
                <p className="text-gray-500">Create your first post to get started</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {existingPosts.map(post => (
                  <div
                    key={post.id}
                    className="bg-white rounded-lg shadow-lg overflow-hidden border border-gray-200 hover:shadow-xl transition-all duration-300"
                  >
                    <div className="relative">
                      <div className="w-full bg-gray-100 flex items-center justify-center" style={{ aspectRatio: '9/16' }}>
                        {isVideo(post.mainImage) ? (
                          <video
                            src={post.mainImage}
                            className="w-full h-full object-contain"
                            muted
                            loop
                            onMouseEnter={(e) => e.currentTarget.play()}
                            onMouseLeave={(e) => e.currentTarget.pause()}
                          />
                        ) : (
                          <img
                            src={post.mainImage}
                            alt={post.category}
                            className="w-full h-full object-contain"
                          />
                        )}
                      </div>
                      
                      {/* Text Overlays */}
                      <div
                        className="absolute pointer-events-none px-2 py-1 rounded"
                        style={{
                          left: `${post.textSettings.x}%`,
                          top: `${post.textSettings.y}%`,
                          transform: 'translate(-50%, -50%)',
                          fontFamily: post.textSettings.font,
                          fontSize: `${post.textSettings.fontSize * 0.4}px`,
                          color: post.textSettings.color,
                          fontWeight: 'bold',
                          backgroundColor: post.textSettings.hasBackground ? post.textSettings.backgroundColor : 'transparent',
                          textShadow: post.textSettings.hasBackground ? 'none' : '2px 2px 4px rgba(0,0,0,0.8)',
                        }}
                      >
                        {post.userName}
                      </div>
                      
                      {post.addressSettings?.enabled && post.addressSettings.text && (
                        <div
                          className="absolute pointer-events-none px-2 py-1 rounded"
                          style={{
                            left: `${post.addressSettings.x}%`,
                            top: `${post.addressSettings.y}%`,
                            transform: 'translate(-50%, -50%)',
                            fontFamily: post.addressSettings.font,
                            fontSize: `${post.addressSettings.fontSize * 0.4}px`,
                            color: post.addressSettings.color,
                            fontWeight: 'bold',
                            backgroundColor: post.addressSettings.hasBackground ? post.addressSettings.backgroundColor : 'transparent',
                            textShadow: post.addressSettings.hasBackground ? 'none' : '2px 2px 4px rgba(0,0,0,0.8)',
                          }}
                        >
                          {post.addressSettings.text}
                        </div>
                      )}
                      
                      {post.phoneSettings?.enabled && post.phoneSettings.text && (
                        <div
                          className="absolute pointer-events-none px-2 py-1 rounded"
                          style={{
                            left: `${post.phoneSettings.x}%`,
                            top: `${post.phoneSettings.y}%`,
                            transform: 'translate(-50%, -50%)',
                            fontFamily: post.phoneSettings.font,
                            fontSize: `${post.phoneSettings.fontSize * 0.4}px`,
                            color: post.phoneSettings.color,
                            fontWeight: 'bold',
                            backgroundColor: post.phoneSettings.hasBackground ? post.phoneSettings.backgroundColor : 'transparent',
                            textShadow: post.phoneSettings.hasBackground ? 'none' : '2px 2px 4px rgba(0,0,0,0.8)',
                          }}
                        >
                          {post.phoneSettings.text}
                        </div>
                      )}
                    </div>
                    
                    <div className="p-4">
                      <div className="flex items-center justify-between mb-3">
                        <div>
                          <h3 className="font-semibold text-gray-800">{post.category}</h3>
                          <p className="text-sm text-gray-500">{post.region}</p>
                        </div>
                        <button
                          onClick={() => handleDeletePost(post.id)}
                          className="p-2 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-colors"
                          title="Delete post"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                      
                      <div className="text-xs text-gray-400">
                        <p>Language: {post.language === 'kannada' ? 'ಕನ್ನಡ' : 'English'}</p>
                        <p>Created: {formatDate(post.createdAt)}</p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-6" style={{ background: 'linear-gradient(135deg, #fff5f0 0%, #f8f4ff 50%, #fff0e6 100%)' }}>
      {uploadError && (
        <div className="mb-4 p-4 bg-red-100 text-red-700 rounded-lg text-center">{uploadError}</div>
      )}
      {showFrameSelector && (
        <div className="fixed inset-0 flex items-center justify-center bg-black bg-opacity-40 z-50">
          <div className="bg-white rounded-xl shadow-2xl p-8 max-w-xs w-full text-center">
            <h2 className="text-xl font-bold mb-4">Select Frame Size</h2>
            <div className="space-y-3">
              {FRAME_SIZES.map(size => (
                <button
                  key={size.label}
                  onClick={() => handleFrameSelect(size)}
                  className="w-full py-2 px-4 rounded-lg border border-gray-300 hover:bg-gray-100 text-gray-800 font-medium mb-2"
                >
                  {size.label}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
      <div className="max-w-4xl mx-auto">
        <div className="bg-white/80 backdrop-blur-lg rounded-2xl shadow-xl p-8 border border-white/20">
          <div className="text-center mb-8">
            <img src="/assets/logo.png" alt="Logo" className="h-24 w-24 mx-auto mb-4" />
            <h1 className="text-3xl font-bold text-gray-800 mb-2">Image Editor</h1>
            <p className="text-gray-600">Create and manage your posts</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            <div className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Language
                </label>
                <div className="flex space-x-4">
                  <label className="flex items-center">
                    <input
                      type="radio"
                      name="language"
                      value="english"
                      checked={language === 'english'}
                      onChange={(e) => setLanguage(e.target.value as 'english')}
                      className="mr-2"
                      style={{ accentColor: '#d74d02' }}
                    />
                    English
                  </label>
                  <label className="flex items-center">
                    <input
                      type="radio"
                      name="language"
                      value="kannada"
                      checked={language === 'kannada'}
                      onChange={(e) => setLanguage(e.target.value as 'kannada')}
                      className="mr-2"
                      style={{ accentColor: '#d74d02' }}
                    />
                    ಕನ್ನಡ
                  </label>
                </div>
              </div>

              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <h3 className="font-semibold text-blue-800 mb-2">Note!</h3>
                <p className="text-sm text-blue-700">
                  You can upload images.
                  <br />
                  Images will be resized to 1080x1920 (Portrait).
                  <br />
                  You can choose multiple categories and regions for each post.
                  <br />
                  You can save and publish your post to the gallery.
                </p>
              </div>
            </div>

            <div className="flex items-center justify-center">
              <label className="flex flex-col items-center justify-center w-full h-64 border-2 border-dashed rounded-lg cursor-pointer transition-colors border-gray-300 bg-gray-50 hover:bg-gray-100">
                <div className="flex flex-col items-center justify-center pt-5 pb-6">
                  <Upload className="h-12 w-12 text-gray-400 mb-4" />
                  <p className="mb-2 text-sm text-gray-500">
                    <span className="font-semibold">Click to upload</span> media file
                  </p>
                  <p className="text-xs text-gray-500">Images, GIFs, Videos up to 50MB</p>
                  <p className="text-xs text-gray-500 mt-2">Will be resized to 1080x1920 (Portrait)</p>
                  <p className="text-xs text-blue-600 mt-2">Categories & regions selected in editor</p>
                </div>
                <input
                  type="file"
                  accept="image/*,video/*,.gif"
                  onChange={handleMediaUpload}
                  className="hidden"
                />
              </label>
            </div>
          </div>

          <div className="mt-8 grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="text-white p-6 rounded-lg" style={{ background: 'linear-gradient(135deg, #d74d02 0%, #2c0036 100%)' }}>
              <Type className="h-8 w-8 mb-2" />
              <h3 className="font-semibold mb-1">Text Elements</h3>
              <p className="text-sm opacity-90">Add username, address, and phone number</p>
            </div>
            <div className="text-white p-6 rounded-lg" style={{ background: 'linear-gradient(135deg, #2c0036 0%, #d74d02 100%)' }}>
              <Move className="h-8 w-8 mb-2" />
              <h3 className="font-semibold mb-1">Profile Placement</h3>
              <p className="text-sm opacity-90">Optional profile photo positioning</p>
            </div>
            <div className="text-white p-6 rounded-lg" style={{ background: 'linear-gradient(135deg, #d74d02 0%, #2c0036 100%)' }}>
              <Save className="h-8 w-8 mb-2" />
              <h3 className="font-semibold mb-1">Save & Publish</h3>
              <p className="text-sm opacity-90">Save your creation to gallery</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}