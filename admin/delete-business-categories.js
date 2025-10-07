// Script to delete all business categories from Firestore
import { initializeApp } from 'firebase/app';
import { getFirestore, collection, getDocs, doc, deleteDoc, writeBatch } from 'firebase/firestore';

// Firebase config (replace with your actual config)
const firebaseConfig = {
  // Add your Firebase config here
  apiKey: "your-api-key",
  authDomain: "your-auth-domain",
  projectId: "prime-status-1db09",
  storageBucket: "your-storage-bucket",
  messagingSenderId: "your-sender-id",
  appId: "your-app-id"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function deleteAllBusinessCategories() {
  try {
    console.log('🗑️ Starting deletion of all business categories...');
    
    // Get all categories
    const categoriesSnapshot = await getDocs(collection(db, 'categories'));
    const allCategories = categoriesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    console.log('📋 Found categories:', allCategories.map(cat => cat.nameEn));
    
    // Business category names to delete
    const businessCategoryNames = [
      'Education & Training',
      'Health & Services', 
      'Retail & Shopping',
      'Finance & Services',
      'Travel & Ticketing',
      'Digital & Tech',
      'Food & Lifestyle',
      'Online Services'
    ];
    
    // Find business categories to delete
    const businessCategoriesToDelete = allCategories.filter(cat => 
      businessCategoryNames.includes(cat.nameEn) || cat.isBusiness === true
    );
    
    console.log('🎯 Business categories to delete:', businessCategoriesToDelete.map(cat => cat.nameEn));
    
    if (businessCategoriesToDelete.length === 0) {
      console.log('✅ No business categories found to delete');
      return;
    }
    
    // Delete in batches
    const batch = writeBatch(db);
    businessCategoriesToDelete.forEach(cat => {
      const categoryRef = doc(db, 'categories', cat.id);
      batch.delete(categoryRef);
      console.log(`🗑️ Marked for deletion: ${cat.nameEn} (ID: ${cat.id})`);
    });
    
    await batch.commit();
    console.log('✅ Successfully deleted all business categories from Firestore!');
    
    // Verify deletion
    const updatedSnapshot = await getDocs(collection(db, 'categories'));
    const remainingCategories = updatedSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    console.log('📋 Remaining categories:', remainingCategories.map(cat => cat.nameEn));
    
  } catch (error) {
    console.error('❌ Error deleting business categories:', error);
  }
}

// Run the deletion
deleteAllBusinessCategories();
