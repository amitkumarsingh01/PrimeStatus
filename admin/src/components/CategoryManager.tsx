import React, { useEffect, useState } from 'react';
import { db } from '../firebase';
import { collection, getDocs, addDoc, deleteDoc, doc, updateDoc, writeBatch, query, orderBy } from 'firebase/firestore';
import { Edit, Trash2, Settings, ArrowUp, ArrowDown } from 'lucide-react';

export default function CategoryManager() {
  const [categories, setCategories] = useState<{ id: string; nameEn: string; nameKn: string; position: number }[]>([]);
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
      }));
      
      console.log('Fetched categories:', fetchedCategories.map(c => ({ name: c.nameEn, position: c.position })));
      
      // If any categories don't have position, assign them
      const categoriesWithPosition = fetchedCategories.filter(c => c.position !== undefined);
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
      
      // Sort by position
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
    setLoading(true);
    try {
      await deleteDoc(doc(db, 'categories', id));
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

  const startEdit = (category: { id: string; nameEn: string; nameKn: string }) => {
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

    const newIndex = direction === 'up' ? currentIndex - 1 : currentIndex + 1;
    if (newIndex < 0 || newIndex >= categories.length) return;

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
                    {categories.map((cat, index) => (
                      <option key={cat.id} value={cat.id}>
                        {index + 1}. {cat.nameEn}
                      </option>
                    ))}
                  </select>
                  <input
                    type="number"
                    value={newPosition}
                    onChange={e => setNewPosition(e.target.value === '' ? '' : Number(e.target.value))}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                    placeholder={`Position (0-${categories.length - 1})`}
                    min="0"
                    max={categories.length - 1}
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
                      onClick={resetToAlphabetical}
                      className="px-3 py-1 text-xs bg-gray-500 text-white rounded hover:bg-gray-600 transition-all"
                      disabled={loading}
                      title="Reset to alphabetical order"
                    >
                      Reset Order
                    </button>
                    <div className="text-sm text-gray-500">
                      {categories.length} categories
                    </div>
                  </div>
                </div>

                {error && <div className="text-red-500 mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">{error}</div>}
                {success && <div className="text-green-600 mb-4 p-3 bg-green-50 border border-green-200 rounded-lg">{success}</div>}
                {loading && <div className="text-gray-500 mb-4">Loading...</div>}

                <ul className="space-y-2">
                  {categories.map((cat, index) => (
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
                              disabled={loading || index === categories.length - 1}
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