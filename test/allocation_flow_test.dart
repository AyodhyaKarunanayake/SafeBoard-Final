import 'package:flutter_test/flutter_test.dart';
import 'package:safeboard/models/passenger.dart';
import 'package:safeboard/services/allocation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Allocation Engine Logic Tests for Route 87', () {
    final allocationService = AllocationService();

    test('Passenger with safetyPreference = true is allocated to Priority Zone (Row 1-3)', () async {
      final passenger = Passenger(
        passengerId: 'p_test_01',
        name: 'Kumari Silva',
        email: 'kumari@test.lk',
        gender: 'female',
        ageGroup: 'adult',
        mobilityStatus: 'none',
        phoneNumber: '+94 77 000 0000',
        safetyPreference: true,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
      );

      final allocation = await allocationService.allocateSeat(
        passenger: passenger,
        journeyId: 'JRN_87_TEST',
        routeId: 'R_87',
        busId: 'BUS_NB_8710',
        boardingStop: 'Colombo (Pettah)',
        alightingStop: 'Jaffna Main Bus Stand',
      );

      expect(allocation.seatNumber, equals('3A'));
      expect(allocation.riskScore, equals(0.05));
      expect(allocation.qrCode.startsWith('SB-JRN_87_TEST-3A'), isTrue);
    });

    test('Passenger with mobilityStatus = wheelchair is allocated to Priority Zone', () async {
      final passenger = Passenger(
        passengerId: 'p_test_02',
        name: 'Sunil Fernando',
        email: 'sunil@test.lk',
        gender: 'male',
        ageGroup: 'elderly',
        mobilityStatus: 'wheelchair',
        phoneNumber: '+94 77 111 2222',
        safetyPreference: false,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
      );

      final allocation = await allocationService.allocateSeat(
        passenger: passenger,
        journeyId: 'JRN_87_TEST_2',
        routeId: 'R_87',
        busId: 'BUS_NB_8710',
        boardingStop: 'Colombo (Pettah)',
        alightingStop: 'Anuradhapura New Town',
      );

      expect(allocation.seatNumber, equals('3A'));
      expect(allocation.riskScore, equals(0.05));
    });
  });
}
