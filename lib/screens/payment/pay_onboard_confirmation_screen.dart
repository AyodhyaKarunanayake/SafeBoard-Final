import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/booking_provider.dart';
import '../../providers/journey_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';

// A modern, QR-free confirmation for "pay the conductor onboard" bookings.
// No scannable code is shown here - a QR implies a paid, ticketed seat, and
// this one isn't paid yet. Instead the conductor verifies the passenger by
// name + a short booking reference against the manifest, the same pattern
// airlines use for a reserved-but-not-yet-ticketed (PNR-only) booking.
class PayOnboardConfirmationScreen extends StatelessWidget {
  const PayOnboardConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final journeyProvider = Provider.of<JourneyProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final alloc = journeyProvider.currentAllocation ?? bookingProvider.lastAllocation;
    final route = bookingProvider.selectedRoute ?? bookingProvider.sampleRoutes.first;
    final bus = bookingProvider.selectedBus;
    final boarding = alloc?.boardingStop ?? bookingProvider.boardingStop ?? route.stops.first;
    final alighting = alloc?.alightingStop ?? bookingProvider.alightingStop ?? route.stops.last;
    final perSeatAmount = bus?.journeyFareLkr(route, boarding, alighting) ?? 0.0;
    final group = bookingProvider.groupAllocations;
    final isGroup = group.length > 1;
    final amount = isGroup ? perSeatAmount * group.length : perSeatAmount;
    final referenceCode = alloc?.referenceCode ?? 'SB-000000';
    final seatNumber = alloc?.seatNumber ?? '-';
    final passengerName = authProvider.passenger?.name ?? 'Passenger';

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Confirmed')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade50, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 13, color: Colors.orange.shade800),
                        const SizedBox(width: 5),
                        Text(
                          'PAY ONBOARD',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.orange.shade800, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isGroup ? '${group.length} Seats Reserved' : 'Seat $seatNumber Reserved',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primaryNavy),
                  ),
                  const SizedBox(height: 4),
                  Text('for $passengerName', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  if (isGroup) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final a in group)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                            child: Text(a.seatNumber, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('BOOKING REFERENCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5)),
                        Text(referenceCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryNavy, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Modern status tracker, the same pattern used for delivery / ride tracking.
            const Text('Booking Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
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
                  _buildStatusStep(
                    icon: Icons.event_seat,
                    label: 'Seat Reserved',
                    isDone: true,
                    isLast: false,
                  ),
                  _buildStatusStep(
                    icon: Icons.payments_outlined,
                    label: 'Pay Rs. ${amount.toStringAsFixed(0)} onboard',
                    isDone: false,
                    isCurrent: true,
                    isLast: false,
                  ),
                  _buildStatusStep(
                    icon: Icons.qr_code_2,
                    label: 'Conductor verifies & issues boarding QR',
                    isDone: false,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.priorityBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.priorityAccent.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.priorityText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isGroup
                          ? 'When you board, tell the conductor your name and reference $referenceCode. Pay Rs. ${amount.toStringAsFixed(0)} for all ${group.length} seats by cash or card - this bulk booking is kept as one ticket under your account, so only you can start, end or report on it.'
                          : 'When you board, tell the conductor your name and reference $referenceCode. Pay Rs. ${amount.toStringAsFixed(0)} by cash or card - they\'ll confirm your seat and hand you your ticket.',
                      style: const TextStyle(fontSize: 12, color: AppColors.priorityText, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BOARDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(boarding, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ALIGHTING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(alighting, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'This booking is saved to My Ticket on the home screen, so you can find your reference and track your bus any time before boarding.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),

            ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done — Go to Home', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildStatusStep({
    required IconData icon,
    required String label,
    required bool isDone,
    bool isCurrent = false,
    required bool isLast,
  }) {
    final color = isDone
        ? AppColors.generalAccent
        : (isCurrent ? Colors.orange.shade700 : AppColors.textMuted);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.generalBg : (isCurrent ? Colors.orange.shade50 : AppColors.backgroundLight),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(isDone ? Icons.check : icon, size: 15, color: color),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: AppColors.borderLight)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 20),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                  color: isDone ? AppColors.textDark : (isCurrent ? Colors.orange.shade800 : AppColors.textMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
