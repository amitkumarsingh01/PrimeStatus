import React, { useState, useRef } from 'react';
import { Save, X, Type, Move, Circle, Square, Palette, Eye, EyeOff, MapPin, Phone, Tag, MapPin as MapPinIcon } from 'lucide-react';
import { db } from '../firebase';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';

interface ImageEditorProps {
  media: string;
  category: string;
  region: string;
  language: 'english' | 'kannada';
  userName: string;
  onSave: (postData: any) => void;
  onCancel: () => void;
}

const CATEGORIES = [
  'Morning',
  'Motivational',
  'Love',
  'Festival',
  'Success',
  'Inspiration',
  'Life',
  'Friendship'
];

const REGIONS = [
  'Hindu',
  'Muslim',
  'Christian',
  'Jain',
  'Buddhist',
  'Sikh',
  'Other'
];

export default function ImageEditor({ media, category, region, language, userName, onSave, onCancel }: ImageEditorProps) {
  const canvasRef = useRef<HTMLDivElement>(null);
  const [selectedCategories, setSelectedCategories] = useState<string[]>(category ? [category] : []);
  const [selectedRegions, setSelectedRegions] = useState<string[]>(region ? [region] : []);
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
  const [addressSettings, setAddressSettings] = useState({
    text: '',
    x: 50,
    y: 80,
    font: 'Arial',
    fontSize: 18,
    color: '#ffffff',
    hasBackground: true,
    backgroundColor: '#000000',
    enabled: false,
  });
  const [phoneSettings, setPhoneSettings] = useState({
    text: '',
    x: 50,
    y: 85,
    font: 'Arial',
    fontSize: 18,
    color: '#ffffff',
    hasBackground: true,
    backgroundColor: '#000000',
    enabled: false,
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
  const [isDraggingAddress, setIsDraggingAddress] = useState(false);
  const [isDraggingPhone, setIsDraggingPhone] = useState(false);
  const [isDraggingProfile, setIsDraggingProfile] = useState(false);

  const handleMouseDown = (type: 'text' | 'address' | 'phone' | 'profile') => {
    if (type === 'text') setIsDraggingText(true);
    if (type === 'address' && addressSettings.enabled) setIsDraggingAddress(true);
    if (type === 'phone' && phoneSettings.enabled) setIsDraggingPhone(true);
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
    if (isDraggingAddress && addressSettings.enabled) {
      setAddressSettings(prev => ({ ...prev, x: Math.max(0, Math.min(100, x)), y: Math.max(0, Math.min(100, y)) }));
    }
    if (isDraggingPhone && phoneSettings.enabled) {
      setPhoneSettings(prev => ({ ...prev, x: Math.max(0, Math.min(100, x)), y: Math.max(0, Math.min(100, y)) }));
    }
    if (isDraggingProfile && profileSettings.enabled) {
      setProfileSettings(prev => ({ ...prev, x: Math.max(0, Math.min(100, x)), y: Math.max(0, Math.min(100, y)) }));
    }
  };

  const handleMouseUp = () => {
    setIsDraggingText(false);
    setIsDraggingAddress(false);
    setIsDraggingPhone(false);
    setIsDraggingProfile(false);
  };

  const handleCategoryToggle = (cat: string) => {
    setSelectedCategories(prev => 
      prev.includes(cat) 
        ? prev.filter(c => c !== cat)
        : [...prev, cat]
    );
  };

  const handleRegionToggle = (reg: string) => {
    setSelectedRegions(prev => 
      prev.includes(reg) 
        ? prev.filter(r => r !== reg)
        : [...prev, reg]
    );
  };

  const handleSave = async () => {
    if (selectedCategories.length === 0) {
      alert('Please select at least one category');
      return;
    }
    if (selectedRegions.length === 0) {
      alert('Please select at least one region');
      return;
    }

    const postData = {
      mainImage: media,
      categories: selectedCategories,
      regions: selectedRegions,
      language,
      textSettings,
      addressSettings,
      phoneSettings,
      profileSettings,
      adminName: userName,
      adminPhotoUrl: profileSettings.enabled ? '' : '',
      likes: 0,
      shares: 0,
      isPublished: true,
      createdBy: userName,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };
    try {
      await addDoc(collection(db, 'admin_posts'), postData);
      alert('Post saved to Firestore!');
      onSave(postData);
    } catch (e) {
      alert('Error saving post: ' + e);
    }
  };

  const isVideo = media.startsWith('data:video/') || media.startsWith('http');

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-orange-900 to-slate-900">
      {/* Header */}
      <div className="sticky top-0 z-10 bg-black/20 backdrop-blur-xl border-b border-white/10">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-white">Media Editor</h1>
              <p className="text-white/60 text-sm">
                Language: {language === 'kannada' ? 'ಕನ್ನಡ' : 'English'}
              </p>
            </div>
            <div className="flex space-x-3">
              <button
                onClick={onCancel}
                className="px-6 py-2 bg-red-500/20 border border-red-500/50 text-red-400 rounded-xl hover:bg-red-500/30 transition-all duration-200 flex items-center space-x-2"
              >
                <X className="h-4 w-4" />
                <span>Cancel</span>
              </button>
              <button
                onClick={handleSave}
                className="px-6 py-2 bg-gradient-to-r from-orange-600 to-blue-600 text-white rounded-xl hover:from-orange-700 hover:to-blue-700 transition-all duration-200 flex items-center space-x-2 shadow-lg"
              >
                <Save className="h-4 w-4" />
                <span>Save Post</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-6 py-6">
        <div className="grid grid-cols-12 gap-6 h-[calc(100vh-140px)]">
          
          {/* Left Panel - Categories & Regions */}
          <div className="col-span-3 space-y-4 overflow-y-auto">
            {/* Categories */}
            <div className="bg-white/10 backdrop-blur-xl rounded-2xl p-4 border border-white/20 shadow-xl">
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
                <Tag className="h-5 w-5 mr-2 text-orange-400" />
                Categories
              </h3>
              <div className="space-y-2">
                {CATEGORIES.map(cat => (
                  <label key={cat} className="flex items-center space-x-3 cursor-pointer group">
                    <input
                      type="checkbox"
                      checked={selectedCategories.includes(cat)}
                      onChange={() => handleCategoryToggle(cat)}
                      className="w-4 h-4 rounded border-gray-300 text-orange-600 focus:ring-orange-500"
                    />
                    <span className="text-sm text-white/80 group-hover:text-white transition-colors">{cat}</span>
                  </label>
                ))}
              </div>
              {selectedCategories.length === 0 && (
                <p className="text-red-400 text-xs mt-3 bg-red-500/10 p-2 rounded-lg">
                  Please select at least one category
                </p>
              )}
              {selectedCategories.length > 0 && (
                <div className="mt-3 p-2 bg-orange-500/10 rounded-lg">
                  <p className="text-xs text-orange-300">
                    Selected: {selectedCategories.join(', ')}
                  </p>
                </div>
              )}
            </div>

            {/* Regions */}
            <div className="bg-white/10 backdrop-blur-xl rounded-2xl p-4 border border-white/20 shadow-xl">
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
                <MapPinIcon className="h-5 w-5 mr-2 text-blue-400" />
                Regions
              </h3>
              <div className="space-y-2">
                {REGIONS.map(reg => (
                  <label key={reg} className="flex items-center space-x-3 cursor-pointer group">
                    <input
                      type="checkbox"
                      checked={selectedRegions.includes(reg)}
                      onChange={() => handleRegionToggle(reg)}
                      className="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                    />
                    <span className="text-sm text-white/80 group-hover:text-white transition-colors">{reg}</span>
                  </label>
                ))}
              </div>
              {selectedRegions.length === 0 && (
                <p className="text-red-400 text-xs mt-3 bg-red-500/10 p-2 rounded-lg">
                  Please select at least one region
                </p>
              )}
              {selectedRegions.length > 0 && (
                <div className="mt-3 p-2 bg-blue-500/10 rounded-lg">
                  <p className="text-xs text-blue-300">
                    Selected: {selectedRegions.join(', ')}
                  </p>
                </div>
              )}
            </div>
          </div>

          {/* Center Panel - Canvas */}
          <div className="col-span-6 flex flex-col">
            <div className="bg-white/10 backdrop-blur-xl rounded-2xl p-6 border border-white/20 shadow-xl flex-1 flex flex-col">
              <div className="text-center mb-4">
                <p className="text-sm text-white/60">Canvas Size: 1080x1920 (9:16 Portrait)</p>
              </div>
              <div className="flex-1 flex items-center justify-center">
                <div
                  ref={canvasRef}
                  className="relative bg-gray-900 rounded-xl overflow-hidden cursor-crosshair shadow-2xl border-2 border-white/20"
                  style={{ 
                    aspectRatio: '9/16',
                    maxWidth: '350px',
                    maxHeight: '620px',
                    width: '100%'
                  }}
                  onMouseMove={handleMouseMove}
                  onMouseUp={handleMouseUp}
                  onMouseLeave={handleMouseUp}
                >
                  {isVideo ? (
                    <video
                      src={media}
                      className="w-full h-full object-contain"
                      controls
                      muted
                      loop
                    />
                  ) : (
                    <img
                      src={media}
                      alt="Uploaded content"
                      className="w-full h-full object-contain"
                    />
                  )}
                  
                  {/* Username Text Element */}
                  <div
                    className="absolute cursor-move select-none px-3 py-1 rounded-lg transition-all duration-200 hover:scale-105"
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
                  
                  {/* Address Text Element */}
                  {addressSettings.enabled && (
                    <div
                      className="absolute cursor-move select-none px-3 py-1 rounded-lg transition-all duration-200 hover:scale-105"
                      style={{
                        left: `${addressSettings.x}%`,
                        top: `${addressSettings.y}%`,
                        transform: 'translate(-50%, -50%)',
                        fontFamily: addressSettings.font,
                        fontSize: `${addressSettings.fontSize}px`,
                        color: addressSettings.color,
                        fontWeight: 'bold',
                        backgroundColor: addressSettings.hasBackground ? addressSettings.backgroundColor : 'transparent',
                        textShadow: addressSettings.hasBackground ? 'none' : '2px 2px 4px rgba(0,0,0,0.8)',
                      }}
                      onMouseDown={() => handleMouseDown('address')}
                    >
                      {addressSettings.text}
                    </div>
                  )}
                  
                  {/* Phone Number Text Element */}
                  {phoneSettings.enabled && (
                    <div
                      className="absolute cursor-move select-none px-3 py-1 rounded-lg transition-all duration-200 hover:scale-105"
                      style={{
                        left: `${phoneSettings.x}%`,
                        top: `${phoneSettings.y}%`,
                        transform: 'translate(-50%, -50%)',
                        fontFamily: phoneSettings.font,
                        fontSize: `${phoneSettings.fontSize}px`,
                        color: phoneSettings.color,
                        fontWeight: 'bold',
                        backgroundColor: phoneSettings.hasBackground ? phoneSettings.backgroundColor : 'transparent',
                        textShadow: phoneSettings.hasBackground ? 'none' : '2px 2px 4px rgba(0,0,0,0.8)',
                      }}
                      onMouseDown={() => handleMouseDown('phone')}
                    >
                      {phoneSettings.text}
                    </div>
                  )}
                  
                  {/* Profile Photo Placeholder */}
                  {profileSettings.enabled && (
                    <div
                      className="absolute cursor-move border-2 border-dashed border-orange-400/50 flex items-center justify-center backdrop-blur-sm transition-all duration-200 hover:border-orange-400"
                      style={{
                        left: `${profileSettings.x}%`,
                        top: `${profileSettings.y}%`,
                        width: `${profileSettings.size}px`,
                        height: `${profileSettings.size}px`,
                        borderRadius: profileSettings.shape === 'circle' ? '50%' : '8px',
                        backgroundColor: profileSettings.hasBackground ? 'rgba(255,255,255,0.1)' : 'transparent',
                        transform: 'translate(-50%, -50%)',
                      }}
                      onMouseDown={() => handleMouseDown('profile')}
                    >
                      <div className="text-white/70 text-xs text-center">Profile Photo</div>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Right Panel - Controls */}
          <div className="col-span-3 space-y-4 overflow-y-auto">
            {/* Username Controls */}
            <div className="bg-white/10 backdrop-blur-xl rounded-2xl p-4 border border-white/20 shadow-xl">
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
                <Type className="h-5 w-5 mr-2 text-green-400" />
                Username
              </h3>
              <div className="space-y-3">
                <div>
                  <label className="block text-sm font-medium text-white/80 mb-2">Text</label>
                  <input
                    type="text"
                    value={textSettings.text}
                    onChange={(e) => setTextSettings(prev => ({ ...prev, text: e.target.value }))}
                    className="w-full px-3 py-2 bg-white/20 border border-white/30 rounded-lg text-white placeholder-white/50 focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                    placeholder="Enter username"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-white/80 mb-2">Size: {textSettings.fontSize}px</label>
                  <input
                    type="range"
                    min="12"
                    max="48"
                    value={textSettings.fontSize}
                    onChange={(e) => setTextSettings(prev => ({ ...prev, fontSize: parseInt(e.target.value) }))}
                    className="w-full accent-orange-500"
                  />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="block text-sm font-medium text-white/80 mb-2">Text Color</label>
                    <input
                      type="color"
                      value={textSettings.color}
                      onChange={(e) => setTextSettings(prev => ({ ...prev, color: e.target.value }))}
                      className="w-full h-10 bg-white/20 border border-white/30 rounded-lg"
                    />
                  </div>
                  {textSettings.hasBackground && (
                    <div>
                      <label className="block text-sm font-medium text-white/80 mb-2">Background</label>
                      <input
                        type="color"
                        value={textSettings.backgroundColor}
                        onChange={(e) => setTextSettings(prev => ({ ...prev, backgroundColor: e.target.value }))}
                        className="w-full h-10 bg-white/20 border border-white/30 rounded-lg"
                      />
                    </div>
                  )}
                </div>
                <div className="flex items-center space-x-2">
                  <input
                    type="checkbox"
                    id="textBackground"
                    checked={textSettings.hasBackground}
                    onChange={(e) => setTextSettings(prev => ({ ...prev, hasBackground: e.target.checked }))}
                    className="w-4 h-4 rounded border-gray-300 text-orange-600 focus:ring-orange-500"
                  />
                  <label htmlFor="textBackground" className="text-sm text-white/80">Enable Background</label>
                </div>
              </div>
            </div>

            {/* Address Controls */}
            <div className="bg-white/10 backdrop-blur-xl rounded-2xl p-4 border border-white/20 shadow-xl">
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
                <MapPin className="h-5 w-5 mr-2 text-orange-400" />
                Address
              </h3>
              <div className="space-y-3">
                <div className="flex items-center space-x-2">
                  <input
                    type="checkbox"
                    id="enableAddress"
                    checked={addressSettings.enabled}
                    onChange={(e) => setAddressSettings(prev => ({ ...prev, enabled: e.target.checked }))}
                    className="w-4 h-4 rounded border-gray-300 text-orange-600 focus:ring-orange-500"
                  />
                  <label htmlFor="enableAddress" className="text-sm text-white/80 flex items-center">
                    {addressSettings.enabled ? <Eye className="h-4 w-4 mr-1" /> : <EyeOff className="h-4 w-4 mr-1" />}
                    Enable Address
                  </label>
                </div>
                
                {addressSettings.enabled && (
                  <>
                    <input
                      type="text"
                      value={addressSettings.text}
                      onChange={(e) => setAddressSettings(prev => ({ ...prev, text: e.target.value }))}
                      className="w-full px-3 py-2 bg-white/20 border border-white/30 rounded-lg text-white placeholder-white/50 focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                      placeholder="Enter address"
                    />
                    <input
                      type="range"
                      min="10"
                      max="36"
                      value={addressSettings.fontSize}
                      onChange={(e) => setAddressSettings(prev => ({ ...prev, fontSize: parseInt(e.target.value) }))}
                      className="w-full accent-orange-500"
                    />
                  </>
                )}
              </div>
            </div>

            {/* Phone Controls */}
            <div className="bg-white/10 backdrop-blur-xl rounded-2xl p-4 border border-white/20 shadow-xl">
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
                <Phone className="h-5 w-5 mr-2 text-cyan-400" />
                Phone
              </h3>
              <div className="space-y-3">
                <div className="flex items-center space-x-2">
                  <input
                    type="checkbox"
                    id="enablePhone"
                    checked={phoneSettings.enabled}
                    onChange={(e) => setPhoneSettings(prev => ({ ...prev, enabled: e.target.checked }))}
                    className="w-4 h-4 rounded border-gray-300 text-cyan-600 focus:ring-cyan-500"
                  />
                  <label htmlFor="enablePhone" className="text-sm text-white/80 flex items-center">
                    {phoneSettings.enabled ? <Eye className="h-4 w-4 mr-1" /> : <EyeOff className="h-4 w-4 mr-1" />}
                    Enable Phone
                  </label>
                </div>
                
                {phoneSettings.enabled && (
                  <>
                    <input
                      type="text"
                      value={phoneSettings.text}
                      onChange={(e) => setPhoneSettings(prev => ({ ...prev, text: e.target.value }))}
                      className="w-full px-3 py-2 bg-white/20 border border-white/30 rounded-lg text-white placeholder-white/50 focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
                      placeholder="Enter phone number"
                    />
                    <input
                      type="range"
                      min="10"
                      max="36"
                      value={phoneSettings.fontSize}
                      onChange={(e) => setPhoneSettings(prev => ({ ...prev, fontSize: parseInt(e.target.value) }))}
                      className="w-full accent-cyan-500"
                    />
                  </>
                )}
              </div>
            </div>

            {/* Profile Controls */}
            <div className="bg-white/10 backdrop-blur-xl rounded-2xl p-4 border border-white/20 shadow-xl">
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
                <Move className="h-5 w-5 mr-2 text-pink-400" />
                Profile
              </h3>
              <div className="space-y-3">
                <div className="flex items-center space-x-2">
                  <input
                    type="checkbox"
                    id="enableProfile"
                    checked={profileSettings.enabled}
                    onChange={(e) => setProfileSettings(prev => ({ ...prev, enabled: e.target.checked }))}
                    className="w-4 h-4 rounded border-gray-300 text-pink-600 focus:ring-pink-500"
                  />
                  <label htmlFor="enableProfile" className="text-sm text-white/80 flex items-center">
                    {profileSettings.enabled ? <Eye className="h-4 w-4 mr-1" /> : <EyeOff className="h-4 w-4 mr-1" />}
                    Enable Profile
                  </label>
                </div>
                
                {profileSettings.enabled && (
                  <>
                    <div className="flex space-x-2">
                      <button
                        onClick={() => setProfileSettings(prev => ({ ...prev, shape: 'circle' }))}
                        className={`flex-1 flex items-center justify-center space-x-1 px-3 py-2 rounded-lg transition-all ${
                          profileSettings.shape === 'circle' 
                            ? 'bg-pink-500 text-white' 
                            : 'bg-white/20 text-white/80 hover:bg-white/30'
                        }`}
                      >
                        <Circle className="h-4 w-4" />
                        <span className="text-xs">Circle</span>
                      </button>
                      <button
                        onClick={() => setProfileSettings(prev => ({ ...prev, shape: 'square' }))}
                        className={`flex-1 flex items-center justify-center space-x-1 px-3 py-2 rounded-lg transition-all ${
                          profileSettings.shape === 'square' 
                            ? 'bg-pink-500 text-white' 
                            : 'bg-white/20 text-white/80 hover:bg-white/30'
                        }`}
                      >
                        <Square className="h-4 w-4" />
                        <span className="text-xs">Square</span>
                      </button>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-white/80 mb-2">Size: {profileSettings.size}px</label>
                      <input
                        type="range"
                        min="40"
                        max="120"
                        value={profileSettings.size}
                        onChange={(e) => setProfileSettings(prev => ({ ...prev, size: parseInt(e.target.value) }))}
                        className="w-full accent-pink-500"
                      />
                    </div>
                  </>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}