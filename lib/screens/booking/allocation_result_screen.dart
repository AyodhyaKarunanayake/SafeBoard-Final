import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/journey_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/seat_allocation.dart';
import '../../constants/colors.dart';
import '../../widgets/zone_pill.dart';
import '../../widgets/bus_diagram.dart';
import '../../widgets/app_bottom_nav_bar.dart';

// Seat letters left-to-right are A, B (left block, 2 seats) then C, D, E
// (right block, 3 seats) - see lib/widgets/bus_diagram.dart for the layout.
String _sideDescription(String seatNumber) {
  final letter = seatNumber.isNotEmpty ? seatNumber[seatNumber.length - 1].toUpperCase() : '';
  switch (letter) {
    case 'A':
      return 'Left window';
    case 'B':
      return 'Left aisle';
    case 'C':
      return 'Right aisle';
    case 'D':
      return 'Right middle';
    case 'E':
    case 'F':
      return 'Right window';
    default:
      return 'Onboard seat';
  }
}

class _SeatZoneInfo {
  final String zoneKey;
  final String zoneLabel;
  final String positionDescription;
  const _SeatZoneInfo(this.zoneKey, this.zoneLabel, this.positionDescription);
}

_SeatZoneInfo _zoneInfoFor(String seatNumber) {
  final isStanding = seatNumber.toUpperCase().startsWith('STANDING');
  final rowNum = isStanding ? null : int.tryParse(RegExp(r'^(\d+)').firstMatch(seatNumber)?.group(1) ?? '');
  if (isStanding) {
    return const _SeatZoneInfo('standing', 'Standing · Near Rear Door', 'Standing space near the rear door for a quick exit.');
  } else if (rowNum != null && rowNum <= 3) {
    return _SeatZoneInfo('priority', 'Priority Zone · Row $rowNum', 'Near front door · ${_sideDescription(seatNumber)}');
  } else if (rowNum == 12) {
    return _SeatZoneInfo('general', 'Rear Bench · Row 12', 'Rear bench seat · ${_sideDescription(seatNumber)}');
  }
  return _SeatZoneInfo('general', 'General Zone · Row ${rowNum ?? 5}', _sideDescription(seatNumber));
}

