import React, { useState } from 'react';
import { Search, Grid, List, Filter, Calendar, User, Play } from 'lucide-react';
import { useApp } from '../contexts/AppContext';

export default function UserDashboard() {
  const { state } = useApp();
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid');

  const categories = ['all', ...new Set(state.posts.map(post => post.category))];
  
  const filteredPosts = state.posts.filter(post => {
    const matchesSearch = post.userName.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         post.category.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesCategory = selectedCategory === 'all' || post.category === selectedCategory;
    return matchesSearch && matchesCategory;
  });

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  };

  const isVideo = (mediaUrl: string) => {
    return mediaUrl.startsWith('data:video/');
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-indigo-50 to-purple-50 p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="bg-white/80 backdrop-blur-lg rounded-2xl shadow-xl p-6 mb-8 border border-white/20">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between">
            <div className="mb-4 md:mb-0">
              <h1 className="text-3xl font-bold text-gray-800 mb-2">Gallery</h1>
              <p className="text-gray-600">Discover amazing posts from our community</p>
            </div>
            
            <div className="flex items-center space-x-4">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-5 w-5" />
                <input
                  type="text"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="Search posts..."
                />
              </div>
              
              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                {categories.map(category => (
                  <option key={category} value={category}>
                    {category === 'all' ? 'All Categories' : category}
                  </option>
                ))}
              </select>
              
              <div className="flex border border-gray-300 rounded-lg overflow-hidden">
                <button
                  onClick={() => setViewMode('grid')}
                  className={`p-2 ${viewMode === 'grid' ? 'bg-blue-500 text-white' : 'bg-white text-gray-600'}`}
                >
                  <Grid className="h-5 w-5" />
                </button>
                <button
                  onClick={() => setViewMode('list')}
                  className={`p-2 ${viewMode === 'list' ? 'bg-blue-500 text-white' : 'bg-white text-gray-600'}`}
                >
                  <List className="h-5 w-5" />
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Posts */}
        {filteredPosts.length === 0 ? (
          <div className="text-center py-12">
            <div className="bg-white/80 backdrop-blur-lg rounded-2xl shadow-xl p-8 border border-white/20">
              <div className="text-gray-400 mb-4">
                <Filter className="h-16 w-16 mx-auto" />
              </div>
              <h3 className="text-xl font-semibold text-gray-600 mb-2">No posts found</h3>
              <p className="text-gray-500">Try adjusting your search or filter criteria</p>
            </div>
          </div>
        ) : (
          <div className={viewMode === 'grid' ? 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6' : 'space-y-6'}>
            {filteredPosts.map(post => (
              <div
                key={post.id}
                className="bg-white/80 backdrop-blur-lg rounded-2xl shadow-xl overflow-hidden border border-white/20 hover:shadow-2xl transition-all duration-300 hover:scale-105"
              >
                <div className="relative">
                  {isVideo(post.mainImage) ? (
                    <div className="relative">
                      <video
                        src={post.mainImage}
                        className="w-full h-48 object-cover"
                        muted
                        loop
                        onMouseEnter={(e) => e.currentTarget.play()}
                        onMouseLeave={(e) => e.currentTarget.pause()}
                      />
                      <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                        <Play className="h-12 w-12 text-white/70" />
                      </div>
                    </div>
                  ) : (
                    <img
                      src={post.mainImage}
                      alt={post.category}
                      className="w-full h-48 object-cover"
                    />
                  )}
                  
                  {/* Current User's Name Text Overlay (using admin's positioning but current user's name) */}
                  <div
                    className="absolute pointer-events-none px-2 py-1 rounded"
                    style={{
                      left: `${post.textSettings.x}%`,
                      top: `${post.textSettings.y}%`,
                      transform: 'translate(-50%, -50%)',
                      fontFamily: post.textSettings.font,
                      fontSize: `${post.textSettings.fontSize * 0.6}px`,
                      color: post.textSettings.color,
                      fontWeight: 'bold',
                      backgroundColor: post.textSettings.hasBackground ? post.textSettings.backgroundColor : 'transparent',
                      textShadow: post.textSettings.hasBackground ? 'none' : '2px 2px 4px rgba(0,0,0,0.8)',
                    }}
                  >
                    {state.currentUser?.name || 'User'}
                  </div>
                  
                  {/* Current User's Profile Photo Overlay (using admin's positioning but current user's photo) */}
                  {post.profileSettings.enabled && state.currentUser && (
                    <div
                      className="absolute"
                      style={{
                        left: `${post.profileSettings.x}%`,
                        top: `${post.profileSettings.y}%`,
                        width: `${post.profileSettings.size * 0.6}px`,
                        height: `${post.profileSettings.size * 0.6}px`,
                        borderRadius: post.profileSettings.shape === 'circle' ? '50%' : '8px',
                        backgroundColor: post.profileSettings.hasBackground ? 'rgba(255,255,255,0.9)' : 'transparent',
                        transform: 'translate(-50%, -50%)',
                        border: '2px solid white',
                        boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
                      }}
                    >
                      <img
                        src={state.currentUser.photo}
                        alt={state.currentUser.name}
                        className="w-full h-full object-cover"
                        style={{
                          borderRadius: post.profileSettings.shape === 'circle' ? '50%' : '6px',
                        }}
                      />
                    </div>
                  )}
                </div>
                
                <div className="p-6">
                  <div className="flex items-center justify-between mb-4">
                    <div className="flex items-center space-x-3">
                      <img
                        src={post.userPhoto}
                        alt={post.userName}
                        className="w-10 h-10 rounded-full object-cover border-2 border-gray-200"
                      />
                      <div>
                        <h3 className="font-semibold text-gray-800">{post.userName}</h3>
                        <p className="text-sm text-gray-500">{post.category}</p>
                        <p className="text-xs text-gray-400">Created by Admin</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-xs text-gray-500 flex items-center">
                        <Calendar className="h-3 w-3 mr-1" />
                        {formatDate(post.createdAt)}
                      </div>
                      <div className="text-xs text-gray-500 mt-1">
                        {post.language === 'kannada' ? 'ಕನ್ನಡ' : 'English'}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}