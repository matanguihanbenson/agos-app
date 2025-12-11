import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  if (kIsWeb) {
    // Web configuration
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDxKMWW9PmoS5SOs_twuJpmvpHTuzixJl8",
        authDomain: "agos-2c752.firebaseapp.com",
        databaseURL: "https://agos-2c752-default-rtdb.asia-southeast1.firebasedatabase.app",
        projectId: "agos-2c752",
        storageBucket: "agos-2c752.firebasestorage.app",
        messagingSenderId: "928680852485",
        appId: "1:928680852485:web:96f747305077ef34c7f06c",
        measurementId: "G-ZDEP2WD4RF",
      ),
    );
  } else {
    // Mobile configuration (uses google-services.json for Android / GoogleService-Info.plist for iOS)
    await Firebase.initializeApp();
  }
  
  runApp(
    const ProviderScope(
      child: AgosApp(),
    ),
  );
}
