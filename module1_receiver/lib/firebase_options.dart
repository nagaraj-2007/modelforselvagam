import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCVA1fqwfZPLiJrK2zrp_GdqSXTR4s2F1o',
    appId: '1:156503385797:web:a6aea4db8fdd94ef99f2ac',
    messagingSenderId: '156503385797',
    projectId: 'maptestmodul',
    authDomain: 'maptestmodul.firebaseapp.com',
    storageBucket: 'maptestmodul.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCVA1fqwfZPLiJrK2zrp_GdqSXTR4s2F1o',
    appId: '1:156503385797:android:a6aea4db8fdd94ef99f2ac',
    messagingSenderId: '156503385797',
    projectId: 'maptestmodul',
    storageBucket: 'maptestmodul.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCVA1fqwfZPLiJrK2zrp_GdqSXTR4s2F1o',
    appId: '1:156503385797:ios:a6aea4db8fdd94ef99f2ac',
    messagingSenderId: '156503385797',
    projectId: 'maptestmodul',
    storageBucket: 'maptestmodul.firebasestorage.app',
    iosBundleId: 'com.example.module1Receiver',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCVA1fqwfZPLiJrK2zrp_GdqSXTR4s2F1o',
    appId: '1:156503385797:macos:a6aea4db8fdd94ef99f2ac',
    messagingSenderId: '156503385797',
    projectId: 'maptestmodul',
    storageBucket: 'maptestmodul.firebasestorage.app',
    iosBundleId: 'com.example.module1Receiver',
  );
}