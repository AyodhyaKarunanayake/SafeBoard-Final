import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/booking_provider.dart';
import '../../providers/journey_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/tickets_provider.dart';
import '../../models/ticket.dart';
import '../../constants/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';

// Shown once the passenger is happy with their allocated seat, before the
// journey starts: pay now in-app, or pay the conductor onboard.
class PaymentOptionsScreen extends StatelessWidget {
  const PaymentOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final journeyProvider = Provider.of<JourneyProvider>(context);
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    final ticketsProvider = Provider.of<TicketsProvider>(context, listen: false);

    final alloc = journeyProvider.currentAllocation ?? bookingProvider.lastAllocation;
    final route = bookingProvider.selectedRoute ?? bookingProvider.sampleRoutes.first;
    final bus = bookingProvider.selectedBus;
    final boarding = alloc?.boardingStop ?? bookingProvider.boardingStop ?? route.stops.first;
    final alighting = alloc?.alightingStop ?? bookingProvider.alightingStop ?? route.stops.last;
    final perSeatAmount = bus?.journeyFareLkr(route, boarding, alighting) ?? 0.0;
    final seatNumber = alloc?.seatNumber ?? '-';

    final group = bookingProvider.groupAllocations;
    final isGroup = group.length > 1;
    final amount = isGroup ? perSeatAmount * group.length : perSeatAmount;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How would you like to pay?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your seat is confirmed. Settle the fare now, or pay the conductor onboard.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            // Trip / fare summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGroup ? '${group.length} seats · ${group.map((a) => a.seatNumber).join(', ')}' : 'Seat $seatNumber',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$boarding → $alighting',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isGroup) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${group.length} × Rs. ${perSeatAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Rs. ${amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            if (isGroup) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.priorityBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.groups_rounded, size: 16, color: AppColors.priorityText),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bulk booking - all seats are kept under one ticket in your account. Only you can start, end or report on this journey.',
                        style: TextStyle(fontSize: 11, color: AppColors.priorityText, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            _buildOptionCard(
              context,
              icon: Icons.credit_card,
              iconColor: AppColors.priorityAccent,
              title: 'Pay Now in the App',
              subtitle: 'Card or mobile wallet - instant, secure checkout.',
              onTap: () => context.go('/payment-portal'),
            ),
            const SizedBox(height: 12),
            _buildOptionCard(
              context,
              icon: Icons.groups_outlined,
              iconColor: AppColors.generalAccent,
              title: 'Pay the Conductor Onboard',
              subtitle: 'Pay by cash or card when the conductor checks your ticket.',
              onTap: () {
                if (alloc == null || bus == null) return;
                paymentProvider.payOnBoard(alloc, amount);
                final payment = paymentProvider.payment;
                if (payment == null) return;

                if (isGroup) {
                  ticketsProvider.addTicket(Ticket(
                    allocation: group.first,
                    extraAllocations: group.skip(1).toList(),
                    payment: payment,
                    bus: bus,
                    route: route,
                  ));
                } else {
                  ticketsProvider.addTicket(Ticket(allocation: alloc, payment: payment, bus: bus, route: route));
                }
                context.go('/pay-onboard-confirmed');
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

}
