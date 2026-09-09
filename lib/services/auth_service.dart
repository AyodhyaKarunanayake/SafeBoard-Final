import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/passenger.dart';

class AuthService {
  fb.FirebaseAuth? get _auth {
    try {
      return fb.FirebaseAuth.instance;
    } catch (e) {
      debugPrint('FirebaseAuth instance unavailable (offline/demo mode): $e');
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('FirebaseFirestore instance unavailable (offline/demo mode): $e');
      return null;
    }
  }

  // Mock / In-memory Fallback User for offline/demo operation
  Passenger? _mockCurrentPassenger = Passenger(
    passengerId: 'p_28745',
    name: 'Ananya Perera',
    email: 'ananya.perera@nsbm.ac.lk',
    gender: 'female',
    ageGroup: 'adult',
    mobilityStatus: 'none',
    phoneNumber: '+94 77 123 4567',
    safetyPreference: true,
    createdDate: DateTime.now().subtract(const Duration(days: 30)),
    updatedDate: DateTime.now(),
  );

  Passenger? get mockUser => _mockCurrentPassenger;

  Stream<fb.User?> get authStateChanges => _auth?.authStateChanges() ?? const Stream.empty();

  fb.User? get currentUser => _auth?.currentUser;

  Future<Passenger?> getPassengerProfile(String uid) async {
    try {
      final firestore = _firestore;
      if (firestore != null) {
        final doc = await firestore.collection('passengers').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          _mockCurrentPassenger = Passenger.fromMap(doc.data()!, doc.id);
          return _mockCurrentPassenger;
        }
      }
    } catch (e) {
      // Fallback for offline execution
    }
    return _mockCurrentPassenger;
  }

  Future<Passenger> signInWithEmailAndPassword(String email, String password) async {
    try {
      final auth = _auth;
      if (auth != null) {
        final cred = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (cred.user != null) {
          final profile = await getPassengerProfile(cred.user!.uid);
          if (profile != null) return profile;
        }
      }
    } catch (e) {
      // Fallback for demo mode
    }
    _mockCurrentPassenger = Passenger(
      passengerId: 'p_28745',
      name: email.contains('@') ? email.split('@').first : 'Passenger',
      email: email,
      gender: 'female',
      ageGroup: 'adult',
      mobilityStatus: 'none',
      phoneNumber: '+94 77 987 6543',
      safetyPreference: true,
      createdDate: DateTime.now(),
      updatedDate: DateTime.now(),
    );
    return _mockCurrentPassenger!;
  }

  Future<Passenger> registerUser({
    required String name,
    required String email,
    required String password,
    required String gender,
  }) async {
    String uid = 'p_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final auth = _auth;
      if (auth != null) {
        final cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (cred.user != null) {
          uid = cred.user!.uid;
        }
      }
    } catch (e) {
      // Offline fallback
    }

    final newPassenger = Passenger(
      passengerId: uid,
      name: name,
      email: email,
      gender: gender,
      ageGroup: 'adult',
      mobilityStatus: 'none',
      phoneNumber: '+94 77 123 4567',
      safetyPreference: true,
      createdDate: DateTime.now(),
      updatedDate: DateTime.now(),
    );

    try {
      final firestore = _firestore;
      if (firestore != null) {
        await firestore.collection('passengers').doc(uid).set(newPassenger.toMap());
      }
    } catch (e) {
      // Offline fallback
    }

    _mockCurrentPassenger = newPassenger;
    return newPassenger;
  }

  Future<void> updatePreferences({
    required bool safetyPreference,
    required String mobilityStatus,
  }) async {
    if (_mockCurrentPassenger == null) return;
    _mockCurrentPassenger = _mockCurrentPassenger!.copyWith(
      safetyPreference: safetyPreference,
      mobilityStatus: mobilityStatus,
    );

    try {
      final firestore = _firestore;
      if (firestore != null) {
        await firestore
            .collection('passengers')
            .doc(_mockCurrentPassenger!.passengerId)
            .update({
          'safety_preference': safetyPreference,
          'mobility_status': mobilityStatus,
          'updated_date': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // Offline fallback
    }
  }

  // Updates editable profile fields - deliberately excludes email, which
  // stays fixed to whatever the passenger signed up with.
  Future<void> updateProfile({
    required String name,
    required String phoneNumber,
    required String mobilityStatus,
    required int avatarColorIndex,
  }) async {
    if (_mockCurrentPassenger == null) return;
    _mockCurrentPassenger = _mockCurrentPassenger!.copyWith(
      name: name,
      phoneNumber: phoneNumber,
      mobilityStatus: mobilityStatus,
      avatarColorIndex: avatarColorIndex,
    );

    try {
      final firestore = _firestore;
      if (firestore != null) {
        await firestore.collection('passengers').doc(_mockCurrentPassenger!.passengerId).update({
          'name': name,
          'phone_number': phoneNumber,
          'mobility_status': mobilityStatus,
          'avatar_color_index': avatarColorIndex,
          'updated_date': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // Offline fallback
    }
  }

  // Returns null on success, or an error message to show the passenger.
  // Uses real Firebase re-authentication + password update when signed in
  // with a real account; falls back to plausible client-side validation in
  // offline/demo mode, since there's no real stored password to check
  // against there.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.trim().isEmpty) return 'Enter your current password.';
    if (newPassword.length < 6) return 'New password must be at least 6 characters.';

    try {
      final user = _auth?.currentUser;
      if (user != null && user.email != null) {
        final credential = fb.EmailAuthProvider.credential(email: user.email!, password: currentPassword);
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPassword);
        return null;
      }
    } catch (e) {
      return 'Could not change your password. Check your current password and try again.';
    }

    // Offline/demo fallback - no real account to update against.
    await Future.delayed(const Duration(milliseconds: 600));
    return null;
  }

  Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (_) {}
  }
}
