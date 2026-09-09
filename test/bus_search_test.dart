import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeboard/providers/booking_provider.dart';
import 'package:safeboard/screens/search/search_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bus Search Logic & Best Fit Engine Tests for Route 87', () {
    test('Correctly filters buses for Route 87 corridor halts', () {
      final provider = BookingProvider();
      provider.setSearchCriteria(
        date: DateTime(2026, 9, 7),
        time: const TimeOfDay(hour: 8, minute: 30),
        boardingStop: 'Colombo (Pettah)',
        alightingStop: 'Jaffna Main Bus Stand',
      );

      final filtered = provider.filteredBuses;
      expect(filtered.isNotEmpty, isTrue);
      for (final bus in filtered) {
        expect(bus.routeId, equals('R_87'));
        expect(bus.servesJourney('Colombo (Pettah)', 'Jaffna Main Bus Stand'), isTrue);
      }
    });

    test('Correctly filters intermediate halts along Route 87 (e.g. Negombo to Anuradhapura)', () {
      final provider = BookingProvider();
      provider.setSearchCriteria(
        date: DateTime(2026, 9, 7),
        time: const TimeOfDay(hour: 7, minute: 0),
        boardingStop: 'Negombo Bus Stand',
        alightingStop: 'Anuradhapura New Town',
      );

      final filtered = provider.filteredBuses;
      expect(filtered.isNotEmpty, isTrue);
      for (final bus in filtered) {
        expect(bus.servesJourney('Negombo Bus Stand', 'Anuradhapura New Town'), isTrue);
      }
    });

    test('Identifies exact or closest Best Fit bus for 08:30 AM search on Route 87', () {
      final provider = BookingProvider();
      provider.setSearchCriteria(
        date: DateTime(2026, 9, 7),
        time: const TimeOfDay(hour: 8, minute: 30),
        boardingStop: 'Colombo (Pettah)',
        alightingStop: 'Jaffna Main Bus Stand',
      );

      final bestFit = provider.bestFitBus;
      expect(bestFit, isNotNull);
      expect(bestFit!.busId, equals('BUS_NB_8710')); // 08:30 AM departure
      expect(bestFit.departureDateTime.hour, equals(8));
      expect(bestFit.departureDateTime.minute, equals(30));
    });

    test('Identifies closest upcoming Best Fit bus for 05:25 AM search on Route 87', () {
      final provider = BookingProvider();
      provider.setSearchCriteria(
        date: DateTime(2026, 9, 7),
        time: const TimeOfDay(hour: 5, minute: 25),
        boardingStop: 'Colombo (Pettah)',
        alightingStop: 'Jaffna Main Bus Stand',
      );

      final bestFit = provider.bestFitBus;
      expect(bestFit, isNotNull);
      // Closest departure after 05:25 AM is 05:30 AM (BUS_NB_8701)
      expect(bestFit!.busId, equals('BUS_NB_8701'));
    });

    test('Excludes bestFitBus from otherUpcomingBuses and sorts them chronologically', () {
      final provider = BookingProvider();
      provider.setSearchCriteria(
        date: DateTime(2026, 9, 7),
        time: const TimeOfDay(hour: 8, minute: 30),
        boardingStop: 'Colombo (Pettah)',
        alightingStop: 'Jaffna Main Bus Stand',
      );

      final bestFit = provider.bestFitBus;
      final others = provider.otherUpcomingBuses;

      expect(bestFit, isNotNull);
      expect(others.any((b) => b.busId == bestFit!.busId), isFalse);

      // Verify chronological order
      for (int i = 0; i < others.length - 1; i++) {
        expect(
          others[i].departureDateTime.isBefore(others[i + 1].departureDateTime) ||
              others[i].departureDateTime.isAtSameMomentAs(others[i + 1].departureDateTime),
          isTrue,
        );
      }
    });

    test('Swapping stops resets search and filters opposite direction', () {
      final provider = BookingProvider();
      provider.setSearchCriteria(
        boardingStop: 'Colombo (Pettah)',
        alightingStop: 'Jaffna Main Bus Stand',
      );
      expect(provider.searchBoardingStop, equals('Colombo (Pettah)'));
      expect(provider.searchAlightingStop, equals('Jaffna Main Bus Stand'));

      provider.swapStops();
      expect(provider.searchBoardingStop, equals('Jaffna Main Bus Stand'));
      expect(provider.searchAlightingStop, equals('Colombo (Pettah)'));
    });
  });

  group('SearchScreen Widget Tests for Route 87', () {
    testWidgets('Renders search controls, Best Fit card and Other Upcoming buses for Route 87', (tester) async {
      final provider = BookingProvider();
      provider.setSearchCriteria(
        date: DateTime(2026, 9, 7),
        time: const TimeOfDay(hour: 8, minute: 30),
        boardingStop: 'Colombo (Pettah)',
        alightingStop: 'Jaffna Main Bus Stand',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BookingProvider>.value(
            value: provider,
            child: const SearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for Best Fit header
      expect(find.text('BEST FIT SUGGESTION'), findsOneWidget);
      expect(find.text('Find Bus & Seats'), findsOneWidget);
      expect(find.text('Request Seat on this Bus'), findsOneWidget);

      // Check for Other upcoming buses section
      expect(find.textContaining('Other Upcoming Buses'), findsOneWidget);
    });
  });
}
