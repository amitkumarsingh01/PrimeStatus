import React from 'react';
import { AppProvider, useApp } from './contexts/AppContext';
import LoginPage from './components/LoginPage';
import AdminLayout from './components/AdminLayout';
import UserDashboard from './components/UserDashboard';
import Header from './components/Header';

function AppContent() {
  const { state } = useApp();

  if (state.isLoginMode || !state.currentUser) {
    return <LoginPage />;
  }

  return (
    <div className="min-h-screen">
      {state.currentUser.isAdmin ? <AdminLayout /> : (
        <>
          <Header />
          <UserDashboard />
        </>
      )}
    </div>
  );
}

function App() {
  return (
    <AppProvider>
      <AppContent />
    </AppProvider>
  );
}

export default App;