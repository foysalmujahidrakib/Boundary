
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js";

import { getAuth } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";

import { getFirestore } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js";

// Your existing Firebase project configuration
const firebaseConfig = {
  apiKey: "AIzaSyDQcVhVxVj8JbDv3m8i0EBQ4zwV12B6Grs",
  authDomain: "boundary-4b4e8.firebaseapp.com",
  projectId: "boundary-4b4e8",
  storageBucket: "boundary-4b4e8.firebasestorage.app",
  messagingSenderId: "636164427849",
  appId: "1:636164427849:web:d2ec68b5027b276f52ef98",
  measurementId: "G-FS1M8TM786"
};

// Check Firebase configuration
export const isConfigured = Boolean(
  firebaseConfig.apiKey &&
  firebaseConfig.projectId &&
  firebaseConfig.appId
);

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Authentication
export const auth = getAuth(app);

// Initialize Firestore Database
export const db = getFirestore(app);

console.log("Firebase initialized successfully!");
