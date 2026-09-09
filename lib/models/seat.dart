class Seat {
  final String seatId;
  final String busId;
  final String seatNumber; // 1A, 1B ... 8A, 8B
  final String seatZone; // priority, general, standing
  final String seatType; // window, aisle
  final double positionX;
  final double positionY;
  final String priorityCategory;
  final String currentStatus; // available, occupied
  final String? occupiedByGender;

  Seat({
    required this.seatId,
    required this.busId,
    required this.seatNumber,
    required this.seatZone,
    required this.seatType,
    required this.positionX,
    required this.positionY,
    required this.priorityCategory,
    required this.currentStatus,
    this.occupiedByGender,
  });

  Map<String, dynamic> toMap() {
    return {
      'seat_id': seatId,
      'bus_id': busId,
      'seat_number': seatNumber,
      'seat_zone': seatZone,
      'seat_type': seatType,
      'position_x': positionX,
      'position_y': positionY,
      'priority_category': priorityCategory,
      'current_status': currentStatus,
      'occupied_by_gender': occupiedByGender,
    };
  }

  factory Seat.fromMap(Map<String, dynamic> map, String docId) {
    return Seat(
      seatId: map['seat_id'] ?? docId,
      busId: map['bus_id'] ?? '',
      seatNumber: map['seat_number'] ?? '',
      seatZone: map['seat_zone'] ?? 'general',
      seatType: map['seat_type'] ?? 'window',
      positionX: (map['position_x'] ?? 0.0).toDouble(),
      positionY: (map['position_y'] ?? 0.0).toDouble(),
      priorityCategory: map['priority_category'] ?? 'standard',
      currentStatus: map['current_status'] ?? 'available',
      occupiedByGender: map['occupied_by_gender'],
    );
  }
}
