// File generated for FlutterFire.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAebiUPE9OyxhrHjanHy98ZXeVBJm0FRvA',
    appId: '1:658020179072:web:0a4c35518737e826d2da65',
    messagingSenderId: '658020179072',
    projectId: 'tomartv-67cda',
    authDomain: 'tomartv-67cda.firebaseapp.com',
    storageBucket: 'tomartv-67cda.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAebiUPE9OyxhrHjanHy98ZXeVBJm0FRvA',
    appId: '1:658020179072:android:0a4c35518737e826d2da65',
    messagingSenderId: '658020179072',
    projectId: 'tomartv-67cda',
    storageBucket: 'tomartv-67cda.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAebiUPE9OyxhrHjanHy98ZXeVBJm0FRvA',
    appId: '1:658020179072:ios:0a4c35518737e826d2da65',
    messagingSenderId: '658020179072',
    projectId: 'tomartv-67cda',
    storageBucket: 'tomartv-67cda.firebasestorage.app',
    iosBundleId: 'com.birdev.tomarTv',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAebiUPE9OyxhrHjanHy98ZXeVBJm0FRvA',
    appId: '1:658020179072:ios:0a4c35518737e826d2da65',
    messagingSenderId: '658020179072',
    projectId: 'tomartv-67cda',
    storageBucket: 'tomartv-67cda.firebasestorage.app',
    iosBundleId: 'com.birdev.tomarTv',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAebiUPE9OyxhrHjanHy98ZXeVBJm0FRvA',
    appId: '1:658020179072:web:0a4c35518737e826d2da65',
    messagingSenderId: '658020179072',
    projectId: 'tomartv-67cda',
    authDomain: 'tomartv-67cda.firebaseapp.com',
    storageBucket: 'tomartv-67cda.firebasestorage.app',
  );
}
