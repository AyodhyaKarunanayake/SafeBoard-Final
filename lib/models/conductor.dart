// A bus conductor - the staff member assigned to a scheduled trip
// (BusTemplate.conductorId / BusSchedule.conductorId / JourneyInstance
// .conductorId all reference this entity). Persisted in the `conductors`
// Firestore collection by ReferenceDataService.
class Conductor {
  final String conductorId;
  final String name;
  final String phoneNumber;
  final double rating;

  const Conductor({
    required this.conductorId,
    required this.name,
    this.phoneNumber = '',
    this.rating = 4.8,
  });

  Map<String, dynamic> toMap() {
    return {
      'conductor_id': conductorId,
      'name': name,
      'phone_number': phoneNumber,
      'rating': rating,
    };
  }

  factory Conductor.fromMap(Map<String, dynamic> map, String docId) {
    return Conductor(
      conductorId: map['conductor_id'] ?? docId,
      name: map['name'] ?? '',
      phoneNumber: map['phone_number'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 4.8,
    );
  }
}
