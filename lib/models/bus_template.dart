// The persisted "BUS" entity: one recurring scheduled trip (e.g. "NB-8701
// departs 05:30 daily"), not tied to a specific calendar date. A concrete,
// bookable BusSchedule for a given date is built by combining a
// BusTemplate with that date - the same template/instance split already
// used for JourneyInstance. Persisted in the `buses` Firestore collection
// by ReferenceDataService.
class BusTemplate {
  final String busId;
  final String busNumber;
  final String routeId;
  final String busType;
  final int departureHour;
  final int departureMinute;
  final int durationMinutes;
  final String startPoint;
  final String endPoint;
  final int availablePrioritySeats;
  final int availableGeneralSeats;
  final int availableLimitedSeats;
  final int availableStanding;
  final String crowdingLevel;
  final double fareLkr;
  final String conductorId;
  final double safetyRating;

  const BusTemplate({
    required this.busId,
    required this.busNumber,
    required this.routeId,
    required this.busType,
    required this.departureHour,
    required this.departureMinute,
    required this.durationMinutes,
    required this.startPoint,
    required this.endPoint,
    required this.availablePrioritySeats,
    required this.availableGeneralSeats,
    required this.availableLimitedSeats,
    required this.availableStanding,
    required this.crowdingLevel,
    required this.fareLkr,
    required this.conductorId,
    this.safetyRating = 4.8,
  });

  Map<String, dynamic> toMap() {
    return {
      'bus_id': busId,
      'bus_number': busNumber,
      'route_id': routeId,
      'bus_type': busType,
      'departure_hour': departureHour,
      'departure_minute': departureMinute,
      'duration_minutes': durationMinutes,
      'start_point': startPoint,
      'end_point': endPoint,
      'available_priority_seats': availablePrioritySeats,
      'available_general_seats': availableGeneralSeats,
      'available_limited_seats': availableLimitedSeats,
      'available_standing': availableStanding,
      'crowding_level': crowdingLevel,
      'fare_lkr': fareLkr,
      'conductor_id': conductorId,
      'safety_rating': safetyRating,
    };
  }

  factory BusTemplate.fromMap(Map<String, dynamic> map, String docId) {
    return BusTemplate(
      busId: map['bus_id'] ?? docId,
      busNumber: map['bus_number'] ?? '',
      routeId: map['route_id'] ?? '',
      busType: map['bus_type'] ?? 'Normal',
      departureHour: map['departure_hour'] ?? 0,
      departureMinute: map['departure_minute'] ?? 0,
      durationMinutes: map['duration_minutes'] ?? 480,
      startPoint: map['start_point'] ?? '',
      endPoint: map['end_point'] ?? '',
      availablePrioritySeats: map['available_priority_seats'] ?? 0,
      availableGeneralSeats: map['available_general_seats'] ?? 0,
      availableLimitedSeats: map['available_limited_seats'] ?? 0,
      availableStanding: map['available_standing'] ?? 0,
      crowdingLevel: map['crowding_level'] ?? 'moderate',
      fareLkr: (map['fare_lkr'] as num?)?.toDouble() ?? 0.0,
      conductorId: map['conductor_id'] ?? '',
      safetyRating: (map['safety_rating'] as num?)?.toDouble() ?? 4.8,
    );
  }
}
