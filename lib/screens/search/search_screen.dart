import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/booking_provider.dart';
import '../../models/bus_schedule.dart';
import '../../models/route_model.dart';
import '../../constants/colors.dart';
import '../../widgets/zone_pill.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/stop_picker_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final allStops = bookingProvider.allUniqueStops;
    final hasCriteria = bookingProvider.hasCompleteSearchCriteria;
    final bestFitBus = bookingProvider.bestFitBus;
    final otherBuses = bookingProvider.otherUpcomingBuses;
    final filteredCount = bookingProvider.filteredBuses.length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            // Top Search Input Box
            _buildSearchControls(context, bookingProvider, allStops),

            // Search Results / Prompt-to-select / Empty State
            if (!hasCriteria)
              _buildSelectCriteriaPrompt()
            else if (filteredCount == 0)
              _buildEmptyState(bookingProvider)
            else ...[
              // Best Fit Suggested Bus Section (Prominently Highlighted)
              if (bestFitBus != null)
                _buildBestFitSection(context, bookingProvider, bestFitBus),

              // Secondary List: Other Upcoming Buses
              if (otherBuses.isNotEmpty)
                _buildOtherUpcomingSection(
                    context, bookingProvider, otherBuses),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
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
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find Bus & Seats',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          SizedBox(height: 6),
          Text('Search Route 87 by boarding and alighting stop.',
              style: TextStyle(fontSize: 13, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildSearchControls(
    BuildContext context,
    BookingProvider provider,
    List<String> allStops,
  ) {
    final dateStr = provider.searchDate == null
        ? null
        : '${provider.searchDate!.day} ${_getMonthName(provider.searchDate!.month)} ${provider.searchDate!.year}';
    final timeStr = provider.searchTime?.format(context);
    final route = provider.selectedRoute ?? provider.sampleRoutes.first;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.fromLTRB(18, 20, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Journey timeline: origin dot, connecting line, destination pin -
          // the familiar ride-booking pattern, simpler than boxed fields.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.generalAccent, width: 2.5),
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 44,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.borderLight,
                    ),
                    const Icon(Icons.location_on_rounded,
                        size: 16, color: AppColors.priorityAccent),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    _buildStopSelector(
                      context: context,
                      label: 'BOARDING STOP',
                      value: provider.searchBoardingStop,
                      placeholder: 'Tap to select boarding stop',
                      allStops: allStops,
                      route: route,
                      onSelected: (stop) =>
                          provider.setSearchCriteria(boardingStop: stop),
                    ),
                    const SizedBox(height: 18),
                    _buildStopSelector(
                      context: context,
                      label: 'ALIGHTING STOP',
                      value: provider.searchAlightingStop,
                      placeholder: 'Tap to select destination stop',
                      allStops: allStops,
                      route: route,
                      onSelected: (stop) =>
                          provider.setSearchCriteria(alightingStop: stop),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Material(
                  color: AppColors.backgroundLight,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => provider.swapStops(),
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(Icons.swap_vert_rounded,
                          color: AppColors.primaryNavy, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Date & Time Row
          Row(
            children: [
              Expanded(
                child: _buildDateTimeTile(
                  icon: Icons.calendar_today_rounded,
                  label: 'DATE',
                  valueText: dateStr,
                  placeholder: 'Select date',
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: provider.searchDate ?? DateTime.now(),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) {
                      provider.setSearchCriteria(date: picked);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateTimeTile(
                  icon: Icons.access_time_rounded,
                  label: 'TIME',
                  valueText: timeStr,
                  placeholder: 'Select time',
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: provider.searchTime ?? TimeOfDay.now(),
                      // Plain numeric HH:MM entry instead of the rotating
                      // clock dial - quicker and simpler to use.
                      initialEntryMode: TimePickerEntryMode.input,
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(alwaysUse24HourFormat: false),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      provider.setSearchCriteria(time: picked);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Zone Legend - a quiet footer note, not a primary input.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ZonePill(zone: 'priority', small: true),
                ZonePill(zone: 'general', small: true),
                ZonePill(zone: 'standing', small: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopSelector({
    required BuildContext context,
    required String label,
    required String? value,
    required String placeholder,
    required List<String> allStops,
    required RouteModel route,
    required ValueChanged<String> onSelected,
  }) {
    final isPlaceholder = value == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _showStopPickerModal(context, label, allStops, route, onSelected);
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value ?? placeholder,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isPlaceholder ? FontWeight.w500 : FontWeight.bold,
                    color: isPlaceholder
                        ? AppColors.textMuted
                        : AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textMuted.withOpacity(0.6), size: 20),
        ],
      ),
    );
  }

  Widget _buildDateTimeTile({
    required IconData icon,
    required String label,
    required String? valueText,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final hasValue = valueText != null;
    return Material(
      color: AppColors.backgroundLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 15, color: AppColors.primaryNavy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(
                      valueText ?? placeholder,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            hasValue ? FontWeight.bold : FontWeight.w500,
                        color:
                            hasValue ? AppColors.textDark : AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStopPickerModal(
    BuildContext context,
    String title,
    List<String> stops,
    RouteModel route,
    ValueChanged<String> onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StopPickerSheet(
          title: title,
          stops: stops,
          route: route,
          onSelected: onSelected,
        );
      },
    );
  }

  Widget _buildBestFitSection(
    BuildContext context,
    BookingProvider provider,
    BusSchedule bus,
  ) {
    final route = provider.selectedRoute ?? provider.sampleRoutes.first;
    final boardingTime = provider.boardingTimeFor(bus);
    final alightingTime = provider.alightingTimeFor(bus);
    final target = provider.targetSearchDateTime;
    final diff = (boardingTime != null && target != null)
        ? boardingTime.difference(target).inMinutes
        : 0;
    final subJourneyMinutes = (boardingTime != null && alightingTime != null)
        ? alightingTime.difference(boardingTime).inMinutes
        : bus.durationMinutes;
    final journeyFare = bus.journeyFareLkr(
      route,
      provider.searchBoardingStop ?? bus.startPoint,
      provider.searchAlightingStop ?? bus.endPoint,
    );

    String timeBadgeText;
    if (diff == 0) {
      timeBadgeText =
          'Reaches ${provider.searchBoardingStop} right at your chosen time';
    } else if (diff > 0) {
      timeBadgeText =
          'Reaches ${provider.searchBoardingStop} in $diff mins (+${diff}m from chosen time)';
    } else {
      timeBadgeText =
          'Reaches ${provider.searchBoardingStop} ${diff.abs()} mins before chosen time';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primaryNavy.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Best Fit Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.primaryNavy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.stars_rounded, color: Colors.amber, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'BEST FIT SUGGESTION',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user,
                          color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '★ ${bus.safetyRating}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Match Info Strip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.priorityBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.priorityAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 14, color: AppColors.priorityText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          timeBadgeText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.priorityText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Bus Route & Number Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bus.busNumber,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${bus.routeName} · ${bus.busType}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
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
                      child: Text(
                        'Rs. ${journeyFare.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Departure -> Arrival Timeline
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatTime(boardingTime),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            provider.searchBoardingStop ?? bus.startPoint,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            BusSchedule.formatDuration(subJourneyMinutes),
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 2),
                          const Row(
                            children: [
                              Icon(Icons.circle,
                                  size: 6, color: AppColors.generalAccent),
                              SizedBox(width: 4),
                              SizedBox(
                                width: 48,
                                child: Divider(
                                    color: AppColors.textMuted, thickness: 1.5),
                              ),
                              Icon(Icons.arrow_forward,
                                  size: 12, color: AppColors.priorityAccent),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bus.crowdingLevel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: bus.crowdingLevel == 'low'
                                  ? Colors.green
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTime(alightingTime),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            provider.searchAlightingStop ?? bus.endPoint,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Seat Availability Mini Bars - a 2x2 grid (4 zones no
                // longer fit comfortably in one row).
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSeatAvailabilityItem(
                            label: 'Priority Zone',
                            avail: bus.availablePrioritySeats,
                            total: bus.totalPrioritySeats,
                            color: AppColors.priorityAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSeatAvailabilityItem(
                            label: 'General Zone',
                            avail: bus.availableGeneralSeats,
                            total: bus.totalGeneralSeats,
                            color: AppColors.generalAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSeatAvailabilityItem(
                            label: 'Limited Zone',
                            avail: bus.availableLimitedSeats,
                            total: bus.totalLimitedSeats,
                            color: AppColors.limitedAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSeatAvailabilityItem(
                            label: 'Standing',
                            avail: bus.availableStanding,
                            total: bus.totalStanding,
                            color: AppColors.standingAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Direct Select / Book CTA Button
                ElevatedButton(
                  onPressed: () {
                    provider.selectBus(bus);
                    context.go('/stop-select');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Request Seat on this Bus',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherUpcomingSection(
    BuildContext context,
    BookingProvider provider,
    List<BusSchedule> buses,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Other Upcoming Buses (${buses.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const Text(
                'Sorted by Time',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: buses.length,
            itemBuilder: (context, index) {
              final bus = buses[index];
              final route =
                  provider.selectedRoute ?? provider.sampleRoutes.first;
              final boardingTime = provider.boardingTimeFor(bus);
              final target = provider.targetSearchDateTime;
              final diff = (boardingTime != null && target != null)
                  ? boardingTime.difference(target).inMinutes
                  : 0;
              String diffStr = diff >= 0 ? '+$diff mins' : '${diff}m';
              final journeyFare = bus.journeyFareLkr(
                route,
                provider.searchBoardingStop ?? bus.startPoint,
                provider.searchAlightingStop ?? bus.endPoint,
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              _formatTime(boardingTime),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundLight,
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: AppColors.borderLight),
                              ),
                              child: Text(
                                diffStr,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.priorityBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Rs. ${journeyFare.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: AppColors.primaryNavy),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${bus.busNumber} · ${bus.routeName}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.circle,
                                size: 6, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              bus.crowdingLevel,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.priorityBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${bus.availablePrioritySeats} Priority',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.priorityText),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.generalBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${bus.availableGeneralSeats} General',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.generalText),
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton(
                          onPressed: () {
                            provider.selectBus(bus);
                            context.go('/stop-select');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryNavy,
                            side:
                                const BorderSide(color: AppColors.primaryNavy),
                            minimumSize: const Size(80, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Select',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectCriteriaPrompt() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_rounded, size: 54, color: AppColors.textMuted),
          SizedBox(height: 14),
          Text(
            'Select Your Journey Details',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy),
          ),
          SizedBox(height: 6),
          Text(
            'Choose a boarding stop, alighting stop, date and time above to see buses reaching your stop around the time you need.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BookingProvider provider) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          const Icon(Icons.directions_bus_outlined,
              size: 54, color: AppColors.textMuted),
          const SizedBox(height: 14),
          const Text(
            'No Direct Buses Found',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 6),
          const Text(
            'We couldn\'t find direct buses matching your chosen boarding and destination stops in that direction. Try switching stops or picking a major corridor below.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          const Text(
            'Popular Routes in Colombo',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: provider.sampleRoutes.map((route) {
              return ActionChip(
                label: Text(
                    '${route.routeName}: ${route.startPoint.split(' ').first} → ${route.endPoint.split(' ').first}'),
                onPressed: () {
                  provider.selectRoute(route);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatAvailabilityItem({
    required String label,
    required int avail,
    required int total,
    required Color color,
  }) {
    double ratio = avail / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark),
            ),
            Text(
              '$avail left',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${formattedHour.toString().padLeft(2, '0')}:$minute $period';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}
