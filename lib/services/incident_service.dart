import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/incident_report.dart';
import 'analytics_service.dart';

class IncidentService {
  final AnalyticsService _analytics = AnalyticsService();

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> submitIncidentReport(IncidentReport report) async {
    try {
      final firestore = _firestore;
      if (firestore != null) {
        await firestore
            .collection('incident_reports')
            .doc(report.incidentId)
            .set(report.toMap());
      }
    } catch (e) {
      // Graceful offline execution
    }

    _analytics.logEvent(
      eventType: 'incident_reported',
      journeyId: report.journeyId,
      incidentType: report.incidentType,
      severityLevel: report.severityLevel,
    );
  }

  // Used by "My reports" - a passenger reviewing their own past incident
  // submissions (including SOS alerts). Empty list on any failure or when
  // offline, same graceful-degradation convention as everywhere else.
  Future<List<IncidentReport>> getIncidentsForPassenger(String passengerId) async {
    try {
      final firestore = _firestore;
      if (firestore == null) return [];
      final snapshot = await firestore
          .collection('incident_reports')
          .where('reporter_passenger_id', isEqualTo: passengerId)
          .orderBy('incident_datetime', descending: true)
          .get();
      return snapshot.docs.map((d) => IncidentReport.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      return [];
    }
  }
}
