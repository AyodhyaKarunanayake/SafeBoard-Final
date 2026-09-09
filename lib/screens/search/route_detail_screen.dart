import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/booking_provider.dart';
import '../../models/route_model.dart';
import '../../models/bus_schedule.dart';
import '../../constants/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';

// A named stretch of Route 87's real, ordered stop list, purely for a more
// readable/catchy presentation - the stops and their order are all genuine
// data from RouteModel, this just groups them into recognisable legs of the
// Colombo -> Jaffna corridor.
class _StopRegion {
  final String title;
  final String blurb;
  final List<String> stops;
  const _StopRegion(this.title, this.blurb, this.stops);
}

const List<_StopRegion> _regions = [
  _StopRegion(
    'Colombo Metro',
    'Where it all begins - through the capital\'s northern suburbs.',
    ['Colombo (Pettah)', 'Kelaniya', 'Peliyagoda Interchange', 'Wattala'],
  ),
  _StopRegion(
    'Gampaha Gateway',
    'Past the airport corridor and into Negombo\'s lagoon country.',
    ['Kandana Junction', 'Ja-Ela', 'Seeduwa', 'Katunayake Junction', 'Negombo Bus Stand'],
  ),
  _StopRegion(
    'Coconut Coast',
    'The scenic west coast, through Sri Lanka\'s coconut triangle.',
    [
      'Kochchikade',
      'Wennappuwa',
      'Madampe',
      'Marawila Junction',
      'Nattandiya',
      'Chilaw Bus Stand',
      'Battuluoya',
      'Madurankuli',
      'Mundel',
      'Puttalam Main Stand',
    ],
  ),
  _StopRegion(
    'Rajarata Heartland',
    'Ancient cities and dry-zone plains around Anuradhapura.',
    ['Anamaduwa', 'Saliyawewa Junction', 'Nochchiyagama', 'Tirappane Junction', 'Anuradhapura New Town', 'Medawachchiya Junction', 'Cheddikulam'],
  ),
  _StopRegion(
    'Vanni Corridor',
    'The long inland stretch through the Vanni, via Elephant Pass.',
    ['Vavuniya Bus Terminal', 'Omanthai', 'Puliyankulam', 'Mankulam Junction', 'Akkarayankulam', 'Kilinochchi Central Stand', 'Elephant Pass'],
  ),
  _StopRegion(
    'Jaffna Peninsula',
    'The final leg into the cultural heart of the North.',
    ['Pallai', 'Chavakachcheri', 'Kaithady', 'Jaffna Main Bus Stand'],
  ),
];

class RouteDetailScreen extends StatelessWidget {
  final String routeId;

  const RouteDetailScreen({
    super.key,
    required this.routeId,
  });

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final route = bookingProvider.sampleRoutes.firstWhere(
      (r) => r.routeId == routeId,
      orElse: () => bookingProvider.sampleRoutes.first,
    );

    final allBuses = bookingProvider.getAllBusSchedulesForDate(DateTime.now());
    final forwardBuses = allBuses.where((b) => b.startPoint == route.startPoint).toList();
    final reverseBuses = allBuses.where((b) => b.startPoint == route.endPoint).toList();

