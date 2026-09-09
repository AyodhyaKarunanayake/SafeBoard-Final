import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/tickets_provider.dart';
import '../../providers/booking_provider.dart';
import '../../models/ticket.dart';
import '../../constants/colors.dart';
import '../../widgets/zone_pill.dart';
import '../../widgets/app_bottom_nav_bar.dart';

// Seat -> gender-aware zone key, same row rule used everywhere else
// (rows 1-3 priority, row 12 the rear bench, everything else general).
String _zoneForSeat(String seatNumber) {
  if (seatNumber.toUpperCase().startsWith('STANDING')) return 'standing';
  final rowNum = int.tryParse(RegExp(r'^(\d+)').firstMatch(seatNumber)?.group(1) ?? '');
  if (rowNum != null && rowNum <= 3) return 'priority';
  return 'general';
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${formattedHour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final ticketsProvider = Provider.of<TicketsProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final trips = ticketsProvider.completedTickets;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Completed Trips',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${trips.length} ${trips.length == 1 ? "Trip" : "Trips"}',
                        style: const TextStyle(
                          color: AppColors.primaryNavy,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => context.go('/incident-history'),
                      icon: const Icon(Icons.shield_outlined, size: 15, color: AppColors.textMuted),
                      label: const Text('My reports', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: trips.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: trips.length,
                    itemBuilder: (context, index) => _buildTripCard(context, trips[index], ticketsProvider, bookingProvider),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF12163F), AppColors.primaryNavy, Color(0xFF2D4A9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Journey History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          SizedBox(height: 6),
          Text('Every trip you\'ve completed on SafeBoard.', style: TextStyle(fontSize: 12.5, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 14),
            const Text(
              'No completed trips yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Once you finish a journey, it will show up here with your fare, seat and safety rating.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.go('/search'),
              icon: const Icon(Icons.event_seat_rounded, size: 18),
              label: const Text('Book a Seat'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, Ticket ticket, TicketsProvider ticketsProvider, BookingProvider bookingProvider) {
    final alloc = ticket.allocation;
    final zone = _zoneForSeat(alloc.seatNumber);
    final rating = ticket.rating;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryNavy,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ticket.route.routeName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ticket.isBulk ? 'Seat ${alloc.seatNumber} +${ticket.extraAllocations.length}' : 'Seat ${alloc.seatNumber}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ticket.isBulk) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(color: AppColors.priorityAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: const Text('BULK', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.priorityAccent)),
                      ),
                    ],
                    ZonePill(zone: zone, small: true),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${alloc.boardingStop} → ${alloc.alightingStop}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _formatDate(ticket.bus.departureDateTime),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ),
                    Text(
                      'Rs. ${ticket.payment.amountLkr.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (rating != null)
                      Row(
                        children: List.generate(5, (sIndex) {
                          return Icon(
                            sIndex < rating ? Icons.star : Icons.star_border,
                            size: 16,
                            color: AppColors.standingAccent,
                          );
                        }),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => context.go('/rating/${ticket.ticketId}'),
                        icon: const Icon(Icons.star_border, size: 16),
                        label: const Text('Rate this trip', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                      ),
                    TextButton.icon(
                      onPressed: () {
                        bookingProvider.prefillStops(boardingStop: alloc.boardingStop, alightingStop: alloc.alightingStop);
                        context.go('/search');
                      },
                      icon: const Icon(Icons.replay_rounded, size: 16),
                      label: const Text('Book again', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Thin Zone Bar at Bottom of Card
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Container(
              height: 4,
              color: AppColors.getZoneAccent(zone),
            ),
          ),
        ],
      ),
    );
  }
}
