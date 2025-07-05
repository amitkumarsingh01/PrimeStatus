import React from 'react';
import { Settings, Users, Image as ImageIcon, LogOut, Eye, VideoIcon, Tag, CreditCard } from 'lucide-react';
import { useApp } from '../contexts/AppContext';

interface SidebarProps {
  activePage: 'dashboard' | 'users' | 'image-editor' | 'existing-posts' | 'video-editor' | 'category-manager' | 'payment';
  onPageChange: (page: 'dashboard' | 'users' | 'image-editor' | 'existing-posts' | 'video-editor' | 'category-manager' | 'payment') => void;
}

export default function Sidebar({ activePage, onPageChange }: SidebarProps) {
  const { logout } = useApp();

  const menuItems = [
    {
      id: 'existing-posts' as const,
      label: 'Existing Posts',
      icon: Eye,
      description: 'View all published posts'
    },
    {
      id: 'users' as const,
      label: 'Users',
      icon: Users,
      description: 'Manage all users'
    },
    {
      id: 'image-editor' as const,
      label: 'Image Editor',
      icon: ImageIcon,
      description: 'Edit images and create posts'
    },
    {
      id: 'video-editor' as const,
      label: 'Video Editor',
      icon: VideoIcon,
      description: 'Edit videos and create posts'
    },
    {
      id: 'category-manager' as const,
      label: 'Manage Categories',
      icon: Tag,
      description: 'Add or remove categories'
    },
    {
      id: 'payment' as const,
      label: 'Subscription Plans',
      icon: CreditCard,
      description: 'Manage pricing and plans'
    }
  ];

  return (
    <div className="w-64 bg-white shadow-lg h-screen fixed left-0 top-0 z-50">
      {/* Header */}
      <div className="p-6 border-b border-gray-200">
        <div className="flex items-center space-x-3">
          <img src="/assets/logo.png" alt="Logo" className="h-20 w-20" />
          {/* <div className="w-10 h-10 rounded-full flex items-center justify-center" style={{ background: 'linear-gradient(135deg, #d74d02 0%, #2c0036 100%)' }}>
            <Settings className="h-5 w-5 text-white" />
          </div> */}
          <div>
            <h1 className="text-lg font-bold text-gray-800">Admin Panel</h1>
            <p className="text-xs text-gray-500">Prime Status Management</p>
          </div>
        </div>
      </div>

      {/* Navigation Menu */}
      <nav className="p-4 space-y-2">
        {menuItems.map((item) => {
          const Icon = item.icon;
          const isActive = activePage === item.id;
          
          return (
            <button
              key={item.id}
              onClick={() => onPageChange(item.id)}
              className={`w-full flex items-center space-x-3 px-4 py-3 rounded-lg transition-all duration-200 text-left ${
                isActive
                  ? 'bg-gradient-to-r from-orange-500 to-purple-600 text-white shadow-lg'
                  : 'text-gray-700 hover:bg-gray-100 hover:text-gray-900'
              }`}
            >
              <Icon className={`h-5 w-5 ${isActive ? 'text-white' : 'text-gray-500'}`} />
              <div className="flex-1">
                <div className={`font-medium ${isActive ? 'text-white' : 'text-gray-900'}`}>
                  {item.label}
                </div>
                <div className={`text-xs ${isActive ? 'text-white/80' : 'text-gray-500'}`}>
                  {item.description}
                </div>
              </div>
            </button>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="absolute bottom-0 left-0 right-0 p-4 border-t border-gray-200">
        <button
          onClick={logout}
          className="w-full flex items-center space-x-3 px-4 py-3 rounded-lg text-gray-700 hover:bg-red-50 hover:text-red-600 transition-all duration-200"
        >
          <LogOut className="h-5 w-5" />
          <span className="font-medium">Logout</span>
        </button>
      </div>
    </div>
  );
} 