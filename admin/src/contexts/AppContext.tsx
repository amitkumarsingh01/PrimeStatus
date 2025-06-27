import React, { createContext, useContext, useReducer, ReactNode } from 'react';
import { AppState, User, Post } from '../types';

interface AppContextType {
  state: AppState;
  login: (user: User) => void;
  logout: () => void;
  addPost: (post: Post) => void;
  updateUser: (user: User) => void;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

const initialState: AppState = {
  currentUser: null,
  posts: [],
  isLoginMode: true,
};

type AppAction = 
  | { type: 'LOGIN'; payload: User }
  | { type: 'LOGOUT' }
  | { type: 'ADD_POST'; payload: Post }
  | { type: 'UPDATE_USER'; payload: User };

function appReducer(state: AppState, action: AppAction): AppState {
  switch (action.type) {
    case 'LOGIN':
      return {
        ...state,
        currentUser: action.payload,
        isLoginMode: false,
      };
    case 'LOGOUT':
      return {
        ...state,
        currentUser: null,
        isLoginMode: true,
      };
    case 'ADD_POST':
      return {
        ...state,
        posts: [action.payload, ...state.posts],
      };
    case 'UPDATE_USER':
      return {
        ...state,
        currentUser: action.payload,
      };
    default:
      return state;
  }
}

export function AppProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(appReducer, initialState);

  const login = (user: User) => {
    dispatch({ type: 'LOGIN', payload: user });
  };

  const logout = () => {
    dispatch({ type: 'LOGOUT' });
  };

  const addPost = (post: Post) => {
    dispatch({ type: 'ADD_POST', payload: post });
  };

  const updateUser = (user: User) => {
    dispatch({ type: 'UPDATE_USER', payload: user });
  };

  return (
    <AppContext.Provider value={{ state, login, logout, addPost, updateUser }}>
      {children}
    </AppContext.Provider>
  );
}

export function useApp() {
  const context = useContext(AppContext);
  if (context === undefined) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
}