import React from 'react';
import { AppProvider, useApp } from './contexts/AppContext';
import LoginPage from './components/LoginPage';
import AdminDashboard from './components/AdminDashboard';
import UserDashboard from './components/UserDashboard';
import Header from './components/Header';

function AppContent() {
  const { state } = useApp();

  if (state.isLoginMode || !state.currentUser) {
    return <LoginPage />;
  }

  return (
    <div className="min-h-screen">
      <Header />
      {state.currentUser.isAdmin ? <AdminDashboard /> : <UserDashboard />}
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