import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/journey_provider.dart';
import '../../providers/tickets_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../models/ticket.dart';
import '../../models/bus_schedule.dart';
import '../../models/route_model.dart';
import '../../models/seat_allocation.dart';
import '../../constants/colors.dart';
import '../../widgets/zone_pill.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/bus_diagram.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/qr_code_widget.dart';
import '../../widgets/tonal_button.dart';

// Seat -> gender-aware zone, mirroring the same row rule used at allocation
// time (rows 1-3 priority, row 12 the rear bench, everything else general;
// see allocation_result_screen.dart's _sideDescription/zoneKey logic).
class _SeatZone {
  final String key; // 'priority' | 'general' | 'standing'
  final String label;
  const _SeatZone(this.key, this.label);

  static _SeatZone forSeat(String seatNumber) {
    if (seatNumber.toUpperCase().startsWith('STANDING')) {
      return const _SeatZone('standing', 'Standing · Limited Zone');
    }
    final rowNum = int.tryParse(RegExp(r'^(\d+)').firstMatch(seatNumber)?.group(1) ?? '');
    if (rowNum != null && rowNum <= 3) return _SeatZone('priority', 'Priority Zone · Row $rowNum');
    if (rowNum == 12) return const _SeatZone('general', 'Rear Bench · Row 12');
    return _SeatZone('general', 'General Zone · Row ${rowNum ?? '-'}');
  }
}

// Bus progress along the FULL fixed route.stops order (Colombo -> Jaffna),
// as a fractional index - same simulated timetable-based approach used by
// TrackBusScreen, since Route 87 has no real GPS feed to read from.
class _RouteProgress {
  final double fullIndex;
  final String statusLabel;

  const _RouteProgress({required this.fullIndex, required this.statusLabel});

  static _RouteProgress compute(BusSchedule bus, RouteModel route) {
    final now = DateTime.now();
    final elapsedMinutes = now.difference(bus.departureDateTime).inMinutes;
    final startIndex = route.stops.indexWhere((s) => s.toLowerCase() == bus.startPoint.toLowerCase());
    final endIndex = route.stops.indexWhere((s) => s.toLowerCase() == bus.endPoint.toLowerCase());

    if (elapsedMinutes < 0) {
      return _RouteProgress(fullIndex: (startIndex == -1 ? 0 : startIndex).toDouble(), statusLabel: 'NOT YET DEPARTED');
    }
    final fraction = (elapsedMinutes / bus.durationMinutes).clamp(0.0, 1.0);
    if (fraction >= 1.0) {
      return _RouteProgress(fullIndex: (endIndex == -1 ? route.stops.length - 1 : endIndex).toDouble(), statusLabel: 'ARRIVED');
    }

    final isForward = startIndex <= endIndex;
    final distFromBusStart = fraction * route.distanceKm;
    final distFromRouteOrigin = isForward ? distFromBusStart : route.distanceKm - distFromBusStart;

    var lowerIdx = 0;
    for (var i = 0; i < route.stopDistancesKm.length; i++) {
      if (route.stopDistancesKm[i] <= distFromRouteOrigin) lowerIdx = i;
    }
    final upperIdx = (lowerIdx + 1 < route.stopDistancesKm.length) ? lowerIdx + 1 : lowerIdx;
    final segStart = route.stopDistancesKm[lowerIdx];
    final segEnd = route.stopDistancesKm[upperIdx];
    final segFraction = segEnd > segStart ? ((distFromRouteOrigin - segStart) / (segEnd - segStart)).clamp(0.0, 1.0) : 0.0;

    return _RouteProgress(fullIndex: lowerIdx + segFraction, statusLabel: 'EN ROUTE');
  }
}

// Interpolates the bus's real-world position between the two route stops
// it's currently between, using [RouteModel.stopCoordinates] (real lat/lng
// already on the model) and the same fractional progress index the rest of
// this screen uses. Returns null if this route has no coordinate data.
LatLng? _interpolatedBusLatLng(RouteModel route, double fullIndex) {
  final loc = route.interpolatedLocation(fullIndex);
  return loc == null ? null : LatLng(loc.lat, loc.lng);
}

