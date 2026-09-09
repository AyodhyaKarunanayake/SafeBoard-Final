class JourneyInstance {
  final String journeyId;
  final String busId;
  final String routeId;
  final String conductorId;
  final DateTime departureDatetime;
  final DateTime arrivalDatetime;
  final int currentOccupancy;
  final int standingCount;
  final String currentStop;
  final String crowdingLevel; // low, moderate, high, critical
  final String status;
  final int priorityOccupied;
  final int generalOccupied;

  JourneyInstance({
    required this.journeyId,
    required this.busId,
    required this.routeId,
    required this.conductorId,
    required this.departureDatetime,
    required this.arrivalDatetime,
    required this.currentOccupancy,
    required this.standingCount,
    required this.currentStop,
    required this.crowdingLevel,
    required this.status,
    this.priorityOccupied = 3,
    this.generalOccupied = 12,
  });

  Map<String, dynamic> toMap() {
    return {
      'journey_id': journeyId,
      'bus_id': busId,
      'route_id': routeId,
      'conductor_id': conductorId,
      'departure_datetime': departureDatetime.toIso8601String(),
      'arrival_datetime': arrivalDatetime.toIso8601String(),
      'current_occupancy': currentOccupancy,
      'standing_count': standingCount,
      'current_stop': currentStop,
      'crowding_level': crowdingLevel,
      'status': status,
      'priority_occupied': priorityOccupied,
      'general_occupied': generalOccupied,
    };
  }

  factory JourneyInstance.fromMap(Map<String, dynamic> map, String docId) {
    return JourneyInstance(
      journeyId: map['journey_id'] ?? docId,
      busId: map['bus_id'] ?? '',
      routeId: map['route_id'] ?? '',
      conductorId: map['conductor_id'] ?? '',
      departureDatetime: map['departure_datetime'] != null
          ? DateTime.parse(map['departure_datetime'])
          : DateTime.now(),
      arrivalDatetime: map['arrival_datetime'] != null
          ? DateTime.parse(map['arrival_datetime'])
          : DateTime.now().add(const Duration(hours: 2)),
      currentOccupancy: map['current_occupancy'] ?? 0,
      standingCount: map['standing_count'] ?? 0,
      currentStop: map['current_stop'] ?? 'Colombo Fort',
      crowdingLevel: map['crowding_level'] ?? 'moderate',
      status: map['status'] ?? 'in_transit',
      priorityOccupied: map['priority_occupied'] ?? 3,
      generalOccupied: map['general_occupied'] ?? 12,
    );
  }
}
