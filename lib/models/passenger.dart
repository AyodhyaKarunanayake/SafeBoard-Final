class Passenger {
  final String passengerId;
  final String name;
  final String email;
  final String gender; // female, male, non-binary, prefer_not_to_say
  final String ageGroup;
  final String mobilityStatus; // none, wheelchair, walking_aid, elderly
  final String phoneNumber;
  final bool safetyPreference;
  // Priority-zone eligibility criterion alongside safetyPreference and
  // mobilityStatus - see AllocationService._isPriorityEligible.
  final bool pregnant;
  // Opt-in, whole-group exemption from the opposite-gender adjacency hard
  // filter for group bookings - see AllocationService.findAdjacentBlock.
  // Only meaningful when set the same on every passenger in a group.
  final bool travelingTogether;
  final DateTime createdDate;
  final DateTime updatedDate;
  // Index into the preset avatar palette (see profile_screen.dart) - stands
  // in for a real uploaded photo, since a cross-platform photo picker
  // (camera/gallery permissions on every target platform) is out of scope
  // for this simulated backend.
  final int avatarColorIndex;

  Passenger({
    required this.passengerId,
    required this.name,
    required this.email,
    required this.gender,
    required this.ageGroup,
    required this.mobilityStatus,
    required this.phoneNumber,
    required this.safetyPreference,
    required this.createdDate,
    required this.updatedDate,
    this.avatarColorIndex = 0,
    this.pregnant = false,
    this.travelingTogether = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'passenger_id': passengerId,
      'name': name,
      'email': email,
      'gender': gender,
      'age_group': ageGroup,
      'mobility_status': mobilityStatus,
      'phone_number': phoneNumber,
      'safety_preference': safetyPreference,
      'pregnant': pregnant,
      'traveling_together': travelingTogether,
      'created_date': createdDate.toIso8601String(),
      'updated_date': updatedDate.toIso8601String(),
      'avatar_color_index': avatarColorIndex,
    };
  }

  factory Passenger.fromMap(Map<String, dynamic> map, String docId) {
    return Passenger(
      passengerId: map['passenger_id'] ?? docId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      gender: map['gender'] ?? 'prefer_not_to_say',
      ageGroup: map['age_group'] ?? 'adult',
      mobilityStatus: map['mobility_status'] ?? 'none',
      phoneNumber: map['phone_number'] ?? '',
      safetyPreference: map['safety_preference'] ?? false,
      pregnant: map['pregnant'] ?? false,
      travelingTogether: map['traveling_together'] ?? false,
      createdDate: map['created_date'] != null
          ? DateTime.parse(map['created_date'])
          : DateTime.now(),
      updatedDate: map['updated_date'] != null
          ? DateTime.parse(map['updated_date'])
          : DateTime.now(),
      avatarColorIndex: map['avatar_color_index'] ?? 0,
    );
  }

  Passenger copyWith({
    String? name,
    String? email,
    String? gender,
    String? ageGroup,
    String? mobilityStatus,
    String? phoneNumber,
    bool? safetyPreference,
    bool? pregnant,
    bool? travelingTogether,
    int? avatarColorIndex,
  }) {
    return Passenger(
      passengerId: passengerId,
      name: name ?? this.name,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      ageGroup: ageGroup ?? this.ageGroup,
      mobilityStatus: mobilityStatus ?? this.mobilityStatus,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      safetyPreference: safetyPreference ?? this.safetyPreference,
      pregnant: pregnant ?? this.pregnant,
      travelingTogether: travelingTogether ?? this.travelingTogether,
      createdDate: createdDate,
      updatedDate: DateTime.now(),
      avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
    );
  }
}
