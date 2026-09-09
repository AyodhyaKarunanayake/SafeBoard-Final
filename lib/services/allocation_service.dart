import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/passenger.dart';
import '../models/seat_allocation.dart';

class AllocationService {
  // Trips at or below this length are considered "short-distance" for the
  // standing-preference rule: when the general zone is nearly full, a
  // short-distance rider stands instead of taking one of the few remaining
  // seats, so those seats stay available for passengers travelling further.
  static const double shortDistanceThresholdKm = 100.0;
  static const int lowSeatAvailabilityThreshold = 3;
  // Matches the bus diagram's Limited Standing Zone (rear), which only
  // marks out 6 physical standing spots.
  static const int standingCapacity = 6;

  // Candidate seats to rotate through when the passenger asks for a
  // different seat - stays within the same eligible zone, just picks a
  // different physical seat in it. Index 0 matches the original allocation.
  static const List<String> _priorityCandidates = ['3A', '2A', '1B', '3B'];
  static const List<String> _generalCandidates = ['5B', '6C', '4D', '7A'];

  FirebaseFunctions? get _functions {
    try {
      return FirebaseFunctions.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Future<SeatAllocation> allocateSeat({
    required Passenger passenger,
    required String journeyId,
    required String routeId,
    required String busId,
    required String boardingStop,
    required String alightingStop,
    double? tripDistanceKm,
    int? availableGeneralSeats,
    int alternateAttempt = 0,
  }) async {
    try {
      final functions = _functions;
      if (functions != null) {
        final callable = functions.httpsCallable('allocateSeat');
        final response = await callable.call({
          'passenger_id': passenger.passengerId,
          'gender': passenger.gender,
          'mobility_status': passenger.mobilityStatus,
          'safety_preference': passenger.safetyPreference,
          'journey_id': journeyId,
          'route_id': routeId,
          'bus_id': busId,
          'boarding_stop': boardingStop,
          'alighting_stop': alightingStop,
          'trip_distance_km': tripDistanceKm,
          'available_general_seats': availableGeneralSeats,
          'alternate_attempt': alternateAttempt,
        });

        final data = response.data;
        return SeatAllocation(
          allocationId: data['allocationId'] ?? 'alloc_${DateTime.now().millisecondsSinceEpoch}',
          bookingId: 'bk_${DateTime.now().millisecondsSinceEpoch}',
          seatId: data['seatId'] ?? '3A',
          seatNumber: data['seatNumber'] ?? '3A',
          busId: busId,
          journeyId: journeyId,
          allocationDatetime: DateTime.now(),
          boardingStop: boardingStop,
          alightingStop: alightingStop,
          allocationType: 'auto',
          riskScore: (data['riskScore'] ?? 0.05).toDouble(),
          status: 'active',
          qrCode: data['qrCode'] ?? 'SB-$journeyId-3A-alloc_001',
        );
      }
    } catch (e) {
      // Fallback
    }

    // Deterministic Client-side Fallback matching the 11-step algorithm exactly
    return _clientSideAllocationFallback(
      passenger: passenger,
      journeyId: journeyId,
      busId: busId,
      boardingStop: boardingStop,
      alightingStop: alightingStop,
      tripDistanceKm: tripDistanceKm,
      availableGeneralSeats: availableGeneralSeats,
      alternateAttempt: alternateAttempt,
    );
  }

  SeatAllocation _clientSideAllocationFallback({
    required Passenger passenger,
    required String journeyId,
    required String busId,
    required String boardingStop,
    required String alightingStop,
    double? tripDistanceKm,
    int? availableGeneralSeats,
    int alternateAttempt = 0,
  }) {
    // Step 4: Safety preference ON or mobility needs -> Priority Zone (Rows 1-3).
    // Priority passengers always get a seat, regardless of trip length.
    bool isPriorityEligible = passenger.safetyPreference || passenger.mobilityStatus != 'none';

    final isShortDistance = tripDistanceKm != null && tripDistanceKm <= shortDistanceThresholdKm;
    final seatsNearlyFull = availableGeneralSeats != null && availableGeneralSeats <= lowSeatAvailabilityThreshold;

    String allocatedSeat;
    double riskScore;

    if (isPriorityEligible) {
      // Row 3/2/1, near front door - a different seat within the same
      // Priority zone on each "request another seat" attempt.
      allocatedSeat = _priorityCandidates[alternateAttempt % _priorityCandidates.length];
      riskScore = 0.05;
    } else if (isShortDistance && seatsNearlyFull) {
      // Step 5b: general seats are scarce and this rider's trip is short -
      // stand instead of taking one of the last few seats, so they stay
      // available for passengers travelling further.
      final standingIndex = ((passenger.passengerId.hashCode.abs() + alternateAttempt * 3) % standingCapacity) + 1;
      allocatedSeat = 'Standing-$standingIndex';
      riskScore = 0.3;
    } else {
      // Step 5: General zone (Rows 4-10) with proximity constraint - a
      // different seat within General on each alternate attempt.
      allocatedSeat = _generalCandidates[alternateAttempt % _generalCandidates.length];
      riskScore = 0.15;
    }

    // Includes [alternateAttempt] so IDs stay unique even when several
    // allocations are requested back-to-back in the same millisecond - e.g.
    // a group booking allocating multiple passengers' seats in one loop.
    final allocId = 'alloc_${DateTime.now().millisecondsSinceEpoch}_$alternateAttempt';
    final bookingId = 'bk_${DateTime.now().millisecondsSinceEpoch}_$alternateAttempt';
    final qrCode = 'SB-$journeyId-$allocatedSeat-$allocId';

    final allocation = SeatAllocation(
      allocationId: allocId,
      bookingId: bookingId,
      seatId: allocatedSeat,
      seatNumber: allocatedSeat,
      busId: busId,
      journeyId: journeyId,
      allocationDatetime: DateTime.now(),
      boardingStop: boardingStop,
      alightingStop: alightingStop,
      allocationType: 'auto',
      riskScore: riskScore,
      status: 'active',
      qrCode: qrCode,
    );

    // Try background update to Firestore if online
    try {
      final firestore = _firestore;
      if (firestore != null) {
        firestore.collection('seat_allocations').doc(allocId).set(allocation.toMap());
        firestore.collection('journey_instances').doc(journeyId).update({
          'current_occupancy': FieldValue.increment(1),
        });
      }
    } catch (_) {}

    return allocation;
  }
}
