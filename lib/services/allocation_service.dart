import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/passenger.dart';
import '../models/seat_allocation.dart';
import 'analytics_service.dart';
import 'allocation_trace_service.dart';

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
  // True when this passenger was bumped out of Priority by the reserve
  // buffer (see AllocationService._allocateOne).
  final bool priorityReserved;
  const _AllocResult(this.seatNumber, this.zone, this.riskScore, {this.priorityReserved = false});
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
  final AnalyticsService _analytics = AnalyticsService();
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

  // Kept for other cosmetic risk-score computations (e.g. the group
  // adjacent-block path) - no longer used to DECIDE which seat
  // pickBestScoredSeat returns; see the hard-filter-then-tiebreak logic
  // below instead.
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

  // True if none of [seat]'s physical neighbours are currently occupied by
  // someone of a different gender than [gender]. This is the Stage A hard
  // filter used by pickBestScoredSeat and (in a group-aware form) by
  // findAdjacentBlock.
  bool _isGenderSafeSeat(_BusSeatMap map, String seat, String gender) {
    for (final neighbor in _neighborsOf(seat)) {
      final occupant = map.seatGender[neighbor];
      if (occupant != null && occupant != gender) return false;
    }
    return true;
  }

  int _compareByRowThenLetter(String a, String b) {
    final rowCompare = _rowOfSeat(a).compareTo(_rowOfSeat(b));
    return rowCompare != 0 ? rowCompare : a.compareTo(b);
  }

  // Nearest-to-front free priority seat, gender-safety hard-filtered the
  // same way General/Limited are: among free priority seats (sorted by
  // row/letter), prefer the nearest one with no opposite-gender neighbour;
  // if every free priority seat has one, fall back to the plain nearest
  // free seat, so a priority-need passenger is never rejected outright just
  // because no gender-safe seat exists.
  //
  // [steps], if non-null, records every free seat considered - purely for
  // the optional viva-demo trace below (see AllocationTraceService).
  String? _pickNearestPrioritySeat(
    _BusSeatMap map,
    Set<String> exclude, {
    String gender = '',
    List<Map<String, dynamic>>? steps,
  }) {
    final free = map.freeSeatsIn('priority').where((s) => !exclude.contains(s)).toList();
    if (free.isEmpty) return null;
    free.sort(_compareByRowThenLetter);

    if (steps != null) {
      for (final seat in free) {
        final neighbors = _neighborsOf(seat);
        steps.add({
          'order': steps.length,
          'seat': seat,
          'zone': 'priority',
          'neighbors': neighbors,
          'neighbor_genders': {for (final n in neighbors) n: map.seatGender[n]},
          'gender_safe': _isGenderSafeSeat(map, seat, gender),
          'passenger_gender': gender,
        });
      }
    }

    final genderSafe = free.where((s) => _isGenderSafeSeat(map, s, gender)).toList();
    final candidates = genderSafe.isNotEmpty ? genderSafe : free;
    return candidates.first;
  }

  // Two-stage selection, used for both General and Limited zones:
  //   Stage A (hard filter) - keep only free seats with no opposite-gender
  //   neighbour.
  //   Stage B (soft tiebreak) - pick the lowest-row seat among survivors
  //   (alphabetical tiebreak); if nothing survives the hard filter (every
  //   free seat has an opposite-gender neighbour), fall back to the same
  //   tiebreak across every free seat in the zone, ignoring gender.
  //
  // [steps], if non-null, records every free seat considered - purely for
  // the optional viva-demo trace below (see AllocationTraceService) - and
  // never changes which seat is returned.
  String? _pickBestScoredSeat(
    _BusSeatMap map,
    String zone,
    String gender,
    Set<String> exclude, {
    List<Map<String, dynamic>>? steps,
  }) {
    final free = map.freeSeatsIn(zone).where((s) => !exclude.contains(s)).toList();
    if (free.isEmpty) return null;

    if (steps != null) {
      for (final seat in free) {
        final neighbors = _neighborsOf(seat);
        steps.add({
          'order': steps.length,
          'seat': seat,
          'zone': zone,
          'neighbors': neighbors,
          'neighbor_genders': {for (final n in neighbors) n: map.seatGender[n]},
          'gender_safe': _isGenderSafeSeat(map, seat, gender),
          'passenger_gender': gender,
        });
      }
    }

    final genderSafe = free.where((s) => _isGenderSafeSeat(map, s, gender)).toList();
    final candidates = genderSafe.isNotEmpty ? genderSafe : free;
    candidates.sort(_compareByRowThenLetter);
    return candidates.first;
  }

  // 2 or fewer free priority seats left -> reserved for passengers with a
  // real mobility need or who are pregnant; a passenger who is only
  // priority-eligible via safetyPreference is bumped to General instead
  // (flagged via priorityReserved) rather than taking one of the last
  // priority seats from someone who needs it more.
  static const int _priorityReserveThreshold = 2;

  // The core per-passenger algorithm (steps 1-5): priority (if eligible) ->
  // general -> limited -> standing -> reject. Used both for a single-seat
  // booking and as the per-passenger fallback when a group can't be seated
  // together.
  // [journeyId] is only used to label the optional viva-demo trace this
  // method fires off (see AllocationTraceService) - it plays no part in
  // which seat gets picked.
  _AllocResult _allocateOne(_BusSeatMap map, Passenger passenger, Set<String> exclude, String journeyId) {
    final steps = <Map<String, dynamic>>[];

    // Fire-and-forget, never awaited - trace logging must never delay or
    // block a real booking, and its failure (see AllocationTraceService)
    // can never surface here either.
    _AllocResult finish(_AllocResult r) {
      AllocationTraceService().writeTrace(
        journeyId: journeyId,
        passengerGender: passenger.gender,
        steps: steps,
        selectedSeat: r.seatNumber,
        selectedZone: r.zone,
      );
      return r;
    }

    var priorityReserved = false;
    if (_isPriorityEligible(passenger)) {
      final freeCount = map.freeSeatsIn('priority').where((s) => !exclude.contains(s)).length;
      final hasStrongPriorityNeed = passenger.mobilityStatus != 'none' || passenger.pregnant;
      if (freeCount <= _priorityReserveThreshold && !hasStrongPriorityNeed) {
        priorityReserved = true; // safetyPreference-only - falls through, flagged for the UI
        steps.add({
          'order': steps.length,
          'type': 'info',
          'note': 'Priority-reserve buffer: <= $_priorityReserveThreshold free priority seats left, '
              'and this passenger only qualifies via safety preference, so priority is held back and '
              'they fall through to General instead.',
        });
      } else {
        final seat = _pickNearestPrioritySeat(map, exclude, gender: passenger.gender, steps: steps);
        if (seat != null) return finish(_AllocResult(seat, 'priority', 0.05));
      }
    }

    steps.add({'order': steps.length, 'type': 'info', 'note': 'Moving to General zone.'});
    final generalSeat = _pickBestScoredSeat(map, 'general', passenger.gender, exclude, steps: steps);
    if (generalSeat != null) {
      final risk = 0.1 + (_isGenderSafeSeat(map, generalSeat, passenger.gender) ? 0.0 : 0.15);
      return finish(_AllocResult(generalSeat, 'general', risk, priorityReserved: priorityReserved));
    }

    steps.add({'order': steps.length, 'type': 'info', 'note': 'General zone full. Moving to Limited zone.'});
    final limitedSeat = _pickBestScoredSeat(map, 'limited', passenger.gender, exclude, steps: steps);
    if (limitedSeat != null) {
      final risk = 0.2 + (_isGenderSafeSeat(map, limitedSeat, passenger.gender) ? 0.0 : 0.15);
      return finish(_AllocResult(limitedSeat, 'limited', risk, priorityReserved: priorityReserved));
    }

    steps.add({'order': steps.length, 'type': 'info', 'note': 'Limited zone full. Moving to Standing.'});
    if (!map.standingFull) {
      final slot = map.standingOccupied + 1;
      final ratio = map.standingOccupied / kStandingCapacity;
      return finish(
        _AllocResult('Standing-$slot', 'standing', 0.5 + ratio * 0.3, priorityReserved: priorityReserved),
      );
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

  // Gender-safety check for a candidate group window: for each seat in the
  // window (assigned to the passenger at the same index in [genders]),
  // every neighbour must either be a fellow group member (exempted when
  // [travelingTogether]) or - for neighbours outside the window, i.e. real,
  // possibly-already-occupied seats belonging to someone else on the bus -
  // not of a different gender. The hard filter always applies to outside
  // neighbours, traveling_together or not.
  bool _windowIsGenderSafe(_BusSeatMap map, List<String> window, List<String> genders, bool travelingTogether) {
    for (var i = 0; i < window.length; i++) {
      final seat = window[i];
      final passengerGender = genders[i];
      for (final neighbor in _neighborsOf(seat)) {
        final neighborIndexInWindow = window.indexOf(neighbor);
        if (neighborIndexInWindow != -1) {
          if (travelingTogether) continue; // fellow group member - mutually exempted
          if (genders[neighborIndexInWindow] != passengerGender) return false;
        } else {
          final occupant = map.seatGender[neighbor];
          if (occupant != null && occupant != passengerGender) return false;
        }
      }
    }
    return true;
  }

  // Searches each row's contiguous blocks, in zone row order, for
  // genders.length free seats sitting next to each other - the "book a
  // group together" case.
  //   Stage A (hard filter) - among windows that fit and are entirely free,
  //   prefer one where every seat is gender-safe (see
  //   _windowIsGenderSafe); opposite-gender members of THIS SAME group are
  //   exempted from each other when [travelingTogether].
  //   Stage B (soft tiebreak) - the first (lowest-row) gender-safe window
  //   wins; if none exists anywhere in the zone, fall back to the first
  //   free window regardless of gender, so the group still gets seated
  //   together.
  // Returns null only if no free window of the right size exists at all.
  List<String>? _findAdjacentBlock(_BusSeatMap map, String zone, List<String> genders, {bool travelingTogether = false}) {
    final count = genders.length;
    final rows = zone == 'priority'
        ? _priorityRows
        : zone == 'general'
            ? _generalRows
            : [..._limitedRows, _rearBenchRow];

    List<String>? fallbackWindow;

    for (final row in rows) {
      for (final block in _rowBlocks(row)) {
        if (block.length < count) continue;
        for (var start = 0; start + count <= block.length; start++) {
          final window = block.sublist(start, start + count);
          if (!window.every((s) => map.seatGender[s] == null)) continue;

          fallbackWindow ??= window;
          if (_windowIsGenderSafe(map, window, genders, travelingTogether)) {
            return window;
          }
        }
      }
    }
    return fallbackWindow;
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
          priorityReserved: data['priority_reserved'] ?? false,
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

    final _AllocResult result;
    try {
      result = _allocateOne(map, passenger, excludeSeats, journeyId);
    } on SeatAllocationException {
      _analytics.logEvent(
        eventType: 'allocation_rejected',
        journeyId: journeyId,
        busId: busId,
        routeId: routeId,
        gender: passenger.gender,
      );
      rethrow;
    }
    _commit(map, result, passenger);
    _analytics.logEvent(
      eventType: 'seat_allocated',
      journeyId: journeyId,
      busId: busId,
      routeId: routeId,
      zone: result.zone,
      gender: passenger.gender,
      riskScore: result.riskScore,
      priorityReserved: result.priorityReserved,
    );
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

    final allEligible = passengers.every(_isPriorityEligible);
    final zoneOrder = allEligible ? const ['priority', 'general', 'limited'] : const ['general', 'limited'];
    final travelingTogetherAll = passengers.every((p) => p.travelingTogether);

    // Seat-assignment order is decided up front (gender-weighted, primary
    // first) so the adjacency search can check each candidate window
    // against the actual genders that would end up sitting in it.
    final ordered = _orderForSelection(passengers);
    final genders = ordered.map((p) => p.gender).toList();

    List<String>? block;
    String? blockZone;
    for (final zone in zoneOrder) {
      block = _findAdjacentBlock(map, zone, genders, travelingTogether: travelingTogetherAll);
      if (block != null) {
        blockZone = zone;
        break;
      }
    }

    _analytics.logEvent(
      eventType: 'group_booking_outcome',
      journeyId: journeyId,
      busId: busId,
      routeId: routeId,
      zone: blockZone,
      seatCount: passengers.length,
      seatingMode: block != null ? 'adjacent' : 'individual_fallback',
      travelingTogether: travelingTogetherAll,
    );

    final byPassenger = <Passenger, SeatAllocation>{};

    if (block != null && blockZone != null) {
      for (var i = 0; i < block.length; i++) {
        final seat = block[i];
        final p = ordered[i];
        map.occupy(seat, p.gender);
        final riskScore = blockZone == 'priority'
            ? 0.05
            : (blockZone == 'general' ? 0.1 : 0.2) + _costFor(map, seat, p.gender);
        _analytics.logEvent(
          eventType: 'seat_allocated',
          journeyId: journeyId,
          busId: busId,
          routeId: routeId,
          zone: blockZone,
          gender: p.gender,
          riskScore: riskScore,
          priorityReserved: false,
        );
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
      for (final p in ordered) {
        final _AllocResult result;
        try {
          result = _allocateOne(map, p, const {}, journeyId);
        } on SeatAllocationException {
          _analytics.logEvent(
            eventType: 'allocation_rejected',
            journeyId: journeyId,
            busId: busId,
            routeId: routeId,
            gender: p.gender,
          );
          rethrow;
        }
        _commit(map, result, p);
        _analytics.logEvent(
          eventType: 'seat_allocated',
          journeyId: journeyId,
          busId: busId,
          routeId: routeId,
          zone: result.zone,
          gender: p.gender,
          riskScore: result.riskScore,
          priorityReserved: result.priorityReserved,
        );
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
      priorityReserved: result.priorityReserved,
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
