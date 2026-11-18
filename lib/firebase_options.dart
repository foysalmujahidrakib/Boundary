// Firebase configuration.
//
// The WEB options below are copied from the web app's js/firebase.js, so the
// Flutter web build talks to the same Firebase project.
//
// For ANDROID / iOS / macOS run this once in the project folder and let it
// overwrite this file (it registers the native apps and downloads their
// config for you):
//
//     dart pub global activate flutterfire_cli
//     flutterfire configure --project=boundary-4b4e8
//
// Firebase API keys identify your project; they are not secrets. Access is
// controlled by firestore.rules.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'Firebase is not configured for this platform yet. '
          'Run `flutterfire configure --project=boundary-4b4e8` in the '
          'project folder, then restart the app.',
        );
      default:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDQcVhVxVj8JbDv3m8i0EBQ4zwV12B6Grs',
    authDomain: 'boundary-4b4e8.firebaseapp.com',
    projectId: 'boundary-4b4e8',
    storageBucket: 'boundary-4b4e8.firebasestorage.app',
    messagingSenderId: '636164427849',
    appId: '1:636164427849:web:d2ec68b5027b276f52ef98',
    measurementId: 'G-FS1M8TM786',
  );
}