    final hasCoords = route.stopCoordinates.length == route.stops.length && route.stopCoordinates.isNotEmpty;
    final routePoints = hasCoords ? route.stopCoordinates.map((c) => LatLng(c.lat, c.lng)).toList() : const <LatLng>[];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, route),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(route, forwardBuses.length + reverseBuses.length),
                  const SizedBox(height: 24),

                  if (routePoints.isNotEmpty) ...[
                    const Text('The Corridor', style: _sectionTitleStyle),
                    const SizedBox(height: 4),
                    const Text(
                      'Every halt, mapped end to end.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    _buildCorridorMap(routePoints),
                    const SizedBox(height: 28),
                  ],

                  Text('All ${route.totalStops} Halts', style: _sectionTitleStyle),
                  const SizedBox(height: 4),
                  const Text(
                    'From Pettah to the Jaffna peninsula, leg by leg.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  ..._buildRegionSections(route),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Buses on Route 87', style: _sectionTitleStyle),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.primaryNavy.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          '${forwardBuses.length + reverseBuses.length} Buses',
                          style: const TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Every registered departure, both directions.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 14),

                  _buildDirectionLabel('${route.startPoint.split(' (').first} → ${route.endPoint.split(' (').first}'),
                  const SizedBox(height: 10),
                  for (final bus in forwardBuses) _buildBusCard(context, bookingProvider, route, bus, isForward: true),
                  const SizedBox(height: 20),

                  _buildDirectionLabel('${route.endPoint.split(' (').first} → ${route.startPoint.split(' (').first}'),
                  const SizedBox(height: 10),
                  for (final bus in reverseBuses) _buildBusCard(context, bookingProvider, route, bus, isForward: false),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/search'),
                      icon: const Icon(Icons.event_seat_rounded, size: 18),
                      label: const Text('Find My Seat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }

  static const _sectionTitleStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primaryNavy);

  Widget _buildHeader(BuildContext context, RouteModel route) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, right: 20, top: 56, bottom: 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B2859), Color(0xFF2D4A9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).canPop() ? context.pop() : context.go('/home'),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
                child: Text(route.routeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  route.routeType,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${route.startPoint.split(' (').first} ⇌ ${route.endPoint.split(' (').first}',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15),
          ),
          const SizedBox(height: 10),
          const Text(
            'Sri Lanka\'s northern lifeline. Route 87 threads the west coast through the '
            'Coconut Triangle, the ancient plains of Anuradhapura and the Vanni, all the '
            'way to Jaffna - with every seat allocated by SafeBoard\'s gender-aware engine.',
            style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(RouteModel route, int busCount) {
    return Row(
      children: [
        Expanded(child: _statChip(Icons.route_rounded, '${route.distanceKm.toStringAsFixed(0)} km', 'Distance')),
        const SizedBox(width: 10),
        Expanded(child: _statChip(Icons.signpost_rounded, '${route.totalStops}', 'Halts')),
        const SizedBox(width: 10),
        Expanded(child: _statChip(Icons.directions_bus_filled_rounded, '$busCount', 'Daily buses')),
      ],
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.generalAccent, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textDark)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildCorridorMap(List<LatLng> routePoints) {
    return Container(
      height: 240,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.coordinates(coordinates: routePoints, padding: const EdgeInsets.all(28)),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'lk.safeboard.app',
            maxZoom: 18,
          ),
          PolylineLayer(polylines: [
            Polyline(points: routePoints, strokeWidth: 4, color: AppColors.primaryNavy.withOpacity(0.65)),
          ]),
          MarkerLayer(markers: [
            for (var i = 1; i < routePoints.length - 1; i++)
              Marker(
                point: routePoints[i],
                width: 8,
                height: 8,
                child: Container(
                  decoration: BoxDecoration(color: AppColors.generalAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.2)),
                ),
              ),
            Marker(
              point: routePoints.first,
              width: 26,
              height: 26,
              child: const Icon(Icons.trip_origin, color: AppColors.priorityAccent, size: 22),
            ),
            Marker(
              point: routePoints.last,
              width: 30,
              height: 30,
              child: const Icon(Icons.flag_circle, color: AppColors.emergencyRed, size: 26),
            ),
          ]),
          const RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRegionSections(RouteModel route) {
    var runningIndex = 0;
    final widgets = <Widget>[];
    for (final region in _regions) {
      final present = region.stops.where((s) => route.stops.contains(s)).toList();
      if (present.isEmpty) continue;
      final startNumber = runningIndex + 1;
      runningIndex += present.length;
      widgets.add(_buildRegionCard(region, present, startNumber));
      widgets.add(const SizedBox(height: 14));
    }
    return widgets;
  }

  Widget _buildRegionCard(_StopRegion region, List<String> stops, int startNumber) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(region.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
          const SizedBox(height: 2),
          Text(region.blurb, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < stops.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.generalBg, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${startNumber + i}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.generalAccent)),
                      const SizedBox(width: 6),
                      Text(stops[i], style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.generalText)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionLabel(String text) {
    return Row(
      children: [
        const Icon(Icons.alt_route_rounded, size: 15, color: AppColors.primaryNavy),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
      ],
    );
  }

  Widget _buildBusCard(BuildContext context, BookingProvider bookingProvider, RouteModel route, BusSchedule bus, {required bool isForward}) {
    return GestureDetector(
      onTap: () {
        bookingProvider.prefillStops(
          boardingStop: isForward ? route.startPoint : route.endPoint,
          alightingStop: isForward ? route.endPoint : route.startPoint,
        );
        context.go('/search');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: AppColors.primaryNavy.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.directions_bus_filled_rounded, color: AppColors.primaryNavy, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bus.busNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${bus.departureTimeFormatted} · ${BusSchedule.formatDuration(bus.durationMinutes)} · ${bus.conductorName}',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Rs. ${bus.fareLkr.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: AppColors.primaryNavy)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 12, color: AppColors.standingAccent),
                    const SizedBox(width: 2),
                    Text('${bus.safetyRating}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
