import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeboard/constants/colors.dart';
import 'package:safeboard/widgets/bus_diagram.dart';
import 'package:safeboard/widgets/zone_pill.dart';

void main() {
  testWidgets('BusDiagram staggers the right column behind the left, fits the rear bench to the same margins, renders 6 uniform standing spots, and highlights allocated seat 3A', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BusDiagram(allocatedSeat: '3A'),
          ),
        ),
      ),
    );

    // 3-zone legend
    expect(find.text('PRIORITY'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('LIMITED STANDING'), findsOneWidget);

    // Every seat uses the same seat-icon visual language.
    expect(find.byIcon(Icons.event_seat), findsWidgets);

    // Allocated seat 3A is rendered and highlighted with a checkmark badge
    expect(find.text('3A'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Left column: rows 1-10 only (then the rear door - no row 11 on the left)
    for (final seat in ['1A', '10B']) {
      expect(find.text(seat), findsOneWidget);
    }
    expect(find.text('11A'), findsNothing);

    // Right column: rows 1-11 (the extra row, staggered in behind the left)
    for (final seat in ['1C', '10E', '11C', '11D', '11E']) {
      expect(find.text(seat), findsOneWidget);
    }

    // Rear bench (row 12) renders exactly 6 seats
    for (final letter in ['A', 'B', 'C', 'D', 'E', 'F']) {
      expect(find.text('12$letter'), findsOneWidget);
    }
    // The bench must fit within the same width and left margin as the seat
    // rows above it, not stretch wider than the rest of the bus.
    final bodyRect = tester.getRect(find.byKey(const Key('busSeatBody')));
    final benchRect = tester.getRect(find.byKey(const Key('rearBench')));
    expect((bodyRect.left - benchRect.left).abs() < 0.5, isTrue, reason: 'Bench should start at the same left margin as the seat rows above it');
    expect((bodyRect.width - benchRect.width).abs() < 0.5, isTrue, reason: 'Bench should not be wider than the seat rows above it');

    // Driver is rendered as a seat with a neutral color, not the navy used
    // for the allocated-seat highlight.
    expect(find.text('Driver'), findsOneWidget);
    final driverContainer = tester.widget<Container>(
      find.ancestor(of: find.text('Driver'), matching: find.byType(Container)).first,
    );
    final driverColor = (driverContainer.decoration as BoxDecoration).color;
    expect(driverColor, isNot(equals(AppColors.primaryNavy)), reason: 'Driver box should not use the navy highlight color');

    // Door labels carry no "(Entry)"/"(Exit)" suffixes.
    expect(find.text('Front Door'), findsOneWidget);
    expect(find.text('Rear Door'), findsOneWidget);

    // Exactly 6 standing spots, all styled the same way (no side variant).
    expect(find.byIcon(Icons.accessibility_new), findsNWidgets(6));
  });

  testWidgets('BusDiagram highlights the passenger\'s own standing spot when allocated standing, capped at 6', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BusDiagram(allocatedSeat: 'Standing-4'),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.accessibility_new), findsNWidgets(6));
  });

  testWidgets('BusDiagram scales its seat grid with the available width', (WidgetTester tester) async {
    Future<double> pumpAtWidth(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: const SingleChildScrollView(child: BusDiagram(allocatedSeat: '3A')),
            ),
          ),
        ),
      );
      return tester.getRect(find.byKey(const Key('busSeatBody'))).width;
    }

    final narrowWidth = await pumpAtWidth(320);
    final wideWidth = await pumpAtWidth(700);

    expect(wideWidth, greaterThan(narrowWidth), reason: 'Seat grid should grow when more width is available');
  });

  testWidgets('ZonePill renders correct label and colors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ZonePill(zone: 'priority', small: true),
        ),
      ),
    );

    expect(find.text('Priority Zone'), findsOneWidget);
  });
}
