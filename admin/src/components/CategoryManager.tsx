import React, { useEffect, useState } from 'react';
import { db } from '../firebase';
import { collection, getDocs, addDoc, deleteDoc, doc, updateDoc } from 'firebase/firestore';

export default function CategoryManager() {
  const [categories, setCategories] = useState<{ id: string; nameEn: string; nameKn: string }[]>([]);
  const [newCategoryEn, setNewCategoryEn] = useState('');
  const [newCategoryKn, setNewCategoryKn] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editNameEn, setEditNameEn] = useState('');
  const [editNameKn, setEditNameKn] = useState('');

  const fetchCategories = async () => {
    setLoading(true);
    setError(null);
    try {
      const querySnapshot = await getDocs(collection(db, 'categories'));
      setCategories(querySnapshot.docs.map(docSnap => ({
        id: docSnap.id,
        nameEn: docSnap.data().nameEn || '',
        nameKn: docSnap.data().nameKn || '',
      })));
    } catch (e) {
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
      await addDoc(collection(db, 'categories'), { nameEn: newCategoryEn.trim(), nameKn: newCategoryKn.trim() });
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

  return (
    <div className="min-h-screen p-6" style={{ background: 'linear-gradient(135deg, #fff5f0 0%, #f8f4ff 50%, #fff0e6 100%)' }}>
      <div className="max-w-2xl mx-auto mt-10 bg-white/90 rounded-2xl shadow-xl p-8 border border-white/20">
        <h2 className="text-3xl font-bold text-gray-800 mb-6">Manage Categories</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
          <input
            type="text"
            value={newCategoryEn}
            onChange={e => setNewCategoryEn(e.target.value)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
            placeholder="Category name (English)"
          />
          <input
            type="text"
            value={newCategoryKn}
            onChange={e => setNewCategoryKn(e.target.value)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
            placeholder="Category name (Kannada)"
          />
          <button
            onClick={handleAdd}
            className="col-span-1 md:col-span-2 mt-2 px-6 py-2 bg-gradient-to-r from-orange-600 to-purple-600 text-white rounded-lg font-semibold shadow hover:from-orange-700 hover:to-purple-700 transition-all"
            disabled={loading || !newCategoryEn.trim() || !newCategoryKn.trim()}
          >
            Add Category
          </button>
        </div>
        {error && <div className="text-red-500 mb-4">{error}</div>}
        {loading && <div className="text-gray-500 mb-4">Loading...</div>}
        <div className="bg-white/80 rounded-xl shadow p-4 border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-700 mb-3">All Categories</h3>
          <ul className="divide-y divide-gray-200">
            {categories.map(cat => (
              <li key={cat.id} className="flex items-center justify-between py-3">
                {editingId === cat.id ? (
                  <div className="flex-1 flex items-center space-x-2">
                    <input
                      type="text"
                      value={editNameEn}
                      onChange={e => setEditNameEn(e.target.value)}
                      className="flex-1 px-3 py-1 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-orange-500"
                      placeholder="English name"
                    />
                    <input
                      type="text"
                      value={editNameKn}
                      onChange={e => setEditNameKn(e.target.value)}
                      className="flex-1 px-3 py-1 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-orange-500"
                      placeholder="Kannada name"
                    />
                    <button
                      onClick={() => handleEdit(cat.id)}
                      className="px-3 py-1 bg-green-500 text-white rounded hover:bg-green-600 transition-all"
                      disabled={loading || !editNameEn.trim() || !editNameKn.trim()}
                    >
                      Save
                    </button>
                    <button
                      onClick={cancelEdit}
                      className="px-3 py-1 bg-gray-500 text-white rounded hover:bg-gray-600 transition-all"
                      disabled={loading}
                    >
                      Cancel
                    </button>
                  </div>
                ) : (
                  <>
                    <div>
                      <span className="font-medium text-gray-900">{cat.nameEn}</span>
                      <span className="ml-2 text-gray-500 text-sm">/ {cat.nameKn}</span>
                    </div>
                    <div className="flex space-x-2">
                      <button
                        onClick={() => startEdit(cat)}
                        className="px-4 py-1 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-all"
                        disabled={loading}
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDelete(cat.id)}
                        className="px-4 py-1 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-all"
                        disabled={loading}
                      >
                        Delete
                      </button>
                    </div>
                  </>
                )}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </div>
  );
} 