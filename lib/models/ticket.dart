import 'seat_allocation.dart';
import 'payment.dart';
import 'bus_schedule.dart';
import 'route_model.dart';

// A completed booking - seat + payment decision + the bus/route it belongs
// to - kept around (independent of whatever the passenger searches for
// next) so several bookings can exist at once and each stays retrievable
// from Home right up until it's boarded.
class Ticket {
  final SeatAllocation allocation;
  final Payment payment;
  final BusSchedule bus;
  final RouteModel route;
  final bool journeyStarted;
  // Set once by TicketsProvider.endJourney - distinct from journeyStarted
  // going back to false, so a completed trip doesn't fall back into
  // "upcoming" on Home and instead moves to History.
  final bool journeyCompleted;
  final int? rating;
  // A bulk (multi-seat) booking made under the primary passenger's own
  // account: [allocation] is the primary's own seat, these are the extra
  // seats suggested for their companions. It's kept as ONE ticket (not one
  // per seat) because bulk bookings only exist under the primary's
  // credentials - there's no separate account for a companion to start,
  // end, or report on their own seat, so every action here (start trip, end
  // journey, rate, incident report) naturally covers the whole group at
  // once instead of needing to be kept in sync across several tickets.
  final List<SeatAllocation> extraAllocations;

  const Ticket({
    required this.allocation,
    required this.payment,
    required this.bus,
    required this.route,
    this.journeyStarted = false,
    this.journeyCompleted = false,
    this.rating,
    this.extraAllocations = const [],
  });

  String get ticketId => allocation.allocationId;

  bool get isBulk => extraAllocations.isNotEmpty;

  int get seatCount => 1 + extraAllocations.length;

  List<SeatAllocation> get allAllocations => [allocation, ...extraAllocations];

  Ticket copyWith({bool? journeyStarted, bool? journeyCompleted, int? rating}) {
    return Ticket(
      allocation: allocation,
      payment: payment,
      bus: bus,
      route: route,
      journeyStarted: journeyStarted ?? this.journeyStarted,
      journeyCompleted: journeyCompleted ?? this.journeyCompleted,
      rating: rating ?? this.rating,
      extraAllocations: extraAllocations,
    );
  }
}
