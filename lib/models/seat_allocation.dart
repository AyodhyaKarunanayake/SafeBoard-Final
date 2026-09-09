class SeatAllocation {
  final String allocationId;
  final String bookingId;
  final String seatId;
  final String seatNumber; // Added convenience
  final String busId;
  final String journeyId;
  final DateTime allocationDatetime;
  final String boardingStop;
  final String alightingStop;
  final String allocationType; // auto, manual_override
  final double riskScore; // 0.0 - 1.0
  final String status;
  final String qrCode;

  SeatAllocation({
    required this.allocationId,
    required this.bookingId,
    required this.seatId,
    required this.seatNumber,
    required this.busId,
    required this.journeyId,
    required this.allocationDatetime,
    required this.boardingStop,
    required this.alightingStop,
    required this.allocationType,
    required this.riskScore,
    required this.status,
    required this.qrCode,
  });

  // A short, human-readable booking reference (e.g. "SB-3K9F2A") a
  // conductor can note down or verify by eye - distinct from [qrCode],
  // which is only meant to be shown/scanned once the fare is paid.
  String get referenceCode {
    final code = allocationId.hashCode.abs().toRadixString(36).toUpperCase().padLeft(6, '0');
    return 'SB-${code.substring(code.length - 6)}';
  }

  Map<String, dynamic> toMap() {
    return {
      'allocation_id': allocationId,
      'booking_id': bookingId,
      'seat_id': seatId,
      'seat_number': seatNumber,
      'bus_id': busId,
      'journey_id': journeyId,
      'allocation_datetime': allocationDatetime.toIso8601String(),
      'boarding_stop': boardingStop,
      'alighting_stop': alightingStop,
      'allocation_type': allocationType,
      'risk_score': riskScore,
      'status': status,
      'qr_code': qrCode,
    };
  }

  factory SeatAllocation.fromMap(Map<String, dynamic> map, String docId) {
    return SeatAllocation(
      allocationId: map['allocation_id'] ?? docId,
      bookingId: map['booking_id'] ?? '',
      seatId: map['seat_id'] ?? '',
      seatNumber: map['seat_number'] ?? map['seat_id'] ?? '',
      busId: map['bus_id'] ?? '',
      journeyId: map['journey_id'] ?? '',
      allocationDatetime: map['allocation_datetime'] != null
          ? DateTime.parse(map['allocation_datetime'])
          : DateTime.now(),
      boardingStop: map['boarding_stop'] ?? '',
      alightingStop: map['alighting_stop'] ?? '',
      allocationType: map['allocation_type'] ?? 'auto',
      riskScore: (map['risk_score'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'active',
      qrCode: map['qr_code'] ?? '',
    );
  }
}
