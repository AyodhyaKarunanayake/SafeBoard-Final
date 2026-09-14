import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/passenger.dart';
import '../models/seat_allocation.dart';

// Thrown when a bus's 64 seats AND its 6 standing spots are all taken.
class SeatAllocationException implements Exception {
  final String message;
  const SeatAllocationException(this.message);
  @override
  String toString() => message;
}

// ── Route 87's physical seat map ─────────────────────────────────────────
// (Kept in sync with lib/widgets/bus_diagram.dart, which renders this same
// structure.)
//   PRIORITY zone - rows 1-3, 5 seats/row (A,B left block / C,D,E right
//                   block)                                          = 15
//   GENERAL zone  - rows 4-6, same layout                           = 15
//   LIMITED zone  - rows 7-11 same layout (25) + row 12, a right-only
//                   3-seat row (C,D,E) beside the rear door, since the
//                   left side is taken up by the door itself (3) + row
//                   13, a 6-seat rear bench A-F with no left/right
//                   split (6)                                       = 34
//   STANDING      - a hard cap of 6, entirely separate from the 64 seats
//                   above - not tied to any row.
const int kPriorityTotalSeats = 15;
const int kGeneralTotalSeats = 15;
const int kLimitedTotalSeats = 34;
const int kStandingCapacity = 6;

const List<int> _priorityRows = [1, 2, 3];
const List<int> _generalRows = [4, 5, 6];
const List<int> _limitedRows = [7, 8, 9, 10, 11, 12]; // + row 13 (the rear bench)
const int _extraRightRow = 12;
const int _rearBenchRow = 13;

// One row's seats in physical left-to-right order, split into the blocks
// that are contiguous ("sit together") groups. Rows 1-11 have an aisle
// between the 2-seat left block and the 3-seat right block, so a left seat
// is never "adjacent" to a right seat; row 12 is right-only (no left pair
// - the rear door takes that space); row 13 is one unbroken 6-seat bench.
List<List<String>> _rowBlocks(int row) {
  if (row == _rearBenchRow) {
    return [
      ['${row}A', '${row}B', '${row}C', '${row}D', '${row}E', '${row}F'],
    ];
  }
  if (row == _extraRightRow) {
    return [
      ['${row}C', '${row}D', '${row}E'],
    ];
  }
  return [
    ['${row}A', '${row}B'],
    ['${row}C', '${row}D', '${row}E'],
  ];
}

List<String> _allSeatsInZone(String zone) {
  switch (zone) {
    case 'priority':
      return [for (final r in _priorityRows) ..._rowBlocks(r).expand((b) => b)];
    case 'general':
      return [for (final r in _generalRows) ..._rowBlocks(r).expand((b) => b)];
    case 'limited':
      return [
        for (final r in _limitedRows) ..._rowBlocks(r).expand((b) => b),
        ..._rowBlocks(_rearBenchRow).expand((b) => b),
      ];
    default:
      return const [];
  }
}

int _rowOfSeat(String seatNumber) =>
    int.parse(RegExp(r'^(\d+)').firstMatch(seatNumber)!.group(1)!);

List<String> _neighborsOf(String seat) {
  final row = _rowOfSeat(seat);
  for (final block in _rowBlocks(row)) {
    final idx = block.indexOf(seat);
    if (idx == -1) continue;
    final neighbors = <String>[];
    if (idx > 0) neighbors.add(block[idx - 1]);
    if (idx < block.length - 1) neighbors.add(block[idx + 1]);
    return neighbors;
  }
  return const [];
}

// One result from the allocation engine, before it's turned into a full
// SeatAllocation record (QR code, booking id, etc).
class _AllocResult {
  final String seatNumber;
  final String zone; // priority | general | limited | standing
  final double riskScore;
  const _AllocResult(this.seatNumber, this.zone, this.riskScore);
}

// Per-bus seat occupancy, held in memory for the app session (this is a
// simulated backend with no live Firestore data) - keyed by busId so two
// different scheduled buses never share seats. Seeded from that bus's
// "available seats" counters so cost-scoring and zone-full checks have
// realistic neighbours to react to from the moment the map is created.
class _BusSeatMap {
  final Map<String, String?> seatGender = {}; // seatNumber -> occupying gender, or null if free
  int standingOccupied = 0;

  _BusSeatMap.seeded({
    required int priorityOccupied,
    required int generalOccupied,
    required int limitedOccupied,
    required int standingOccupied,
  }) {
    for (final seat in _allSeatsInZone('priority')) {
      seatGender[seat] = null;
    }
    for (final seat in _allSeatsInZone('general')) {
      seatGender[seat] = null;
    }
    for (final seat in _allSeatsInZone('limited')) {
      seatGender[seat] = null;
    }
    this.standingOccupied = standingOccupied.clamp(0, kStandingCapacity);
    _seedZone('priority', priorityOccupied);
    _seedZone('general', generalOccupied);
    _seedZone('limited', limitedOccupied);
  }

