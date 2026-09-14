import 'package:flutter_test/flutter_test.dart';
import 'package:safeboard/models/passenger.dart';
import 'package:safeboard/services/allocation_service.dart';

Passenger _passenger({
  required String id,
  String gender = 'female',
  String mobilityStatus = 'none',
  bool safetyPreference = false,
  bool pregnant = false,
  bool travelingTogether = false,
}) {
  final now = DateTime.now();
  return Passenger(
    passengerId: id,
    name: 'Test $id',
    email: '$id@test.lk',
    gender: gender,
    ageGroup: 'adult',
    mobilityStatus: mobilityStatus,
    phoneNumber: '+94 77 000 0000',
    safetyPreference: safetyPreference,
    pregnant: pregnant,
    travelingTogether: travelingTogether,
    createdDate: now,
    updatedDate: now,
  );
}

Future<dynamic> _allocate(
  AllocationService service,
  Passenger passenger, {
  required String busId,
  int? availablePrioritySeats,
  int? availableGeneralSeats,
  int? availableLimitedSeats,
  int? availableStanding,
}) {
  return service.allocateSeat(
    passenger: passenger,
    journeyId: 'JRN_TEST',
    routeId: 'R_87',
    busId: busId,
    boardingStop: 'Colombo (Pettah)',
    alightingStop: 'Jaffna Main Bus Stand',
    availablePrioritySeats: availablePrioritySeats,
    availableGeneralSeats: availableGeneralSeats,
    availableLimitedSeats: availableLimitedSeats,
    availableStanding: availableStanding,
  );
}