String _etaLabel(int minutes) {
  if (minutes <= 0) return 'now';
  if (minutes < 60) return '$minutes min';
  return BusSchedule.formatDuration(minutes);
}

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> with SingleTickerProviderStateMixin {
  Timer? _refreshTimer;
  late final AnimationController _pulseController;
  final MapController _mapController = MapController();
  bool _userPannedMap = false;
  bool _autoEndInFlight = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    // Simulated GPS refresh cadence (5-10s) - there's no real device/bus
    // location feed in this app, so position is re-derived each tick from
    // the bus's timetable, same as elsewhere in the app.
    _refreshTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) return;
      _checkAutoEndJourney();
      if (mounted) setState(() {});
    });
    // Catches an already-overdue journey the moment this tab is opened,
    // rather than waiting for the first timer tick.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAutoEndJourney());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // A passenger who forgets to tap "I've reached my stop" shouldn't be left
  // in an "active journey" state forever - once the bus has been past the
  // alighting halt for 5 minutes, the journey ends itself and the seat is
  // freed for the allocation engine, same as the manual end-journey action.
  void _checkAutoEndJourney() {
    if (!mounted || _autoEndInFlight) return;
    final ticketsProvider = Provider.of<TicketsProvider>(context, listen: false);
    final ticket = ticketsProvider.activeTicket;
    if (ticket == null) return;

    final alightTime = ticket.bus.timeAtStop(ticket.allocation.alightingStop, ticket.route);
    if (alightTime == null) return;
    if (DateTime.now().isBefore(alightTime.add(const Duration(minutes: 5)))) return;

    _autoEndInFlight = true;
    final journeyProvider = Provider.of<JourneyProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    ticketsProvider.endJourney(ticket.ticketId);
    journeyProvider.endJourney();
    bookingProvider.resetSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/rating/${ticket.ticketId}');
    });
  }

  void _autoRecenterMap(LatLng busLatLng) {
    if (_userPannedMap) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(busLatLng, _mapController.camera.zoom);
      } catch (_) {
        // Map not attached yet on the very first frame - safe to skip.
      }
    });
  }

  Future<void> _confirmEndJourney(TicketsProvider ticketsProvider, JourneyProvider journeyProvider, Ticket ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End your journey?'),
        content: const Text('This confirms you\'ve reached your stop and frees your seat for the allocation engine.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
            child: const Text('Yes, I\'ve arrived'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ticketsProvider.endJourney(ticket.ticketId);
    journeyProvider.endJourney();
    Provider.of<BookingProvider>(context, listen: false).resetSearch();
    if (mounted) context.go('/rating/${ticket.ticketId}');
  }

  void _showSeatingMap(String seatNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                const Text('Bus Seating Map', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                const SizedBox(height: 12),
                BusDiagram(allocatedSeat: seatNumber),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConductorMessageSheet(BuildContext context) {
    const presets = [
      'Can I get a seat change?',
      'How many stops to my destination?',
      'The bus feels overcrowded right now',
      'Thank you, all good',
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Text the conductor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
            const SizedBox(height: 4),
            const Text('For non-emergency questions only. Use the SOS button for anything urgent.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 14),
            for (final preset in presets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sent to conductor: "$preset"'), duration: const Duration(seconds: 2)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(child: Text(preset, style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600))),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final journeyProvider = Provider.of<JourneyProvider>(context);
    final ticketsProvider = Provider.of<TicketsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final ticket = ticketsProvider.activeTicket;

    if (ticket == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.navigation_outlined, size: 48, color: AppColors.textMuted.withOpacity(0.6)),
                const SizedBox(height: 12),
                const Text('No journey in progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 6),
                const Text(
                  'Once the conductor checks your ticket and you enter your boarding code from My Ticket, live tracking and safety tools show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
      );
    }

    final bus = ticket.bus;
    final route = ticket.route;
    final alloc = ticket.allocation;
    final zone = _SeatZone.forSeat(alloc.seatNumber);

    final rawBoardIdx = route.stops.indexWhere((s) => s.toLowerCase() == alloc.boardingStop.toLowerCase());
    final rawAlightIdx = route.stops.indexWhere((s) => s.toLowerCase() == alloc.alightingStop.toLowerCase());
    final boardIdx = rawBoardIdx == -1 ? 0 : rawBoardIdx;
    final alightIdx = rawAlightIdx == -1 ? route.stops.length - 1 : rawAlightIdx;
    final isForward = boardIdx <= alightIdx;
    final lo = isForward ? boardIdx : alightIdx;
    final hi = isForward ? alightIdx : boardIdx;

    // Passenger's own segment only - boarding halt through alighting halt,
    // in the order they'll actually pass through them.
    final segmentStops = isForward ? route.stops.sublist(lo, hi + 1) : route.stops.sublist(lo, hi + 1).reversed.toList();

    final progress = _RouteProgress.compute(bus, route);
    final segFraction = (isForward ? (progress.fullIndex - lo) : (hi - progress.fullIndex)).clamp(0.0, (segmentStops.length - 1).toDouble());
    final currentSegIndex = segFraction.floor().clamp(0, segmentStops.length - 1);

    final nextSegIndex = currentSegIndex + 1 < segmentStops.length ? currentSegIndex + 1 : null;
    String? nextHaltText;
    if (nextSegIndex != null) {
      final nextStopName = segmentStops[nextSegIndex];
      final nextTime = bus.timeAtStop(nextStopName, route);
      if (nextTime != null) {
        final diffMin = nextTime.difference(DateTime.now()).inMinutes;
        nextHaltText = 'Approaching $nextStopName — ${_etaLabel(diffMin < 0 ? 0 : diffMin)}';
      } else {
        nextHaltText = 'Next: $nextStopName';
      }
    } else {
      nextHaltText = 'Approaching your destination — ${alloc.alightingStop}';
    }

    final boardTime = bus.timeAtStop(alloc.boardingStop, route);
    final alightTime = bus.timeAtStop(alloc.alightingStop, route);
    final now = DateTime.now();
    final elapsedText = boardTime != null ? BusSchedule.formatDuration(now.difference(boardTime).inMinutes.clamp(0, 100000)) : '--';
    final remainingText = alightTime != null ? BusSchedule.formatDuration(alightTime.difference(now).inMinutes.clamp(0, 100000)) : '--';
    final tripFraction = hi > lo ? ((progress.fullIndex - lo) / (hi - lo)).clamp(0.0, 1.0) : 1.0;

    final occupancyFraction = (journeyProvider.currentOccupancy / 42.0).clamp(0.0, 1.0);
    final Color occupancyColor = occupancyFraction >= 0.9
        ? AppColors.emergencyRed
        : occupancyFraction >= 0.75
            ? AppColors.standingAccent
            : AppColors.generalAccent;
    final occupancyLabel = occupancyFraction >= 0.9 ? 'CRITICAL' : (occupancyFraction >= 0.75 ? 'HIGH' : 'MODERATE');

    final int nearbyCount;
    final int nearbyCapacity;
    switch (zone.key) {
      case 'priority':
        nearbyCount = journeyProvider.priorityOccupied;
        nearbyCapacity = 12;
        break;
      case 'standing':
        nearbyCount = journeyProvider.standingCount;
        nearbyCapacity = 18;
        break;
      default:
        nearbyCount = journeyProvider.generalOccupied;
        nearbyCapacity = 30;
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(bus, route, occupancyFraction, occupancyColor, occupancyLabel),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLiveMapCard(route, progress, boardIdx, alightIdx, nextHaltText),
                      const SizedBox(height: 16),
                      _buildSeatCard(alloc, zone, ticket),
                      const SizedBox(height: 12),
                      _buildTripProgressCard(alloc, tripFraction, elapsedText, remainingText),
                      const SizedBox(height: 12),
                      _buildNearbyCard(zone, nearbyCount, nearbyCapacity),
                      const SizedBox(height: 20),
                      const Text('Your Journey (boarding → destination)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                      const SizedBox(height: 12),
                      _buildSegmentList(segmentStops, currentSegIndex),
                      const SizedBox(height: 20),
                      _buildQuickActions(context, ticket),
                      const SizedBox(height: 10),
                      TonalButton(
                        icon: Icons.warning_amber_rounded,
                        label: 'Report a safety incident',
                        color: AppColors.emergencyRed,
                        onPressed: () => context.go('/incident'),
                      ),
                      const SizedBox(height: 10),
                      TonalButton(
                        icon: Icons.check_circle_outline,
                        label: 'I\'ve reached my stop',
                        color: AppColors.primaryNavy,
                        onPressed: () => _confirmEndJourney(ticketsProvider, journeyProvider, ticket),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TonalButton(
                          icon: Icons.folder_outlined,
                          label: 'My reports',
                          color: AppColors.textMuted,
                          dense: true,
                          expand: false,
                          onPressed: () => context.go('/incident-history'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Mandatory SOS control - fixed in the thumb-reachable bottom
          // third, above the bottom nav bar, never buried in a menu.
          Positioned(
            right: 20,
            bottom: 96,
            child: SOSButton(
              onTrigger: () => journeyProvider.triggerSOS(
                passengerId: authProvider.passenger?.passengerId ?? 'p_28745',
                journeyId: alloc.journeyId,
                seatLocation: alloc.seatNumber,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildHeader(BusSchedule bus, RouteModel route, double occupancyFraction, Color occupancyColor, String occupancyLabel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, right: 20, top: 56, bottom: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF12163F), AppColors.primaryNavy, Color(0xFF2D4A9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${route.routeName} · ${bus.busNumber}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.15 + 0.1 * _pulseController.value),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      const Text('JOURNEY IN PROGRESS', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Conductor: ${bus.conductorName}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.groups_rounded, size: 16, color: occupancyColor),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: occupancyFraction,
                      minHeight: 7,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(occupancyColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(occupancyLabel, style: TextStyle(color: occupancyColor, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // A real, geographic map (OpenStreetMap tiles via flutter_map) rather
  // than a schematic strip - works on every platform this app runs on,
  // including the web build in a browser, with no API key required.
  Widget _buildLiveMapCard(RouteModel route, _RouteProgress progress, int boardIdx, int alightIdx, String nextHaltText) {
    final hasCoords = route.stopCoordinates.length == route.stops.length && route.stopCoordinates.isNotEmpty;
    final busLatLng = hasCoords ? _interpolatedBusLatLng(route, progress.fullIndex) : null;
    final routePoints = hasCoords ? route.stopCoordinates.map((c) => LatLng(c.lat, c.lng)).toList() : const <LatLng>[];

    if (busLatLng != null) _autoRecenterMap(busLatLng);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.directions_bus_filled_rounded, size: 16, color: AppColors.primaryNavy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nextHaltText,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.generalBg, borderRadius: BorderRadius.circular(6)),
                  child: const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.generalAccent)),
                ),
              ],
            ),
          ),
          if (busLatLng == null || routePoints.isEmpty)
            const SizedBox(
              height: 220,
              child: Center(
                child: Text('Map unavailable for this route', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
            )
          else
            SizedBox(
              height: 260,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: busLatLng,
                      initialZoom: 10,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                      onPositionChanged: (camera, hasGesture) {
                        if (hasGesture) _userPannedMap = true;
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'lk.safeboard.app',
                        maxZoom: 18,
                      ),
                      PolylineLayer(polylines: [
                        Polyline(points: routePoints, strokeWidth: 4, color: AppColors.primaryNavy.withOpacity(0.55)),
                      ]),
                      MarkerLayer(markers: [
                        for (var i = 0; i < routePoints.length; i++)
                          if (i != boardIdx && i != alightIdx)
                            Marker(
                              point: routePoints[i],
                              width: 10,
                              height: 10,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: i <= progress.fullIndex ? AppColors.generalAccent : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.generalAccent, width: 1.5),
                                ),
                              ),
                            ),
                        if (boardIdx >= 0 && boardIdx < routePoints.length)
                          Marker(
                            point: routePoints[boardIdx],
                            width: 30,
                            height: 30,
                            child: const Icon(Icons.trip_origin, color: AppColors.priorityAccent, size: 24),
                          ),
                        if (alightIdx >= 0 && alightIdx < routePoints.length)
                          Marker(
                            point: routePoints[alightIdx],
                            width: 34,
                            height: 34,
                            child: const Icon(Icons.flag_circle, color: AppColors.emergencyRed, size: 28),
                          ),
                        // The passenger is already aboard once a journey is
                        // active, so the bus's live position IS the
                        // passenger's own position - label it as such rather
                        // than a generic vehicle marker.
                        Marker(
                          point: busLatLng,
                          width: 92,
                          height: 68,
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryNavy,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                child: const Text("You're here", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryNavy,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [BoxShadow(color: AppColors.primaryNavy.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)],
                                ),
                                child: const Icon(Icons.directions_bus, size: 16, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ]),
                      const RichAttributionWidget(
                        alignment: AttributionAlignment.bottomLeft,
                        attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                      ),
                    ],
                  ),
                  if (_userPannedMap)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: FloatingActionButton.small(
                        heroTag: 'journey_map_recenter',
                        backgroundColor: AppColors.primaryNavy,
                        onPressed: () {
                          setState(() => _userPannedMap = false);
                          _mapController.move(busLatLng, _mapController.camera.zoom);
                        },
                        child: const Icon(Icons.my_location, color: Colors.white, size: 18),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeatCard(SeatAllocation alloc, _SeatZone zone, Ticket ticket) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderLight)),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.getZoneBg(zone.key), borderRadius: BorderRadius.circular(12)),
            child: Text(alloc.seatNumber, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.getZoneAccent(zone.key))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.isBulk ? 'My Seat · +${ticket.extraAllocations.length} companion${ticket.extraAllocations.length == 1 ? '' : 's'}' : 'My Seat',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                ZonePill(zone: zone.key, small: true),
              ],
            ),
          ),
          TonalButton(
            icon: Icons.event_seat_outlined,
            label: 'View map',
            color: AppColors.primaryNavy,
            dense: true,
            expand: false,
            onPressed: () => _showSeatingMap(alloc.seatNumber),
          ),
        ],
      ),
    );
  }

  Widget _buildTripProgressCard(SeatAllocation alloc, double fraction, String elapsedText, String remainingText) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trip Progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: fraction, minHeight: 8, backgroundColor: AppColors.borderLight, valueColor: const AlwaysStoppedAnimation(AppColors.generalAccent)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(alloc.boardingStop, style: const TextStyle(fontSize: 10, color: AppColors.textMuted), overflow: TextOverflow.ellipsis)),
              Text('$elapsedText elapsed · $remainingText left', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              Flexible(child: Text(alloc.alightingStop, style: const TextStyle(fontSize: 10, color: AppColors.textMuted), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyCard(_SeatZone zone, int count, int capacity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.getZoneBg(zone.key), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.people_alt_outlined, size: 18, color: AppColors.getZoneAccent(zone.key)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count of $capacity seats occupied in your zone right now',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getZoneText(zone.key)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentList(List<String> segmentStops, int currentSegIndex) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: segmentStops.length,
      itemBuilder: (context, index) {
        final stop = segmentStops[index];
        final isPast = index < currentSegIndex;
        final isCurrent = index == currentSegIndex;
        final isFirst = index == 0;
        final isLast = index == segmentStops.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isPast ? Colors.green : (isCurrent ? AppColors.primaryNavy : Colors.white),
                    shape: BoxShape.circle,
                    border: Border.all(color: isPast ? Colors.green : (isCurrent ? AppColors.primaryNavy : AppColors.borderLight), width: 2),
                  ),
                  child: isPast
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : (isCurrent ? const Center(child: CircleAvatar(radius: 4, backgroundColor: Colors.white)) : null),
                ),
                if (index < segmentStops.length - 1) Container(width: 2, height: 36, color: isPast ? Colors.green : AppColors.borderLight),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stop,
                              style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, fontSize: 13, color: isCurrent ? AppColors.primaryNavy : AppColors.textDark)),
                          if (isFirst) const Text('Boarding halt', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          if (isLast) const Text('Destination', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primaryNavy, borderRadius: BorderRadius.circular(10)),
                        child: const Text('NOW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context, Ticket ticket) {
    final isPaid = ticket.payment.isPaid;
    return Row(
      children: [
        Expanded(
          child: TonalButton(
            icon: Icons.chat_bubble_outline,
            label: 'Text Conductor',
            color: AppColors.generalAccent,
            onPressed: () => _showConductorMessageSheet(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TonalButton(
            icon: isPaid ? Icons.qr_code_rounded : Icons.confirmation_number_outlined,
            label: 'My Ticket',
            color: AppColors.primaryNavy,
            onPressed: () => _showTicketReference(context, ticket, isPaid),
          ),
        ),
      ],
    );
  }

  void _showTicketReference(BuildContext context, Ticket ticket, bool isPaid) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Fare Reference', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
            const SizedBox(height: 16),
            if (isPaid) ...[
              QRCodeWidget(data: ticket.allocation.qrCode, size: 150),
              const SizedBox(height: 10),
              const Text('Show this to the conductor if asked', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ] else ...[
              Text(ticket.allocation.referenceCode, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primaryNavy, letterSpacing: 1)),
              const SizedBox(height: 8),
              const Text('Booking reference · pay onboard', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
            const SizedBox(height: 16),
            Text('Seat ${ticket.allocation.seatNumber} · Rs. ${ticket.payment.amountLkr.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          ],
        ),
      ),
    );
  }
}
