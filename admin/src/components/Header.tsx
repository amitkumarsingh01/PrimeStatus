import React from 'react';
import { LogOut, User, Settings, Home } from 'lucide-react';
import { useApp } from '../contexts/AppContext';

export default function Header() {
  const { state, logout } = useApp();

  if (!state.currentUser) return null;

  return (
    <header className="bg-white/80 backdrop-blur-lg border-b border-white/20 sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <img src="/assets/logo.png" alt="Logo" className="h-16 w-16 mx-auto mb-4" />
            {/* <div className="w-10 h-10 rounded-full flex items-center justify-center" style={{ background: 'linear-gradient(135deg, #d74d02 0%, #2c0036 100%)' }}>
              <Home className="h-5 w-5 text-white" />
            </div> */}
            <div>
              <h1 className="text-xl font-bold text-gray-800">Prime Status</h1>
              <p className="text-sm text-gray-600">
                {state.currentUser.isAdmin ? 'Admin Dashboard' : 'User Gallery'}
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-4">
            <div className="flex items-center space-x-3">
              <img
                src={state.currentUser.photo}
                alt={state.currentUser.name}
                className="w-10 h-10 rounded-full object-cover border-2 border-gray-200"
              />
              <div className="hidden md:block">
                <p className="font-semibold text-gray-800">{state.currentUser.name}</p>
                <p className="text-sm text-gray-600">
                  {state.currentUser.isAdmin ? 'Administrator' : 'User'}
                </p>
              </div>
            </div>

            <button
              onClick={logout}
              className="flex items-center space-x-2 px-4 py-2 text-white rounded-lg transition-colors"
              style={{ background: 'linear-gradient(135deg, #d74d02 0%, #2c0036 100%)' }}
            >
              <LogOut className="h-4 w-4" />
              <span>Logout</span>
            </button>
          </div>
        </div>
      </div>
    </header>
  );
}