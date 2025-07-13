import React, { useState, useEffect } from 'react';
import { collection, addDoc, getDocs, deleteDoc, doc, updateDoc } from 'firebase/firestore';
import { db } from '../firebase';

interface SubscriptionPlan {
  id?: string;
  title: string;
  subtitle: string;
  price: number;
  duration: number; // Duration in days
  usageType: 'Personal' | 'Business';
  isActive: boolean;
  createdAt: Date;
}

export default function Payment() {
  const [plans, setPlans] = useState<SubscriptionPlan[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingPlan, setEditingPlan] = useState<SubscriptionPlan | null>(null);
  const [selectedUsageType, setSelectedUsageType] = useState<'Personal' | 'Business'>('Personal');

  const [formData, setFormData] = useState({
    title: '',
    subtitle: '',
    price: '',
    duration: '30', // Default to 30 days
    customDuration: '',
    usageType: 'Personal' as 'Personal' | 'Business',
    isActive: true,
  });

  useEffect(() => {
    fetchPlans();
  }, []);

  const fetchPlans = async () => {
    try {
      const querySnapshot = await getDocs(collection(db, 'subscriptionPlans'));
      const plansData: SubscriptionPlan[] = [];
      querySnapshot.forEach((doc) => {
        plansData.push({ id: doc.id, ...doc.data() } as SubscriptionPlan);
      });
      setPlans(plansData);
    } catch (error) {
      console.error('Error fetching plans:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      const planData = {
        ...formData,
        price: parseFloat(formData.price),
        duration: formData.duration === 'custom' 
          ? parseInt(formData.customDuration) 
          : parseInt(formData.duration),
        createdAt: new Date(),
      };

      if (editingPlan) {
        // Update existing plan
        await updateDoc(doc(db, 'subscriptionPlans', editingPlan.id!), planData);
      } else {
        // Add new plan
        await addDoc(collection(db, 'subscriptionPlans'), planData);
      }

      setFormData({
        title: '',
        subtitle: '',
        price: '',
        duration: '30',
        customDuration: '',
        usageType: 'Personal',
        isActive: true,
      });
      setShowForm(false);
      setEditingPlan(null);
      fetchPlans();
    } catch (error) {
      console.error('Error saving plan:', error);
    }
  };

  const handleEdit = (plan: SubscriptionPlan) => {
    setEditingPlan(plan);
    setFormData({
      title: plan.title,
      subtitle: plan.subtitle,
      price: plan.price.toString(),
      duration: plan.duration.toString(),
      customDuration: '',
      usageType: plan.usageType,
      isActive: plan.isActive,
    });
    setShowForm(true);
  };

  const handleDelete = async (planId: string) => {
    if (window.confirm('Are you sure you want to delete this plan?')) {
      try {
        await deleteDoc(doc(db, 'subscriptionPlans', planId));
        fetchPlans();
      } catch (error) {
        console.error('Error deleting plan:', error);
      }
    }
  };

  const togglePlanStatus = async (plan: SubscriptionPlan) => {
    try {
      await updateDoc(doc(db, 'subscriptionPlans', plan.id!), {
        isActive: !plan.isActive,
      });
      fetchPlans();
    } catch (error) {
      console.error('Error updating plan status:', error);
    }
  };

  const filteredPlans = plans.filter(plan => plan.usageType === selectedUsageType);

  // Helper function to format duration in days to readable format
  const formatDuration = (days: number): string => {
    if (days === 30) return 'month';
    if (days === 90) return '3 months';
    if (days === 180) return '6 months';
    if (days === 365) return 'year';
    if (days === 730) return '2 years';
    if (days < 30) return `${days} days`;
    if (days < 365) return `${Math.round(days / 30)} months`;
    return `${Math.round(days / 365)} years`;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-6" style={{ background: 'linear-gradient(135deg, #fff5f0 0%, #f8f4ff 50%, #fff0e6 100%)' }}>
      <div className="max-w-7xl mx-auto">
        <div className="bg-white/80 backdrop-blur-lg rounded-2xl shadow-xl p-8 border border-white/20">
          {/* Header */}
          <div className="text-center mb-8">
            <img src="/assets/logo.png" alt="Logo" className="h-24 w-24 mx-auto mb-4" />
            <h1 className="text-3xl font-bold text-gray-800 mb-2">Subscription Plans Management</h1>
            <p className="text-gray-600">Manage pricing and plans for Personal and Business users</p>
          </div>

          {/* Usage Type Tabs */}
          <div className="mb-8">
            <div className="flex justify-center space-x-4">
              <button
                onClick={() => setSelectedUsageType('Personal')}
                className={`px-8 py-4 rounded-xl font-semibold transition-all duration-300 transform hover:scale-105 ${
                  selectedUsageType === 'Personal'
                    ? 'bg-gradient-to-r from-orange-500 to-purple-600 text-white shadow-lg'
                    : 'bg-white text-gray-700 hover:bg-gray-50 border-2 border-gray-200'
                }`}
              >
                <div className="flex items-center space-x-2">
                  <div className="w-3 h-3 rounded-full bg-blue-400"></div>
                  <span>Personal Plans</span>
                </div>
              </button>
              <button
                onClick={() => setSelectedUsageType('Business')}
                className={`px-8 py-4 rounded-xl font-semibold transition-all duration-300 transform hover:scale-105 ${
                  selectedUsageType === 'Business'
                    ? 'bg-gradient-to-r from-orange-500 to-purple-600 text-white shadow-lg'
                    : 'bg-white text-gray-700 hover:bg-gray-50 border-2 border-gray-200'
                }`}
              >
                <div className="flex items-center space-x-2">
                  <div className="w-3 h-3 rounded-full bg-green-400"></div>
                  <span>Business Plans</span>
                </div>
              </button>
            </div>
          </div>

          {/* Add New Plan Button */}
          <div className="mb-8 text-center">
            <button
              onClick={() => {
                setShowForm(true);
                setEditingPlan(null);
                setFormData({
                  title: '',
                  subtitle: '',
                  price: '',
                  duration: '30',
                  customDuration: '',
                  usageType: selectedUsageType,
                  isActive: true,
                });
              }}
              className="bg-gradient-to-r from-green-500 to-emerald-600 text-white px-8 py-4 rounded-xl hover:from-green-600 hover:to-emerald-700 transition-all duration-300 transform hover:scale-105 shadow-lg flex items-center space-x-3 mx-auto"
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
              </svg>
              <span className="font-semibold">Add New {selectedUsageType} Plan</span>
            </button>
          </div>

          {/* Plans Grid */}
          {filteredPlans.length === 0 ? (
            <div className="text-center py-12">
              <div className="text-gray-400 mb-4">
                <svg className="h-16 w-16 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                </svg>
              </div>
              <h3 className="text-xl font-semibold text-gray-600 mb-2">No {selectedUsageType} plans found</h3>
              <p className="text-gray-500">Create your first {selectedUsageType.toLowerCase()} plan to get started</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
              {filteredPlans.map((plan) => (
                <div
                  key={plan.id}
                  className={`bg-white rounded-2xl shadow-lg overflow-hidden border-2 transition-all duration-300 transform hover:scale-105 hover:shadow-xl ${
                    plan.isActive ? 'border-green-200' : 'border-gray-200 opacity-75'
                  }`}
                >
                  {/* Plan Header */}
                  <div className="p-6">
                    <div className="flex justify-between items-start mb-4">
                      <div className="flex-1">
                        <h3 className="text-2xl font-bold text-gray-800 mb-2">{plan.title}</h3>
                        <p className="text-gray-600 text-sm mb-4 leading-relaxed">{plan.subtitle}</p>
                        <div className="flex items-baseline space-x-2 mb-4">
                          <span className="text-4xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
                            ₹{plan.price}
                          </span>
                          <span className="text-gray-500 text-lg">/{formatDuration(plan.duration)}</span>
                        </div>
                      </div>
                      <div className="flex items-center">
                        <button
                          onClick={() => togglePlanStatus(plan)}
                          className={`px-4 py-2 rounded-full text-sm font-medium transition-all duration-300 ${
                            plan.isActive
                              ? 'bg-green-100 text-green-800 hover:bg-green-200'
                              : 'bg-gray-100 text-gray-800 hover:bg-gray-200'
                          }`}
                        >
                          {plan.isActive ? '✓ Active' : '○ Inactive'}
                        </button>
                      </div>
                    </div>

                    {/* Action Buttons */}
                    <div className="flex space-x-3">
                      <button
                        onClick={() => handleEdit(plan)}
                        className="flex-1 bg-gradient-to-r from-blue-500 to-blue-600 text-white py-3 px-4 rounded-xl hover:from-blue-600 hover:to-blue-700 transition-all duration-300 font-medium"
                      >
                        Edit Plan
                      </button>
                      <button
                        onClick={() => handleDelete(plan.id!)}
                        className="flex-1 bg-gradient-to-r from-red-500 to-red-600 text-white py-3 px-4 rounded-xl hover:from-red-600 hover:to-red-700 transition-all duration-300 font-medium"
                      >
                        Delete
                      </button>
                    </div>
                  </div>

                  {/* Plan Status Indicator */}
                  <div className={`h-2 ${plan.isActive ? 'bg-gradient-to-r from-green-400 to-green-600' : 'bg-gray-300'}`}></div>
                </div>
              ))}
            </div>
          )}

          {/* Feature Cards */}
          <div className="mt-12 grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="text-white p-6 rounded-xl" style={{ background: 'linear-gradient(135deg, #2563eb 0%, #1e40af 100%)' }}>
              <svg className="h-8 w-8 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
              </svg>
              <h3 className="font-semibold mb-2">Dynamic Pricing</h3>
              <p className="text-sm opacity-90">Set different prices for Personal and Business users</p>
            </div>
            <div className="text-white p-6 rounded-xl" style={{ background: 'linear-gradient(135deg, #1e40af 0%, #2563eb 100%)' }}>
              <svg className="h-8 w-8 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <h3 className="font-semibold mb-2">Active Management</h3>
              <p className="text-sm opacity-90">Enable or disable plans without deletion</p>
            </div>
            <div className="text-white p-6 rounded-xl" style={{ background: 'linear-gradient(135deg, #2563eb 0%, #1e40af 100%)' }}>
              <svg className="h-8 w-8 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
              <h3 className="font-semibold mb-2">Real-time Updates</h3>
              <p className="text-sm opacity-90">Changes reflect immediately in the app</p>
            </div>
          </div>
        </div>
      </div>

      {/* Add/Edit Plan Modal */}
      {showForm && (
        <div className="fixed inset-0 bg-black bg-opacity-60 flex items-center justify-center z-50 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-lg mx-4 transform transition-all duration-300 scale-100">
            {/* Modal Header */}
            <div className="text-center mb-6">
              <div className="w-16 h-16 bg-gradient-to-r from-blue-500 to-purple-600 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                </svg>
              </div>
              <h2 className="text-2xl font-bold text-gray-800 mb-2">
                {editingPlan ? 'Edit Subscription Plan' : 'Create New Plan'}
              </h2>
              <p className="text-gray-600">
                {editingPlan ? 'Update the plan details below' : 'Fill in the details to create a new subscription plan'}
              </p>
            </div>
            
            <form onSubmit={handleSubmit} className="space-y-6">
              {/* Title */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">
                  Plan Title *
                </label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  placeholder="e.g., Monthly Premium, Annual Pro"
                  className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300"
                  required
                />
              </div>

              {/* Subtitle */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">
                  Description *
                </label>
                <input
                  type="text"
                  value={formData.subtitle}
                  onChange={(e) => setFormData({ ...formData, subtitle: e.target.value })}
                  placeholder="e.g., Perfect for personal use, Best value for businesses"
                  className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300"
                  required
                />
              </div>

              {/* Price and Duration Row */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">
                    Price (₹) *
                  </label>
                  <input
                    type="number"
                    value={formData.price}
                    onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                    placeholder="99"
                    className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300"
                    min="0"
                    step="0.01"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">
                    Duration (Days) *
                  </label>
                  <select
                    value={formData.duration}
                    onChange={(e) => setFormData({ ...formData, duration: e.target.value })}
                    className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300"
                    required
                  >
                    <option value="7">7 days (1 week)</option>
                    <option value="15">15 days (2 weeks)</option>
                    <option value="30">30 days (1 month)</option>
                    <option value="60">60 days (2 months)</option>
                    <option value="90">90 days (3 months)</option>
                    <option value="180">180 days (6 months)</option>
                    <option value="365">365 days (1 year)</option>
                    <option value="730">730 days (2 years)</option>
                    <option value="custom">Custom (enter below)</option>
                  </select>
                </div>
              </div>

              {/* Custom Duration Input */}
              {formData.duration === 'custom' && (
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">
                    Custom Duration (Days) *
                  </label>
                  <input
                    type="number"
                    value={formData.customDuration || ''}
                    onChange={(e) => setFormData({ ...formData, customDuration: e.target.value })}
                    placeholder="Enter number of days"
                    className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300"
                    min="1"
                    required
                  />
                </div>
              )}

              {/* Usage Type */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">
                  User Type *
                </label>
                <select
                  value={formData.usageType}
                  onChange={(e) => setFormData({ ...formData, usageType: e.target.value as 'Personal' | 'Business' })}
                  className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-300"
                >
                  <option value="Personal">Personal Users</option>
                  <option value="Business">Business Users</option>
                </select>
              </div>

              {/* Active Status */}
              <div className="flex items-center p-4 bg-gray-50 rounded-xl">
                <input
                  type="checkbox"
                  id="isActive"
                  checked={formData.isActive}
                  onChange={(e) => setFormData({ ...formData, isActive: e.target.checked })}
                  className="w-5 h-5 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                />
                <label htmlFor="isActive" className="ml-3 text-sm font-medium text-gray-700">
                  Make this plan active and available to users
                </label>
              </div>

              {/* Action Buttons */}
              <div className="flex space-x-4 pt-6">
                <button
                  type="submit"
                  className="flex-1 bg-gradient-to-r from-blue-500 to-blue-600 text-white py-3 px-6 rounded-xl hover:from-blue-600 hover:to-blue-700 transition-all duration-300 font-semibold transform hover:scale-105"
                >
                  {editingPlan ? 'Update Plan' : 'Create Plan'}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setShowForm(false);
                    setEditingPlan(null);
                  }}
                  className="flex-1 bg-gray-200 text-gray-700 py-3 px-6 rounded-xl hover:bg-gray-300 transition-all duration-300 font-semibold"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
