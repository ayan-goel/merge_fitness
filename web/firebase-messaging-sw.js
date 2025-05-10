// Import and configure the Firebase SDK
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js');

/*
 * You need to add your Firebase configuration here.
 * Since this is a public file, it's recommended to only include
 * the necessary configuration for the messaging functionality.
 */
firebase.initializeApp({
  apiKey: "AIzaSyA35JhkIkQpF-m-IqBgyTo2w7bkUCGlHuU",
  authDomain: "merge-finess.firebaseapp.com",
  projectId: "merge-finess",
  storageBucket: "merge-finess.firebasestorage.app",
  messagingSenderId: "394880012668",
  appId: "1:394880012668:web:0b9e69fdf32aa9e6cb54f9",
  measurementId: "G-YMH0FG4M05"
});

// Retrieve an instance of Firebase Messaging
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('Background message received:', payload);
  
  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
  
  return Promise.resolve();
}); 