import React, { useEffect, useState } from 'react';
import { Settings, Trash2, X } from 'lucide-react';
import { db } from '../firebase';
import { collection, getDocs, query, orderBy, deleteDoc, doc } from 'firebase/firestore';
import { Post } from '../types';

interface ExistingPostsProps {
  onBack?: () => void;
}

export default function ExistingPosts({ onBack }: ExistingPostsProps) {
  const [existingPosts, setExistingPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(false);
  const [frameFilter, setFrameFilter] = useState<'all' | '1080x1080' | '1080x1350' | '1080x1920'>('all');

  useEffect(() => {
    fetchExistingPosts();
    // eslint-disable-next-line
  }, []);

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
            text: '', x: 50, y: 80, font: 'Arial', fontSize: 18, color: '#ffffff', hasBackground: true, backgroundColor: '#000000', enabled: false,
          },
          phoneSettings: data.phoneSettings || {
            text: '', x: 50, y: 85, font: 'Arial', fontSize: 18, color: '#ffffff', hasBackground: true, backgroundColor: '#000000', enabled: false,
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
    return mediaUrl.startsWith('data:video/') || (mediaUrl.startsWith('http') && mediaUrl.includes('video'));
  };

  // Frame filter logic
  const filteredPosts = frameFilter === 'all'
    ? existingPosts
    : existingPosts.filter(post => {
        const size = post.frameSize || post["frameSize"];
        if (!size || typeof size.width !== 'number' || typeof size.height !== 'number') return false;
        if (frameFilter === '1080x1080') return size.width === 1080 && size.height === 1080;
        if (frameFilter === '1080x1350') return size.width === 1080 && size.height === 1350;
        if (frameFilter === '1080x1920') return size.width === 1080 && size.height === 1920;
        return true;
      });

  return (
    <div className="min-h-screen p-6" style={{ background: 'linear-gradient(135deg, #fff5f0 0%, #f8f4ff 50%, #fff0e6 100%)' }}>
      <div className="max-w-7xl mx-auto">
        <div className="bg-white/80 backdrop-blur-lg rounded-2xl shadow-xl p-6 border border-white/20">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h1 className="text-3xl font-bold text-gray-800 mb-2">Existing Posts</h1>
              <p className="text-gray-600">Manage your published posts</p>
            </div>
            {onBack && (
              <button
                onClick={onBack}
                className="px-4 py-2 bg-gray-500 text-white rounded-lg hover:bg-gray-600 transition-colors flex items-center space-x-2"
              >
                <X className="h-4 w-4" />
                <span>Back to Dashboard</span>
              </button>
            )}
          </div>

          {/* Frame Filter */}
          {/* <div className="mb-6 flex flex-wrap gap-3 items-center">
            <span className="font-medium text-gray-700 mr-2">Filter by Frame:</span>
            <button
              className={`px-4 py-1 rounded-lg border ${frameFilter === 'all' ? 'bg-orange-500 text-white' : 'bg-white text-gray-700'} transition`}
              onClick={() => setFrameFilter('all')}
            >
              All
            </button>
            <button
              className={`px-4 py-1 rounded-lg border ${frameFilter === '1080x1080' ? 'bg-orange-500 text-white' : 'bg-white text-gray-700'} transition`}
              onClick={() => setFrameFilter('1080x1080')}
            >
              1080x1080
            </button>
            <button
              className={`px-4 py-1 rounded-lg border ${frameFilter === '1080x1350' ? 'bg-orange-500 text-white' : 'bg-white text-gray-700'} transition`}
              onClick={() => setFrameFilter('1080x1350')}
            >
              1080x1350
            </button>
            <button
              className={`px-4 py-1 rounded-lg border ${frameFilter === '1080x1920' ? 'bg-orange-500 text-white' : 'bg-white text-gray-700'} transition`}
              onClick={() => setFrameFilter('1080x1920')}
            >
              1080x1920
            </button>
          </div> */}

          {loading ? (
            <div className="text-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 mx-auto mb-4" style={{ borderColor: '#d74d02' }}></div>
              <p className="text-gray-600">Loading posts...</p>
            </div>
          ) : filteredPosts.length === 0 ? (
            <div className="text-center py-12">
              <div className="text-gray-400 mb-4">
                <Settings className="h-16 w-16 mx-auto" />
              </div>
              <h3 className="text-xl font-semibold text-gray-600 mb-2">No posts found</h3>
              <p className="text-gray-500">Create your first post to get started</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {filteredPosts.map(post => (
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
                      {/* Debug: Show frameSize info */}
                      <p className="mt-1 text-[10px] text-orange-600">Frame: {post.frameSize && typeof post.frameSize.width === 'number' && typeof post.frameSize.height === 'number' ? `${post.frameSize.width}x${post.frameSize.height}` : <span className="text-red-500">No frameSize</span>}</p>
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