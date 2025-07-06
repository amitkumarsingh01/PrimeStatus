export interface User {
  id: string;
  name: string;
  photo: string;
  isAdmin: boolean;
}

export interface Post {
  id: string;
  userId: string;
  userName: string;
  userPhoto: string;
  mainImage: string;
  category: string;
  region: string;
  language: 'english' | 'kannada';
  frameSize?: { width: number; height: number };
  textSettings: {
    text: string;
    x: number;
    y: number;
    font: string;
    fontSize: number;
    color: string;
    hasBackground: boolean;
    backgroundColor: string;
  };
  addressSettings: {
    text: string;
    x: number;
    y: number;
    font: string;
    fontSize: number;
    color: string;
    hasBackground: boolean;
    backgroundColor: string;
    enabled: boolean;
  };
  phoneSettings: {
    text: string;
    x: number;
    y: number;
    font: string;
    fontSize: number;
    color: string;
    hasBackground: boolean;
    backgroundColor: string;
    enabled: boolean;
  };
  profileSettings: {
    x: number;
    y: number;
    shape: 'circle' | 'square';
    size: number;
    hasBackground: boolean;
    enabled: boolean;
  };
  createdAt: string;
}

export interface AppState {
  currentUser: User | null;
  posts: Post[];
  isLoginMode: boolean;
}