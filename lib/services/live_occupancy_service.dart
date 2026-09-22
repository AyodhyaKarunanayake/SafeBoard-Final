import 'package:cloud_firestore/cloud_firestore.dart';
import 'allocation_service.dart';

// Zone boundaries mirror AllocationService's row layout - rows 1-3 are
// priority, 4-6 general, 7-13 limited; a "Standing-N" seat_number is
// standing. Kept in sync with allocation_service.dart, not re-derived.
String zoneOfSeatNumber(String seatNumber) {
  if (seatNumber.toUpperCase().startsWith('STANDING')) return 'standing';
  final match = RegExp(r'^(\d+)').firstMatch(seatNumber);
  final row = match != null ? int.parse(match.group(1)!) : 0;
  if (row >= 1 && row <= 3) return 'priority';
  if (row >= 4 && row <= 6) return 'general';
  return 'limited';
}

class LiveOccupancyService {
  // Live "seats left" per zone for a bus, computed from real active
  // seat_allocations documents - not a static counter - so these numbers
  // genuinely reflect real bookings as they happen.
  Stream<Map<String, int>> availableSeatsFor(String busId) {
    try {
      return FirebaseFirestore.instance
          .collection('seat_allocations')
          .where('bus_id', isEqualTo: busId)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .map((snapshot) {
        final occupied = {'priority': 0, 'general': 0, 'limited': 0, 'standing': 0};
        for (final doc in snapshot.docs) {
          final seatNumber = (doc.data()['seat_number'] ?? '') as String;
          final zone = zoneOfSeatNumber(seatNumber);
          occupied[zone] = (occupied[zone] ?? 0) + 1;
        }
        return {
          'priority': (kPriorityTotalSeats - occupied['priority']!).clamp(0, kPriorityTotalSeats),
          'general': (kGeneralTotalSeats - occupied['general']!).clamp(0, kGeneralTotalSeats),
          'limited': (kLimitedTotalSeats - occupied['limited']!).clamp(0, kLimitedTotalSeats),
          'standing': (kStandingCapacity - occupied['standing']!).clamp(0, kStandingCapacity),
        };
      });
    } catch (_) {
      // Firestore unreachable (offline/demo/test environment, same as every
      // other service in this app) - an empty stream never emits, so
      // StreamBuilder keeps snapshot.data null and callers fall back to the
      // bus's static counters, exactly as if this stream simply hadn't
      // resolved yet.
      return const Stream.empty();
    }
  }
}
