import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/tickets_provider.dart';
import '../../providers/journey_provider.dart';
import '../../models/ticket.dart';
import '../../constants/colors.dart';
import '../../widgets/qr_code_widget.dart';
import '../../widgets/app_bottom_nav_bar.dart';

// Where a passenger's ticket lives between booking and boarding.
// Paid-in-app bookings show the boarding QR here (and only here, besides
// the payment success screen); pay-onboard bookings show the booking
// reference instead, since no QR exists until the fare is actually paid.
//
// This is also where the trip is actually started: the conductor issues a
// one-time code when they check the ticket/reference, the passenger enters
// it here, and the app hands off to the Journey tab.
class MyTicketScreen extends StatefulWidget {
  final String? ticketId;

  const MyTicketScreen({super.key, this.ticketId});

  @override
  State<MyTicketScreen> createState() => _MyTicketScreenState();
}

class _MyTicketScreenState extends State<MyTicketScreen> {
  final _otpController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _startTrip(TicketsProvider ticketsProvider, JourneyProvider journeyProvider, Ticket ticket) {
    final error = ticketsProvider.startJourney(ticket.ticketId, _otpController.text.trim());
    setState(() => _error = error);
    if (error == null) {
      // Keep the existing Journey/incident-reporting flow (which reads
      // JourneyProvider) in sync with the ticket that just went active.
      journeyProvider.setCurrentAllocation(ticket.allocation);
      context.go('/journey');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketsProvider = Provider.of<TicketsProvider>(context);
    final journeyProvider = Provider.of<JourneyProvider>(context, listen: false);
    final ticket = widget.ticketId != null ? ticketsProvider.ticketById(widget.ticketId!) : null;

    if (ticket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Ticket')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                const Text(
                  'This ticket could not be found. Book a seat to see it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => context.go('/search'),
                  child: const Text('Find a Bus'),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      );
    }

    final alloc = ticket.allocation;
    final bus = ticket.bus;
    final isPaid = ticket.payment.isPaid;
    final isBulk = ticket.isBulk;

    return Scaffold(
      appBar: AppBar(title: const Text('My Ticket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (isPaid ? AppColors.generalAccent : Colors.orange).withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: ticket.journeyStarted
                          ? AppColors.priorityBg
                          : (isPaid ? AppColors.generalBg : Colors.orange.shade50),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ticket.journeyStarted ? Icons.directions_bus : (isPaid ? Icons.verified : Icons.schedule),
                          size: 13,
                          color: ticket.journeyStarted ? AppColors.priorityAccent : (isPaid ? AppColors.generalAccent : Colors.orange.shade800),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          ticket.journeyStarted ? 'JOURNEY IN PROGRESS' : (isPaid ? 'PAID · READY TO BOARD' : 'PAY ONBOARD'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: ticket.journeyStarted ? AppColors.priorityAccent : (isPaid ? AppColors.generalAccent : Colors.orange.shade800),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isPaid) ...[
                    QRCodeWidget(data: alloc.qrCode, size: 160),
                    const SizedBox(height: 10),
                    const Text(
                      'Show this QR to the conductor when boarding',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                    ),
                  ] else ...[
                    Text(
                      alloc.referenceCode,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.primaryNavy, letterSpacing: 1),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tell the conductor your name and this reference, then pay onboard',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Seat ${alloc.seatNumber} · ${bus.busNumber}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  Text(
                    '${alloc.boardingStop} → ${alloc.alightingStop}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  if (isBulk) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.priorityBg, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.groups_rounded, size: 13, color: AppColors.priorityText),
                          const SizedBox(width: 5),
                          Text(
                            'BULK TICKET · ${ticket.seatCount} SEATS',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.priorityText, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final a in ticket.extraAllocations)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(8)),
                            child: Text(a.seatNumber, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (ticket.journeyStarted)
              ElevatedButton.icon(
                onPressed: () => context.go('/journey'),
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Go to Journey Tracking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            else ...[
              // Start Trip: the conductor issues a one-time code when they
              // check the ticket/reference at the door.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ready to Board?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                    const SizedBox(height: 4),
                    const Text(
                      'When the conductor checks your ticket, they\'ll give you a boarding code. Enter it below to start your journey.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        filled: true,
                        fillColor: AppColors.backgroundLight,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(fontSize: 11, color: Colors.red)),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _startTrip(ticketsProvider, journeyProvider, ticket),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Start Trip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.go('/track-bus/${ticket.ticketId}'),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Track My Bus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryNavy,
                  side: const BorderSide(color: AppColors.primaryNavy),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 20),

            const Text('Trip Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _row('Route', ticket.route.routeName),
                  const Divider(height: 20),
                  _row('Bus', bus.busNumber),
                  const Divider(height: 20),
                  _row('Booking Reference', alloc.referenceCode),
                  const Divider(height: 20),
                  if (isBulk) ...[
                    _row('Seats', '${ticket.seatCount} (${ticket.allAllocations.map((a) => a.seatNumber).join(', ')})'),
                    const Divider(height: 20),
                  ],
                  _row('Fare', 'Rs. ${ticket.payment.amountLkr.toStringAsFixed(0)}${isBulk ? ' (all seats)' : ''}'),
                ],
              ),
            ),
            if (isBulk) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.generalBg, borderRadius: BorderRadius.circular(12)),
                child: const Text(
                  'This bulk booking is kept under your account only. Starting or ending the trip here applies to all seats at once.',
                  style: TextStyle(fontSize: 11, color: AppColors.generalText, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }
}
