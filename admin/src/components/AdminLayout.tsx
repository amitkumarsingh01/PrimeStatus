import React, { useState } from 'react';
import Sidebar from './Sidebar';
import AdminDashboard from './AdminDashboard';
import Users from './Users';
import ImageEditor from './ImageEditor';
import ExistingPosts from './ExistingPosts';
import VideoEditor from './VideoEditor';
import NewImageEditor from './NewImageEditor';
import CategoryManager from './CategoryManager';
import Payment from './Payment';

type AdminPage = 'dashboard' | 'users' | 'image-editor' | 'existing-posts' | 'video-editor' | 'category-manager' | 'payment';

export default function AdminLayout() {
  const [activePage, setActivePage] = useState<AdminPage>('existing-posts');
  const [editorProps, setEditorProps] = useState<{
    media: string;
    frameSize: { width: number; height: number };
    mediaType: 'image' | 'video';
    language: 'english' | 'kannada';
    userName: string;
  } | null>(null);
  const [isEditing, setIsEditing] = useState(false);

  const handlePageChange = (page: AdminPage) => {
    setActivePage(page);
    // Clear editor props when switching away from image editor
    if (page !== 'image-editor') {
      setEditorProps(null);
    }
  };

  const openEditor = (props: {
    media: string;
    frameSize: { width: number; height: number };
    mediaType: 'image' | 'video';
    language: 'english' | 'kannada';
    userName: string;
  }) => {
    setEditorProps({ ...props });
    setIsEditing(true);
  };

  const closeEditor = () => {
    setEditorProps(null);
    setIsEditing(false);
  };

  const renderActivePage = () => {
    if (isEditing && editorProps) {
      return (
        <ImageEditor
          media={editorProps.media}
          frameSize={editorProps.frameSize}
          mediaType={editorProps.mediaType}
          language={editorProps.language}
          userName={editorProps.userName}
          onCancel={closeEditor}
        />
      );
    }
    switch (activePage) {
      case 'dashboard':
        return <AdminDashboard onOpenImageEditor={openEditor} />;
      case 'existing-posts':
        return <ExistingPosts />;
      case 'users':
        return <Users />;
      case 'image-editor':
        return <NewImageEditor onOpenEditor={openEditor} />;
      case 'video-editor':
        return <VideoEditor onOpenEditor={openEditor} />;
      case 'category-manager':
        return <CategoryManager />;
      case 'payment':
        return <Payment />;
      default:
        return <AdminDashboard onOpenImageEditor={openEditor} />;
    }
  };

  return (
    <div className="flex h-screen bg-gray-50">
      <Sidebar activePage={activePage} onPageChange={handlePageChange} />
      <div className="flex-1 ml-64 overflow-auto">
        {renderActivePage()}
      </div>
    </div>
  );
} 