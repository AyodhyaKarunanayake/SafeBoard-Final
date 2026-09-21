import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Allows robust offline execution & testing without GCP credentials initialized
    debugPrint('Firebase init fallback: $e');
  }
  runApp(const SafeBoardApp());
}