  // Deterministic alternating-gender fill (not random) so allocation stays
  // reproducible/testable, while still giving the cost-scoring function
  // real opposite-gender neighbours to weigh.
  void _seedZone(String zone, int occupiedCount) {
    final seats = _allSeatsInZone(zone);
    final n = occupiedCount.clamp(0, seats.length);
    for (var i = 0; i < n; i++) {
      seatGender[seats[i]] = i.isEven ? 'male' : 'female';
    }
  }

  List<String> freeSeatsIn(String zone) =>
      _allSeatsInZone(zone).where((s) => seatGender[s] == null).toList();

  bool get standingFull => standingOccupied >= kStandingCapacity;

  void occupy(String seat, String gender) => seatGender[seat] = gender;

  // Frees a seat, or (for a "Standing-N" label) decrements the standing
  // headcount - used when a passenger is offered a different suggestion and
  // their previous, never-booked pick shouldn't keep counting against the
  // pool.
  void release(String seatOrStanding) {
    if (seatOrStanding.toUpperCase().startsWith('STANDING')) {
      if (standingOccupied > 0) standingOccupied--;
      return;
    }
    if (seatGender.containsKey(seatOrStanding)) seatGender[seatOrStanding] = null;
  }
}

class AllocationService {
  // How strongly an opposite-gender neighbour counts against a candidate
  // seat - mirrors the weight_factor the old Firestore-backed rules engine
  // used to read from `allocation_rules`.
  static const double _proximityWeight = 0.5;

  final Map<String, _BusSeatMap> _seatMaps = {};
  int _idCounter = 0;

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

  bool _isPriorityEligible(Passenger p) =>
      p.safetyPreference || p.mobilityStatus != 'none' || p.pregnant;

  _BusSeatMap _mapFor(
    String busId, {
    int? availablePrioritySeats,
    int? availableGeneralSeats,
    int? availableLimitedSeats,
    int? availableStanding,
  }) {
    return _seatMaps.putIfAbsent(
      busId,
      () => _BusSeatMap.seeded(
        priorityOccupied: kPriorityTotalSeats -
            (availablePrioritySeats ?? kPriorityTotalSeats).clamp(0, kPriorityTotalSeats),
        generalOccupied: kGeneralTotalSeats -
            (availableGeneralSeats ?? kGeneralTotalSeats).clamp(0, kGeneralTotalSeats),
        limitedOccupied: kLimitedTotalSeats -
            (availableLimitedSeats ?? kLimitedTotalSeats).clamp(0, kLimitedTotalSeats),
        standingOccupied:
            kStandingCapacity - (availableStanding ?? kStandingCapacity).clamp(0, kStandingCapacity),
      ),
    );
  }

  double _costFor(_BusSeatMap map, String seat, String passengerGender) {
    double cost = _rowOfSeat(seat) * 0.02;
    for (final neighbor in _neighborsOf(seat)) {
      final occupant = map.seatGender[neighbor];
      if (occupant != null && occupant != passengerGender) {
        cost += 0.2 * _proximityWeight;
      }
    }
    return cost;
  }

  // Nearest-to-front free priority seat - no cost-scoring, priority
  // passengers always get the closest available seat to the front door.
  String? _pickNearestPrioritySeat(_BusSeatMap map, Set<String> exclude) {
    final free = map.freeSeatsIn('priority').where((s) => !exclude.contains(s)).toList();
    if (free.isEmpty) return null;
    free.sort((a, b) {
      final rowCompare = _rowOfSeat(a).compareTo(_rowOfSeat(b));
      return rowCompare != 0 ? rowCompare : a.compareTo(b);
    });
    return free.first;
  }

  // Lowest opposite-gender-proximity cost, tie-broken deterministically -
  // used for both General and Limited zones.
  String? _pickBestScoredSeat(_BusSeatMap map, String zone, String gender, Set<String> exclude) {
    final free = map.freeSeatsIn(zone).where((s) => !exclude.contains(s)).toList();
    if (free.isEmpty) return null;
    free.sort((a, b) {
      final costCompare = _costFor(map, a, gender).compareTo(_costFor(map, b, gender));
      return costCompare != 0 ? costCompare : a.compareTo(b);
    });
    return free.first;
  }

