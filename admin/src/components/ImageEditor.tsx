import React, { useState, useRef, useEffect } from 'react';
import { Save, X, Type, Move, Circle, Square, Palette, Eye, EyeOff, MapPin, Phone, Tag, MapPin as MapPinIcon, Bell } from 'lucide-react';
import { db, uploadMediaFile } from '../firebase';
import { collection, addDoc, serverTimestamp, getDocs, writeBatch, doc } from 'firebase/firestore';

// Add @font-face declarations for local Kannada fonts
const fontFaceStyles = `
  @font-face {
    font-family: 'AnekKannada';
    src: url('/assets/fonts/Anek_Kannada/AnekKannada-VariableFont_wdth,wght.ttf') format('truetype');
    font-weight: normal;
    font-style: normal;
  }
  @font-face {
    font-family: 'BalooTamma2';
    src: url('/assets/fonts/Baloo_Tamma_2/BalooTamma2-VariableFont_wght.ttf') format('truetype');
    font-weight: normal;
    font-style: normal;
  }
  @font-face {
    font-family: 'NotoSansKannada';
    src: url('/assets/fonts/Noto_Sans_Kannada/NotoSansKannada-VariableFont_wdth,wght.ttf') format('truetype');
    font-weight: normal;
    font-style: normal;
  }
`;

interface ImageEditorProps {
  media: string;
  frameSize: { width: number; height: number };
  mediaType: 'image' | 'video';
  language: 'english' | 'kannada';
  userName: string;
  onSave?: (postData: any) => void;
  onCancel?: () => void;
}

const REGIONS = [
  'Hindu',
  'Muslim',
  'Christian',
  'Jain',
  'Buddhist',
  'Sikh',
  'Other'
];

const ENGLISH_FONTS = [
  'Poppins-Bold',
  'Poppins-BoldItalic',
  'Poppins-Medium',
  'Poppins-Regular',
  'Poppins-SemiBold',
  'Poppins-SemiBoldItalic',
  'Roboto-Bold',
  'Roboto-Medium',
  'Roboto-Regular',
  'Roboto-Light',
  'OpenSans-Bold',
  'OpenSans-SemiBold',
  'OpenSans-Regular',
  'OpenSans-Light',
  'Montserrat-Bold',
  'Montserrat-SemiBold',
  'Montserrat-Regular',
  'Montserrat-Light',
  'Inter-Bold',
  'Inter-SemiBold',
  'Inter-Regular',
  'Inter-Light',
  'Lato-Bold',
  'Lato-Regular',
  'Lato-Light',
  'SourceSansPro-Bold',
  'SourceSansPro-Regular',
  'SourceSansPro-Light',
  'Nunito-Bold',
  'Nunito-SemiBold',
  'Nunito-Regular',
  'Nunito-Light',
  'Ubuntu-Bold',
  'Ubuntu-Medium',
  'Ubuntu-Regular',
  'Ubuntu-Light',
  'PlayfairDisplay-Bold',
  'PlayfairDisplay-Regular',
  'Merriweather-Bold',
  'Merriweather-Regular',
  'Merriweather-Light',
  'Oswald-Bold',
  'Oswald-Regular',
  'Oswald-Light',
  'Raleway-Bold',
  'Raleway-SemiBold',
  'Raleway-Regular',
  'Raleway-Light',
  'PT-Sans-Bold',
  'PT-Sans-Regular',
  'PT-Sans-Narrow-Bold',
  'PT-Sans-Narrow-Regular',
  'Work-Sans-Bold',
  'Work-Sans-SemiBold',
  'Work-Sans-Regular',
  'Work-Sans-Light',
  'Quicksand-Bold',
  'Quicksand-SemiBold',
  'Quicksand-Regular',
  'Quicksand-Light',
  'Josefin-Sans-Bold',
  'Josefin-Sans-SemiBold',
  'Josefin-Sans-Regular',
  'Josefin-Sans-Light',
  'Bebas-Neue',
  'Anton',
  'Righteous',
  'Fredoka-One',
  'Pacifico',
  'Dancing-Script-Bold',
  'Dancing-Script-Regular',
  'Great-Vibes',
  'Satisfy',
  'Kaushan-Script',
  'Allura',
  'Alex-Brush',
  'Tangerine-Bold',
  'Tangerine-Regular',
  'Sacramento',
  'Courgette',
  'Yellowtail',
  'Homemade-Apple',
  'Caveat-Bold',
  'Caveat-Regular',
  'Indie-Flower',
  'Permanent-Marker',
  'Shadows-Into-Light',
  'Architects-Daughter',
  'Rock-Salt',
  'Special-Elite',
  'VT323',
  'Press-Start-2P',
  'Orbitron-Bold',
  'Orbitron-Regular',
  'Audiowide',
  'Russo-One',
  'Black-Ops-One',
  'Changa-One',
  'Faster-One',
  'Freckle-Face',
  'Frijole',
  'Gravitas-One',
  'Iceberg',
  'Keania-One',
  'Lemon',
  'Londrina-Solid',
  'Megrim',
  'Monoton',
  'Nixie-One',
  'Offside',
  'Plaster',
  'Ribeye',
  'Ribeye-Marrow',
  'Sonsie-One',
  'Stalinist-One',
  'UnifrakturMaguntia',
  'Vampiro-One',
  'Vast-Shadow',
  'Wallpoet',
  'Zilla-Slab-Bold',
  'Zilla-Slab-Regular',
  'Zilla-Slab-Light',
];
const KANNADA_FONT_GROUPS = [
  {
    label: 'Kannada Fonts',
    fonts: [
      'AnekKannada',
      'BalooTamma2',
      'NotoSansKannada',
    ],
  },
];

const getFontOptions = (lang: 'english' | 'kannada') => {
  if (lang === 'english') return ENGLISH_FONTS;
  // Flatten all Kannada fonts for value, but group for display
  return KANNADA_FONT_GROUPS.flatMap(g => g.fonts);
};
const getFontGroups = (lang: 'english' | 'kannada') => {
  if (lang === 'english') return null;
  return KANNADA_FONT_GROUPS;
};