class AllocationResultScreen extends StatelessWidget {
  const AllocationResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final journeyProvider = Provider.of<JourneyProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);

    // Group booking (more than 1 seat) - a distinct, multi-seat summary.
    // Single-seat bookings (the default) fall straight through to the
    // unchanged flow below.
    final group = bookingProvider.groupAllocations;
    if (group.length > 1) {
      return _buildGroupResult(context, group, bookingProvider);
    }

    final alloc = journeyProvider.currentAllocation ?? bookingProvider.lastAllocation;
    final seatNumber = alloc?.seatNumber ?? '3A';
    final referenceCode = alloc?.referenceCode ?? 'SB-000000';
    final boarding = alloc?.boardingStop ?? 'Colombo (Pettah)';
    final alighting = alloc?.alightingStop ?? 'Jaffna Main Bus Stand';

    final isStanding = seatNumber.toUpperCase().startsWith('STANDING');
    final rowNum = isStanding ? null : int.tryParse(RegExp(r'^(\d+)').firstMatch(seatNumber)?.group(1) ?? '');
    final String zoneKey;
    final String zoneLabel;
    final String positionDescription;
    if (isStanding) {
      zoneKey = 'standing';
      zoneLabel = 'Standing · Near Rear Door';
      positionDescription = 'Standing space near the rear door for a quick exit.';
    } else if (rowNum != null && rowNum <= 3) {
      zoneKey = 'priority';
      zoneLabel = 'Priority Zone · Row $rowNum';
      positionDescription = 'Near front door · ${_sideDescription(seatNumber)}';
    } else if (rowNum == 12) {
      zoneKey = 'general';
      zoneLabel = 'Rear Bench · Row 12';
      positionDescription = 'Rear bench seat · ${_sideDescription(seatNumber)}';
    } else {
      zoneKey = 'general';
      zoneLabel = 'General Zone · Row ${rowNum ?? 5}';
      positionDescription = _sideDescription(seatNumber);
    }
    final zoneBg = AppColors.getZoneBg(zoneKey);
    final zoneAccent = AppColors.getZoneAccent(zoneKey);
    final zoneText = AppColors.getZoneText(zoneKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Allocation Confirmed'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zone Banner at top - reflects the actual allocated zone
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: zoneBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: zoneAccent.withOpacity(0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: zoneAccent.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        zoneLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: zoneText,
                        ),
                      ),
                      ZonePill(zone: zoneKey, small: true),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isStanding ? 'Standing' : seatNumber,
                            style: TextStyle(
                              fontSize: isStanding ? 28 : 32,
                              fontWeight: FontWeight.w900,
                              color: zoneAccent,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            positionDescription,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: zoneText,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: zoneAccent.withOpacity(0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'BOOKING REF',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 0.5),
                                ),
                                Text(
                                  referenceCode,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: zoneAccent),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 110,
                            child: Text(
                              'Your boarding QR unlocks after payment',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 10, color: zoneText.withOpacity(0.8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSeatChangeControls(context, bookingProvider, journeyProvider),
            const SizedBox(height: 20),

            // Boarding & Alighting Stop Chips Side by Side
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BOARDING',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          boarding,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ALIGHTING',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alighting,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // "Why this seat?" Section
            const Text(
              'Why this seat?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
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
                  if (isStanding)
                    _buildWhyRow(
                      Icons.directions_walk,
                      AppColors.standingAccent,
                      'Short-Distance Standing Preference',
                      'Seats were nearly full, so short-distance passengers stand to keep seats free for longer journeys.',
                    )
                  else
                    _buildWhyRow(
                      Icons.shield_outlined,
                      AppColors.priorityAccent,
                      'Safety Preference Matched',
                      'Your active safety preference granted top-tier Priority Zone access.',
                    ),
                  const Divider(height: 16),
                  _buildWhyRow(
                    Icons.sensor_door_outlined,
                    AppColors.generalAccent,
                    isStanding ? 'Rear Door Proximity' : 'Front Door Proximity',
                    isStanding
                        ? 'Positioned near the rear exit for a quick, low-friction alighting.'
                        : 'Positioned near the front entrance for swift exit & conductor visibility.',
                  ),
                  const Divider(height: 16),
                  _buildWhyRow(
                    Icons.swap_horizontal_circle_outlined,
                    AppColors.standingAccent,
                    'Gender & Standing Spacing',
                    'Algorithm enforced maximum buffer from standing congestion.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // "Your position on the bus" Section with Custom BusDiagram Widget
            const Text(
              'Your position on the bus',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 10),
            BusDiagram(allocatedSeat: seatNumber),
            const SizedBox(height: 28),

            // Action Buttons
            ElevatedButton(
              onPressed: () => context.go('/payment-options'),
              child: const Text('Continue to payment →'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: referenceCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Booking reference $referenceCode copied.')),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryNavy,
                side: const BorderSide(color: AppColors.primaryNavy),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Copy booking reference'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }

  // Lets the passenger ask for a different seat (limited chances), and
  // freely browse back to a suggestion they saw earlier without spending
  // one of those chances.
  Widget _buildSeatChangeControls(
    BuildContext context,
    BookingProvider bookingProvider,
    JourneyProvider journeyProvider,
  ) {
    final total = bookingProvider.allocationHistory.length;
    final current = bookingProvider.currentSuggestionNumber;
    final remaining = bookingProvider.remainingSeatChanges;
    final busy = bookingProvider.isAllocating;

    void sync(SeatAllocation? result) {
      if (result != null) journeyProvider.setCurrentAllocation(result);
    }

    Future<void> requestAnother() async {
      final passenger = Provider.of<AuthProvider>(context, listen: false).passenger;
      if (passenger == null) return;
      final result = await bookingProvider.requestAlternateSeat(passenger);
      journeyProvider.setCurrentAllocation(result);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Not the right seat?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
              ),
              if (total > 1)
                Text('Suggestion $current of $total', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (total > 1) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy || !bookingProvider.canGoToPreviousSuggestion
                        ? null
                        : () => sync(bookingProvider.goToPreviousSuggestion()),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Previous', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryNavy),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy || !bookingProvider.canGoToNextSuggestion
                        ? null
                        : () => sync(bookingProvider.goToNextSuggestion()),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Next', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryNavy),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: total > 1 ? 2 : 1,
                child: ElevatedButton.icon(
                  onPressed: busy || !bookingProvider.canRequestAnotherSeat ? null : requestAnother,
                  icon: const Icon(Icons.shuffle, size: 16),
                  label: Text(
                    bookingProvider.canRequestAnotherSeat ? 'Request another seat' : 'No more seat changes',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
                ),
              ),
            ],
          ),
          if (bookingProvider.canRequestAnotherSeat) ...[
            const SizedBox(height: 6),
            Text(
              '$remaining seat change${remaining == 1 ? '' : 's'} left',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupResult(BuildContext context, List<SeatAllocation> group, BookingProvider bookingProvider) {
    final bus = bookingProvider.selectedBus;
    final route = bookingProvider.selectedRoute ?? bookingProvider.sampleRoutes.first;
    final boarding = group.first.boardingStop;
    final alighting = group.first.alightingStop;
    final perSeatFare = bus?.journeyFareLkr(route, boarding, alighting) ?? 0.0;
    final totalFare = perSeatFare * group.length;
    final seatNumbers = group.map((a) => a.seatNumber).toList();

    return Scaffold(
      appBar: AppBar(title: Text('${group.length} Seats Confirmed')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primaryNavy, Color(0xFF2D4A9A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.primaryNavy.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text('${group.length} seats allocated', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('$boarding → $alighting', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 16),
                  Text('Rs. ${totalFare.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.0)),
                  const SizedBox(height: 4),
                  Text('${group.length} × Rs. ${perSeatFare.toStringAsFixed(0)} total', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('Your Seats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
            const SizedBox(height: 10),
            for (var i = 0; i < group.length; i++) ...[
              _buildGroupSeatCard(group[i], i == 0 ? 'You' : 'Companion $i'),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),

            const Text('Seating Map', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
            const SizedBox(height: 10),
            BusDiagram(allocatedSeat: seatNumbers.first, extraAllocatedSeats: seatNumbers.skip(1).toList()),
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: () => context.go('/payment-options'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue to payment →'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildGroupSeatCard(SeatAllocation alloc, String label) {
    final info = _zoneInfoFor(alloc.seatNumber);
    final bg = AppColors.getZoneBg(info.zoneKey);
    final accent = AppColors.getZoneAccent(info.zoneKey);
    final text = AppColors.getZoneText(info.zoneKey);
    final isStanding = alloc.seatNumber.toUpperCase().startsWith('STANDING');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: accent.withOpacity(0.35))),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: accent.withOpacity(0.4))),
            child: isStanding
                ? Icon(Icons.accessibility_new, color: accent, size: 20)
                : Text(alloc.seatNumber, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: text)),
                const SizedBox(height: 2),
                Text(info.zoneLabel, style: TextStyle(fontSize: 11, color: text.withOpacity(0.85))),
              ],
            ),
          ),
          ZonePill(zone: info.zoneKey, small: true),
        ],
      ),
    );
  }

  Widget _buildWhyRow(IconData icon, Color color, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
