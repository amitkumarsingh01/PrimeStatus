import React, { useState } from 'react';
import { Plus, Upload, Type, Move, Settings, Save } from 'lucide-react';
import { useApp } from '../contexts/AppContext';
import { Post } from '../types';
import ImageEditor from './ImageEditor';
import { uploadMediaFile } from '../firebase';

export default function AdminDashboard() {
  const { state, addPost } = useApp();
  const [showEditor, setShowEditor] = useState(false);
  const [selectedMedia, setSelectedMedia] = useState<string>('');
  const [category, setCategory] = useState('');
  const [language, setLanguage] = useState<'english' | 'kannada'>('english');

  const handleMediaUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      if (file.type.startsWith('video/')) {
        // Upload video to Firebase Storage
        const url = await uploadMediaFile(file, `admin_videos/${file.name}_${Date.now()}`);
        setSelectedMedia(url); // Pass URL, not base64
      } else {
        // For images, you can still use base64 if you want
        const reader = new FileReader();
        reader.onload = (event) => {
          setSelectedMedia(event.target?.result as string);
        };
        reader.readAsDataURL(file);
      }
      setShowEditor(true);
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
      category,
      language,
      createdAt: new Date().toISOString(),
    };
    
    addPost(newPost);
    setShowEditor(false);
    setSelectedMedia('');
    setCategory('');
  };

  if (showEditor && selectedMedia) {
    return (
      <ImageEditor
        media={selectedMedia}
        category={category}
        language={language}
        userName={state.currentUser?.name || ''}
        onSave={handlePostSave}
        onCancel={() => setShowEditor(false)}
      />
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-purple-50 to-pink-50 p-6">
      <div className="max-w-4xl mx-auto">
        <div className="bg-white/80 backdrop-blur-lg rounded-2xl shadow-xl p-8 border border-white/20">
          <div className="text-center mb-8">
            <div className="bg-gradient-to-r from-indigo-500 to-purple-600 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
              <Settings className="h-8 w-8 text-white" />
            </div>
            <h1 className="text-3xl font-bold text-gray-800 mb-2">Admin Dashboard</h1>
            <p className="text-gray-600">Create and manage your posts</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            <div className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Category
                </label>
                <input
                  type="text"
                  value={category}
                  onChange={(e) => setCategory(e.target.value)}
                  className="w-full px-4 py-3 rounded-lg border border-gray-300 focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all duration-200"
                  placeholder="Enter category name"
                />
              </div>

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
                    />
                    ಕನ್ನಡ
                  </label>
                </div>
              </div>
            </div>

            <div className="flex items-center justify-center">
              <label className="flex flex-col items-center justify-center w-full h-64 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer bg-gray-50 hover:bg-gray-100 hover:border-indigo-400 transition-colors">
                <div className="flex flex-col items-center justify-center pt-5 pb-6">
                  <Upload className="h-12 w-12 text-gray-400 mb-4" />
                  <p className="mb-2 text-sm text-gray-500">
                    <span className="font-semibold">Click to upload</span> media file
                  </p>
                  <p className="text-xs text-gray-500">Images, GIFs, Videos up to 50MB</p>
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
            <div className="bg-gradient-to-r from-blue-500 to-cyan-500 text-white p-6 rounded-lg">
              <Type className="h-8 w-8 mb-2" />
              <h3 className="font-semibold mb-1">Username Display</h3>
              <p className="text-sm opacity-90">Position username text with background options</p>
            </div>
            <div className="bg-gradient-to-r from-purple-500 to-pink-500 text-white p-6 rounded-lg">
              <Move className="h-8 w-8 mb-2" />
              <h3 className="font-semibold mb-1">Profile Placement</h3>
              <p className="text-sm opacity-90">Optional profile photo positioning</p>
            </div>
            <div className="bg-gradient-to-r from-green-500 to-teal-500 text-white p-6 rounded-lg">
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