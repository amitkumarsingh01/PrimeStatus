import React, { useEffect, useState } from 'react';
import { db } from '../firebase';
import { collection, getDocs, addDoc, deleteDoc, doc, updateDoc, writeBatch, query, orderBy } from 'firebase/firestore';
import { Edit, Trash2, Settings, ArrowUp, ArrowDown } from 'lucide-react';

export default function CategoryManager() {
  const [categories, setCategories] = useState<{ id: string; nameEn: string; nameKn: string; position: number; isFixed?: boolean; isDynamic?: boolean; isBusiness?: boolean; type?: string }[]>([]);
  const [newCategoryEn, setNewCategoryEn] = useState('');
  const [newCategoryKn, setNewCategoryKn] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editNameEn, setEditNameEn] = useState('');
  const [editNameKn, setEditNameKn] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [newPosition, setNewPosition] = useState<number | ''>('');

  // Helper function to get current time-based greeting
  const getCurrentTimeGreeting = () => {
    const hour = new Date().getHours();
    if (hour >= 5 && hour < 12) {
      return { nameEn: 'Good Morning', nameKn: 'ಶುಭೋದಯ' };
    } else if (hour >= 12 && hour < 17) {
      return { nameEn: 'Good Afternoon', nameKn: 'ಶುಭ ಮಧ್ಯಾಹ್ನ' };
    } else if (hour >= 17 && hour < 20) {
      return { nameEn: 'Good Evening', nameKn: 'ಶುಭ ಸಂಜೆ' };
    } else {
      return { nameEn: 'Good Night', nameKn: 'ಶುಭ ರಾತ್ರಿ' };
    }
  };

  // Helper function to get current day-based greeting
  const getCurrentDayGreeting = () => {
    const days = [
      { nameEn: 'Good Sunday', nameKn: 'ಶುಭ ಭಾನುವಾರ' },
      { nameEn: 'Good Monday', nameKn: 'ಶುಭ ಸೋಮವಾರ' },
      { nameEn: 'Good Tuesday', nameKn: 'ಶುಭ ಮಂಗಳವಾರ' },
      { nameEn: 'Good Wednesday', nameKn: 'ಶುಭ ಬುಧವಾರ' },
      { nameEn: 'Good Thursday', nameKn: 'ಶುಭ ಗುರುವಾರ' },
      { nameEn: 'Good Friday', nameKn: 'ಶುಭ ಶುಕ್ರವಾರ' },
      { nameEn: 'Good Saturday', nameKn: 'ಶುಭ ಶನಿವಾರ' }
    ];
    return days[new Date().getDay()];
  };

  // Business categories for business users
  const getBusinessCategories = () => {
    return [
      {
        id: 'education-training',
        nameEn: 'Education & Training',
        nameKn: 'ಶಿಕ್ಷಣ ಮತ್ತು ತರಬೇತಿ',
        position: 2, // After dynamic categories
        isFixed: true,
        isBusiness: true,
        type: 'business'
      },
      {
        id: 'health-services',
        nameEn: 'Health & Services',
        nameKn: 'ಆರೋಗ್ಯ ಮತ್ತು ಸೇವೆಗಳು',
        position: 3,
        isFixed: true,
        isBusiness: true,
        type: 'business'
      },
      {
        id: 'retail-shopping',
        nameEn: 'Retail & Shopping',
        nameKn: 'ರಿಟೇಲ್ ಮತ್ತು ಶಾಪಿಂಗ್',
        position: 4,
        isFixed: true,
        isBusiness: true,
        type: 'business'
      },
      {
        id: 'finance-services',
        nameEn: 'Finance & Services',
        nameKn: 'ಹಣಕಾಸು ಮತ್ತು ಸೇವೆಗಳು',
        position: 5,
        isFixed: true,
        isBusiness: true,
        type: 'business'
      },
      {
        id: 'travel-ticketing',
        nameEn: 'Travel & Ticketing',
        nameKn: 'ಪ್ರಯಾಣ ಮತ್ತು ಟಿಕೆಟಿಂಗ್',
        position: 6,
        isFixed: true,
        isBusiness: true,
        type: 'business'
      },
      {
        id: 'digital-tech',
        nameEn: 'Digital & Tech',
        nameKn: 'ಡಿಜಿಟಲ್ ಮತ್ತು ತಂತ್ರಜ್ಞಾನ',
        position: 7,
        isFixed: true,
        isBusiness: true,
        type: 'business'
      },
      {
        id: 'food-lifestyle',
        nameEn: 'Food & Lifestyle',
        nameKn: 'ಆಹಾರ ಮತ್ತು ಜೀವನಶೈಲಿ',
        position: 8,
        isFixed: true,
        isBusiness: true,
        type: 'business'
      },
      {
        id: 'online-services',
        nameEn: 'Online Services',
        nameKn: 'ಆನ್ಲೈನ್ ಸೇವೆಗಳು',
        position: 9,
        isFixed: true,
        isBusiness: true,
        type: 'business'
      }
    ];
  };

  // Dynamic greeting categories that change automatically
  const getDynamicCategories = () => {
    const timeGreeting = getCurrentTimeGreeting();
    const dayGreeting = getCurrentDayGreeting();
    
    return [
      {
        id: 'time-greeting',
        nameEn: timeGreeting.nameEn,
        nameKn: timeGreeting.nameKn,
        position: 0, // Always first
        isFixed: true,
        isDynamic: true,
        type: 'time'
      },
      {
        id: 'day-greeting',
        nameEn: dayGreeting.nameEn,
        nameKn: dayGreeting.nameKn,
        position: 1, // Always second
        isFixed: true,
        isDynamic: true,
        type: 'day'
      }
    ];
  };

  const fetchCategories = async () => {
    setLoading(true);
    setError(null);
    try {
      // First, get all categories
      const querySnapshot = await getDocs(collection(db, 'categories'));
      let fetchedCategories = querySnapshot.docs.map((docSnap) => ({
        id: docSnap.id,
        nameEn: docSnap.data().nameEn || '',
        nameKn: docSnap.data().nameKn || '',
        position: docSnap.data().position ?? 0,
        isFixed: docSnap.data().isFixed || false,
        isDynamic: docSnap.data().isDynamic || false,
        isBusiness: docSnap.data().isBusiness || false,
        type: docSnap.data().type || '',
      }));
      
      console.log('Fetched categories:', fetchedCategories.map(c => ({ name: c.nameEn, position: c.position })));
      
      // Check if dynamic categories exist in Firestore
      const existingDynamicCategories = fetchedCategories.filter(cat => cat.isFixed && cat.isDynamic);
      const dynamicCategories = getDynamicCategories();
      
      // Check if business categories exist in Firestore
      const existingBusinessCategories = fetchedCategories.filter(cat => cat.isFixed && cat.isBusiness);
      const businessCategories = getBusinessCategories();
      
      // Clean up duplicate dynamic categories first
      const timeCategories = existingDynamicCategories.filter(cat => cat.type === 'time');
      const dayCategories = existingDynamicCategories.filter(cat => cat.type === 'day');
      
      if (timeCategories.length > 1 || dayCategories.length > 1) {
        console.log('Found duplicate dynamic categories, cleaning up...');
        const batch = writeBatch(db);
        
        // Keep only the first time category and first day category, delete the rest
        if (timeCategories.length > 1) {
          timeCategories.slice(1).forEach(cat => {
            const categoryRef = doc(db, 'categories', cat.id);
            batch.delete(categoryRef);
            console.log(`Deleting duplicate time category: ${cat.nameEn}`);
          });
        }
        
        if (dayCategories.length > 1) {
          dayCategories.slice(1).forEach(cat => {
            const categoryRef = doc(db, 'categories', cat.id);
            batch.delete(categoryRef);
            console.log(`Deleting duplicate day category: ${cat.nameEn}`);
          });
        }
        
        await batch.commit();
        console.log('Duplicate dynamic categories cleaned up');
        
        // Fetch categories again to get the cleaned list
        const updatedQuerySnapshot = await getDocs(collection(db, 'categories'));
        fetchedCategories = updatedQuerySnapshot.docs.map((docSnap) => ({
          id: docSnap.id,
          nameEn: docSnap.data().nameEn || '',
          nameKn: docSnap.data().nameKn || '',
          position: docSnap.data().position ?? 0,
          isFixed: docSnap.data().isFixed || false,
          isDynamic: docSnap.data().isDynamic || false,
          type: docSnap.data().type || '',
        }));
      }
      
      // Re-check dynamic categories after cleanup
      const cleanedDynamicCategories = fetchedCategories.filter(cat => cat.isFixed && cat.isDynamic);
      
      // Check if we need to create dynamic categories (only if they don't exist at all)
      if (cleanedDynamicCategories.length === 0) {
        console.log('Creating dynamic categories in Firestore:', dynamicCategories.map(c => c.nameEn));
        const batch = writeBatch(db);
        
        dynamicCategories.forEach((dynamicCat) => {
          const newCategoryRef = doc(collection(db, 'categories'));
          batch.set(newCategoryRef, {
            nameEn: dynamicCat.nameEn,
            nameKn: dynamicCat.nameKn,
            position: dynamicCat.position,
            isFixed: true,
            isDynamic: true,
            type: dynamicCat.type
          });
          console.log(`Creating dynamic category: ${dynamicCat.nameEn} at position ${dynamicCat.position}`);
        });
        
        await batch.commit();
        console.log('Dynamic categories created in Firestore');
        
        // Fetch categories again to get the updated list
        const updatedQuerySnapshot = await getDocs(collection(db, 'categories'));
        fetchedCategories = updatedQuerySnapshot.docs.map((docSnap) => ({
          id: docSnap.id,
          nameEn: docSnap.data().nameEn || '',
          nameKn: docSnap.data().nameKn || '',
          position: docSnap.data().position ?? 0,
          isFixed: docSnap.data().isFixed || false,
          isDynamic: docSnap.data().isDynamic || false,
          isBusiness: docSnap.data().isBusiness || false,
          type: docSnap.data().type || '',
        }));
      } else {
        // Update existing dynamic categories with current values
        const batch = writeBatch(db);
        let hasUpdates = false;
        
        dynamicCategories.forEach((dynamicCat) => {
          const existingCat = cleanedDynamicCategories.find(cat => cat.type === dynamicCat.type);
          if (existingCat && (existingCat.nameEn !== dynamicCat.nameEn || existingCat.nameKn !== dynamicCat.nameKn)) {
            const categoryRef = doc(db, 'categories', existingCat.id);
            batch.update(categoryRef, {
              nameEn: dynamicCat.nameEn,
              nameKn: dynamicCat.nameKn
            });
            console.log(`Updating dynamic category: ${existingCat.nameEn} → ${dynamicCat.nameEn}`);
            hasUpdates = true;
          }
        });
        
        if (hasUpdates) {
          await batch.commit();
          console.log('Dynamic categories updated in Firestore');
          
          // Fetch categories again to get the updated list
          const updatedQuerySnapshot = await getDocs(collection(db, 'categories'));
          fetchedCategories = updatedQuerySnapshot.docs.map((docSnap) => ({
            id: docSnap.id,
            nameEn: docSnap.data().nameEn || '',
            nameKn: docSnap.data().nameKn || '',
            position: docSnap.data().position ?? 0,
            isFixed: docSnap.data().isFixed || false,
            isDynamic: docSnap.data().isDynamic || false,
            type: docSnap.data().type || '',
          }));
        }
      }
      
      // First, delete all existing business categories to start fresh
      const businessCategoryNames = businessCategories.map(cat => cat.nameEn);
      const allExistingBusinessCategories = fetchedCategories.filter(cat => 
        businessCategoryNames.includes(cat.nameEn) || cat.isBusiness
      );
      
      if (allExistingBusinessCategories.length > 0) {
        console.log('Deleting existing business categories from Firestore:', allExistingBusinessCategories.map(cat => cat.nameEn));
        const deleteBatch = writeBatch(db);
        allExistingBusinessCategories.forEach(cat => {
          const categoryRef = doc(db, 'categories', cat.id);
          deleteBatch.delete(categoryRef);
        });
        await deleteBatch.commit();
        console.log('Deleted existing business categories');
        
        // Fetch categories again after deletion
        const updatedQuerySnapshot = await getDocs(collection(db, 'categories'));
        fetchedCategories = updatedQuerySnapshot.docs.map((docSnap) => ({
          id: docSnap.id,
          nameEn: docSnap.data().nameEn || '',
          nameKn: docSnap.data().nameKn || '',
          position: docSnap.data().position || 0,
          isFixed: docSnap.data().isFixed || false,
          isDynamic: docSnap.data().isDynamic || false,
          isBusiness: docSnap.data().isBusiness || false,
          type: docSnap.data().type || '',
        }));
      }

      // Now create fresh business categories
      const currentBusinessCategories = fetchedCategories.filter(cat => cat.isFixed && cat.isBusiness);
      if (currentBusinessCategories.length === 0) {
        console.log('Creating fresh business categories in Firestore:', businessCategories.map(c => c.nameEn));
        const batch = writeBatch(db);
        
        businessCategories.forEach((businessCat) => {
          const newCategoryRef = doc(collection(db, 'categories'));
          batch.set(newCategoryRef, {
            nameEn: businessCat.nameEn,
            nameKn: businessCat.nameKn,
            position: businessCat.position,
            isFixed: true,
            isBusiness: true,
            type: businessCat.type
          });
          console.log(`Creating business category: ${businessCat.nameEn} at position ${businessCat.position}`);
        });
        
        await batch.commit();
        console.log('Fresh business categories created in Firestore');
        
        // Fetch categories again to get the updated list
        const updatedQuerySnapshot = await getDocs(collection(db, 'categories'));
        fetchedCategories = updatedQuerySnapshot.docs.map((docSnap) => ({
          id: docSnap.id,
          nameEn: docSnap.data().nameEn || '',
          nameKn: docSnap.data().nameKn || '',
          position: docSnap.data().position ?? 0,
          isFixed: docSnap.data().isFixed || false,
          isDynamic: docSnap.data().isDynamic || false,
          isBusiness: docSnap.data().isBusiness || false,
          type: docSnap.data().type || '',
        }));
      }
      
      // If any categories don't have position, assign them
      const categoriesWithPosition = fetchedCategories.filter(c => c.position !== undefined && c.position >= 0);
      const categoriesWithoutPosition = fetchedCategories.filter(c => c.position === undefined);
      
      if (categoriesWithoutPosition.length > 0) {
        console.log('Found categories without position:', categoriesWithoutPosition.map(c => c.nameEn));
        const maxPosition = categoriesWithPosition.length > 0 
          ? Math.max(...categoriesWithPosition.map(c => c.position)) 
          : -1;
        
        const batch = writeBatch(db);
        categoriesWithoutPosition.forEach((cat, index) => {
          const newPosition = maxPosition + index + 1;
          const categoryRef = doc(db, 'categories', cat.id);
          batch.update(categoryRef, { position: newPosition });
          cat.position = newPosition;
          console.log(`Assigned position ${newPosition} to ${cat.nameEn}`);
        });
        await batch.commit();
        console.log('Updated categories without position');
      }
      
      // Sort by position (fixed categories will be at the top)
      fetchedCategories.sort((a, b) => a.position - b.position);
      console.log('Sorted categories:', fetchedCategories.map(c => ({ name: c.nameEn, position: c.position })));
      setCategories(fetchedCategories);
    } catch (e) {
      console.error('Error fetching categories:', e);
      setError('Failed to fetch categories');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCategories();
  }, []);

  // Update dynamic categories every minute (only if they exist)
  useEffect(() => {
    if (categories.length === 0) return; // Don't run if categories haven't loaded yet
    
    const updateDynamicCategories = async () => {
      const dynamicCategories = getDynamicCategories();
      const currentDynamicCategories = categories.filter(cat => cat.isFixed && cat.isDynamic);
      
      if (currentDynamicCategories.length === 0) return; // No dynamic categories to update
      
      // Check if any dynamic categories need updating
      const needsUpdate = dynamicCategories.some(dynamicCat => {
        const currentCat = currentDynamicCategories.find(c => c.type === dynamicCat.type);
        return currentCat && currentCat.nameEn !== dynamicCat.nameEn;
      });
      
      if (needsUpdate) {
        console.log('Updating dynamic categories...');
        const batch = writeBatch(db);
        
        dynamicCategories.forEach(dynamicCat => {
          const currentCat = currentDynamicCategories.find(c => c.type === dynamicCat.type);
          if (currentCat && currentCat.nameEn !== dynamicCat.nameEn) {
            const categoryRef = doc(db, 'categories', currentCat.id);
            batch.update(categoryRef, {
              nameEn: dynamicCat.nameEn,
              nameKn: dynamicCat.nameKn
            });
            console.log(`Updated ${currentCat.nameEn} to ${dynamicCat.nameEn}`);
          }
        });
        
        await batch.commit();
        fetchCategories(); // Refresh the list
      }
    };

    // Update every minute
    const interval = setInterval(updateDynamicCategories, 60000);
    
    return () => clearInterval(interval);
  }, [categories]);

  const handleAdd = async () => {
    if (!newCategoryEn.trim() || !newCategoryKn.trim()) return;
    setLoading(true);
    try {
      // Add new category at the end
      const newPosition = categories.length > 0 ? Math.max(...categories.map(c => c.position)) + 1 : 0;
      await addDoc(collection(db, 'categories'), { 
        nameEn: newCategoryEn.trim(), 
        nameKn: newCategoryKn.trim(),
        position: newPosition
      });
      setNewCategoryEn('');
      setNewCategoryKn('');
      fetchCategories();
    } catch (e) {
      setError('Failed to add category');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    const category = categories.find(c => c.id === id);
    if (category?.isFixed) {
      setError('Fixed categories cannot be deleted');
      return;
    }

    // Show confirmation dialog
    const isConfirmed = window.confirm(`Are you sure you want to delete "${category?.nameEn}"? This action cannot be undone.`);
    
    if (!isConfirmed) {
      return;
    }

    setLoading(true);
    try {
      await deleteDoc(doc(db, 'categories', id));
      setSuccess(`Category "${category?.nameEn}" deleted successfully!`);
      setTimeout(() => setSuccess(null), 3000);
      fetchCategories();
    } catch (e) {
      setError('Failed to delete category');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = async (id: string) => {
    if (!editNameEn.trim() || !editNameKn.trim()) return;
    setLoading(true);
    try {
      await updateDoc(doc(db, 'categories', id), { 
        nameEn: editNameEn.trim(), 
        nameKn: editNameKn.trim() 
      });
      setEditingId(null);
      setEditNameEn('');
      setEditNameKn('');
      fetchCategories();
    } catch (e) {
      setError('Failed to update category');
    } finally {
      setLoading(false);
    }
  };

  const startEdit = (category: { id: string; nameEn: string; nameKn: string; isFixed?: boolean }) => {
    if (category.isFixed) {
      setError('Fixed categories cannot be edited');
      return;
    }
    setEditingId(category.id);
    setEditNameEn(category.nameEn);
    setEditNameKn(category.nameKn);
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditNameEn('');
    setEditNameKn('');
  };

  const resetToAlphabetical = async () => {
    if (!window.confirm('This will reset all categories to alphabetical order. Continue?')) return;
    
    setLoading(true);
    try {
      const sortedCategories = [...categories].sort((a, b) => a.nameEn.localeCompare(b.nameEn));
      const updatedItems = sortedCategories.map((item, index) => ({
        ...item,
        position: index
      }));

      setCategories(updatedItems);

      const batch = writeBatch(db);
      updatedItems.forEach((item) => {
        const categoryRef = doc(db, 'categories', item.id);
        batch.update(categoryRef, { position: item.position });
      });
      await batch.commit();
      
      setSuccess('Categories reset to alphabetical order!');
      setTimeout(() => setSuccess(null), 3000);
    } catch (e) {
      setError('Failed to reset category order');
      fetchCategories();
    } finally {
      setLoading(false);
    }
  };

  const cleanupDuplicateCategories = async () => {
    if (!window.confirm('This will remove all duplicate categories and keep only unique ones. This action cannot be undone. Continue?')) return;
    
    setLoading(true);
    setError(null);
    
    try {
      // Get all categories from Firestore
      const querySnapshot = await getDocs(collection(db, 'categories'));
      const allCategories = querySnapshot.docs.map((docSnap) => ({
        id: docSnap.id,
        nameEn: docSnap.data().nameEn || '',
        nameKn: docSnap.data().nameKn || '',
        position: docSnap.data().position ?? 0,
        isFixed: docSnap.data().isFixed || false,
        isDynamic: docSnap.data().isDynamic || false,
        isBusiness: docSnap.data().isBusiness || false,
        type: docSnap.data().type || '',
      }));

      console.log('Total categories found:', allCategories.length);

      // Group categories by name to find duplicates
      const groupedCategories = allCategories.reduce((groups, category) => {
        const key = category.nameEn.toLowerCase().trim();
        if (!groups[key]) {
          groups[key] = [];
        }
        groups[key].push(category);
        return groups;
      }, {} as Record<string, typeof allCategories>);

      // Find duplicates and keep the best one from each group
      const categoriesToDelete: string[] = [];
      const categoriesToKeep: typeof allCategories = [];

      Object.entries(groupedCategories).forEach(([name, categoryGroup]) => {
        if (categoryGroup.length > 1) {
          console.log(`Found ${categoryGroup.length} duplicates for: ${name}`);
          
          // Sort by priority: dynamic categories first, then by position
          categoryGroup.sort((a, b) => {
            if (a.isDynamic && !b.isDynamic) return -1;
            if (!a.isDynamic && b.isDynamic) return 1;
            return a.position - b.position;
          });

          // Keep the first one (best one), delete the rest
          const keepCategory = categoryGroup[0];
          categoriesToKeep.push(keepCategory);
          
          categoryGroup.slice(1).forEach(cat => {
            categoriesToDelete.push(cat.id);
          });
        } else {
          // No duplicates, keep the single category
          categoriesToKeep.push(categoryGroup[0]);
        }
      });

      console.log('Categories to keep:', categoriesToKeep.length);
      console.log('Categories to delete:', categoriesToDelete.length);

      if (categoriesToDelete.length > 0) {
        // Delete duplicate categories
        const batch = writeBatch(db);
        categoriesToDelete.forEach(categoryId => {
          const categoryRef = doc(db, 'categories', categoryId);
          batch.delete(categoryRef);
        });
        await batch.commit();

        // Reassign positions to remaining categories
        const sortedCategories = categoriesToKeep.sort((a, b) => a.position - b.position);
        const updatedCategories = sortedCategories.map((cat, index) => ({
          ...cat,
          position: index
        }));

        const updateBatch = writeBatch(db);
        updatedCategories.forEach((cat) => {
          const categoryRef = doc(db, 'categories', cat.id);
          updateBatch.update(categoryRef, { position: cat.position });
        });
        await updateBatch.commit();

        setSuccess(`Cleaned up ${categoriesToDelete.length} duplicate categories! ${categoriesToKeep.length} unique categories remaining.`);
        setTimeout(() => setSuccess(null), 5000);
      } else {
        setSuccess('No duplicate categories found!');
        setTimeout(() => setSuccess(null), 3000);
      }

      // Refresh the categories list
      fetchCategories();
    } catch (e) {
      console.error('Error cleaning up categories:', e);
      setError('Failed to cleanup duplicate categories');
    } finally {
      setLoading(false);
    }
  };

  const cleanupDuplicateDynamicCategories = async () => {
    if (!window.confirm('This will remove duplicate dynamic categories (time/day greetings) and keep only one of each type. Continue?')) return;
    
    setLoading(true);
    setError(null);
    
    try {
      // Get all categories from Firestore
      const querySnapshot = await getDocs(collection(db, 'categories'));
      const allCategories = querySnapshot.docs.map((docSnap) => ({
        id: docSnap.id,
        nameEn: docSnap.data().nameEn || '',
        nameKn: docSnap.data().nameKn || '',
        position: docSnap.data().position ?? 0,
        isFixed: docSnap.data().isFixed || false,
        isDynamic: docSnap.data().isDynamic || false,
        isBusiness: docSnap.data().isBusiness || false,
        type: docSnap.data().type || '',
      }));

      // Find dynamic categories
      const dynamicCategories = allCategories.filter(cat => cat.isFixed && cat.isDynamic);
      const timeCategories = dynamicCategories.filter(cat => cat.type === 'time');
      const dayCategories = dynamicCategories.filter(cat => cat.type === 'day');

      const categoriesToDelete: string[] = [];

      // Keep only the first time category, delete the rest
      if (timeCategories.length > 1) {
        timeCategories.slice(1).forEach(cat => {
          categoriesToDelete.push(cat.id);
        });
      }

      // Keep only the first day category, delete the rest
      if (dayCategories.length > 1) {
        dayCategories.slice(1).forEach(cat => {
          categoriesToDelete.push(cat.id);
        });
      }

      if (categoriesToDelete.length > 0) {
        // Delete duplicate dynamic categories
        const batch = writeBatch(db);
        categoriesToDelete.forEach(categoryId => {
          const categoryRef = doc(db, 'categories', categoryId);
          batch.delete(categoryRef);
        });
        await batch.commit();

        setSuccess(`Cleaned up ${categoriesToDelete.length} duplicate dynamic categories!`);
        setTimeout(() => setSuccess(null), 3000);
      } else {
        setSuccess('No duplicate dynamic categories found!');
        setTimeout(() => setSuccess(null), 3000);
      }

      // Refresh the categories list
      fetchCategories();
    } catch (e) {
      console.error('Error cleaning up dynamic categories:', e);
      setError('Failed to cleanup duplicate dynamic categories');
    } finally {
      setLoading(false);
    }
  };

  const handlePositionChange = async () => {
    if (!selectedCategory || newPosition === '' || newPosition < 0 || newPosition >= categories.length) {
      setError('Please select a category and enter a valid position (0-' + (categories.length - 1) + ')');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const selectedCat = categories.find(c => c.id === selectedCategory);
      if (!selectedCat) {
        setError('Selected category not found');
        return;
      }

      // Check if it's a fixed category
      if (selectedCat.isFixed) {
        setError('Fixed categories cannot be reordered');
        return;
      }

      const oldPosition = selectedCat.position;
      const newPos = Number(newPosition);

      // Create new array with updated positions
      const updatedCategories = [...categories];
      
      // Remove the selected category from its current position
      updatedCategories.splice(oldPosition, 1);
      
      // Insert it at the new position
      updatedCategories.splice(newPos, 0, selectedCat);
      
      // Update all positions
      const finalCategories = updatedCategories.map((cat, index) => ({
        ...cat,
        position: index
      }));

      // Update in Firebase
      const batch = writeBatch(db);
      finalCategories.forEach((cat) => {
        const categoryRef = doc(db, 'categories', cat.id);
        batch.update(categoryRef, { position: cat.position });
      });
      await batch.commit();

      setCategories(finalCategories);
      setSelectedCategory(null);
      setNewPosition('');
      setSuccess(`Moved "${selectedCat.nameEn}" to position ${newPos + 1}!`);
      setTimeout(() => setSuccess(null), 3000);
    } catch (e) {
      console.error('Error updating category position:', e);
      setError('Failed to update category position');
    } finally {
      setLoading(false);
    }
  };

  const moveCategory = async (categoryId: string, direction: 'up' | 'down') => {
    const currentIndex = categories.findIndex(c => c.id === categoryId);
    if (currentIndex === -1) return;

    const category = categories[currentIndex];
    if (category.isFixed) {
      setError('Fixed categories cannot be reordered');
      return;
    }

    const newIndex = direction === 'up' ? currentIndex - 1 : currentIndex + 1;
    if (newIndex < 0 || newIndex >= categories.length) return;

    // Don't allow moving past fixed categories
    if (newIndex < categories.filter(c => c.isFixed).length) {
      setError('Cannot move category before fixed categories');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const updatedCategories = [...categories];
      const [movedCategory] = updatedCategories.splice(currentIndex, 1);
      updatedCategories.splice(newIndex, 0, movedCategory);

      // Update all positions
      const finalCategories = updatedCategories.map((cat, index) => ({
        ...cat,
        position: index
      }));

      // Update in Firebase
      const batch = writeBatch(db);
      finalCategories.forEach((cat) => {
        const categoryRef = doc(db, 'categories', cat.id);
        batch.update(categoryRef, { position: cat.position });
      });
      await batch.commit();

      setCategories(finalCategories);
      setSuccess(`Moved "${movedCategory.nameEn}" ${direction}!`);
      setTimeout(() => setSuccess(null), 3000);
    } catch (e) {
      console.error('Error moving category:', e);
      setError('Failed to move category');
    } finally {
      setLoading(false);
    }
  };

  const forceRefresh = async () => {
    setLoading(true);
    setError(null);
    try {
      // First clean up any duplicate dynamic categories
      await cleanupDuplicateDynamicCategories();
      // Then fetch fresh data
      await fetchCategories();
      setSuccess('Categories refreshed and cleaned up!');
      setTimeout(() => setSuccess(null), 3000);
    } catch (e) {
      setError('Failed to refresh categories');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen p-6" style={{ background: 'linear-gradient(135deg, #fff5f0 0%, #f8f4ff 50%, #fff0e6 100%)' }}>
      <div className="max-w-7xl mx-auto">
        <div className="bg-white/80 backdrop-blur-lg rounded-2xl shadow-xl p-6 border border-white/20">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center space-x-3">
              <div className="w-12 h-12 rounded-full flex items-center justify-center" style={{ background: 'linear-gradient(135deg, #d74d02 0%, #2c0036 100%)' }}>
                <Settings className="h-6 w-6 text-white" />
              </div>
              <div>
                <h1 className="text-3xl font-bold text-gray-800">Manage Categories</h1>
                <p className="text-gray-600">Organize and reorder your categories</p>
              </div>
            </div>
            <div className="text-right">
              <div className="text-2xl font-bold text-gray-800">{categories.length}</div>
              <div className="text-sm text-gray-600">Total Categories</div>
            </div>
          </div>
          
          {/* Instructions */}
          <div className="mb-6 p-4 bg-gradient-to-r from-blue-50 to-purple-50 border border-blue-200 rounded-lg">
            <h3 className="text-sm font-semibold text-blue-800 mb-2 flex items-center">
              <span className="mr-2">📋</span>
              How to reorder categories:
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <ul className="text-sm text-blue-700 space-y-1">
                <li className="flex items-center">
                  <span className="mr-2">⬆️⬇️</span>
                  <span>Use arrow buttons to move categories up/down</span>
                </li>
                <li className="flex items-center">
                  <span className="mr-2">#️⃣</span>
                  <span>Or select a category and enter its new position number</span>
                </li>
              </ul>
              <ul className="text-sm text-purple-700 space-y-1">
                <li className="flex items-center">
                  <span className="mr-2">💾</span>
                  <span>Order is automatically saved to Firebase</span>
                </li>
                <li className="flex items-center">
                  <span className="mr-2">📱</span>
                  <span>Categories at the top appear first in mobile app</span>
                </li>
              </ul>
            </div>
            <div className="mt-3 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
              <p className="text-sm text-yellow-800">
                <strong>Note:</strong> If you see duplicate dynamic categories (like "Good Monday" and "Good Thursday" at the same time), 
                click "Cleanup Dynamic Duplicates" or "Refresh" to fix this issue. Dynamic categories should automatically update based on current time and day.
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Add New Category Section */}
            <div className="lg:col-span-1">
              <div className="bg-white/90 rounded-xl shadow p-6 border border-gray-200">
                <h3 className="text-lg font-semibold text-gray-700 mb-4">Add New Category</h3>
                <div className="space-y-4">
                  <input
                    type="text"
                    value={newCategoryEn}
                    onChange={e => setNewCategoryEn(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                    placeholder="Category name (English)"
                  />
                  <input
                    type="text"
                    value={newCategoryKn}
                    onChange={e => setNewCategoryKn(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                    placeholder="Category name (Kannada)"
                  />
                  <button
                    onClick={handleAdd}
                    className="w-full px-6 py-2 bg-gradient-to-r from-orange-600 to-purple-600 text-white rounded-lg font-semibold shadow hover:from-orange-700 hover:to-purple-700 transition-all"
                    disabled={loading || !newCategoryEn.trim() || !newCategoryKn.trim()}
                  >
                    Add Category
                  </button>
                </div>
              </div>

              {/* Position Change Section */}
              <div className="bg-white/90 rounded-xl shadow p-6 border border-gray-200 mt-6">
                <h3 className="text-lg font-semibold text-gray-700 mb-4">Change Position</h3>
                <div className="space-y-4">
                  <select
                    value={selectedCategory || ''}
                    onChange={e => setSelectedCategory(e.target.value || null)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                  >
                    <option value="">Select a category</option>
                    {categories.filter(cat => !cat.isFixed).map((cat, index) => (
                      <option key={cat.id} value={cat.id}>
                        {cat.position + 1}. {cat.nameEn}
                      </option>
                    ))}
                  </select>
                  <input
                    type="number"
                    value={newPosition}
                    onChange={e => setNewPosition(e.target.value === '' ? '' : Number(e.target.value))}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                    placeholder={`Position (${categories.filter(c => c.isFixed).length + 1}-${categories.length})`}
                    min={categories.filter(c => c.isFixed).length + 1}
                    max={categories.length}
                  />
                  <button
                    onClick={handlePositionChange}
                    className="w-full px-6 py-2 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-lg font-semibold shadow hover:from-blue-700 hover:to-indigo-700 transition-all"
                    disabled={loading || !selectedCategory || newPosition === ''}
                  >
                    Move to Position
                  </button>
                </div>
              </div>
            </div>

            {/* Categories List Section */}
            <div className="lg:col-span-2">
              <div className="bg-white/90 rounded-xl shadow p-6 border border-gray-200">
                <div className="flex justify-between items-center mb-4">
                  <h3 className="text-lg font-semibold text-gray-700">All Categories</h3>
                  <div className="flex items-center space-x-3">
                    <button
                      onClick={cleanupDuplicateCategories}
                      className="px-3 py-1 text-xs bg-red-500 text-white rounded hover:bg-red-600 transition-all"
                      disabled={loading}
                      title="Remove duplicate categories"
                    >
                      Cleanup Duplicates
                    </button>
                    <button
                      onClick={resetToAlphabetical}
                      className="px-3 py-1 text-xs bg-gray-500 text-white rounded hover:bg-gray-600 transition-all"
                      disabled={loading}
                      title="Reset to alphabetical order"
                    >
                      Reset Order
                    </button>
                    <button
                      onClick={cleanupDuplicateDynamicCategories}
                      className="px-3 py-1 text-xs bg-purple-500 text-white rounded hover:bg-purple-600 transition-all"
                      disabled={loading}
                      title="Remove duplicate dynamic categories"
                    >
                      Cleanup Dynamic Duplicates
                    </button>
                    <button
                      onClick={forceRefresh}
                      className="px-3 py-1 text-xs bg-blue-500 text-white rounded hover:bg-blue-600 transition-all"
                      disabled={loading}
                      title="Force refresh categories"
                    >
                      Refresh
                    </button>
                    <div className="text-sm text-gray-500">
                      {categories.length} categories
                    </div>
                  </div>
                </div>

                {error && <div className="text-red-500 mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">{error}</div>}
                {success && <div className="text-green-600 mb-4 p-3 bg-green-50 border border-green-200 rounded-lg">{success}</div>}
                {loading && <div className="text-gray-500 mb-4">Loading...</div>}

                {/* Dynamic Categories Section */}
                <div className="mb-6">
                  <h4 className="text-md font-semibold text-gray-700 mb-3 flex items-center">
                    <span className="mr-2">🔄</span>
                    Dynamic Categories (Auto-changing)
                  </h4>
                  <ul className="space-y-2">
                    {categories.filter(cat => cat.isFixed && cat.isDynamic).map((cat, index) => (
                      <li
                        key={cat.id}
                        className="flex items-center justify-between p-4 bg-gradient-to-r from-green-50 to-blue-50 rounded-lg border border-green-200"
                      >
                        <div className="flex items-center space-x-3 flex-1">
                          <div className="text-green-600 text-sm font-mono bg-green-100 px-3 py-1 rounded">
                            #{cat.position + 1}
                          </div>
                          <div>
                            <span className="font-medium text-gray-900">{cat.nameEn}</span>
                            <span className="ml-2 text-gray-500 text-sm">/ {cat.nameKn}</span>
                            <div className="text-xs text-gray-500 mt-1">
                              {cat.type === 'time' ? '🕐 Time-based' : '📅 Day-based'} - Updates automatically
                            </div>
                          </div>
                        </div>
                        <div className="flex items-center space-x-2">
                          <span className="text-xs text-green-600 bg-green-100 px-2 py-1 rounded">
                            Dynamic
                          </span>
                        </div>
                      </li>
                    ))}
                  </ul>
                </div>

                {/* Business Categories Section */}
                <div className="mb-6">
                  <h4 className="text-md font-semibold text-gray-700 mb-3 flex items-center">
                    <span className="mr-2">🏢</span>
                    Business Categories
                  </h4>
                  <ul className="space-y-2">
                    {categories.filter(cat => cat.isFixed && cat.isBusiness).map((cat, index) => (
                      <li
                        key={cat.id}
                        className="flex items-center justify-between p-4 bg-gradient-to-r from-purple-50 to-indigo-50 rounded-lg border border-purple-200"
                      >
                        <div className="flex items-center space-x-3 flex-1">
                          <div className="text-purple-600 text-sm font-mono bg-purple-100 px-3 py-1 rounded">
                            #{cat.position + 1}
                          </div>
                          <div>
                            <span className="font-medium text-gray-900">{cat.nameEn}</span>
                            <span className="ml-2 text-gray-500 text-sm">/ {cat.nameKn}</span>
                            <div className="text-xs text-gray-500 mt-1">
                              🏢 Business Category - For business users
                            </div>
                          </div>
                        </div>
                        <div className="flex items-center space-x-2">
                          <span className="text-xs text-purple-600 bg-purple-100 px-2 py-1 rounded">
                            Business
                          </span>
                        </div>
                      </li>
                    ))}
                  </ul>
                </div>

                {/* Regular Categories Section */}
                <div>
                  <h4 className="text-md font-semibold text-gray-700 mb-3 flex items-center">
                    <span className="mr-2">📝</span>
                    Custom Categories
                  </h4>
                  <ul className="space-y-2">
                    {categories.filter(cat => !cat.isFixed).map((cat, index) => (
                      <li
                        key={cat.id}
                        className="flex items-center justify-between p-4 bg-white rounded-lg border border-gray-200 hover:bg-gray-50 hover:border-orange-300 transition-all"
                      >
                        {editingId === cat.id ? (
                          <div className="flex-1 flex items-center space-x-2">
                            <input
                              type="text"
                              value={editNameEn}
                              onChange={e => setEditNameEn(e.target.value)}
                              className="flex-1 px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-orange-500"
                              placeholder="English name"
                            />
                            <input
                              type="text"
                              value={editNameKn}
                              onChange={e => setEditNameKn(e.target.value)}
                              className="flex-1 px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-orange-500"
                              placeholder="Kannada name"
                            />
                            <button
                              onClick={() => handleEdit(cat.id)}
                              className="px-3 py-2 bg-green-500 text-white rounded hover:bg-green-600 transition-all"
                              disabled={loading || !editNameEn.trim() || !editNameKn.trim()}
                            >
                              Save
                            </button>
                            <button
                              onClick={cancelEdit}
                              className="px-3 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 transition-all"
                              disabled={loading}
                            >
                              Cancel
                            </button>
                          </div>
                        ) : (
                          <>
                            <div className="flex items-center space-x-3 flex-1">
                              <div className="text-gray-400 text-sm font-mono bg-gray-100 px-3 py-1 rounded">
                                #{cat.position + 1}
                              </div>
                              <div>
                                <span className="font-medium text-gray-900">{cat.nameEn}</span>
                                <span className="ml-2 text-gray-500 text-sm">/ {cat.nameKn}</span>
                              </div>
                            </div>
                            <div className="flex space-x-2">
                              <button
                                onClick={() => moveCategory(cat.id, 'up')}
                                className="px-2 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 transition-all"
                                disabled={loading || index === 0}
                                title="Move up"
                              >
                                <ArrowUp size={14} />
                              </button>
                              <button
                                onClick={() => moveCategory(cat.id, 'down')}
                                className="px-2 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 transition-all"
                                disabled={loading || index === categories.filter(c => !c.isFixed).length - 1}
                                title="Move down"
                              >
                                <ArrowDown size={14} />
                              </button>
                              <button
                                onClick={() => startEdit(cat)}
                                className="px-3 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-all flex items-center space-x-1"
                                disabled={loading}
                              >
                                <Edit size={14} />
                                <span>Edit</span>
                              </button>
                              <button
                                onClick={() => handleDelete(cat.id)}
                                className="px-3 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-all flex items-center space-x-1"
                                disabled={loading}
                              >
                                <Trash2 size={14} />
                                <span>Delete</span>
                              </button>
                            </div>
                          </>
                        )}
                      </li>
                    ))}
                  </ul>
                </div>

                {/* Order Summary */}
                <div className="mt-4 p-3 bg-gray-50 rounded-lg">
                  <div className="text-sm text-gray-600">
                    <strong>Current Order:</strong> {categories.map(c => c.nameEn).join(' → ')}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
} 