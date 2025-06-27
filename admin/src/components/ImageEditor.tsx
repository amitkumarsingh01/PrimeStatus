import React, { useState, useRef } from 'react';
import { Save, X, Type, Move, Circle, Square, Palette, Eye, EyeOff } from 'lucide-react';

interface ImageEditorProps {
  media: string;
  category: string;
  language: 'english' | 'kannada';
  userName: string;
  onSave: (postData: any) => void;
  onCancel: () => void;
}

export default function ImageEditor({ media, category, language, userName, onSave, onCancel }: ImageEditorProps) {
  const canvasRef = useRef<HTMLDivElement>(null);
  const [textSettings, setTextSettings] = useState({
    text: userName,
    x: 50,
    y: 90,
    font: 'Arial',
    fontSize: 24,
    color: '#ffffff',
    hasBackground: true,
    backgroundColor: '#000000',
  });
  const [profileSettings, setProfileSettings] = useState({
    x: 20,
    y: 20,
    shape: 'circle' as 'circle' | 'square',
    size: 80,
    hasBackground: true,
    enabled: false,
  });
  const [isDraggingText, setIsDraggingText] = useState(false);
  const [isDraggingProfile, setIsDraggingProfile] = useState(false);

  const handleMouseDown = (type: 'text' | 'profile') => {
    if (type === 'text') setIsDraggingText(true);
    if (type === 'profile' && profileSettings.enabled) setIsDraggingProfile(true);
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!canvasRef.current) return;
    
    const rect = canvasRef.current.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * 100;
    const y = ((e.clientY - rect.top) / rect.height) * 100;
    
    if (isDraggingText) {
      setTextSettings(prev => ({ ...prev, x: Math.max(0, Math.min(100, x)), y: Math.max(0, Math.min(100, y)) }));
    }
    if (isDraggingProfile && profileSettings.enabled) {
      setProfileSettings(prev => ({ ...prev, x: Math.max(0, Math.min(100, x)), y: Math.max(0, Math.min(100, y)) }));
    }
  };

  const handleMouseUp = () => {
    setIsDraggingText(false);
    setIsDraggingProfile(false);
  };

  const handleSave = () => {
    onSave({
      mainImage: media,
      textSettings,
      profileSettings,
    });
  };

  const isVideo = media.startsWith('data:video/');

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-purple-900 to-violet-900 p-4">
      <div className="max-w-7xl mx-auto">
        <div className="bg-white/10 backdrop-blur-lg rounded-2xl shadow-xl border border-white/20 p-6">
          <div className="flex items-center justify-between mb-6">
            <h1 className="text-2xl font-bold text-white">Media Editor</h1>
            <div className="flex space-x-3">
              <button
                onClick={onCancel}
                className="px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-colors flex items-center space-x-2"
              >
                <X className="h-4 w-4" />
                <span>Cancel</span>
              </button>
              <button
                onClick={handleSave}
                className="px-4 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 transition-colors flex items-center space-x-2"
              >
                <Save className="h-4 w-4" />
                <span>Save</span>
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Canvas */}
            <div className="lg:col-span-2">
              <div className="bg-white rounded-lg p-4">
                <div
                  ref={canvasRef}
                  className="relative w-full aspect-video bg-gray-100 rounded-lg overflow-hidden cursor-crosshair"
                  onMouseMove={handleMouseMove}
                  onMouseUp={handleMouseUp}
                  onMouseLeave={handleMouseUp}
                >
                  {isVideo ? (
                    <video
                      src={media}
                      className="w-full h-full object-cover"
                      controls
                      muted
                      loop
                    />
                  ) : (
                    <img
                      src={media}
                      alt="Uploaded content"
                      className="w-full h-full object-cover"
                    />
                  )}
                  
                  {/* Username Text Element */}
                  <div
                    className="absolute cursor-move select-none px-3 py-1 rounded"
                    style={{
                      left: `${textSettings.x}%`,
                      top: `${textSettings.y}%`,
                      transform: 'translate(-50%, -50%)',
                      fontFamily: textSettings.font,
                      fontSize: `${textSettings.fontSize}px`,
                      color: textSettings.color,
                      fontWeight: 'bold',
                      backgroundColor: textSettings.hasBackground ? textSettings.backgroundColor : 'transparent',
                      textShadow: textSettings.hasBackground ? 'none' : '2px 2px 4px rgba(0,0,0,0.8)',
                    }}
                    onMouseDown={() => handleMouseDown('text')}
                  >
                    {textSettings.text}
                  </div>
                  
                  {/* Profile Photo Placeholder */}
                  {profileSettings.enabled && (
                    <div
                      className="absolute cursor-move border-2 border-dashed border-white/50 flex items-center justify-center"
                      style={{
                        left: `${profileSettings.x}%`,
                        top: `${profileSettings.y}%`,
                        width: `${profileSettings.size}px`,
                        height: `${profileSettings.size}px`,
                        borderRadius: profileSettings.shape === 'circle' ? '50%' : '8px',
                        backgroundColor: profileSettings.hasBackground ? 'rgba(255,255,255,0.2)' : 'transparent',
                        transform: 'translate(-50%, -50%)',
                      }}
                      onMouseDown={() => handleMouseDown('profile')}
                    >
                      <div className="text-white text-xs text-center">Profile Photo</div>
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Controls */}
            <div className="space-y-6">
              {/* Text Controls */}
              <div className="bg-white/10 backdrop-blur-lg rounded-lg p-4 border border-white/20">
                <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
                  <Type className="h-5 w-5 mr-2" />
                  Username Display
                </h3>
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-white/80 mb-1">Username</label>
                    <input
                      type="text"
                      value={textSettings.text}
                      onChange={(e) => setTextSettings(prev => ({ ...prev, text: e.target.value }))}
                      className="w-full px-3 py-2 bg-white/20 border border-white/30 rounded-lg text-white placeholder-white/50 focus:ring-2 focus:ring-blue-500"
                      placeholder="Enter username"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-white/80 mb-1">Font</label>
                    <select
                      value={textSettings.font}
                      onChange={(e) => setTextSettings(prev => ({ ...prev, font: e.target.value }))}
                      className="w-full px-3 py-2 bg-white/20 border border-white/30 rounded-lg text-white focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="Arial">Arial</option>
                      <option value="Helvetica">Helvetica</option>
                      <option value="Times New Roman">Times New Roman</option>
                      <option value="Georgia">Georgia</option>
                      <option value="Verdana">Verdana</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-white/80 mb-1">Size: {textSettings.fontSize}px</label>
                    <input
                      type="range"
                      min="12"
                      max="48"
                      value={textSettings.fontSize}
                      onChange={(e) => setTextSettings(prev => ({ ...prev, fontSize: parseInt(e.target.value) }))}
                      className="w-full"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-white/80 mb-1">Text Color</label>
                    <input
                      type="color"
                      value={textSettings.color}
                      onChange={(e) => setTextSettings(prev => ({ ...prev, color: e.target.value }))}
                      className="w-full h-10 bg-white/20 border border-white/30 rounded-lg"
                    />
                  </div>
                  <div className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      id="textBackground"
                      checked={textSettings.hasBackground}
                      onChange={(e) => setTextSettings(prev => ({ ...prev, hasBackground: e.target.checked }))}
                      className="rounded"
                    />
                    <label htmlFor="textBackground" className="text-sm text-white/80">Background</label>
                  </div>
                  {textSettings.hasBackground && (
                    <div>
                      <label className="block text-sm font-medium text-white/80 mb-1">Background Color</label>
                      <input
                        type="color"
                        value={textSettings.backgroundColor}
                        onChange={(e) => setTextSettings(prev => ({ ...prev, backgroundColor: e.target.value }))}
                        className="w-full h-10 bg-white/20 border border-white/30 rounded-lg"
                      />
                    </div>
                  )}
                </div>
              </div>

              {/* Profile Controls */}
              <div className="bg-white/10 backdrop-blur-lg rounded-lg p-4 border border-white/20">
                <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
                  <Move className="h-5 w-5 mr-2" />
                  Profile Photo (Optional)
                </h3>
                <div className="space-y-4">
                  <div className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      id="enableProfile"
                      checked={profileSettings.enabled}
                      onChange={(e) => setProfileSettings(prev => ({ ...prev, enabled: e.target.checked }))}
                      className="rounded"
                    />
                    <label htmlFor="enableProfile" className="text-sm text-white/80 flex items-center">
                      {profileSettings.enabled ? <Eye className="h-4 w-4 mr-1" /> : <EyeOff className="h-4 w-4 mr-1" />}
                      Enable Profile Photo
                    </label>
                  </div>
                  
                  {profileSettings.enabled && (
                    <>
                      <div>
                        <label className="block text-sm font-medium text-white/80 mb-1">Shape</label>
                        <div className="flex space-x-4">
                          <button
                            onClick={() => setProfileSettings(prev => ({ ...prev, shape: 'circle' }))}
                            className={`flex items-center space-x-2 px-3 py-2 rounded-lg ${
                              profileSettings.shape === 'circle' 
                                ? 'bg-blue-500 text-white' 
                                : 'bg-white/20 text-white/80'
                            }`}
                          >
                            <Circle className="h-4 w-4" />
                            <span>Circle</span>
                          </button>
                          <button
                            onClick={() => setProfileSettings(prev => ({ ...prev, shape: 'square' }))}
                            className={`flex items-center space-x-2 px-3 py-2 rounded-lg ${
                              profileSettings.shape === 'square' 
                                ? 'bg-blue-500 text-white' 
                                : 'bg-white/20 text-white/80'
                            }`}
                          >
                            <Square className="h-4 w-4" />
                            <span>Square</span>
                          </button>
                        </div>
                      </div>
                      <div>
                        <label className="block text-sm font-medium text-white/80 mb-1">Size: {profileSettings.size}px</label>
                        <input
                          type="range"
                          min="40"
                          max="120"
                          value={profileSettings.size}
                          onChange={(e) => setProfileSettings(prev => ({ ...prev, size: parseInt(e.target.value) }))}
                          className="w-full"
                        />
                      </div>
                      <div className="flex items-center space-x-2">
                        <input
                          type="checkbox"
                          id="profileBackground"
                          checked={profileSettings.hasBackground}
                          onChange={(e) => setProfileSettings(prev => ({ ...prev, hasBackground: e.target.checked }))}
                          className="rounded"
                        />
                        <label htmlFor="profileBackground" className="text-sm text-white/80">Background</label>
                      </div>
                    </>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}