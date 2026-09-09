import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Allows robust offline execution & testing without GCP credentials initialized
    debugPrint('Firebase init fallback: $e');
  }
  runApp(const SafeBoardApp());
}
