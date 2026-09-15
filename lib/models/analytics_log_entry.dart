// A single event in the system's ANALYTICS_LOG - written at the moments
// that matter for evaluating the gender-aware allocation algorithm (which
// zone a passenger landed in, whether the priority-reserve buffer or the
// traveling-together exemption fired, whether a group had to be split up,
// whether the bus ever hit capacity) plus safety-incident activity. Purely
// write-only from the app's side - nothing in the UI reads this back; it
// exists for offline analysis (e.g. exporting from Firestore) rather than
// as a user-facing feature.
class AnalyticsLogEntry {
  final String logId;
  final String eventType; // seat_allocated | group_booking_outcome | allocation_rejected | incident_reported
  final DateTime timestamp;
  final String? journeyId;
  final String? busId;
  final String? routeId;
  final String? zone; // priority | general | limited | standing - for allocation events
  final String? gender;
  final double? riskScore;
  final bool? priorityReserved;
  final bool? travelingTogether;
  final int? seatCount; // group size, for group_booking_outcome
  final String? seatingMode; // adjacent | individual_fallback - for group_booking_outcome
  final String? incidentType;
  final String? severityLevel;

  const AnalyticsLogEntry({
    required this.logId,
    required this.eventType,
    required this.timestamp,
    this.journeyId,
    this.busId,
    this.routeId,
    this.zone,
    this.gender,
    this.riskScore,
    this.priorityReserved,
    this.travelingTogether,
    this.seatCount,
    this.seatingMode,
    this.incidentType,
    this.severityLevel,
  });

  Map<String, dynamic> toMap() {
    return {
      'log_id': logId,
      'event_type': eventType,
      'timestamp': timestamp.toIso8601String(),
      'journey_id': journeyId,
      'bus_id': busId,
      'route_id': routeId,
      'zone': zone,
      'gender': gender,
      'risk_score': riskScore,
      'priority_reserved': priorityReserved,
      'traveling_together': travelingTogether,
      'seat_count': seatCount,
      'seating_mode': seatingMode,
      'incident_type': incidentType,
      'severity_level': severityLevel,
    };
  }
}