function getFontFamily(font: string) {
  // English fonts (Poppins)
  if (font.startsWith('Poppins')) return `'${font}', Poppins, Arial, sans-serif`;
  
  // Google Fonts - Sans Serif
  if (font.startsWith('Roboto')) return `'${font}', Roboto, Arial, sans-serif`;
  if (font.startsWith('OpenSans')) return `'${font}', 'Open Sans', Arial, sans-serif`;
  if (font.startsWith('Montserrat')) return `'${font}', Montserrat, Arial, sans-serif`;
  if (font.startsWith('Inter')) return `'${font}', Inter, Arial, sans-serif`;
  if (font.startsWith('Lato')) return `'${font}', Lato, Arial, sans-serif`;
  if (font.startsWith('SourceSansPro')) return `'${font}', 'Source Sans Pro', Arial, sans-serif`;
  if (font.startsWith('Nunito')) return `'${font}', Nunito, Arial, sans-serif`;
  if (font.startsWith('Ubuntu')) return `'${font}', Ubuntu, Arial, sans-serif`;
  if (font.startsWith('Raleway')) return `'${font}', Raleway, Arial, sans-serif`;
  if (font.startsWith('PT-Sans')) return `'${font}', 'PT Sans', Arial, sans-serif`;
  if (font.startsWith('Work-Sans')) return `'${font}', 'Work Sans', Arial, sans-serif`;
  if (font.startsWith('Quicksand')) return `'${font}', Quicksand, Arial, sans-serif`;
  if (font.startsWith('Josefin-Sans')) return `'${font}', 'Josefin Sans', Arial, sans-serif`;
  if (font.startsWith('Zilla-Slab')) return `'${font}', 'Zilla Slab', Arial, sans-serif`;
  
  // Google Fonts - Serif
  if (font.startsWith('PlayfairDisplay')) return `'${font}', 'Playfair Display', Georgia, serif`;
  if (font.startsWith('Merriweather')) return `'${font}', Merriweather, Georgia, serif`;
  
  // Google Fonts - Display/Decorative
  if (font.startsWith('Oswald')) return `'${font}', Oswald, Arial, sans-serif`;
  if (font.startsWith('Bebas-Neue')) return `'Bebas Neue', Arial, sans-serif`;
  if (font === 'Anton') return `'Anton', Arial, sans-serif`;
  if (font === 'Righteous') return `'Righteous', Arial, sans-serif`;
  if (font === 'Fredoka-One') return `'Fredoka One', Arial, sans-serif`;
  if (font === 'Pacifico') return `'Pacifico', cursive`;
  if (font.startsWith('Dancing-Script')) return `'${font}', 'Dancing Script', cursive`;
  if (font === 'Great-Vibes') return `'Great Vibes', cursive`;
  if (font === 'Satisfy') return `'Satisfy', cursive`;
  if (font === 'Kaushan-Script') return `'Kaushan Script', cursive`;
  if (font === 'Allura') return `'Allura', cursive`;
  if (font === 'Alex-Brush') return `'Alex Brush', cursive`;
  if (font.startsWith('Tangerine')) return `'${font}', Tangerine, cursive`;
  if (font === 'Sacramento') return `'Sacramento', cursive`;
  if (font === 'Courgette') return `'Courgette', cursive`;
  if (font === 'Yellowtail') return `'Yellowtail', cursive`;
  if (font === 'Homemade-Apple') return `'Homemade Apple', cursive`;
  if (font.startsWith('Caveat')) return `'${font}', Caveat, cursive`;
  if (font === 'Indie-Flower') return `'Indie Flower', cursive`;
  if (font === 'Permanent-Marker') return `'Permanent Marker', cursive`;
  if (font === 'Shadows-Into-Light') return `'Shadows Into Light', cursive`;
  if (font === 'Architects-Daughter') return `'Architects Daughter', cursive`;
  if (font === 'Rock-Salt') return `'Rock Salt', cursive`;
  if (font === 'Special-Elite') return `'Special Elite', cursive`;
  if (font === 'VT323') return `'VT323', monospace`;
  if (font === 'Press-Start-2P') return `'Press Start 2P', monospace`;
  if (font.startsWith('Orbitron')) return `'${font}', Orbitron, monospace`;
  if (font === 'Audiowide') return `'Audiowide', cursive`;
  if (font === 'Russo-One') return `'Russo One', sans-serif`;
  if (font === 'Black-Ops-One') return `'Black Ops One', cursive`;
  if (font === 'Changa-One') return `'Changa One', cursive`;
  if (font === 'Faster-One') return `'Faster One', cursive`;
  if (font === 'Freckle-Face') return `'Freckle Face', cursive`;
  if (font === 'Frijole') return `'Frijole', cursive`;
  if (font === 'Gravitas-One') return `'Gravitas One', cursive`;
  if (font === 'Iceberg') return `'Iceberg', cursive`;
  if (font === 'Keania-One') return `'Keania One', cursive`;
  if (font === 'Lemon') return `'Lemon', cursive`;
  if (font === 'Londrina-Solid') return `'Londrina Solid', cursive`;
  if (font === 'Megrim') return `'Megrim', cursive`;
  if (font === 'Monoton') return `'Monoton', cursive`;
  if (font === 'Nixie-One') return `'Nixie One', cursive`;
  if (font === 'Offside') return `'Offside', cursive`;
  if (font === 'Plaster') return `'Plaster', cursive`;
  if (font === 'Ribeye') return `'Ribeye', cursive`;
  if (font === 'Ribeye-Marrow') return `'Ribeye Marrow', cursive`;
  if (font === 'Sonsie-One') return `'Sonsie One', cursive`;
  if (font === 'Stalinist-One') return `'Stalinist One', cursive`;
  if (font === 'UnifrakturMaguntia') return `'UnifrakturMaguntia', cursive`;
  if (font === 'Vampiro-One') return `'Vampiro One', cursive`;
  if (font === 'Vast-Shadow') return `'Vast Shadow', cursive`;
  if (font === 'Wallpoet') return `'Wallpoet', cursive`;
  
  // Kannada Fonts
  if (font === 'AnekKannada') return `'AnekKannada', 'Anek Kannada', Arial, sans-serif`;
  if (font === 'BalooTamma2') return `'BalooTamma2', 'Baloo Tamma 2', Arial, sans-serif`;
  if (font === 'NotoSansKannada') return `'NotoSansKannada', 'Noto Sans Kannada', Arial, sans-serif`;
  
  return `'${font}', Arial, sans-serif`;
}

