import 'package:cloud_firestore/cloud_firestore.dart';

// Tells Firestore a passenger's seat is free again once they end their
// journey, so the conductor app can show the seat as empty (and offer it to a
// standing passenger). Until now ending a journey only changed local state on
// the passenger's phone.
//
// Follows the same graceful-degradation convention as every other service in
// the app: fire-and-forget, never throws into the caller, and does nothing when
// Firestore is unreachable. It uses update(), never set(), so it can only mark
// an allocation that already exists; it never creates one. 'released' is the
// status the seat_allocations schema already defines for a freed seat.
class SeatReleaseService {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  void release(String allocationId) {
    try {
      final firestore = _firestore;
      if (firestore == null) return;
      firestore
          .collection('seat_allocations')
          .doc(allocationId)
          .update({'status': 'released'})
          .catchError((_) {});
    } catch (_) {
      // Best-effort only - the journey has already ended for the passenger.
    }
  }
}
