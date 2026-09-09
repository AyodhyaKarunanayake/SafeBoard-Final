import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/booking_provider.dart';
import '../../models/bus_schedule.dart';
import '../../constants/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';

// Boarding/alighting stop, date & time are already chosen on the search
// screen - this screen only reviews those choices (plus the picked bus)
// before triggering seat allocation. It never re-asks for them.
class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final route = bookingProvider.selectedRoute ?? bookingProvider.sampleRoutes.first;
    final bus = bookingProvider.selectedBus ?? bookingProvider.bestFitBus;
    final boarding = bookingProvider.boardingStop ?? bookingProvider.searchBoardingStop ?? route.stops.first;
    final alighting = bookingProvider.alightingStop ?? bookingProvider.searchAlightingStop ?? route.stops.last;

    if (bus == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm Booking')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                const Text(
                  'No bus selected yet. Please go back and choose a bus from the search results.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => context.go('/search'),
                  child: const Text('Back to Search'),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
      );
    }

    final boardingTime = bus.timeAtStop(boarding, route);
    final alightingTime = bus.timeAtStop(alighting, route);
    final journeyMinutes = (boardingTime != null && alightingTime != null)
        ? alightingTime.difference(boardingTime).inMinutes
        : bus.durationMinutes;
    final dateStr = bookingProvider.searchDate != null ? _formatDate(bookingProvider.searchDate!) : '-';
    final journeyFare = bus.journeyFareLkr(route, boarding, alighting);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Booking Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/search');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review Your Journey',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
            ),
            const SizedBox(height: 4),
            const Text(
              'Please check these details before we allocate your seat.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bus.busNumber,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${bus.routeName} · ${bus.busType}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryNavy.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs. ${(journeyFare * bookingProvider.seatCount).toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            if (bookingProvider.isGroupBooking)
                              Text(
                                '${bookingProvider.seatCount} × Rs. ${journeyFare.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 9, color: Colors.white70),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  _detailRow(Icons.trip_origin, 'Boarding Stop', boarding, AppColors.generalAccent),
                  const SizedBox(height: 12),
                  _detailRow(Icons.place, 'Alighting Stop', alighting, AppColors.priorityAccent),
                  const SizedBox(height: 12),
                  _detailRow(Icons.calendar_today, 'Travel Date', dateStr, AppColors.primaryNavy),
                  const SizedBox(height: 12),
                  _detailRow(
                    Icons.access_time_filled,
                    'You board at',
                    boardingTime != null ? _formatTime(boardingTime) : bus.departureTimeFormatted,
                    AppColors.primaryNavy,
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    Icons.flag,
                    'Estimated arrival',
                    alightingTime != null ? _formatTime(alightingTime) : bus.arrivalTimeFormatted,
                    AppColors.primaryNavy,
                  ),
                  const SizedBox(height: 12),
                  _detailRow(Icons.timelapse, 'Journey duration', BusSchedule.formatDuration(journeyMinutes), AppColors.textMuted),
                  const SizedBox(height: 12),
                  _detailRow(
                    Icons.groups,
                    'Crowding level',
                    bus.crowdingLevel.toUpperCase(),
                    bus.crowdingLevel == 'low' ? Colors.green : Colors.orange.shade800,
                  ),
                  const SizedBox(height: 12),
                  _detailRow(Icons.verified_user, 'Safety rating', '★ ${bus.safetyRating}', AppColors.priorityText),
                  const SizedBox(height: 12),
                  _detailRow(Icons.person, 'Conductor', bus.conductorName, AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _seatCountChip('Priority', bus.availablePrioritySeats, AppColors.priorityAccent),
                  _seatCountChip('General', bus.availableGeneralSeats, AppColors.generalAccent),
                  _seatCountChip('Standing', bus.availableStanding, AppColors.standingAccent),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildGroupBookingSection(context, bookingProvider),
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: () {
                context.go('/requesting');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bookingProvider.isGroupBooking
                        ? 'Confirm & Request ${bookingProvider.seatCount} Seats'
                        : 'Confirm & Request Seat',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }

  // "If the seat booking count is 1, not to change anything" - this whole
  // section only ever mutates BookingProvider.seatCount/companions, which
  // the rest of the booking flow (RequestingScreen, AllocationResultScreen)
  // only branches on when seatCount > 1. At 1 seat, nothing downstream
  // changes.
  Widget _buildGroupBookingSection(BuildContext context, BookingProvider bookingProvider) {
    final isGroup = bookingProvider.isGroupBooking;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Booking for more than 1 seat?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 2),
                    Text(
                      'We\'ll run the allocation for everyone in your group.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isGroup,
                activeColor: AppColors.primaryNavy,
                onChanged: (val) => bookingProvider.setSeatCount(val ? 2 : 1),
              ),
            ],
          ),
          if (isGroup) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Number of seats', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppColors.primaryNavy,
                      onPressed: bookingProvider.seatCount > 2 ? () => bookingProvider.setSeatCount(bookingProvider.seatCount - 1) : null,
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${bookingProvider.seatCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppColors.primaryNavy,
                      onPressed: bookingProvider.seatCount < BookingProvider.maxSeatCount
                          ? () => bookingProvider.setSeatCount(bookingProvider.seatCount + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            const Text('Up to ${BookingProvider.maxSeatCount} seats per booking.', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            for (var i = 0; i < bookingProvider.companions.length; i++) ...[
              _buildCompanionForm(bookingProvider, i),
              if (i < bookingProvider.companions.length - 1) const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCompanionForm(BookingProvider bookingProvider, int index) {
    final companion = bookingProvider.companions[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Companion ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryNavy)),
          const SizedBox(height: 10),
          const Text('Gender', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _miniChip('Female', companion.gender == 'female', () => bookingProvider.updateCompanion(index, gender: 'female')),
              _miniChip('Male', companion.gender == 'male', () => bookingProvider.updateCompanion(index, gender: 'male')),
              _miniChip('Prefer not to say', companion.gender == 'prefer_not_to_say', () => bookingProvider.updateCompanion(index, gender: 'prefer_not_to_say')),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Mobility Needs', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _miniChip('None', companion.mobilityStatus == 'none', () => bookingProvider.updateCompanion(index, mobilityStatus: 'none')),
              _miniChip('Wheelchair', companion.mobilityStatus == 'wheelchair', () => bookingProvider.updateCompanion(index, mobilityStatus: 'wheelchair')),
              _miniChip('Walking aid', companion.mobilityStatus == 'walking_aid', () => bookingProvider.updateCompanion(index, mobilityStatus: 'walking_aid')),
              _miniChip('Elderly', companion.mobilityStatus == 'elderly', () => bookingProvider.updateCompanion(index, mobilityStatus: 'elderly')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Priority Zone Preference', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Switch(
                value: companion.safetyPreference,
                activeColor: AppColors.priorityAccent,
                onChanged: (val) => bookingProvider.updateCompanion(index, safetyPreference: val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryNavy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primaryNavy : AppColors.borderLight),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.w500, color: selected ? Colors.white : AppColors.textDark),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }

  Widget _seatCountChip(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${formattedHour.toString().padLeft(2, '0')}:$minute $period';
  }
}