export default function ImageEditor({ media, frameSize, mediaType, language, userName, onSave, onCancel }: ImageEditorProps) {
  const canvasRef = useRef<HTMLDivElement>(null);
  const [categories, setCategories] = useState<{ id: string; nameEn: string; nameKn: string; isBusiness?: boolean }[]>([]);
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]);
  const [selectedRegions, setSelectedRegions] = useState<string[]>([]);
  const [selectedBusinessCategory, setSelectedBusinessCategory] = useState<string>('');
  const [sendNotification, setSendNotification] = useState(false);
  const [isScheduled, setIsScheduled] = useState(false);
  const [scheduledDate, setScheduledDate] = useState('');
  const [scheduledTime, setScheduledTime] = useState('');

  // Default settings for 1080x1350 (Portrait)
  const portraitDefaults = {
    textSettings: {
      text: 'ಶ್ರೀ ಆನಂದಕುಮಾರ ಪ್ಯಾಟಿ',
      x: 33.25,
      y: 84.87999877929687,
      font: language === 'kannada' ? 'NotoSansKannada' : 'Arial',
      fontSize: 16,
      color: '#ffffff',
      hasBackground: false,
      backgroundColor: '#000000',
    },
    addressSettings: {
      text: 'ಅಧ್ಯಕ್ಷರು, ಆವಿಷ್ಕಾರ ಶಿಕ್ಷಣ ಸಂಸ್ಥೆ ಸುರಪುರ',
      x: 34,
      y: 91.47999877929688,
      font: language === 'kannada' ? 'NotoSansKannada' : 'Arial',
      fontSize: 12,
      color: '#ffffff',
      hasBackground: false,
      backgroundColor: '#000000',
      enabled: true,
    },
    phoneSettings: {
      text: '9876543210',
      x: 45,
      y: 85,
      font: language === 'kannada' ? 'NotoSansKannada' : 'Arial',
      fontSize: 18,
      color: '#ffffff',
      hasBackground: true,
      backgroundColor: '#000000',
      enabled: false,
    },
    businessNameSettings: {
      text: 'PrimeStatus Business',
      x: 50,
      y: 20,
      font: language === 'kannada' ? 'NotoSansKannada' : 'Arial',
      fontSize: 14,
      color: '#ffffff',
      hasBackground: false,
      backgroundColor: '#000000',
      enabled: false,
    },
    designationSettings: {
      text: 'Software Engineer',
      x: 50,
      y: 25,
      font: language === 'kannada' ? 'NotoSansKannada' : 'Arial',
      fontSize: 16,
      color: '#ffffff',
      hasBackground: false,
      backgroundColor: '#000000',
      enabled: false,
    },
    profileSettings: {
      x: 83.25,
      y: 85.87999877929687,
      shape: 'square' as 'circle' | 'square',
      size: 100,
      hasBackground: false,
      enabled: true,
    },
  };
  // Default settings for 1080x1080 (Square)
  const squareDefaults = {
    textSettings: {
      text: 'ಶ್ರೀ ಆನಂದಕುಮಾರ ಪ್ಯಾಟಿ',
      x: 36,
      y: 86.5999984741211,
      font: language === 'kannada' ? 'NotoSansKannada' : 'Arial',
      fontSize: 19,
      color: '#ffffff',
      hasBackground: false,
      backgroundColor: '#000000',
    },
    addressSettings: {
      text: 'ಅಧ್ಯಕ್ಷರು, ಆವಿಷ್ಕಾರ ಶಿಕ್ಷಣ ಸಂಸ್ಥೆ ಸುರಪುರ',
      x: 36.75,
      y: 94.8499984741211,
      font: language === 'kannada' ? 'NotoSansKannada' : 'Arial',
      fontSize: 13,
      color: '#ffffff',
      hasBackground: false,
      backgroundColor: '#000000',
      enabled: true,
    },
    phoneSettings: {
      text: '9876543210',
      x: 21,
      y: 68.3499984741211,
      font: language === 'kannada' ? 'NotoSansKannada' : 'Arial',
      fontSize: 18,
      color: '#ffffff',
      hasBackground: false,
      backgroundColor: '#000000',
      enabled: false,
    },
    businessNameSettings: {
      text: 'PrimeStatus Business',
      x: 50,
      y: 15,
      font: language === 'kannada' ? 'NotoSansKannada' : 'Arial',
      fontSize: 16,
      color: '#ffffff',
      hasBackground: false,
      backgroundColor: '#000000',
      enabled: false,
    },
    designationSettings: {
      text: 'Software Engineer',
      x: 50,
      y: 20,
      font: language === 'kannada' ? 'NotoSansKannada' : 'Arial',
      fontSize: 18,
      color: '#ffffff',
      hasBackground: false,
      backgroundColor: '#000000',
      enabled: false,
    },
    profileSettings: {
      x: 85.75,
      y: 86.0999984741211,
      shape: 'square' as 'circle' | 'square',
      size: 104,
      hasBackground: false,
      enabled: true,
    },
  };

  // Pick defaults based on frameSize
  function getDefaults() {
    if (frameSize.width === 1080 && frameSize.height === 1350) return portraitDefaults;
    if (frameSize.width === 1080 && frameSize.height === 1080) return squareDefaults;
    // fallback to portrait
    return portraitDefaults;
  }

  // State for settings
  const [textSettings, setTextSettings] = useState(getDefaults().textSettings);
  const [addressSettings, setAddressSettings] = useState(getDefaults().addressSettings);
  const [phoneSettings, setPhoneSettings] = useState(getDefaults().phoneSettings);
  const [businessNameSettings, setBusinessNameSettings] = useState(getDefaults().businessNameSettings);
  const [designationSettings, setDesignationSettings] = useState(getDefaults().designationSettings);
  const [profileSettings, setProfileSettings] = useState(getDefaults().profileSettings);

  // Update settings if frameSize changes
  useEffect(() => {
    const defaults = getDefaults();
    setTextSettings(defaults.textSettings);
    setAddressSettings(defaults.addressSettings);
    setPhoneSettings(defaults.phoneSettings);
    setBusinessNameSettings(defaults.businessNameSettings);
    setDesignationSettings(defaults.designationSettings);
    setProfileSettings(defaults.profileSettings);
  }, [frameSize.width, frameSize.height, language]);

  const [isDraggingText, setIsDraggingText] = useState(false);
  const [isDraggingAddress, setIsDraggingAddress] = useState(false);
  const [isDraggingPhone, setIsDraggingPhone] = useState(false);
  const [isDraggingBusinessName, setIsDraggingBusinessName] = useState(false);
  const [isDraggingDesignation, setIsDraggingDesignation] = useState(false);
  const [isDraggingProfile, setIsDraggingProfile] = useState(false);

  useEffect(() => {
    // Fetch categories from Firestore
    const fetchCategories = async () => {
      try {
        const querySnapshot = await getDocs(collection(db, 'categories'));
        let fetchedCategories = querySnapshot.docs.map(docSnap => ({
          id: docSnap.id,
          nameEn: docSnap.data().nameEn || '',
          nameKn: docSnap.data().nameKn || '',
          isBusiness: docSnap.data().isBusiness || false,
        }));

        // Check if business categories exist, if not create them
        const businessCategoryNames = [
          'Education & Training', 'Health & Services', 'Retail & Shopping', 
          'Finance & Services', 'Travel & Ticketing', 'Digital & Tech', 
          'Food & Lifestyle', 'Online Services'
        ];
        
        const existingBusinessCategories = fetchedCategories.filter(cat => cat.isBusiness);
        const existingBusinessCategoryNames = existingBusinessCategories.map(cat => cat.nameEn);
        
        // Find missing business categories
        const missingBusinessCategories = businessCategoryNames.filter(name => 
          !existingBusinessCategoryNames.includes(name)
        );
        
        if (missingBusinessCategories.length > 0) {
          console.log('Creating missing business categories in Firestore:', missingBusinessCategories);
          const businessCategories = [
            { nameEn: 'Education & Training', nameKn: 'ಶಿಕ್ಷಣ ಮತ್ತು ತರಬೇತಿ', position: 2 },
            { nameEn: 'Health & Services', nameKn: 'ಆರೋಗ್ಯ ಮತ್ತು ಸೇವೆಗಳು', position: 3 },
            { nameEn: 'Retail & Shopping', nameKn: 'ರಿಟೇಲ್ ಮತ್ತು ಶಾಪಿಂಗ್', position: 4 },
            { nameEn: 'Finance & Services', nameKn: 'ಹಣಕಾಸು ಮತ್ತು ಸೇವೆಗಳು', position: 5 },
            { nameEn: 'Travel & Ticketing', nameKn: 'ಪ್ರಯಾಣ ಮತ್ತು ಟಿಕೆಟಿಂಗ್', position: 6 },
            { nameEn: 'Digital & Tech', nameKn: 'ಡಿಜಿಟಲ್ ಮತ್ತು ತಂತ್ರಜ್ಞಾನ', position: 7 },
            { nameEn: 'Food & Lifestyle', nameKn: 'ಆಹಾರ ಮತ್ತು ಜೀವನಶೈಲಿ', position: 8 },
            { nameEn: 'Online Services', nameKn: 'ಆನ್ಲೈನ್ ಸೇವೆಗಳು', position: 9 }
          ].filter(cat => missingBusinessCategories.includes(cat.nameEn));

          const batch = writeBatch(db);
          businessCategories.forEach((businessCat) => {
            const newCategoryRef = doc(collection(db, 'categories'));
            batch.set(newCategoryRef, {
              nameEn: businessCat.nameEn,
              nameKn: businessCat.nameKn,
              position: businessCat.position,
              isFixed: true,
              isBusiness: true,
              type: 'business'
            });
          });
          await batch.commit();
          console.log('Missing business categories created in Firestore');

          // Fetch categories again to get the updated list
          const updatedQuerySnapshot = await getDocs(collection(db, 'categories'));
          fetchedCategories = updatedQuerySnapshot.docs.map(docSnap => ({
            id: docSnap.id,
            nameEn: docSnap.data().nameEn || '',
            nameKn: docSnap.data().nameKn || '',
            isBusiness: docSnap.data().isBusiness || false,
          }));
        }
        
        // Remove duplicate business categories (keep only unique ones)
        const uniqueBusinessCategories = [];
        const seenBusinessNames = new Set();
        
        fetchedCategories.forEach(cat => {
          if (cat.isBusiness && !seenBusinessNames.has(cat.nameEn)) {
            seenBusinessNames.add(cat.nameEn);
            uniqueBusinessCategories.push(cat);
          }
        });
        
        // Replace business categories with unique ones
        const nonBusinessCategories = fetchedCategories.filter(cat => !cat.isBusiness);
        fetchedCategories = [...nonBusinessCategories, ...uniqueBusinessCategories];

        console.log('All categories loaded:', fetchedCategories.map(cat => ({ name: cat.nameEn, isBusiness: cat.isBusiness })));
        setCategories(fetchedCategories);
        
        // Auto-select all regions only
        setSelectedRegions([...REGIONS]);
        
      } catch (e) {
        console.error('Error fetching/creating categories:', e);
      }
    };
    fetchCategories();
  }, []);

  const handleMouseDown = (type: 'text' | 'address' | 'phone' | 'businessName' | 'designation' | 'profile') => {
    if (type === 'text') setIsDraggingText(true);
    if (type === 'address' && addressSettings.enabled) setIsDraggingAddress(true);
    if (type === 'phone' && phoneSettings.enabled) setIsDraggingPhone(true);
    if (type === 'businessName' && businessNameSettings.enabled) setIsDraggingBusinessName(true);
    if (type === 'designation' && designationSettings.enabled) setIsDraggingDesignation(true);
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
    if (isDraggingBusinessName && businessNameSettings.enabled) {
      setBusinessNameSettings(prev => ({ ...prev, x: Math.max(0, Math.min(100, x)), y: Math.max(0, Math.min(100, y)) }));
    }
    if (isDraggingDesignation && designationSettings.enabled) {
      setDesignationSettings(prev => ({ ...prev, x: Math.max(0, Math.min(100, x)), y: Math.max(0, Math.min(100, y)) }));
    }
    if (isDraggingProfile && profileSettings.enabled) {
      setProfileSettings(prev => ({ ...prev, x: Math.max(0, Math.min(100, x)), y: Math.max(0, Math.min(100, y)) }));
    }
  };

  const handleMouseUp = () => {
    setIsDraggingText(false);
    setIsDraggingAddress(false);
    setIsDraggingPhone(false);
    setIsDraggingBusinessName(false);
    setIsDraggingDesignation(false);
    setIsDraggingProfile(false);
  };

  const handleCategoryToggle = (catId: string) => {
    setSelectedCategories(prev =>
      prev.includes(catId)
        ? prev.filter(c => c !== catId)
        : [...prev, catId]
    );
  };

  const handleRegionToggle = (reg: string) => {
    setSelectedRegions(prev => 
      prev.includes(reg) 
        ? prev.filter(r => r !== reg)
        : [...prev, reg]
    );
  };

  const handleSave = async (isScheduledPost: boolean = false) => {
    if (selectedCategories.length === 0) {
      alert('Please select at least one category');
      return;
    }
    if (selectedRegions.length === 0) {
      alert('Please select at least one region');
      return;
    }
    if (isScheduledPost && (!scheduledDate || !scheduledTime)) {
      alert('Please select both date and time for scheduled post');
      return;
    }
    if (isScheduledPost) {
      const scheduledDateTime = new Date(`${scheduledDate}T${scheduledTime}`);
      if (scheduledDateTime <= new Date()) {
        alert('Scheduled time must be in the future');
        return;
      }
    }

    let mainImageUrl = media;
    if (mediaType === 'image' && media.startsWith('data:')) {
      // Upload base64 image to Firebase Storage
      const fileName = `admin_images/${userName}_${Date.now()}.png`;
      mainImageUrl = await uploadMediaFile(dataURLtoFile(media, fileName), fileName);
    }

    // Adjust x-axis values before sending to Firebase
    const adjustedTextSettings = {
      ...textSettings,
      x: textSettings.x - 5
    };

    const adjustedAddressSettings = {
      ...addressSettings,
      x: addressSettings.x - 5
    };

    const adjustedPhoneSettings = {
      ...phoneSettings,
      x: phoneSettings.x - 5
    };

    const adjustedBusinessNameSettings = {
      ...businessNameSettings,
      x: businessNameSettings.x - 5
    };

    const adjustedDesignationSettings = {
      ...designationSettings,
      x: designationSettings.x - 5
    };

    // Get category names instead of IDs (excluding business categories)
    const selectedCategoryNames = categories
      .filter(cat => selectedCategories.includes(cat.id) && !cat.isBusiness)
      .map(cat => cat.nameEn);

    // Get business category name if selected
    const businessCategoryName = selectedBusinessCategory 
      ? categories.find(cat => cat.id === selectedBusinessCategory)?.nameEn || ''
      : '';

    const postData = {
      mainImage: mainImageUrl,
      categories: selectedCategoryNames,
      businessCategory: businessCategoryName,
      regions: selectedRegions,
      frameSize,
      mediaType,
      language,
      textSettings: adjustedTextSettings,
      addressSettings: adjustedAddressSettings,
      phoneSettings: adjustedPhoneSettings,
      businessNameSettings: adjustedBusinessNameSettings,
      designationSettings: adjustedDesignationSettings,
      profileSettings,
      adminName: userName,
      adminPhotoUrl: profileSettings.enabled ? '' : '',
      likes: 0,
      shares: 0,
      isPublished: !isScheduledPost, // Only publish immediately if not scheduled
      isScheduled: isScheduledPost,
      scheduledDateTime: isScheduledPost ? new Date(`${scheduledDate}T${scheduledTime}`).toISOString() : null,
      sendNotification: sendNotification, // Include notification preference
      createdBy: userName,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    try {
      // Save the post to Firestore
      const docRef = await addDoc(collection(db, 'admin_posts'), postData);
      
      // If notification is enabled and not scheduled, create a notification document for automatic sending
      if (sendNotification && !isScheduledPost) {
        const notificationData = {
          title: 'New Post Available!',
          body: `Check out the latest post by PrimeStatus`,
          imageUrl: mainImageUrl,
          postId: docRef.id,
          adminName: userName,
          categories: selectedCategoryNames,
          businessCategory: businessCategoryName,
          regions: selectedRegions,
          language: language,
          topic: 'all_users', // Topic to send to
          status: 'pending',
          createdAt: serverTimestamp(),
          fcmData: {
            postId: docRef.id,
            adminName: userName,
            imageUrl: mainImageUrl,
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
          }
        };
        
        await addDoc(collection(db, 'pending_notifications'), notificationData);
        console.log('Notification document created. Will be sent automatically.');
      }
      
      // Show success message
      if (isScheduledPost) {
        const scheduledDateTime = new Date(`${scheduledDate}T${scheduledTime}`);
        alert(`Post scheduled successfully! It will be published on ${scheduledDateTime.toLocaleDateString()} at ${scheduledDateTime.toLocaleTimeString()}`);
      } else {
        alert('Post saved and published successfully!' + (sendNotification ? ' Notification will be sent to all users.' : ''));
      }
      
      onSave?.(postData);
    } catch (e) {
      alert('Error saving post: ' + e);
    }
  };

  // Helper to convert base64 to File
  function dataURLtoFile(dataurl: string, filename: string) {
    const arr = dataurl.split(','), match = arr[0].match(/:(.*?);/);
    const mime = match ? match[1] : 'image/png';
    const bstr = atob(arr[1]), n = bstr.length, u8arr = new Uint8Array(n);
    for (let i = 0; i < n; i++) u8arr[i] = bstr.charCodeAt(i);
    return new File([u8arr], filename, { type: mime });
  }

  // Calculate scaled frame size to fit within max bounds but keep aspect ratio
  const MAX_WIDTH = 400;
  const MAX_HEIGHT = 700;
  let scale = Math.min(MAX_WIDTH / frameSize.width, MAX_HEIGHT / frameSize.height);
  const scaledWidth = Math.round(frameSize.width * scale);
  const scaledHeight = Math.round(frameSize.height * scale);

  return (
    <div className="min-h-screen bg-white">
      {/* Inject font-face styles */}
      <style dangerouslySetInnerHTML={{ __html: fontFaceStyles }} />
      
      {/* Header */}
      <div className="sticky top-0 z-10 bg-white border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-black">Media Editor</h1>
              <p className="text-gray-600 text-sm">
                Language: {language === 'kannada' ? 'ಕನ್ನಡ' : 'English'}
              </p>
            </div>
            <div className="flex space-x-3">
              <button
                onClick={onCancel}
                className="px-6 py-2 bg-red-100 border border-red-300 text-red-700 rounded-xl hover:bg-red-200 transition-all duration-200 flex items-center space-x-2"
              >
                <X className="h-4 w-4" />
                <span>Cancel</span>
              </button>
              <div className="flex space-x-3">
              <button
                  onClick={() => handleSave(false)}
                className="px-6 py-2 bg-gradient-to-r from-orange-400 to-blue-400 text-black rounded-xl hover:from-orange-500 hover:to-blue-500 transition-all duration-200 flex items-center space-x-2 shadow-lg"
              >
                <Save className="h-4 w-4" />
                <span>Save Post</span>
              </button>
                <button
                  onClick={() => handleSave(true)}
                  disabled={!isScheduled || !scheduledDate || !scheduledTime}
                  className="px-6 py-2 bg-gradient-to-r from-green-400 to-teal-400 text-black rounded-xl hover:from-green-500 hover:to-teal-500 transition-all duration-200 flex items-center space-x-2 shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <Save className="h-4 w-4" />
                  <span>Schedule Post</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-6 py-6">
        <div className="grid grid-cols-12 gap-6 h-[calc(100vh-140px)]">
          
          {/* Left Panel - Categories & Regions */}
          <div className="col-span-3 space-y-4 overflow-y-auto">
            {/* Notification Settings */}
            <div className="bg-gray-50 rounded-2xl p-4 border border-gray-200 shadow-xl">
              <h3 className="text-lg font-semibold text-black mb-4 flex items-center">
                <Bell className="h-5 w-5 mr-2 text-purple-400" />
                Notification & Scheduling
              </h3>
              <div className="space-y-3">
                <div className="flex items-center space-x-3 cursor-pointer group">
                  <input
                    type="checkbox"
                    id="sendNotification"
                    checked={sendNotification}
                    onChange={(e) => setSendNotification(e.target.checked)}
                    className="w-4 h-4 rounded border-gray-300 text-purple-600 focus:ring-purple-500"
                  />
                  <label htmlFor="sendNotification" className="text-sm text-gray-700 group-hover:text-black transition-colors cursor-pointer">
                    Send notification to all users
                  </label>
                </div>
                {sendNotification && (
                  <div className="mt-3 p-3 bg-purple-500/10 rounded-lg">
                    <p className="text-xs text-purple-600">
                      <strong>Notification Preview:</strong><br/>
                      Title: "New Post Available!"<br/>
                      Body: "Check out the latest post by PrimeStatus"<br/>
                      Image: Will include the post image<br/>
                      <br/>
                      <strong>Note:</strong> Notification will be sent automatically to all users
                    </p>
                  </div>
                )}

                {/* Scheduling Option */}
                <div className="border-t border-gray-200 pt-4">
                  <div className="flex items-center space-x-3 cursor-pointer group">
                    <input
                      type="checkbox"
                      id="isScheduled"
                      checked={isScheduled}
                      onChange={(e) => setIsScheduled(e.target.checked)}
                      className="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                    />
                    <label htmlFor="isScheduled" className="text-sm text-gray-700 group-hover:text-black transition-colors cursor-pointer">
                      Schedule this post
                    </label>
                  </div>
                  
                  {isScheduled && (
                    <div className="ml-7 mt-3 space-y-3">
                      <div>
                        <label className="block text-xs text-gray-600 mb-1">Date</label>
                        <input
                          type="date"
                          value={scheduledDate}
                          onChange={(e) => setScheduledDate(e.target.value)}
                          min={new Date().toISOString().split('T')[0]}
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                        />
                      </div>
                      <div>
                        <label className="block text-xs text-gray-600 mb-1">Time</label>
                        <input
                          type="time"
                          value={scheduledTime}
                          onChange={(e) => setScheduledTime(e.target.value)}
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                        />
                      </div>
                      <div className="p-3 bg-blue-50 rounded-lg border border-blue-200">
                        <p className="text-xs text-blue-600">
                          ⏰ Post will be automatically published at the scheduled time
                        </p>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Categories */}
            <div className="bg-gray-50 rounded-2xl p-4 border border-gray-200 shadow-xl">
              <h3 className="text-lg font-semibold text-black mb-4 flex items-center">
                <Tag className="h-5 w-5 mr-2 text-orange-400" />
                Categories
              </h3>
              <div className="space-y-2">
                {categories.length === 0 ? (
                  <div className="text-gray-400 text-sm">No categories found. Add some in Category Manager.</div>
                ) : (
                  categories.filter(cat => !cat.isBusiness).map(cat => (
                    <label key={cat.id} className="flex items-center space-x-3 cursor-pointer group">
                      <input
                        type="checkbox"
                        checked={selectedCategories.includes(cat.id)}
                        onChange={() => handleCategoryToggle(cat.id)}
                        className="w-4 h-4 rounded border-gray-300 text-orange-600 focus:ring-orange-500"
                      />
                      <span className="text-sm text-gray-700 group-hover:text-black transition-colors">
                        {language === 'kannada' ? cat.nameKn : cat.nameEn}
                      </span>
                    </label>
                  ))
                )}
              </div>
              {selectedCategories.length === 0 && (
                <p className="text-red-400 text-xs mt-3 bg-red-500/10 p-2 rounded-lg">
                  Please select at least one category
                </p>
              )}
              {selectedCategories.length > 0 && (
                <div className="mt-3 p-2 bg-orange-500/10 rounded-lg">
                  <p className="text-xs text-orange-300">
                    Selected: {categories.filter(cat => selectedCategories.includes(cat.id) && !cat.isBusiness).map(cat => language === 'kannada' ? cat.nameKn : cat.nameEn).join(', ')}
                  </p>
                </div>
              )}
            </div>

            {/* Business Category Selection */}
            <div className="bg-gray-50 rounded-2xl p-4 border border-gray-200 shadow-xl">
              <h3 className="text-lg font-semibold text-black mb-4 flex items-center">
                <Tag className="h-5 w-5 mr-2 text-purple-400" />
                Business Categories
              </h3>
              <div className="space-y-3">
                <select
                  value={selectedBusinessCategory}
                  onChange={(e) => setSelectedBusinessCategory(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 bg-white"
                >
                  <option value="">Select a business category (optional)</option>
                  {categories.filter(cat => cat.isBusiness).map(cat => (
                    <option key={cat.id} value={cat.id}>
                      {language === 'kannada' ? cat.nameKn : cat.nameEn}
                    </option>
                  ))}
                </select>
                {selectedBusinessCategory && (
                  <div className="mt-3 p-2 bg-purple-500/10 rounded-lg">
                    <p className="text-xs text-purple-300">
                      Selected: {categories.find(cat => cat.id === selectedBusinessCategory)?.nameEn || ''}
                    </p>
                  </div>
                )}
                <p className="text-xs text-gray-500">
                  💡 This will help business users find posts relevant to their industry
                </p>
              </div>
            </div>

            {/* Regions */}
            <div className="bg-gray-50 rounded-2xl p-4 border border-gray-200 shadow-xl">
              <h3 className="text-lg font-semibold text-black mb-4 flex items-center">
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
                    <span className="text-sm text-gray-700 group-hover:text-black transition-colors">{reg}</span>
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
            <div className="bg-gray-50 rounded-2xl p-6 border border-gray-200 shadow-xl flex-1 flex flex-col">
              <div className="text-center mb-4">
                <p className="text-sm text-gray-600">Canvas Size: {frameSize.width}x{frameSize.height} ({frameSize.width}:{frameSize.height} Portrait)</p>
              </div>
              <div className="flex-1 flex items-center justify-center">
                <div
                  ref={canvasRef}
                  className="relative bg-gray-900 rounded-xl overflow-hidden cursor-crosshair shadow-2xl border-2 border-white/20"
                  style={{
                    width: `${scaledWidth}px`,
                    height: `${scaledHeight}px`,
                    aspectRatio: `${frameSize.width} / ${frameSize.height}`,
                    maxWidth: '100%',
                    maxHeight: '100%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    background: '#222',
                  }}
                  onMouseMove={handleMouseMove}
                  onMouseUp={handleMouseUp}
                  onMouseLeave={handleMouseUp}
                >
                  {mediaType === 'video' ? (
                    <video
                      src={media}
                      className="w-full h-full object-contain"
                      controls
                      muted
                      loop
                      style={{ background: '#111' }}
                    />
                  ) : (
                    <img
                      src={media}
                      alt="Uploaded content"
                      className="w-full h-full object-contain"
                      style={{ background: '#111' }}
                    />
                  )}
                  
                  {/* Username Text Element */}
                  <div
                    className="absolute cursor-move select-none px-3 py-1 rounded-lg transition-all duration-200 hover:scale-105"
                    style={{
                      left: `${textSettings.x}%`,
                      top: `${textSettings.y}%`,
                      transform: 'translate(-50%, -50%)',
                      fontFamily: getFontFamily(textSettings.font),
                      fontSize: `${textSettings.fontSize}px`,
                      color: textSettings.color,
                      fontWeight: 'bold',
                      backgroundColor: textSettings.hasBackground ? textSettings.backgroundColor : 'transparent',
                      textShadow: textSettings.hasBackground ? 'none' : '2px 2px 4px rgba(0,0,0,0.8)',
                      whiteSpace: 'nowrap', // Force single line
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
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
                        fontFamily: getFontFamily(addressSettings.font),
                        fontSize: `${addressSettings.fontSize}px`,
                        color: addressSettings.color,
                        fontWeight: 'bold',
                        backgroundColor: addressSettings.hasBackground ? addressSettings.backgroundColor : 'transparent',
                        textShadow: addressSettings.hasBackground ? 'none' : '2px 2px 4px rgba(0,0,0,0.8)',
                        whiteSpace: 'nowrap', // Force single line
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
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
                        fontFamily: getFontFamily(phoneSettings.font),
                        fontSize: `${phoneSettings.fontSize}px`,
                        color: phoneSettings.color,
                        fontWeight: 'bold',
                        backgroundColor: phoneSettings.hasBackground ? phoneSettings.backgroundColor : 'transparent',
                        textShadow: phoneSettings.hasBackground ? 'none' : '2px 2px 4px rgba(0,0,0,0.8)',
                        whiteSpace: 'nowrap', // Force single line
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                      }}
                      onMouseDown={() => handleMouseDown('phone')}
                    >
                      {phoneSettings.text}
                    </div>
                  )}
                  
                  {/* Business Name Text Element */}
                  {businessNameSettings.enabled && (
                    <div
                      className="absolute cursor-move select-none px-3 py-1 rounded-lg transition-all duration-200 hover:scale-105"
                      style={{
                        left: `${businessNameSettings.x}%`,
                        top: `${businessNameSettings.y}%`,
                        transform: 'translate(-50%, -50%)',
                        fontFamily: getFontFamily(businessNameSettings.font),
                        fontSize: `${businessNameSettings.fontSize}px`,
                        color: businessNameSettings.color,
                        fontWeight: 'bold',
                        backgroundColor: businessNameSettings.hasBackground ? businessNameSettings.backgroundColor : 'transparent',
                        textShadow: businessNameSettings.hasBackground ? 'none' : '2px 2px 4px rgba(0,0,0,0.8)',
                        whiteSpace: 'nowrap', // Force single line
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                      }}
                      onMouseDown={() => handleMouseDown('businessName')}
                    >
                      {businessNameSettings.text}
                    </div>
                  )}
                  
                  {/* Designation Text Element */}
                  {designationSettings.enabled && (
                    <div
                      className="absolute cursor-move select-none px-3 py-1 rounded-lg transition-all duration-200 hover:scale-105"
                      style={{
                        left: `${designationSettings.x}%`,
                        top: `${designationSettings.y}%`,
                        transform: 'translate(-50%, -50%)',
                        fontFamily: getFontFamily(designationSettings.font),
                        fontSize: `${designationSettings.fontSize}px`,
                        color: designationSettings.color,
                        fontWeight: 'bold',
                        backgroundColor: designationSettings.hasBackground ? designationSettings.backgroundColor : 'transparent',
                        textShadow: designationSettings.hasBackground ? 'none' : '2px 2px 4px rgba(0,0,0,0.8)',
                        whiteSpace: 'nowrap', // Force single line
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                      }}
                      onMouseDown={() => handleMouseDown('designation')}
                    >
                      {designationSettings.text}
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
                      <div className="text-gray-700 text-xs text-center">Profile Photo</div>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Right Panel - Controls */}
          <div className="col-span-3 space-y-4 overflow-y-auto">
            {/* Username Controls */}
            <div className="bg-gray-50 rounded-2xl p-4 border border-gray-200 shadow-xl">
              <h3 className="text-lg font-semibold text-black mb-4 flex items-center">
                <Type className="h-5 w-5 mr-2 text-green-400" />
                Username
              </h3>
              <div className="space-y-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Text</label>
                  <input
                    type="text"
                    value={textSettings.text}
                    onChange={(e) => setTextSettings(prev => ({ ...prev, text: e.target.value }))}
                    className="w-full px-3 py-2 bg-white border border-gray-300 rounded-lg text-gray-700 placeholder-gray-400 focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                    placeholder="Enter username"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Size: {textSettings.fontSize}px</label>
                  <input
                    type="range"
                    min="12"
                    max="48"
                    value={textSettings.fontSize}
                    onChange={(e) => setTextSettings(prev => ({ ...prev, fontSize: parseInt(e.target.value) }))}
                    className="w-full accent-orange-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Font</label>
                  <select
                    value={textSettings.font}
                    onChange={e => setTextSettings(prev => ({ ...prev, font: e.target.value }))}
                    className="w-full px-3 py-2 bg-white border border-gray-300 rounded-lg text-gray-700 focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                  >
                    {language === 'english'
                      ? ENGLISH_FONTS.map(font => (
                          <option key={font} value={font}>{font}</option>
                        ))
                      : KANNADA_FONT_GROUPS.map(group => (
                          <optgroup key={group.label} label={group.label}>
                            {group.fonts.map(font => (
                              <option key={font} value={font}>{font}</option>
                            ))}
                          </optgroup>
                        ))}
                  </select>
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Text Color</label>
                    <input
                      type="color"
                      value={textSettings.color}
                      onChange={e => setTextSettings(prev => ({ ...prev, color: e.target.value }))}
                      className="w-full h-10 bg-white border border-gray-300 rounded-lg"
                    />
                  </div>
                  {textSettings.hasBackground && (
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Background Color</label>
                      <input
                        type="color"
                        value={textSettings.backgroundColor}
                        onChange={e => setTextSettings(prev => ({ ...prev, backgroundColor: e.target.value }))}
                        className="w-full h-10 bg-white border border-gray-300 rounded-lg"
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
                    className="w-4 h-4 rounded border-gray-300 text-green-600 focus:ring-green-500"
                  />
                  <label htmlFor="textBackground" className="text-sm text-gray-700">Enable Background</label>
                </div>
              </div>
            </div>

            {/* Address Controls */}
            <div className="bg-gray-50 rounded-2xl p-4 border border-gray-200 shadow-xl">
              <h3 className="text-lg font-semibold text-black mb-4 flex items-center">
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
                  <label htmlFor="enableAddress" className="text-sm text-gray-700 flex items-center">
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
                      className="w-full px-3 py-2 bg-white border border-gray-300 rounded-lg text-gray-700 placeholder-gray-400 focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                      placeholder="Enter address"
                    />
                    <label className="block text-sm font-medium text-gray-700 mb-2">Size: {addressSettings.fontSize}px</label>
                    <input
                      type="range"
                      min="10"
                      max="36"
                      value={addressSettings.fontSize}
                      onChange={(e) => setAddressSettings(prev => ({ ...prev, fontSize: parseInt(e.target.value) }))}
                      className="w-full accent-orange-500"
                    />
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Font</label>
                      <select
                        value={addressSettings.font}
                        onChange={e => setAddressSettings(prev => ({ ...prev, font: e.target.value }))}
                        className="w-full px-3 py-2 bg-white border border-gray-300 rounded-lg text-gray-700 focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                      >
                        {language === 'english'
                          ? ENGLISH_FONTS.map(font => (
                              <option key={font} value={font}>{font}</option>
                            ))
                          : KANNADA_FONT_GROUPS.map(group => (
                              <optgroup key={group.label} label={group.label}>
                                {group.fonts.map(font => (
                                  <option key={font} value={font}>{font}</option>
                                ))}
                              </optgroup>
                            ))}
                      </select>
                    </div>
                    <div className="grid grid-cols-2 gap-2 mt-2">
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-2">Text Color</label>
                        <input
                          type="color"
                          value={addressSettings.color}
                          onChange={e => setAddressSettings(prev => ({ ...prev, color: e.target.value }))}
                          className="w-full h-10 bg-white border border-gray-300 rounded-lg"
                        />
                      </div>
                      {addressSettings.hasBackground && (
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-2">Background Color</label>
                          <input
                            type="color"
                            value={addressSettings.backgroundColor}
                            onChange={e => setAddressSettings(prev => ({ ...prev, backgroundColor: e.target.value }))}
                            className="w-full h-10 bg-white border border-gray-300 rounded-lg"
                          />
                        </div>
                      )}
                    </div>
                    <div className="flex items-center space-x-2 mt-2">
                      <input
                        type="checkbox"
                        id="addressBackground"
                        checked={addressSettings.hasBackground}
                        onChange={(e) => setAddressSettings(prev => ({ ...prev, hasBackground: e.target.checked }))}
                        className="w-4 h-4 rounded border-gray-300 text-orange-600 focus:ring-orange-500"
                      />
                      <label htmlFor="addressBackground" className="text-sm text-gray-700">Enable Background</label>
                    </div>
                  </>
                )}
              </div>
            </div>

            {/* Phone Controls */}
            <div className="bg-gray-50 rounded-2xl p-4 border border-gray-200 shadow-xl">
              <h3 className="text-lg font-semibold text-black mb-4 flex items-center">
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
                  <label htmlFor="enablePhone" className="text-sm text-gray-700 flex items-center">
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
                      className="w-full px-3 py-2 bg-white border border-gray-300 rounded-lg text-gray-700 placeholder-gray-400 focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
                      placeholder="Enter phone number"
                    />
                    <label className="block text-sm font-medium text-gray-700 mb-2">Size: {phoneSettings.fontSize}px</label>
                    <input
                      type="range"
                      min="10"
                      max="36"
                      value={phoneSettings.fontSize}
                      onChange={(e) => setPhoneSettings(prev => ({ ...prev, fontSize: parseInt(e.target.value) }))}
                      className="w-full accent-cyan-500"
                    />
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Font</label>
                      <select
                        value={phoneSettings.font}
                        onChange={e => setPhoneSettings(prev => ({ ...prev, font: e.target.value }))}
                        className="w-full px-3 py-2 bg-white border border-gray-300 rounded-lg text-gray-700 focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
                      >
                        {language === 'english'
                          ? ENGLISH_FONTS.map(font => (
                              <option key={font} value={font}>{font}</option>
                            ))
                          : KANNADA_FONT_GROUPS.map(group => (
                              <optgroup key={group.label} label={group.label}>
                                {group.fonts.map(font => (
                                  <option key={font} value={font}>{font}</option>
                                ))}
                              </optgroup>
                            ))}
                      </select>
                    </div>
                    <div className="grid grid-cols-2 gap-2 mt-2">
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-2">Text Color</label>
                        <input
                          type="color"
                          value={phoneSettings.color}
                          onChange={e => setPhoneSettings(prev => ({ ...prev, color: e.target.value }))}
                          className="w-full h-10 bg-white border border-gray-300 rounded-lg"
                        />
                      </div>
                      {phoneSettings.hasBackground && (
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-2">Background Color</label>
                          <input
                            type="color"
                            value={phoneSettings.backgroundColor}
                            onChange={e => setPhoneSettings(prev => ({ ...prev, backgroundColor: e.target.value }))}
                            className="w-full h-10 bg-white border border-gray-300 rounded-lg"
                          />
                        </div>
                      )}
                    </div>
                    <div className="flex items-center space-x-2 mt-2">
                      <input
                        type="checkbox"
                        id="phoneBackground"
                        checked={phoneSettings.hasBackground}
                        onChange={(e) => setPhoneSettings(prev => ({ ...prev, hasBackground: e.target.checked }))}
                        className="w-4 h-4 rounded border-gray-300 text-cyan-600 focus:ring-cyan-500"
                      />
                      <label htmlFor="phoneBackground" className="text-sm text-gray-700">Enable Background</label>
                    </div>
                  </>
                )}
              </div>
            </div>

            {/* Business Name Controls */}
            <div className="bg-gray-50 rounded-2xl p-4 border border-gray-200 shadow-xl">
              <h3 className="text-lg font-semibold text-black mb-4 flex items-center">
                <Type className="h-5 w-5 mr-2 text-purple-400" />
                Business Name
              </h3>
              <div className="space-y-3">
                <div className="flex items-center space-x-2">
                  <input
                    type="checkbox"
                    id="enableBusinessName"
                    checked={businessNameSettings.enabled}
                    onChange={(e) => setBusinessNameSettings(prev => ({ ...prev, enabled: e.target.checked }))}
                    className="w-4 h-4 rounded border-gray-300 text-purple-600 focus:ring-purple-500"
                  />
                  <label htmlFor="enableBusinessName" className="text-sm text-gray-700 flex items-center">
                    {businessNameSettings.enabled ? <Eye className="h-4 w-4 mr-1" /> : <EyeOff className="h-4 w-4 mr-1" />}
                    Enable Business Name
                  </label>
                </div>
                
                {businessNameSettings.enabled && (
                  <>
                    <input
                      type="text"
                      value={businessNameSettings.text}
                      onChange={(e) => setBusinessNameSettings(prev => ({ ...prev, text: e.target.value }))}
                      className="w-full px-3 py-2 bg-white border border-gray-300 rounded-lg text-gray-700 placeholder-gray-400 focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                      placeholder="Enter business name"
                    />
                    <label className="block text-sm font-medium text-gray-700 mb-2">Size: {businessNameSettings.fontSize}px</label>
                    <input
                      type="range"
                      min="10"
                      max="36"
                      value={businessNameSettings.fontSize}
                      onChange={(e) => setBusinessNameSettings(prev => ({ ...prev, fontSize: parseInt(e.target.value) }))}
                      className="w-full accent-purple-500"
                    />
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Font</label>
                      <select
                        value={businessNameSettings.font}
                        onChange={e => setBusinessNameSettings(prev => ({ ...prev, font: e.target.value }))}
                        className="w-full px-3 py-2 bg-white border border-gray-300 rounded-lg text-gray-700 focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                      >
                        {language === 'english'
                          ? ENGLISH_FONTS.map(font => (
                              <option key={font} value={font}>{font}</option>
                            ))
                          : KANNADA_FONT_GROUPS.map(group => (
                              <optgroup key={group.label} label={group.label}>
                                {group.fonts.map(font => (
                                  <option key={font} value={font}>{font}</option>
                                ))}
                              </optgroup>
                            ))}
                      </select>
                    </div>
                    <div className="grid grid-cols-2 gap-2 mt-2">
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-2">Text Color</label>
                        <input
                          type="color"
                          value={businessNameSettings.color}
                          onChange={e => setBusinessNameSettings(prev => ({ ...prev, color: e.target.value }))}
                          className="w-full h-10 bg-white border border-gray-300 rounded-lg"
                        />
                      </div>
                      {businessNameSettings.hasBackground && (
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-2">Background Color</label>
                          <input
                            type="color"
                            value={businessNameSettings.backgroundColor}
                            onChange={e => setBusinessNameSettings(prev => ({ ...prev, backgroundColor: e.target.value }))}
                            className="w-full h-10 bg-white border border-gray-300 rounded-lg"
                          />
                        </div>
                      )}
                    </div>
                    <div className="flex items-center space-x-2 mt-2">
                      <input
                        type="checkbox"
                        id="businessNameBackground"
                        checked={businessNameSettings.hasBackground}
                        onChange={(e) => setBusinessNameSettings(prev => ({ ...prev, hasBackground: e.target.checked }))}
                        className="w-4 h-4 rounded border-gray-300 text-purple-600 focus:ring-purple-500"
                      />
                      <label htmlFor="businessNameBackground" className="text-sm text-gray-700">Enable Background</label>
                    </div>
                  </>
                )}
              </div>
            </div>

            {/* Designation Controls */}
            <div className="bg-gray-50 rounded-2xl p-4 border border-gray-200 shadow-xl">
              <h3 className="text-lg font-semibold text-black mb-4 flex items-center">
                <Type className="h-5 w-5 mr-2 text-blue-400" />
                Designation
              </h3>
              <div className="space-y-3">
                <div className="flex items-center space-x-2">
                  <input
                    type="checkbox"
                    id="enableDesignation"
                    checked={designationSettings.enabled}
                    onChange={(e) => setDesignationSettings(prev => ({ ...prev, enabled: e.target.checked }))}
                    className="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                  <label htmlFor="enableDesignation" className="text-sm text-gray-700 flex items-center">
                    {designationSettings.enabled ? <Eye className="h-4 w-4 mr-1" /> : <EyeOff className="h-4 w-4 mr-1" />}
                    Enable Designation
                  </label>
                </div>
                
                {designationSettings.enabled && (
                  <>
                    <input
                      type="text"
                      value={designationSettings.text}
                      onChange={(e) => setDesignationSettings(prev => ({ ...prev, text: e.target.value }))}
                      className="w-full px-3 py-2 bg-white border border-gray-300 rounded-lg text-gray-700 placeholder-gray-400 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      placeholder="Enter designation"
                    />
                    <label className="block text-sm font-medium text-gray-700 mb-2">Size: {designationSettings.fontSize}px</label>
                    <input
                      type="range"
                      min="10"
                      max="36"
                      value={designationSettings.fontSize}
                      onChange={(e) => setDesignationSettings(prev => ({ ...prev, fontSize: parseInt(e.target.value) }))}
                      className="w-full accent-blue-500"
                    />
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Font</label>
                      <select
                        value={designationSettings.font}
                        onChange={e => setDesignationSettings(prev => ({ ...prev, font: e.target.value }))}
                        className="w-full px-3 py-2 bg-white border border-gray-300 rounded-lg text-gray-700 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      >
                        {language === 'english'
                          ? ENGLISH_FONTS.map(font => (
                              <option key={font} value={font}>{font}</option>
                            ))
                          : KANNADA_FONT_GROUPS.map(group => (
                              <optgroup key={group.label} label={group.label}>
                                {group.fonts.map(font => (
                                  <option key={font} value={font}>{font}</option>
                                ))}
                              </optgroup>
                            ))}
                      </select>
                    </div>
                    <div className="grid grid-cols-2 gap-2 mt-2">
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-2">Text Color</label>
                        <input
                          type="color"
                          value={designationSettings.color}
                          onChange={e => setDesignationSettings(prev => ({ ...prev, color: e.target.value }))}
                          className="w-full h-10 bg-white border border-gray-300 rounded-lg"
                        />
                      </div>
                      {designationSettings.hasBackground && (
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-2">Background Color</label>
                          <input
                            type="color"
                            value={designationSettings.backgroundColor}
                            onChange={e => setDesignationSettings(prev => ({ ...prev, backgroundColor: e.target.value }))}
                            className="w-full h-10 bg-white border border-gray-300 rounded-lg"
                          />
                        </div>
                      )}
                    </div>
                    <div className="flex items-center space-x-2 mt-2">
                      <input
                        type="checkbox"
                        id="designationBackground"
                        checked={designationSettings.hasBackground}
                        onChange={(e) => setDesignationSettings(prev => ({ ...prev, hasBackground: e.target.checked }))}
                        className="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                      />
                      <label htmlFor="designationBackground" className="text-sm text-gray-700">Enable Background</label>
                    </div>
                  </>
                )}
              </div>
            </div>

            {/* Profile Controls */}
            <div className="bg-gray-50 rounded-2xl p-4 border border-gray-200 shadow-xl">
              <h3 className="text-lg font-semibold text-black mb-4 flex items-center">
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
                  <label htmlFor="enableProfile" className="text-sm text-gray-700 flex items-center">
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
                            : 'bg-gray-50 text-gray-700 hover:bg-gray-100'
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
                            : 'bg-gray-50 text-gray-700 hover:bg-gray-100'
                        }`}
                      >
                        <Square className="h-4 w-4" />
                        <span className="text-xs">Square</span>
                      </button>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">Size: {profileSettings.size}px</label>
                      <input
                        type="range"
                        min="40"
                        max="250"
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