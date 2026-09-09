class IncidentReport {
  final String incidentId;
  final String journeyId;
  final String reporterPassengerId;
  final String incidentType; // unwanted_contact, verbal_harassment, physical_assault, unsafe_crowding, other
  final DateTime incidentDatetime;
  final String seatLocation;
  final String severityLevel; // low, medium, high
  final String description;
  final String actionTaken;
  final String status;
  final DateTime? resolutionDate;

  IncidentReport({
    required this.incidentId,
    required this.journeyId,
    required this.reporterPassengerId,
    required this.incidentType,
    required this.incidentDatetime,
    required this.seatLocation,
    required this.severityLevel,
    required this.description,
    required this.actionTaken,
    required this.status,
    this.resolutionDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'incident_id': incidentId,
      'journey_id': journeyId,
      'reporter_passenger_id': reporterPassengerId,
      'incident_type': incidentType,
      'incident_datetime': incidentDatetime.toIso8601String(),
      'seat_location': seatLocation,
      'severity_level': severityLevel,
      'description': description,
      'action_taken': actionTaken,
      'status': status,
      'resolution_date': resolutionDate?.toIso8601String(),
    };
  }

  factory IncidentReport.fromMap(Map<String, dynamic> map, String docId) {
    return IncidentReport(
      incidentId: map['incident_id'] ?? docId,
      journeyId: map['journey_id'] ?? '',
      reporterPassengerId: map['reporter_passenger_id'] ?? '',
      incidentType: map['incident_type'] ?? 'other',
      incidentDatetime: map['incident_datetime'] != null
          ? DateTime.parse(map['incident_datetime'])
          : DateTime.now(),
      seatLocation: map['seat_location'] ?? '3A',
      severityLevel: map['severity_level'] ?? 'medium',
      description: map['description'] ?? '',
      actionTaken: map['action_taken'] ?? 'Notified Conductor',
      status: map['status'] ?? 'pending',
      resolutionDate: map['resolution_date'] != null
          ? DateTime.parse(map['resolution_date'])
          : null,
    );
  }
}
