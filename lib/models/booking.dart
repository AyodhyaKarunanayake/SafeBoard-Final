class Booking {
  final String bookingId;
  final String passengerId;
  final String routeId;
  final String busId;
  final String boardingStop;
  final String alightingStop;
  final DateTime bookingDatetime;
  final String preferredZone; // priority, general, standing
  final String status;

  Booking({
    required this.bookingId,
    required this.passengerId,
    required this.routeId,
    required this.busId,
    required this.boardingStop,
    required this.alightingStop,
    required this.bookingDatetime,
    required this.preferredZone,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'booking_id': bookingId,
      'passenger_id': passengerId,
      'route_id': routeId,
      'bus_id': busId,
      'boarding_stop': boardingStop,
      'alighting_stop': alightingStop,
      'booking_datetime': bookingDatetime.toIso8601String(),
      'preferred_zone': preferredZone,
      'status': status,
    };
  }

  factory Booking.fromMap(Map<String, dynamic> map, String docId) {
    return Booking(
      bookingId: map['booking_id'] ?? docId,
      passengerId: map['passenger_id'] ?? '',
      routeId: map['route_id'] ?? '',
      busId: map['bus_id'] ?? '',
      boardingStop: map['boarding_stop'] ?? '',
      alightingStop: map['alighting_stop'] ?? '',
      bookingDatetime: map['booking_datetime'] != null
          ? DateTime.parse(map['booking_datetime'])
          : DateTime.now(),
      preferredZone: map['preferred_zone'] ?? 'general',
      status: map['status'] ?? 'confirmed',
    );
  }
}