  // The core per-passenger algorithm (steps 1-5): priority (if eligible) ->
  // general -> limited -> standing -> reject. Used both for a single-seat
  // booking and as the per-passenger fallback when a group can't be seated
  // together.
  _AllocResult _allocateOne(_BusSeatMap map, Passenger passenger, Set<String> exclude) {
    if (_isPriorityEligible(passenger)) {
      final seat = _pickNearestPrioritySeat(map, exclude);
      if (seat != null) return _AllocResult(seat, 'priority', 0.05);
    }

    final generalSeat = _pickBestScoredSeat(map, 'general', passenger.gender, exclude);
    if (generalSeat != null) {
      return _AllocResult(generalSeat, 'general', 0.1 + _costFor(map, generalSeat, passenger.gender));
    }

    final limitedSeat = _pickBestScoredSeat(map, 'limited', passenger.gender, exclude);
    if (limitedSeat != null) {
      return _AllocResult(limitedSeat, 'limited', 0.2 + _costFor(map, limitedSeat, passenger.gender));
    }

    if (!map.standingFull) {
      final slot = map.standingOccupied + 1;
      final ratio = map.standingOccupied / kStandingCapacity;
      return _AllocResult('Standing-$slot', 'standing', 0.5 + ratio * 0.3);
    }

    throw const SeatAllocationException(
      'This bus is at capacity - every seat and standing spot is taken.',
    );
  }

  void _commit(_BusSeatMap map, _AllocResult result, Passenger passenger) {
    if (result.zone == 'standing') {
      map.standingOccupied++;
    } else {
      map.occupy(result.seatNumber, passenger.gender);
    }
  }

  // Searches each row's contiguous blocks, in zone row order, for [count]
  // free seats sitting next to each other - the "book a group together"
  // case. Returns null if no single block in the zone can fit the whole
  // group (this never searches across rows or across the aisle).
  List<String>? _findAdjacentBlock(_BusSeatMap map, String zone, int count) {
    final rows = zone == 'priority'
        ? _priorityRows
        : zone == 'general'
            ? _generalRows
            : [..._limitedRows, _rearBenchRow];

    for (final row in rows) {
      for (final block in _rowBlocks(row)) {
        if (block.length < count) continue;
        for (var start = 0; start + count <= block.length; start++) {
          final window = block.sublist(start, start + count);
          if (window.every((s) => map.seatGender[s] == null)) {
            return window;
          }
        }
      }
    }
    return null;
  }

  // Primary passenger keeps first pick (it's their own booking); among the
  // rest, priority-eligible female companions are weighted ahead of other
  // priority-eligible companions, who in turn go ahead of non-eligible
  // ones - so when a scarce priority/adjacent seat can't fit everyone, an
  // eligible female companion is the one seated first.
  List<Passenger> _orderForSelection(List<Passenger> passengers) {
    if (passengers.length <= 1) return passengers;
    final primary = passengers.first;
    final rest = passengers.skip(1).toList();
    rest.sort((a, b) {
      final aEligible = _isPriorityEligible(a);
      final bEligible = _isPriorityEligible(b);
      final aFemaleEligible = aEligible && a.gender == 'female';
      final bFemaleEligible = bEligible && b.gender == 'female';
      if (aFemaleEligible != bFemaleEligible) return aFemaleEligible ? -1 : 1;
      if (aEligible != bEligible) return aEligible ? -1 : 1;
      return 0;
    });
    return [primary, ...rest];
  }

  // Frees a previously-suggested (never booked) seat, so "request another
  // seat" browsing doesn't permanently shrink the pool.
  void releaseSeat({required String busId, required String seatNumber}) {
    _seatMaps[busId]?.release(seatNumber);
  }

  Future<SeatAllocation> allocateSeat({
    required Passenger passenger,
    required String journeyId,
    required String routeId,
    required String busId,
    required String boardingStop,
    required String alightingStop,
    int? availablePrioritySeats,
    int? availableGeneralSeats,
    int? availableLimitedSeats,
    int? availableStanding,
    Set<String> excludeSeats = const {},
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
          'pregnant': passenger.pregnant,
          'journey_id': journeyId,
          'route_id': routeId,
          'bus_id': busId,
          'boarding_stop': boardingStop,
          'alighting_stop': alightingStop,
          'seat_count': 1,
        });

