import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/analytics_log_entry.dart';

// Writes to the ANALYTICS_LOG collection - best-effort and fire-and-forget,
// exactly like every other Firestore write in this app (see
// AllocationService, IncidentService): never awaited by the caller, never
// throws into the calling flow, and silently does nothing if Firestore
// isn't reachable. Analytics must never be able to slow down or break the
// feature it's observing.
class AnalyticsService {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  int _counter = 0;

  void logEvent({
    required String eventType,
    String? journeyId,
    String? busId,
    String? routeId,
    String? zone,
    String? gender,
    double? riskScore,
    bool? priorityReserved,
    bool? travelingTogether,
    int? seatCount,
    String? seatingMode,
    String? incidentType,
    String? severityLevel,
  }) {
    final entry = AnalyticsLogEntry(
      logId: 'log_${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
      eventType: eventType,
      timestamp: DateTime.now(),
      journeyId: journeyId,
      busId: busId,
      routeId: routeId,
      zone: zone,
      gender: gender,
      riskScore: riskScore,
      priorityReserved: priorityReserved,
      travelingTogether: travelingTogether,
      seatCount: seatCount,
      seatingMode: seatingMode,
      incidentType: incidentType,
      severityLevel: severityLevel,
    );

    try {
      final firestore = _firestore;
      if (firestore != null) {
        firestore.collection('analytics_log').doc(entry.logId).set(entry.toMap());
      }
    } catch (_) {}
  }
}
