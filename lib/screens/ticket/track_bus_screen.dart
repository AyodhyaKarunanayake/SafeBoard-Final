import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/tickets_provider.dart';
import '../../models/bus_schedule.dart';
import '../../models/route_model.dart';
import '../../constants/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';

// Lets a passenger track their bus before boarding - from the moment their
// seat is confirmed, not just once they're already on the journey (that's
// what /journey is for). Route 87 has no real GPS feed, so position is
// simulated from the bus's own timetable (departure time + duration),
// the same way the rest of the app estimates per-stop arrival times.
class TrackBusScreen extends StatefulWidget {
  final String? ticketId;

  const TrackBusScreen({super.key, this.ticketId});

  @override
  State<TrackBusScreen> createState() => _TrackBusScreenState();
}

class _TrackBusScreenState extends State<TrackBusScreen> {
  bool _showMap = true;
  Timer? _timer;
  final _scrollController = ScrollController();
  bool _didAutoScroll = false;
  final MapController _mapController = MapController();
  bool _userPannedMap = false;

  static const double _rowHeight = 46.0;

  @override
  void initState() {
    super.initState();
    // Refresh periodically so the bus marker visibly creeps forward, like a
    // live tracker, without needing a real location feed.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    _mapController.dispose();
    super.dispose();
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

  void _autoScrollTo(double targetIndex, int stopCount) {
    if (_didAutoScroll || !_scrollController.hasClients) return;
    _didAutoScroll = true;
    final target = (targetIndex * _rowHeight - 180).clamp(0.0, (stopCount * _rowHeight));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(target, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ticketsProvider = Provider.of<TicketsProvider>(context);
    final ticket = widget.ticketId != null ? ticketsProvider.ticketById(widget.ticketId!) : null;

    if (ticket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Track My Bus')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No active booking to track yet.', style: TextStyle(color: AppColors.textMuted)),
          ),
        ),
        bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      );
    }

    final alloc = ticket.allocation;
    final bus = ticket.bus;
    final route = ticket.route;

    final progress = _BusProgress.compute(bus, route);
    _autoScrollTo(progress.currentStopIndex, route.stops.length);

    final boardingIndex = route.stops.indexWhere((s) => s.toLowerCase() == alloc.boardingStop.toLowerCase());
    final boardingEta = bus.timeAtStop(alloc.boardingStop, route);
    final now = DateTime.now();

    String etaText;
    if (boardingEta == null) {
      etaText = 'Estimated time unavailable';
    } else {
      final diff = boardingEta.difference(now).inMinutes;
      if (diff > 1) {
        etaText = 'Arrives at your stop in ${BusSchedule.formatDuration(diff)}';
      } else if (diff >= -2) {
        etaText = 'Arriving at your stop now';
      } else {
        etaText = 'Already passed your stop';
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Track My Bus')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(bus.busNumber, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: progress.statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text(progress.statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: progress.statusColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: AppColors.priorityText),
                    const SizedBox(width: 6),
                    Text(etaText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.priorityText)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _toggleTab('Map', Icons.map_outlined, true)),
                    const SizedBox(width: 8),
                    Expanded(child: _toggleTab('List', Icons.list_alt, false)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _showMap
                ? _buildMapView(route, bus, progress, boardingIndex)
                : _buildListView(bus, route, alloc.boardingStop, progress),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  Widget _toggleTab(String label, IconData icon, bool isMap) {
    final selected = _showMap == isMap;
    return GestureDetector(
      onTap: () => setState(() => _showMap = isMap),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryNavy : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  // A real geographic map (OpenStreetMap tiles via flutter_map) once the
  // bus has actually left on its scheduled trip. Before that there's
  // nothing real to track yet, so a live-looking map would be misleading -
  // show a plain "not departed" state instead.
  Widget _buildMapView(RouteModel route, BusSchedule bus, _BusProgress progress, int boardingIndex) {
    final hasDeparted = progress.statusLabel != 'NOT YET DEPARTED';
    if (!hasDeparted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded, size: 44, color: AppColors.textMuted.withOpacity(0.5)),
              const SizedBox(height: 14),
              const Text(
                'Your bus hasn\'t started this trip yet',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              Text(
                'Scheduled to depart ${bus.startPoint} at ${bus.departureTimeFormatted}. Live map tracking starts once it\'s on the road.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final hasCoords = route.stopCoordinates.length == route.stops.length && route.stopCoordinates.isNotEmpty;
    final loc = hasCoords ? route.interpolatedLocation(progress.currentStopIndex) : null;
    final busLatLng = loc == null ? null : LatLng(loc.lat, loc.lng);
    if (busLatLng == null) {
      return const Center(
        child: Text('Map unavailable for this route', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      );
    }

    final routePoints = route.stopCoordinates.map((c) => LatLng(c.lat, c.lng)).toList();
    _autoRecenterMap(busLatLng);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: busLatLng,
                initialZoom: 9.5,
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
                    if (i != boardingIndex)
                      Marker(
                        point: routePoints[i],
                        width: 10,
                        height: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: i <= progress.currentStopIndex ? AppColors.generalAccent : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.generalAccent, width: 1.5),
                          ),
                        ),
                      ),
                  if (boardingIndex >= 0 && boardingIndex < routePoints.length)
                    Marker(
                      point: routePoints[boardingIndex],
                      width: 30,
                      height: 30,
                      child: const Icon(Icons.trip_origin, color: AppColors.priorityAccent, size: 24),
                    ),
                  Marker(
                    point: busLatLng,
                    width: 34,
                    height: 34,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: AppColors.primaryNavy.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)],
                      ),
                      child: const Icon(Icons.directions_bus, size: 16, color: Colors.white),
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
                  heroTag: 'track_bus_map_recenter',
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
    );
  }

  Widget _buildListView(BusSchedule bus, RouteModel route, String boardingStop, _BusProgress progress) {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: route.stops.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final stop = route.stops[index];
        final isBoarding = stop.toLowerCase() == boardingStop.toLowerCase();
        final isPassed = index < progress.currentStopIndex;
        final time = bus.timeAtStop(stop, route);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isBoarding ? AppColors.priorityBg : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isBoarding ? AppColors.priorityAccent.withOpacity(0.4) : AppColors.borderLight),
          ),
          child: Row(
            children: [
              Icon(
                isPassed ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: isPassed ? AppColors.generalAccent : AppColors.textMuted.withOpacity(0.5),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  stop,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isBoarding ? FontWeight.w900 : FontWeight.w600,
                    color: isBoarding ? AppColors.priorityText : AppColors.textDark,
                  ),
                ),
              ),
              Text(
                time != null ? _formatTime(time) : '--:--',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isBoarding ? AppColors.priorityText : AppColors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${formattedHour.toString().padLeft(2, '0')}:$minute $period';
  }
}

