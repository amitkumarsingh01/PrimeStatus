import React, { useState } from 'react';
import { User, LogIn, Lock, AlertCircle } from 'lucide-react';
import { useApp } from '../contexts/AppContext';

export default function LoginPage() {
  const { login } = useApp();
  const [formData, setFormData] = useState({
    username: '',
    password: '',
  });
  const [error, setError] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    // Fixed credentials
    const ADMIN_USERNAME = 'admin';
    const ADMIN_PASSWORD = 'admin123#';

    if (formData.username === ADMIN_USERNAME && formData.password === ADMIN_PASSWORD) {
      const user = {
        id: Date.now().toString(),
        name: 'Admin User',
        photo: `https://api.dicebear.com/7.x/avataaars/svg?seed=admin`,
        isAdmin: true,
      };
      login(user);
    } else {
      setError('Invalid username or password. Please try again.');
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-orange-50 via-purple-50 to-orange-100 flex items-center justify-center p-4" style={{ background: 'linear-gradient(135deg, #fff5f0 0%, #f8f4ff 50%, #fff0e6 100%)' }}>
      <div className="bg-white/80 backdrop-blur-lg rounded-2xl shadow-xl p-8 w-full max-w-md border border-white/20">
        <div className="text-center mb-8">
          <img src="/assets/logo.png" alt="Logo" className="h-20 w-20 mx-auto mb-4" />
          {/* <div className="w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4" style={{ background: 'linear-gradient(135deg, #d74d02 0%, #2c0036 100%)' }}>
            <img src="/assets/logo.png" alt="Logo" className="h-8 w-8" />
          </div> */}
          <h1 className="text-3xl font-bold text-gray-800 mb-2">Admin Login</h1>
          <p className="text-gray-600">Sign in to access admin dashboard</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-4 flex items-center space-x-2">
              <AlertCircle className="h-5 w-5 text-red-500" />
              <span className="text-red-700 text-sm">{error}</span>
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Username
            </label>
            <input
              type="text"
              value={formData.username}
              onChange={(e) => setFormData(prev => ({ ...prev, username: e.target.value }))}
              className="w-full px-4 py-3 rounded-lg border border-gray-300 focus:ring-2 focus:border-transparent transition-all duration-200"
              style={{ '--tw-ring-color': '#d74d02' } as React.CSSProperties}
              placeholder="Enter username"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Password
            </label>
            <input
              type="password"
              value={formData.password}
              onChange={(e) => setFormData(prev => ({ ...prev, password: e.target.value }))}
              className="w-full px-4 py-3 rounded-lg border border-gray-300 focus:ring-2 focus:border-transparent transition-all duration-200"
              style={{ '--tw-ring-color': '#d74d02' } as React.CSSProperties}
              placeholder="Enter password"
              required
            />
          </div>

          {/* <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <div className="flex items-start space-x-2">
              <Lock className="h-5 w-5 text-blue-500 mt-0.5" />
              <div className="text-sm text-blue-700">
                <p className="font-medium mb-1">Login Credentials:</p>
                <p><strong>Username:</strong> admin</p>
                <p><strong>Password:</strong> admin123#</p>
              </div>
            </div>
          </div> */}

          <button
            type="submit"
            className="w-full text-white py-3 px-4 rounded-lg font-medium focus:outline-none focus:ring-2 focus:ring-offset-2 transition-all duration-200 flex items-center justify-center space-x-2"
            style={{ background: 'linear-gradient(135deg, #d74d02 0%, #2c0036 100%)' }}
          >
            <LogIn className="h-5 w-5" />
            <span>Sign In</span>
          </button>
        </form>
      </div>
    </div>
  );
}