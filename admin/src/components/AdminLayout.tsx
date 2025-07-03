import React, { useState } from 'react';
import Sidebar from './Sidebar';
import AdminDashboard from './AdminDashboard';
import Users from './Users';
import ImageEditor from './ImageEditor';
import ExistingPosts from './ExistingPosts';
import VideoEditor from './VideoEditor';
import NewImageEditor from './NewImageEditor';
type AdminPage = 'dashboard' | 'users' | 'image-editor' | 'existing-posts' | 'video-editor';

export default function AdminLayout() {
  const [activePage, setActivePage] = useState<AdminPage>('dashboard');
  const [editorProps, setEditorProps] = useState<{
    media: string;
    category: string;
    region: string;
    language: 'english' | 'kannada';
    userName: string;
    onSave: (postData: any) => void;
    onCancel: () => void;
  } | null>(null);

  const handlePageChange = (page: AdminPage) => {
    setActivePage(page);
    // Clear editor props when switching away from image editor
    if (page !== 'image-editor') {
      setEditorProps(null);
    }
  };

  const openImageEditor = (props: typeof editorProps) => {
    setEditorProps(props);
    setActivePage('image-editor');
  };

  const closeImageEditor = () => {
    setEditorProps(null);
    setActivePage('dashboard');
  };

  const renderActivePage = () => {
    switch (activePage) {
      case 'dashboard':
        return (
          <AdminDashboard 
            onOpenImageEditor={openImageEditor}
          />
        );
      case 'existing-posts':
        return <ExistingPosts />;
      case 'users':
        return <Users />;
      // case 'image-editor':
      //   return editorProps ? (
      //     <ImageEditor
      //       media={editorProps.media}
      //       category={editorProps.category}
      //       region={editorProps.region}
      //       language={editorProps.language}
      //       userName={editorProps.userName}
      //       onSave={editorProps.onSave}
      //       onCancel={closeImageEditor}
      //     />
      //   ) : (
      //     <div className="flex items-center justify-center h-screen">
      //       <p>No image selected for editing</p>
      //     </div>
      //   );
      case 'image-editor':
        return <NewImageEditor onOpenImageEditor={openImageEditor} />;
      case 'video-editor':
        return <VideoEditor onOpenImageEditor={openImageEditor} />;
      default:
        return <AdminDashboard onOpenImageEditor={openImageEditor} />;
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