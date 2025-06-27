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
  language: 'english' | 'kannada';
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