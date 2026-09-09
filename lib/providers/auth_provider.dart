import 'package:flutter/material.dart';
import '../models/passenger.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  Passenger? _passenger;
  bool _isLoading = false;

  Passenger? get passenger => _passenger ?? _authService.mockUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => passenger != null;

  AuthProvider() {
    _passenger = _authService.mockUser;
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      _passenger = await _authService.signInWithEmailAndPassword(email, password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String gender,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      _passenger = await _authService.registerUser(
        name: name,
        email: email,
        password: password,
        gender: gender,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePreferences({
    required bool safetyPreference,
    required String mobilityStatus,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.updatePreferences(
        safetyPreference: safetyPreference,
        mobilityStatus: mobilityStatus,
      );
      _passenger = _passenger?.copyWith(
        safetyPreference: safetyPreference,
        mobilityStatus: mobilityStatus,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Name, phone, mobility status and avatar are editable; email is not
  // passed here at all - it stays fixed to what the passenger signed up
  // with.
  Future<void> updateProfile({
    required String name,
    required String phoneNumber,
    required String mobilityStatus,
    required int avatarColorIndex,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.updateProfile(
        name: name,
        phoneNumber: phoneNumber,
        mobilityStatus: mobilityStatus,
        avatarColorIndex: avatarColorIndex,
      );
      _passenger = _passenger?.copyWith(
        name: name,
        phoneNumber: phoneNumber,
        mobilityStatus: mobilityStatus,
        avatarColorIndex: avatarColorIndex,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Returns null on success, or an error message to show the passenger.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      return await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _passenger = null;
    notifyListeners();
  }
}
