import { useState, useEffect } from 'react';
import { Users as UsersIcon, Search, Filter, Eye, Trash2, Crown, DollarSign } from 'lucide-react';
import { db } from '../firebase';
import { collection, getDocs, deleteDoc, doc } from 'firebase/firestore';

interface FirebaseUser {
  id: string;
  name: string;
  email: string;
  phoneNumber?: string;
  address?: string;
  city?: string;
  usageType?: string;
  profilePhotoUrl?: string;
  createdAt?: any;
  lastLoginAt?: any;
  dateOfBirth?: string;
  religion?: string;
  state?: string;
  subscription?: string;
  subscriptionDate?: any;
  updatedAt?: any;
  language?: string;
}

// Helper to format any cell value for display
function formatCell(value: any) {
  if (!value) return '';
  // Firestore Timestamp object
  if (typeof value === 'object' && value.seconds !== undefined && value.nanoseconds !== undefined) {
    const date = new Date(value.seconds * 1000);
    return date.toLocaleString();
  }
  // If it's an object, show as JSON
  if (typeof value === 'object') {
    return JSON.stringify(value);
  }
  return value;
}

export default function Users() {
  const [users, setUsers] = useState<FirebaseUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterType, setFilterType] = useState<'all' | 'business' | 'personal'>('all');
  const [subscriptionFilter, setSubscriptionFilter] = useState<'all' | 'free' | 'paid'>('all');
  const [sortBy, setSortBy] = useState<'name' | 'subscription' | 'subscriptionDate' | 'createdAt'>('createdAt');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      // Fetch all users, no orderBy
      const usersQuery = collection(db, 'users');
      const querySnapshot = await getDocs(usersQuery);
      const fetchedUsers: FirebaseUser[] = [];
      querySnapshot.forEach((docSnapshot) => {
        const data = docSnapshot.data();
        fetchedUsers.push({
          id: docSnapshot.id,
          name: data.name || data.userName || 'Unknown User',
          email: data.email || 'No email',
          phoneNumber: data.phoneNumber || data.userPhoneNumber || '',
          address: data.address || data.userAddress || '',
          city: data.city || data.userCity || '',
          usageType: data.usageType || 'Personal',
          profilePhotoUrl: data.profilePhotoUrl || 'https://api.dicebear.com/7.x/avataaars/svg?seed=user',
          createdAt: data.createdAt,
          lastLoginAt: data.lastLoginAt,
          dateOfBirth: data.dateOfBirth || '',
          religion: data.religion || '',
          state: data.state || '',
          subscription: data.subscription || '',
          subscriptionDate: data.subscriptionDate || '',
          updatedAt: data.updatedAt || '',
          language: data.language || '',
        });
      });
      // Sort: by createdAt (desc, if present), else by name
      fetchedUsers.sort((a, b) => {
        if (a.createdAt && b.createdAt) {
          const aTime = a.createdAt.seconds ? a.createdAt.seconds : new Date(a.createdAt).getTime() / 1000;
          const bTime = b.createdAt.seconds ? b.createdAt.seconds : new Date(b.createdAt).getTime() / 1000;
          return bTime - aTime;
        }
        if (a.name && b.name) {
          return a.name.localeCompare(b.name);
        }
        return 0;
      });
      setUsers(fetchedUsers);
    } catch (error) {
      console.error('Error fetching users:', error);
      alert('Error loading users');
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteUser = async (userId: string) => {
    if (window.confirm('Are you sure you want to delete this user? This action cannot be undone.')) {
      try {
        await deleteDoc(doc(db, 'users', userId));
        setUsers(prev => prev.filter(user => user.id !== userId));
        alert('User deleted successfully!');
      } catch (error) {
        console.error('Error deleting user:', error);
        alert('Error deleting user');
      }
    }
  };

  // Helper function to determine if user is paid
  const isPaidUser = (user: FirebaseUser) => {
    return user.subscription && user.subscription.toLowerCase() !== 'free' && user.subscription.toLowerCase() !== '';
  };

  const filteredUsers = users.filter(user => {
    const matchesSearch = (user.name?.toLowerCase() || '').includes(searchTerm.toLowerCase()) ||
                         (user.email?.toLowerCase() || '').includes(searchTerm.toLowerCase()) ||
                         (user.phoneNumber?.toLowerCase() || '').includes(searchTerm.toLowerCase());
    
    const matchesFilter = filterType === 'all' || 
                         (filterType === 'business' && user.usageType === 'Business') ||
                         (filterType === 'personal' && user.usageType === 'Personal');
    
    const matchesSubscription = subscriptionFilter === 'all' ||
                               (subscriptionFilter === 'free' && !isPaidUser(user)) ||
                               (subscriptionFilter === 'paid' && isPaidUser(user));
    
    return matchesSearch && matchesFilter && matchesSubscription;
  });

  // Sort users based on selected criteria
  const sortedUsers = [...filteredUsers].sort((a, b) => {
    let comparison = 0;
    
    switch (sortBy) {
      case 'name':
        comparison = (a.name || '').localeCompare(b.name || '');
        break;
      case 'subscription':
        const aPaid = isPaidUser(a);
        const bPaid = isPaidUser(b);
        comparison = aPaid === bPaid ? 0 : aPaid ? 1 : -1;
        break;
      case 'subscriptionDate':
        const aSubDate = a.subscriptionDate?.seconds || 0;
        const bSubDate = b.subscriptionDate?.seconds || 0;
        comparison = bSubDate - aSubDate;
        break;
      case 'createdAt':
      default:
        const aTime = a.createdAt?.seconds || 0;
        const bTime = b.createdAt?.seconds || 0;
        comparison = bTime - aTime;
        break;
    }
    
    return sortOrder === 'asc' ? comparison : -comparison;
  });

  return (
    <div className="min-h-screen p-6" style={{ background: 'linear-gradient(135deg, #fff5f0 0%, #f8f4ff 50%, #fff0e6 100%)' }}>
      <div className="max-w-7xl mx-auto">
        <div className="bg-white/80 backdrop-blur-lg rounded-2xl shadow-xl p-6 border border-white/20">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center space-x-3">
              <div className="w-12 h-12 rounded-full flex items-center justify-center" style={{ background: 'linear-gradient(135deg, #d74d02 0%, #2c0036 100%)' }}>
                <UsersIcon className="h-6 w-6 text-white" />
              </div>
              <div>
                <h1 className="text-3xl font-bold text-gray-800">Users Management</h1>
                <p className="text-gray-600">Manage all registered users</p>
              </div>
            </div>
            <div className="text-right">
              <div className="text-2xl font-bold text-gray-800">{sortedUsers.length}</div>
              <div className="text-sm text-gray-600">
                Total Users ({sortedUsers.filter(u => isPaidUser(u)).length} Paid, {sortedUsers.filter(u => !isPaidUser(u)).length} Free)
              </div>
            </div>
          </div>

          {/* Search and Filter */}
          <div className="flex flex-col lg:flex-row gap-4 mb-6">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-4 w-4" />
              <input
                type="text"
                placeholder="Search users by name, email, or phone..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
              />
            </div>
            <div className="flex flex-col sm:flex-row gap-2">
              <div className="flex items-center space-x-2">
                <Filter className="h-4 w-4 text-gray-400" />
                <select
                  value={filterType}
                  onChange={(e) => setFilterType(e.target.value as 'all' | 'business' | 'personal')}
                  className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                >
                  <option value="all">All Users</option>
                  <option value="business">Business Users</option>
                  <option value="personal">Personal Users</option>
                </select>
              </div>
              <div className="flex items-center space-x-2">
                <DollarSign className="h-4 w-4 text-gray-400" />
                <select
                  value={subscriptionFilter}
                  onChange={(e) => setSubscriptionFilter(e.target.value as 'all' | 'free' | 'paid')}
                  className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                >
                  <option value="all">All Subscriptions</option>
                  <option value="free">Free Users</option>
                  <option value="paid">Paid Users</option>
                </select>
              </div>
            </div>
          </div>

          {loading ? (
            <div className="text-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 mx-auto mb-4" style={{ borderColor: '#d74d02' }}></div>
              <p className="text-gray-600">Loading users...</p>
            </div>
          ) : sortedUsers.length === 0 ? (
            <div className="text-center py-12">
              <div className="text-gray-400 mb-4">
                <UsersIcon className="h-16 w-16 mx-auto" />
              </div>
              <h3 className="text-xl font-semibold text-gray-600 mb-2">No users found</h3>
              <p className="text-gray-500">
                {searchTerm || filterType !== 'all' 
                  ? 'Try adjusting your search or filter criteria' 
                  : 'No users have registered yet'}
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full bg-white rounded-lg shadow-sm text-xs">
                <thead>
                  <tr className="border-b border-gray-200">
                    <th className="px-2 py-2">Photo</th>
                    <th className="px-2 py-2">Name</th>
                    <th className="px-2 py-2">Email</th>
                    <th className="px-2 py-2">Phone</th>
                    <th className="px-2 py-2">Address</th>
                    <th className="px-2 py-2">City</th>
                    <th className="px-2 py-2">State</th>
                    <th className="px-2 py-2">Type</th>
                    <th className="px-2 py-2">Language</th>
                    <th className="px-2 py-2">DOB</th>
                    <th className="px-2 py-2">Religion</th>
                    <th className="px-2 py-2">Subscription</th>
                    <th className="px-2 py-2">Subscr. Date</th>
                    <th className="px-2 py-2">Updated At</th>
                    <th className="px-2 py-2">Created At</th>
                    <th className="px-2 py-2">Actions</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {sortedUsers.map((user) => (
                    <tr key={user.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-2 py-2">
                        <img
                          className="h-8 w-8 rounded-full object-cover"
                          src={user.profilePhotoUrl}
                          alt={user.name}
                        />
                      </td>
                      <td className="px-2 py-2">{formatCell(user.name)}</td>
                      <td className="px-2 py-2">{formatCell(user.email)}</td>
                      <td className="px-2 py-2">{formatCell(user.phoneNumber)}</td>
                      <td className="px-2 py-2">{formatCell(user.address)}</td>
                      <td className="px-2 py-2">{formatCell(user.city)}</td>
                      <td className="px-2 py-2">{formatCell(user.state)}</td>
                      <td className="px-2 py-2">{formatCell(user.usageType)}</td>
                      <td className="px-2 py-2">{formatCell(user.language)}</td>
                      <td className="px-2 py-2">{formatCell(user.dateOfBirth)}</td>
                      <td className="px-2 py-2">{formatCell(user.religion)}</td>
                      <td className="px-2 py-2">
                        <div className="flex items-center space-x-1">
                          {isPaidUser(user) ? (
                            <>
                              <Crown className="h-3 w-3 text-yellow-500" />
                              <span className="text-green-600 font-medium bg-green-50 px-2 py-1 rounded-full text-xs">
                                {formatCell(user.subscription)}
                              </span>
                            </>
                          ) : (
                            <>
                              <span className="text-gray-500 font-medium bg-gray-50 px-2 py-1 rounded-full text-xs">
                                Free
                              </span>
                            </>
                          )}
                        </div>
                      </td>
                      <td className="px-2 py-2">{formatCell(user.subscriptionDate)}</td>
                      <td className="px-2 py-2">{formatCell(user.updatedAt)}</td>
                      <td className="px-2 py-2">{formatCell(user.createdAt)}</td>
                      <td className="px-2 py-2">
                        <div className="flex items-center space-x-2">
                          <button
                            onClick={() => {
                              alert(`Viewing details for ${user.name}`);
                            }}
                            className="text-blue-600 hover:text-blue-900 p-1 rounded hover:bg-blue-50"
                            title="View details"
                          >
                            <Eye className="h-4 w-4" />
                          </button>
                          <button
                            onClick={() => handleDeleteUser(user.id)}
                            className="text-red-600 hover:text-red-900 p-1 rounded hover:bg-red-50"
                            title="Delete user"
                          >
                            <Trash2 className="h-4 w-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
} 