int _rowOf(String seatNumber) => int.parse(RegExp(r'^(\d+)').firstMatch(seatNumber)!.group(1)!);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Allocation Engine Logic Tests for Route 87', () {
    test('Seat map totals are exactly 15 priority + 15 general + 34 limited = 64 seats, plus a 6-cap standing', () {
      expect(kPriorityTotalSeats, 15);
      expect(kGeneralTotalSeats, 15);
      expect(kLimitedTotalSeats, 34);
      expect(kPriorityTotalSeats + kGeneralTotalSeats + kLimitedTotalSeats, 64);
      expect(kStandingCapacity, 6);
    });

    test('Passenger with safetyPreference = true is allocated to the nearest free Priority seat (Row 1-3)', () async {
      final service = AllocationService();
      final passenger = _passenger(id: 'p1', safetyPreference: true);

      final allocation = await _allocate(service, passenger, busId: 'BUS_TEST_1');

      expect(_rowOf(allocation.seatNumber), lessThanOrEqualTo(3));
      expect(allocation.seatNumber, equals('1A'), reason: 'nearest-to-front free priority seat on an empty bus');
      expect(allocation.riskScore, equals(0.05));
      expect(allocation.qrCode.startsWith('SB-JRN_TEST-1A'), isTrue);
    });

    test('Passenger with mobilityStatus != none is allocated to Priority Zone', () async {
      final service = AllocationService();
      final passenger = _passenger(id: 'p2', gender: 'male', mobilityStatus: 'wheelchair');

      final allocation = await _allocate(service, passenger, busId: 'BUS_TEST_2');

      expect(_rowOf(allocation.seatNumber), lessThanOrEqualTo(3));
      expect(allocation.riskScore, equals(0.05));
    });

    test('Pregnant passenger is allocated to Priority Zone', () async {
      final service = AllocationService();
      final passenger = _passenger(id: 'p3', pregnant: true);

      final allocation = await _allocate(service, passenger, busId: 'BUS_TEST_3');

      expect(_rowOf(allocation.seatNumber), lessThanOrEqualTo(3));
      expect(allocation.riskScore, equals(0.05));
    });

    test('A non-eligible passenger is allocated to General Zone (Row 4-6), not Priority', () async {
      final service = AllocationService();
      final passenger = _passenger(id: 'p4');

      final allocation = await _allocate(service, passenger, busId: 'BUS_TEST_4');

      final row = _rowOf(allocation.seatNumber);
      expect(row, inInclusiveRange(4, 6));
      expect(allocation.seatNumber, equals('4A'), reason: 'lowest-cost free general seat on an empty bus is the first one');
    });

    test('Eligible passenger falls through to General when Priority zone is completely full', () async {
      final service = AllocationService();
      final passenger = _passenger(id: 'p5', safetyPreference: true);

      final allocation = await _allocate(service, passenger, busId: 'BUS_TEST_5', availablePrioritySeats: 0);

      final row = _rowOf(allocation.seatNumber);
      expect(row, inInclusiveRange(4, 6), reason: 'priority was full, so this eligible passenger should land in general');
    });

    test('Non-eligible passenger falls through to Limited (Row 7-12) when General zone is completely full', () async {
      final service = AllocationService();
      final passenger = _passenger(id: 'p6');

      final allocation = await _allocate(service, passenger, busId: 'BUS_TEST_6', availableGeneralSeats: 0);

      final row = _rowOf(allocation.seatNumber);
      expect(row, inInclusiveRange(7, 13));
    });

    test('Passenger is allocated Standing only once Priority, General AND Limited are all full', () async {
      final service = AllocationService();
      final passenger = _passenger(id: 'p7');

      final allocation = await _allocate(
        service,
        passenger,
        busId: 'BUS_TEST_7',
        availablePrioritySeats: 0,
        availableGeneralSeats: 0,
        availableLimitedSeats: 0,
      );

      expect(allocation.seatNumber, equals('Standing-1'));
      expect(allocation.riskScore, greaterThanOrEqualTo(0.5));
    });

    test('Allocation is rejected once every seat AND all 6 standing spots are full ("bus at capacity")', () async {
      final service = AllocationService();
      final passenger = _passenger(id: 'p8');

      expect(
        () => _allocate(
          service,
          passenger,
          busId: 'BUS_TEST_8',
          availablePrioritySeats: 0,
          availableGeneralSeats: 0,
          availableLimitedSeats: 0,
          availableStanding: 0,
        ),
        throwsA(isA<SeatAllocationException>()),
      );
    });

    test('Opposite-gender cost-scoring steers a passenger away from a seat next to a different gender when an equal-cost seat is free', () async {
      final service = AllocationService();
      const busId = 'BUS_TEST_9';

      // Seat the first female into 4A (the first free general seat).
      final first = await _allocate(service, _passenger(id: 'p9a', gender: 'female'), busId: busId);
      expect(first.seatNumber, equals('4A'));

      // A male passenger next: 4B (4A's only neighbour) carries an
      // opposite-gender penalty that 4C/4D/4E don't, so he should NOT be
      // seated directly next to her when a same-cost alternative exists.
      final second = await _allocate(service, _passenger(id: 'p9b', gender: 'male'), busId: busId);
      expect(second.seatNumber, isNot(equals('4B')));
      expect(_rowOf(second.seatNumber), equals(4));
    });

    test('A 2-seat group where both passengers are priority-eligible is seated adjacently in Priority (1A & 1B)', () async {
      final service = AllocationService();
      final passengers = [
        _passenger(id: 'g1a', gender: 'female', safetyPreference: true),
        _passenger(id: 'g1b', gender: 'male', safetyPreference: true),
      ];

      final results = await service.allocateGroup(
        passengers: passengers,
        journeyId: 'JRN_TEST',
        routeId: 'R_87',
        busId: 'BUS_TEST_10',
        boardingStop: 'Colombo (Pettah)',
        alightingStop: 'Jaffna Main Bus Stand',
      );

      final seats = results.map((r) => r.seatNumber).toSet();
      expect(seats, equals({'1A', '1B'}));
    });

    test('A 2-seat group with no priority need is seated adjacently in General (not Priority) when not everyone is eligible', () async {
      final service = AllocationService();
      final passengers = [
        _passenger(id: 'g2a', gender: 'male'),
        _passenger(id: 'g2b', gender: 'female'),
      ];

      final results = await service.allocateGroup(
        passengers: passengers,
        journeyId: 'JRN_TEST',
        routeId: 'R_87',
        busId: 'BUS_TEST_11',
        boardingStop: 'Colombo (Pettah)',
        alightingStop: 'Jaffna Main Bus Stand',
      );

      final seats = results.map((r) => r.seatNumber).toSet();
      expect(seats, equals({'4A', '4B'}));
    });

    test('A group too large for any single contiguous block falls back to individual allocation (no duplicate seats, request still succeeds)', () async {
      final service = AllocationService();
      final passengers = List.generate(
        7,
        (i) => _passenger(id: 'g3_$i', gender: i.isEven ? 'male' : 'female'),
      );

      final results = await service.allocateGroup(
        passengers: passengers,
        journeyId: 'JRN_TEST',
        routeId: 'R_87',
        busId: 'BUS_TEST_12',
        boardingStop: 'Colombo (Pettah)',
        alightingStop: 'Jaffna Main Bus Stand',
      );

      expect(results.length, 7);
      final seats = results.map((r) => r.seatNumber).toSet();
      expect(seats.length, 7, reason: 'every passenger must get their own distinct seat');
    });

    test('Among competing eligible companions for the one remaining Priority seat, the eligible female is weighted ahead of the eligible male', () async {
      final service = AllocationService();
      // General and Limited are both saturated, so the group can't be
      // seated together anywhere (the whole group isn't priority-eligible,
      // so Priority isn't even tried for adjacency) and this falls through
      // to the individual per-passenger fallback - exactly where the
      // gender-weighted selection order applies. Only 1 free priority seat
      // exists for the two eligible companions to compete over.
      // Deliberately listing the male companion BEFORE the female one in
      // the input to prove the *engine* reorders them, not the caller.
      // Both companions are eligible via a mobility need (not just
      // safetyPreference), so the priority-reserve-buffer rule doesn't
      // itself exclude them here - this test is isolating the gender-
      // weighted ordering specifically.
      final primary = _passenger(id: 'g4_primary', gender: 'male'); // not priority-eligible
      final maleCompanion = _passenger(id: 'g4_male', gender: 'male', mobilityStatus: 'wheelchair');
      final femaleCompanion = _passenger(id: 'g4_female', gender: 'female', mobilityStatus: 'wheelchair');

      final results = await service.allocateGroup(
        passengers: [primary, maleCompanion, femaleCompanion],
        journeyId: 'JRN_TEST',
        routeId: 'R_87',
        busId: 'BUS_TEST_13',
        boardingStop: 'Colombo (Pettah)',
        alightingStop: 'Jaffna Main Bus Stand',
        availablePrioritySeats: 1,
        availableGeneralSeats: 0,
        availableLimitedSeats: 0,
      );

      expect(results.length, 3);
      final femaleSeat = results[2].seatNumber;
      final maleSeat = results[1].seatNumber;
      expect(_rowOf(femaleSeat), lessThanOrEqualTo(3), reason: 'the female companion (index 2, primary-first order) should win the one free priority seat');
      expect(maleSeat.toUpperCase().startsWith('STANDING'), isTrue, reason: 'the male companion should have fallen through past the now-taken priority seat, past the saturated general/limited zones, to standing');
    });

    test('releaseSeat frees a previously-suggested seat back to the pool so it can be offered again', () async {
      final service = AllocationService();
      const busId = 'BUS_TEST_14';
      final passenger = _passenger(id: 'p10', gender: 'female');

      final first = await _allocate(service, passenger, busId: busId);
      expect(first.seatNumber, equals('4A'));

      service.releaseSeat(busId: busId, seatNumber: first.seatNumber);

      // With 4A released and excluded, a fresh allocation for a second
      // passenger should land back on 4A (now free) if not excluded...
      final second = await _allocate(service, _passenger(id: 'p11', gender: 'female'), busId: busId);
      expect(second.seatNumber, equals('4A'), reason: 'the released seat should be free again');
    });

    test('General zone: a gender-safe seat farther from the front is chosen over a closer opposite-gender-adjacent seat', () async {
      final service = AllocationService();
      // Seed 4A(male),4B(female),4C(male),4D(female) occupied, leaving 4E
      // free but unsafe (its only neighbour, 4D, is female) - while every
      // row 5+ seat is completely free and therefore gender-safe.
      final allocation = await _allocate(
        service,
        _passenger(id: 'a1', gender: 'male'),
        busId: 'BUS_TEST_A',
        availableGeneralSeats: kGeneralTotalSeats - 4,
      );
      expect(allocation.seatNumber, equals('5A'),
          reason: 'the gender-safe seat, even though a row farther back, must beat the closer-but-unsafe 4E');
    });

    test('General zone: when the only remaining free seat is opposite-gender-adjacent, allocation still succeeds via the fallback tiebreak', () async {
      final service = AllocationService();
      // Only 6E is free; its one neighbour (6D) is seeded female, so no
      // gender-safe seat exists anywhere in the zone.
      final allocation = await _allocate(
        service,
        _passenger(id: 'b1', gender: 'male'),
        busId: 'BUS_TEST_B',
        availableGeneralSeats: 1,
      );
      expect(allocation.seatNumber, equals('6E'));
    });

    test('With only 2 free Priority seats left, a safety_preference-only passenger is routed to General (priority_reserved), while a mobility passenger still gets Priority', () async {
      final service = AllocationService();

      final safetyOnly = await _allocate(
        service,
        _passenger(id: 'c1', safetyPreference: true),
        busId: 'BUS_TEST_C1',
        availablePrioritySeats: 2,
      );
      expect(_rowOf(safetyOnly.seatNumber), greaterThan(3),
          reason: 'a safety_preference-only passenger should be bumped to General once only 2 priority seats remain');
      expect(safetyOnly.priorityReserved, isTrue);

      final mobility = await _allocate(
        service,
        _passenger(id: 'c2', mobilityStatus: 'wheelchair'),
        busId: 'BUS_TEST_C2',
        availablePrioritySeats: 2,
      );
      expect(_rowOf(mobility.seatNumber), lessThanOrEqualTo(3),
          reason: 'a passenger with a real mobility need should still get a priority seat even with only 2 left');
      expect(mobility.priorityReserved, isFalse);
    });

    test('A 2-seat group with traveling_together=true and different genders is seated adjacent to each other successfully', () async {
      final service = AllocationService();
      final passengers = [
        _passenger(id: 'd1', gender: 'male', travelingTogether: true),
        _passenger(id: 'd2', gender: 'female', travelingTogether: true),
      ];

      final results = await service.allocateGroup(
        passengers: passengers,
        journeyId: 'JRN_TEST',
        routeId: 'R_87',
        busId: 'BUS_TEST_D',
        boardingStop: 'Colombo (Pettah)',
        alightingStop: 'Jaffna Main Bus Stand',
      );

      expect(results.length, 2);
      final seats = results.map((r) => r.seatNumber).toSet();
      expect(seats, equals({'4A', '4B'}),
          reason: 'traveling_together should let differently-gendered companions sit adjacent to each other');
    });
  });
}
