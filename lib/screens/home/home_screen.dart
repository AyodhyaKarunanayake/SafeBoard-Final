import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/journey_provider.dart';
import '../../providers/tickets_provider.dart';
import '../../models/ticket.dart';
import '../../constants/colors.dart';
import '../../widgets/zone_pill.dart';
import '../../widgets/app_bottom_nav_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final journeyProvider = Provider.of<JourneyProvider>(context);
    final ticketsProvider = Provider.of<TicketsProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final passenger = authProvider.passenger;
    final totalStops = bookingProvider.sampleRoutes.first.totalStops;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Deep Navy Header (same in both states) ───────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                  left: 20, right: 20, top: 56, bottom: 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF12163F),
                    AppColors.primaryNavy,
                    Color(0xFF2D4A9A)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_greeting()}, ${passenger?.name.split(' ').first ?? 'Passenger'}!',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your Smart Bus Companion',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => context.go('/notifications'),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_none,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Status Chip
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: passenger?.safetyPreference == true
                              ? AppColors.priorityBg
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: passenger?.safetyPreference == true
                                    ? AppColors.priorityAccent
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              passenger?.safetyPreference == true
                                  ? 'Priority Zone Active'
                                  : 'Standard Allocation',
                              style: TextStyle(
                                color: passenger?.safetyPreference == true
                                    ? AppColors.priorityText
                                    : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Body switches on journey state ───────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ticketsProvider.tickets.isNotEmpty
                  ? _buildTicketsBody(context, journeyProvider, ticketsProvider, totalStops)
                  : _buildFreshBody(context, totalStops),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  // ── STATE A: No booking yet — welcome & Book a Seat ─────────────────────
  Widget _buildFreshBody(BuildContext context, int totalStops) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero CTA card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B2859), Color(0xFF2D4A9A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryNavy.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_bus_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ready to travel?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'SafeBoard allocates you a safe, well-matched seat on Sri Lankan public transport.',
                style:
                    TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/search'),
                  icon: const Icon(Icons.event_seat_rounded, size: 18),
                  label: const Text(
                    'Book a Seat',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryNavy,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // How It Works
        const Text(
          'How it works',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryNavy,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              _buildStep(
                icon: Icons.search_rounded,
                color: AppColors.generalAccent,
                title: 'Search your route',
                subtitle:
                    'Find your bus and select boarding & alighting stops.',
              ),
              const Padding(
                padding: EdgeInsets.only(left: 48),
                child: Divider(height: 20),
              ),
              _buildStep(
                icon: Icons.auto_awesome_rounded,
                color: AppColors.priorityAccent,
                title: 'Seat auto-allocated',
                subtitle:
                    'Our algorithm picks your safest seat based on your safety preferences.',
              ),
              const Padding(
                padding: EdgeInsets.only(left: 48),
                child: Divider(height: 20),
              ),
              _buildStep(
                icon: Icons.qr_code_2_rounded,
                color: AppColors.standingAccent,
                title: 'Board & show QR',
                subtitle:
                    'Show your QR code to the conductor and take your allocated seat.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Popular Route
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Popular Route',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/search'),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildRouteCard(
          context,
          routeNo: '87',
          name: 'Colombo (Pettah) ➔ Jaffna',
          type: '$totalStops Halts · Semi Luxury & Normal',
        ),
        const SizedBox(height: 24),

        // Info card (no SOS for fresh users)
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 28),
          decoration: BoxDecoration(
            color: AppColors.generalBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.generalAccent.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: AppColors.generalAccent, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Seat Allocation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.generalText,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'SafeBoard enforces safe proximity buffers so every passenger travels with confidence.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.generalText,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── STATE B: Has tickets — ticket list + Book Another Seat + corridor ───
  // No SOS/emergency card here by design: that's only relevant once a
  // journey has actually started (boarded), which is what the Journey tab
  // is for - showing it while a passenger is still waiting at home isn't
  // practical and would just be alarming noise.
  Widget _buildTicketsBody(BuildContext context, JourneyProvider journeyProvider,
      TicketsProvider ticketsProvider, int totalStops) {
    final activeTicket = ticketsProvider.activeTicket;
    // Once a ticket's journey has started it's represented solely by the
    // "Active Journey" banner above (which opens the Journey tab); once it's
    // finished it belongs on the History tab instead - neither should show
    // up again in the plain upcoming-ticket list.
    final tickets = ticketsProvider.upcomingTickets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active Journey Banner (Pink) - only once a ticket's trip has
        // actually been started via the OTP on its ticket screen.
        if (activeTicket != null)
          GestureDetector(
            onTap: () => context.go('/journey'),
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.priorityBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.priorityAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.priorityAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_bus,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ACTIVE JOURNEY · Route 87',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.priorityText,
                              ),
                            ),
                            ZonePill(zone: 'priority', small: true),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeTicket.isBulk
                              ? 'Seat ${activeTicket.allocation.seatNumber} (+${activeTicket.extraAllocations.length}) · Next: ${journeyProvider.currentStop}'
                              : 'Seat ${activeTicket.allocation.seatNumber} · Next: ${journeyProvider.currentStop}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.priorityText),
                ],
              ),
            ),
          ),

        // My Tickets
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Tickets (${tickets.length})',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy),
            ),
            TextButton.icon(
              onPressed: () => context.go('/search'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Book Another Seat'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (tickets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Text(
              'No other upcoming tickets. Book another seat to plan your next trip.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          )
        else
          for (final ticket in tickets) _buildTicketCard(context, ticket),
        const SizedBox(height: 12),

        // Route Corridor
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Route Corridor',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/search'),
              child: const Text('View departures'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildRouteCard(
          context,
          routeNo: '87',
          name: 'Colombo (Pettah) ➔ Jaffna',
          type: '$totalStops Halts · Semi Luxury & Normal',
        ),
        const SizedBox(height: 20),

        // Safety Tip Card
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: AppColors.generalBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.generalAccent.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: AppColors.generalAccent, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Safety Tip: Door Proximity',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.generalText,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Priority seats are placed near the front door for easy exit and conductor oversight.',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.generalText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helper: one ticket card (QR / booking reference, live before boarding) ─
  Widget _buildTicketCard(BuildContext context, Ticket ticket) {
    final alloc = ticket.allocation;
    final isPaid = ticket.payment.isPaid;
    final accent = ticket.journeyStarted
        ? AppColors.priorityAccent
        : (isPaid ? AppColors.generalAccent : Colors.orange.shade700);

    final String statusLabel;
    if (ticket.journeyStarted) {
      statusLabel = 'IN PROGRESS';
    } else if (isPaid) {
      statusLabel = 'PAID';
    } else {
      statusLabel = 'PAY ONBOARD';
    }

    return GestureDetector(
      onTap: () => context.go('/my-ticket/${ticket.ticketId}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: accent.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(
                ticket.journeyStarted
                    ? Icons.directions_bus
                    : (isPaid
                        ? Icons.qr_code_2
                        : Icons.confirmation_number_outlined),
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ticket.isBulk
                              ? 'Seat ${alloc.seatNumber} +${ticket.extraAllocations.length} · ${ticket.bus.busNumber}'
                              : 'Seat ${alloc.seatNumber} · ${ticket.bus.busNumber}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: AppColors.primaryNavy),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (ticket.isBulk) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.priorityAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('BULK',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.priorityAccent)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(statusLabel,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${alloc.boardingStop.split(' ').first} → ${alloc.alightingStop.split(' ').first} · ${isPaid ? "Show your QR" : "Ref ${alloc.referenceCode}"}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  // ── Helper: Step row for "How it works" ──────────────────────────────────
  Widget _buildStep({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helper: Route card ───────────────────────────────────────────────────
  Widget _buildRouteCard(BuildContext context,
      {required String routeNo, required String name, required String type}) {
    return GestureDetector(
      onTap: () => context.go('/route/R_$routeNo'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                routeNo,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    type,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  // Time-of-day greeting instead of a static "Hello" - the same pattern
  // most modern apps use for their home header.
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
