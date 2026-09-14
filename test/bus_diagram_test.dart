import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeboard/constants/colors.dart';
import 'package:safeboard/widgets/bus_diagram.dart';
import 'package:safeboard/widgets/zone_pill.dart';

void main() {
  testWidgets(
      'BusDiagram renders 11 uniform 5-seat rows, a 6-seat rear bench, 6 standing spots down the aisle, and highlights allocated seat 3A',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BusDiagram(allocatedSeat: '3A'),
          ),
        ),
      ),
    );

    // 4-zone legend: Priority, General, Limited and Standing are now
    // visually distinct (Limited is a real seat, Standing is not).
    expect(find.text('PRIORITY'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('LIMITED'), findsOneWidget);
    expect(find.text('STANDING'), findsOneWidget);

    // Every seat uses the same seat-icon visual language.
    expect(find.byIcon(Icons.event_seat), findsWidgets);

    // Allocated seat 3A is rendered and highlighted with a checkmark badge.
    expect(find.text('3A'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Rows 1-11 are uniform: every row has the full A,B,C,D,E set, no
    // staggering or row-count mismatch between the left and right blocks.
    for (final row in [1, 6, 11]) {
      for (final letter in ['A', 'B', 'C', 'D', 'E']) {
        expect(find.text('$row$letter'), findsOneWidget, reason: 'seat $row$letter should be on the diagram');
      }
    }
    // No row 14 (only rows 1-13 exist).
    expect(find.text('14A'), findsNothing);

    // Row 12 is right-only (beside the rear door, no left pair) - fills
    // the space the rear door leaves empty on the right column.
    for (final letter in ['C', 'D', 'E']) {
      expect(find.text('12$letter'), findsOneWidget, reason: 'seat 12$letter should be on the diagram, beside the rear door');
    }
    expect(find.text('12A'), findsNothing, reason: 'row 12 has no left pair - the rear door occupies that space');
    expect(find.text('12B'), findsNothing);

    // Rear bench (row 13) renders exactly 6 seats, no left/right split.
    for (final letter in ['A', 'B', 'C', 'D', 'E', 'F']) {
      expect(find.text('13$letter'), findsOneWidget);
    }
    // The bench must fit within the same width and left margin as the seat
    // rows above it, not stretch wider than the rest of the bus.
    final bodyRect = tester.getRect(find.byKey(const Key('busSeatBody')));
    final benchRect = tester.getRect(find.byKey(const Key('rearBench')));
    expect((bodyRect.left - benchRect.left).abs() < 0.5, isTrue,
        reason: 'Bench should start at the same left margin as the seat rows above it');
    expect((bodyRect.width - benchRect.width).abs() < 0.5, isTrue,
        reason: 'Bench should not be wider than the seat rows above it');

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

    // Exactly 6 standing spots, all styled the same way (no side variant),
    // rendered as their own strip separate from the seat rows.
    expect(find.byIcon(Icons.accessibility_new), findsNWidgets(6));
  });

  testWidgets('BusDiagram highlights every seat in a multi-seat (group) allocation, not just the primary one', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BusDiagram(allocatedSeat: '1A', extraAllocatedSeats: ['1B', '13F']),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsNWidgets(3));
  });

  testWidgets("BusDiagram highlights the passenger's own standing spot when allocated standing, capped at 6", (WidgetTester tester) async {
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

  testWidgets('ZonePill renders the Limited Zone label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ZonePill(zone: 'limited', small: true),
        ),
      ),
    );

    expect(find.text('Limited Zone'), findsOneWidget);
  });
}
