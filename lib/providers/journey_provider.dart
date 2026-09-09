import 'package:flutter/material.dart';
import '../models/journey_instance.dart';
import '../models/seat_allocation.dart';
import '../models/incident_report.dart';
import '../services/incident_service.dart';

class JourneyProvider with ChangeNotifier {
  final IncidentService _incidentService = IncidentService();

  SeatAllocation? _currentAllocation;
  JourneyInstance? _activeJourney;

  // Real-time simulated / Firestore state
  int _currentOccupancy = 27; // Total occupied out of 42
  int _standingCount = 4; // Standing out of 18
  final int _priorityOccupied = 3;
  final int _generalOccupied = 20;
  final String _currentStop = 'N Colombo Fort';
  String _crowdingLevel = 'moderate';
  bool _isJourneyActive = false;

  SeatAllocation? get currentAllocation => _currentAllocation;
  JourneyInstance? get activeJourney => _activeJourney;
  int get currentOccupancy => _currentOccupancy;
  int get standingCount => _standingCount;
  int get priorityOccupied => _priorityOccupied;
  int get generalOccupied => _generalOccupied;
  String get currentStop => _currentStop;
  String get crowdingLevel => _crowdingLevel;
  bool get isJourneyActive => _isJourneyActive;

  JourneyProvider();  // Fresh state — no journey or allocation until user books

  void setCurrentAllocation(SeatAllocation allocation) {
    _currentAllocation = allocation;
    _isJourneyActive = true;
    notifyListeners();
  }

  void updateOccupancy(int newOccupancy, int newStanding) {
    _currentOccupancy = newOccupancy;
    _standingCount = newStanding;
    if (_currentOccupancy > 40) {
      _crowdingLevel = 'critical';
    } else if (_currentOccupancy > 35) {
      _crowdingLevel = 'high';
    } else {
      _crowdingLevel = 'moderate';
    }
    notifyListeners();
  }

  Future<void> submitIncident(IncidentReport report) async {
    await _incidentService.submitIncidentReport(report);
  }

  // Builds and files an SOS report after the passenger confirms on the SOS
  // button's quick Yes/Cancel dialog. The conductor is notified (simulated
  // here as a Firestore write, like the full incident form) and the button
  // itself shows the passenger a brief "Alert sent" confirmation once this
  // completes.
  Future<void> triggerSOS({
    required String passengerId,
    required String journeyId,
    required String seatLocation,
  }) async {
    final report = IncidentReport(
      incidentId: 'SOS_${DateTime.now().millisecondsSinceEpoch}',
      journeyId: journeyId,
      reporterPassengerId: passengerId,
      incidentType: 'unwanted_contact',
      incidentDatetime: DateTime.now(),
      seatLocation: seatLocation,
      severityLevel: 'high',
      description: 'SOS triggered by passenger from the Journey tab.',
      actionTaken: 'Conductor notified via FCM · seat and GPS point attached',
      status: 'escalated',
    );
    await submitIncident(report);
  }

  Future<List<IncidentReport>> getMyIncidents(String passengerId) {
    return _incidentService.getIncidentsForPassenger(passengerId);
  }

  void endJourney() {
    _isJourneyActive = false;
    notifyListeners();
  }
}
