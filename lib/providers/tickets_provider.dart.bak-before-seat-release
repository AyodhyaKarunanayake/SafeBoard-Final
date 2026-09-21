import 'package:flutter/material.dart';
import '../models/ticket.dart';

class TicketsProvider with ChangeNotifier {
  final List<Ticket> _tickets = [];

  List<Ticket> get tickets => List.unmodifiable(_tickets);

  Ticket? ticketById(String ticketId) {
    for (final t in _tickets) {
      if (t.ticketId == ticketId) return t;
    }
    return null;
  }

  // At most one ticket can be an active (boarded) journey at a time - a
  // passenger can't be on two buses at once.
  Ticket? get activeTicket {
    for (final t in _tickets) {
      if (t.journeyStarted) return t;
    }
    return null;
  }

  // Tickets that still belong on Home: not yet boarded, not yet finished.
  List<Ticket> get upcomingTickets => _tickets.where((t) => !t.journeyStarted && !t.journeyCompleted).toList();

  // Finished trips, most recent departure first - this is what the History
  // tab shows.
  List<Ticket> get completedTickets {
    final list = _tickets.where((t) => t.journeyCompleted).toList();
    list.sort((a, b) => b.bus.departureDateTime.compareTo(a.bus.departureDateTime));
    return list;
  }

  void addTicket(Ticket ticket) {
    _tickets.removeWhere((t) => t.ticketId == ticket.ticketId);
    _tickets.add(ticket);
    notifyListeners();
  }

  // Verifies the conductor's OTP (fixed at "1234" for this app) and marks
  // the ticket's journey as started. Returns null on success, or an error
  // message to show the passenger.
  String? startJourney(String ticketId, String otp) {
    if (activeTicket != null && activeTicket!.ticketId != ticketId) {
      return 'You already have an active journey. End it before starting another.';
    }
    if (otp != '1234') {
      return 'Incorrect OTP. Ask the conductor for the code they issued.';
    }
    final index = _tickets.indexWhere((t) => t.ticketId == ticketId);
    if (index == -1) return 'Ticket not found.';

    _tickets[index] = _tickets[index].copyWith(journeyStarted: true);
    notifyListeners();
    return null;
  }

  // Ends the journey AND marks it completed in one step - a finished trip
  // never falls back into "upcoming" on Home, it moves straight to History.
  void endJourney(String ticketId) {
    final index = _tickets.indexWhere((t) => t.ticketId == ticketId);
    if (index == -1) return;
    _tickets[index] = _tickets[index].copyWith(journeyStarted: false, journeyCompleted: true);
    notifyListeners();
  }

  void rateTicket(String ticketId, int stars) {
    final index = _tickets.indexWhere((t) => t.ticketId == ticketId);
    if (index == -1) return;
    _tickets[index] = _tickets[index].copyWith(rating: stars.clamp(1, 5));
    notifyListeners();
  }

  void removeTicket(String ticketId) {
    _tickets.removeWhere((t) => t.ticketId == ticketId);
    notifyListeners();
  }
}
