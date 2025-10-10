import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getStorage, ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { getFunctions } from 'firebase/functions';

const firebaseConfig = {
  apiKey: "AIzaSyCGkRvNqYwz0B8HoRqqFMI0-wu-nvkVgpE",
  authDomain: "prime-status-1db09.firebaseapp.com",
  projectId: "prime-status-1db09",
  storageBucket: "prime-status-1db09.firebasestorage.app",
  messagingSenderId: "344256821707",
  appId: "1:344256821707:web:5e7fe5c7d7b414308ade4e",
  measurementId: "G-XKV0NY6S12"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const storage = getStorage(app);
export const functions = getFunctions(app);

export async function uploadMediaFile(file: File, path: string): Promise<string> {
  const storageRef = ref(storage, path);
  await uploadBytes(storageRef, file);
  return await getDownloadURL(storageRef);
} 