        final data = response.data;
        return SeatAllocation(
          allocationId: data['allocationId'] ?? 'alloc_${DateTime.now().millisecondsSinceEpoch}',
          bookingId: 'bk_${DateTime.now().millisecondsSinceEpoch}',
          seatId: data['seatId'] ?? '1A',
          seatNumber: data['seatNumber'] ?? '1A',
          busId: busId,
          journeyId: journeyId,
          allocationDatetime: DateTime.now(),
          boardingStop: boardingStop,
          alightingStop: alightingStop,
          allocationType: 'auto',
          riskScore: (data['riskScore'] ?? 0.05).toDouble(),
          status: 'active',
          qrCode: data['qrCode'] ?? 'SB-$journeyId-1A-alloc_001',
        );
      }
    } catch (_) {
      // Fall through to the deterministic client-side engine below.
    }

    final map = _mapFor(
      busId,
      availablePrioritySeats: availablePrioritySeats,
      availableGeneralSeats: availableGeneralSeats,
      availableLimitedSeats: availableLimitedSeats,
      availableStanding: availableStanding,
    );
    final result = _allocateOne(map, passenger, excludeSeats);
    _commit(map, result, passenger);
    return _buildAllocation(result, busId, journeyId, boardingStop, alightingStop);
  }

  // Multi-seat ("seat_count > 1") booking: tries to seat the whole group
  // together in one zone first (priority only if every passenger is
  // eligible, otherwise starting at general, then limited); if no zone has
  // a large-enough contiguous block, falls back to allocating everyone
  // individually through the normal per-passenger steps 1-5, so the
  // request never fails outright just because the group can't sit as one
  // block.
  Future<List<SeatAllocation>> allocateGroup({
    required List<Passenger> passengers,
    required String journeyId,
    required String routeId,
    required String busId,
    required String boardingStop,
    required String alightingStop,
    int? availablePrioritySeats,
    int? availableGeneralSeats,
    int? availableLimitedSeats,
    int? availableStanding,
  }) async {
    final map = _mapFor(
      busId,
      availablePrioritySeats: availablePrioritySeats,
      availableGeneralSeats: availableGeneralSeats,
      availableLimitedSeats: availableLimitedSeats,
      availableStanding: availableStanding,
    );

    final count = passengers.length;
    final allEligible = passengers.every(_isPriorityEligible);
    final zoneOrder = allEligible ? const ['priority', 'general', 'limited'] : const ['general', 'limited'];

    List<String>? block;
    String? blockZone;
    for (final zone in zoneOrder) {
      block = _findAdjacentBlock(map, zone, count);
      if (block != null) {
        blockZone = zone;
        break;
      }
    }

    final byPassenger = <Passenger, SeatAllocation>{};

    if (block != null && blockZone != null) {
      final ordered = _orderForSelection(passengers);
      for (var i = 0; i < block.length; i++) {
        final seat = block[i];
        final p = ordered[i];
        map.occupy(seat, p.gender);
        final riskScore = blockZone == 'priority'
            ? 0.05
            : (blockZone == 'general' ? 0.1 : 0.2) + _costFor(map, seat, p.gender);
        byPassenger[p] = _buildAllocation(
          _AllocResult(seat, blockZone, riskScore),
          busId,
          journeyId,
          boardingStop,
          alightingStop,
        );
      }
    } else {
      // Couldn't seat the group together in any single zone - fall back to
      // the normal individual allocation logic for each passenger, still
      // sharing one seat map so nobody collides.
      final ordered = _orderForSelection(passengers);
      for (final p in ordered) {
        final result = _allocateOne(map, p, const {});
        _commit(map, result, p);
        byPassenger[p] = _buildAllocation(result, busId, journeyId, boardingStop, alightingStop);
      }
    }

    // Always return in the original (primary-first) passenger order,
    // regardless of the gender-weighted order seats were assigned in.
    return passengers.map((p) => byPassenger[p]!).toList();
  }

  SeatAllocation _buildAllocation(
    _AllocResult result,
    String busId,
    String journeyId,
    String boardingStop,
    String alightingStop,
  ) {
    // A monotonic counter (not just a timestamp) guarantees unique ids even
    // when several allocations happen back-to-back in the same
    // millisecond - e.g. a group booking allocating multiple seats in a
    // tight synchronous loop.
    final suffix = '${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';
    final allocId = 'alloc_$suffix';
    final bookingId = 'bk_$suffix';
    final qrCode = 'SB-$journeyId-${result.seatNumber}-$allocId';

    final allocation = SeatAllocation(
      allocationId: allocId,
      bookingId: bookingId,
      seatId: result.seatNumber,
      seatNumber: result.seatNumber,
      busId: busId,
      journeyId: journeyId,
      allocationDatetime: DateTime.now(),
      boardingStop: boardingStop,
      alightingStop: alightingStop,
      allocationType: 'auto',
      riskScore: result.riskScore,
      status: 'active',
      qrCode: qrCode,
    );

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
