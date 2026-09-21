import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/passenger.dart';

// Thrown when Firebase Auth actively rejected a sign-in/sign-up attempt
// (wrong password, unknown account, email already registered, weak
// password, ...) - as opposed to Firebase simply being unreachable, which
// still falls back to the offline/demo path below.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

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
        return null;
      }
    } catch (e) {
      // Fallback for offline execution
    }
    return _mockCurrentPassenger;
  }

  // Throws AuthException (with a friendly message) when Firebase Auth is
  // reachable and actively rejects the credentials - wrong password,
  // unknown account, etc. Only falls back to the offline/demo passenger
  // when Firebase itself is unreachable (auth == null, or a genuine
  // network failure), so a bad password can never silently "succeed".
  Future<Passenger> signInWithEmailAndPassword(String email, String password) async {
    final auth = _auth;
    if (auth == null) return _offlineSignIn(email);

    try {
      final cred = await auth.signInWithEmailAndPassword(email: email, password: password);
      final user = cred.user;
      if (user == null) throw const AuthException('Could not sign in. Please try again.');

      final profile = await getPassengerProfile(user.uid);
      if (profile != null) return profile;

      // Credentials were valid but no Firestore profile doc exists yet
      // (e.g. it failed to write during an offline sign-up) - build one
      // now rather than treating a correctly-authenticated user as an
      // error.
      final freshProfile = Passenger(
        passengerId: user.uid,
        name: user.email?.split('@').first ?? 'Passenger',
        email: user.email ?? email,
        gender: 'prefer_not_to_say',
        ageGroup: 'adult',
        mobilityStatus: 'none',
        phoneNumber: '',
        safetyPreference: false,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
      );
      try {
        final firestore = _firestore;
        if (firestore != null) {
          await firestore.collection('passengers').doc(user.uid).set(freshProfile.toMap());
        }
      } catch (_) {}
      _mockCurrentPassenger = freshProfile;
      return freshProfile;
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') return _offlineSignIn(email);
      throw AuthException(_friendlyAuthError(e));
    }
  }

  // Throws AuthException when Firebase Auth is reachable and rejects the
  // sign-up (email already registered, weak password, invalid email, ...).
  // Only falls back to the offline/demo passenger when Firebase itself is
  // unreachable.
  Future<Passenger> registerUser({
    required String name,
    required String email,
    required String password,
    required String gender,
  }) async {
    final auth = _auth;
    if (auth == null) return _offlineRegister(name: name, email: email, gender: gender);

    String uid;
    try {
      final cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
      uid = cred.user?.uid ?? '';
      if (uid.isEmpty) throw const AuthException('Could not create your account. Please try again.');
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        return _offlineRegister(name: name, email: email, gender: gender);
      }
      throw AuthException(_friendlyAuthError(e));
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
      // Graceful offline execution - the account is real either way; the
      // Firestore profile doc will simply be missing until next sync.
    }

    _mockCurrentPassenger = newPassenger;
    return newPassenger;
  }

  Passenger _offlineSignIn(String email) {
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

  Passenger _offlineRegister({required String name, required String email, required String gender}) {
    final newPassenger = Passenger(
      passengerId: 'p_${DateTime.now().millisecondsSinceEpoch}',
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
    _mockCurrentPassenger = newPassenger;
    return newPassenger;
  }

  String _friendlyAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for that email address.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password is too weak - use at least 6 characters.';
      case 'user-not-found':
        return 'No account found for that email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
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