class _BusProgress {
  final double currentStopIndex; // fractional position along route.stops
  final String statusLabel;
  final Color statusColor;

  const _BusProgress({required this.currentStopIndex, required this.statusLabel, required this.statusColor});

  static _BusProgress compute(BusSchedule bus, RouteModel route) {
    final now = DateTime.now();
    final elapsedMinutes = now.difference(bus.departureDateTime).inMinutes;

    if (elapsedMinutes < 0) {
      final startIndex = route.stops.indexWhere((s) => s.toLowerCase() == bus.startPoint.toLowerCase());
      return _BusProgress(
        currentStopIndex: (startIndex == -1 ? 0 : startIndex).toDouble(),
        statusLabel: 'NOT YET DEPARTED',
        statusColor: AppColors.textMuted,
      );
    }

    final fraction = (elapsedMinutes / bus.durationMinutes).clamp(0.0, 1.0);
    if (fraction >= 1.0) {
      final endIndex = route.stops.indexWhere((s) => s.toLowerCase() == bus.endPoint.toLowerCase());
      return _BusProgress(
        currentStopIndex: (endIndex == -1 ? route.stops.length - 1 : endIndex).toDouble(),
        statusLabel: 'ARRIVED',
        statusColor: AppColors.generalAccent,
      );
    }

    final startIndex = route.stops.indexWhere((s) => s.toLowerCase() == bus.startPoint.toLowerCase());
    final endIndex = route.stops.indexWhere((s) => s.toLowerCase() == bus.endPoint.toLowerCase());
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

    return _BusProgress(
      currentStopIndex: lowerIdx + segFraction,
      statusLabel: 'EN ROUTE',
      statusColor: Colors.orange.shade700,
    );
  }
}
