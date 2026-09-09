import 'dart:math' as math;

class StopLocation {
  final double lat;
  final double lng;

  const StopLocation(this.lat, this.lng);
}

class StopMatch {
  final String stopName;
  final double distanceKm;

  const StopMatch(this.stopName, this.distanceKm);
}

class RouteModel {
  final String routeId;
  final String routeName;
  final String startPoint;
  final String endPoint;
  final int totalStops;
  final double distanceKm;
  final String routeType;
  final String status;
  final List<String> stops;

  // Cumulative distance (km) of each entry in [stops] measured from stops.first,
  // i.e. always in the fixed Colombo -> Jaffna geographic order regardless of
  // which direction a particular bus travels. Used to estimate when a bus
  // reaches an intermediate stop.
  final List<double> stopDistancesKm;

  // Approximate real-world coordinates of each entry in [stops], same order.
  // Used to snap a freely-searched Google Places result to the nearest
  // official stop this bus actually halts at.
  final List<StopLocation> stopCoordinates;

  RouteModel({
    required this.routeId,
    required this.routeName,
    required this.startPoint,
    required this.endPoint,
    required this.totalStops,
    required this.distanceKm,
    required this.routeType,
    required this.status,
    required this.stops,
    this.stopDistancesKm = const [],
    this.stopCoordinates = const [],
  });

  double? distanceToStopKm(String stopName) {
    final idx = stops.indexWhere((s) => s.toLowerCase() == stopName.toLowerCase());
    if (idx == -1 || idx >= stopDistancesKm.length) return null;
    return stopDistancesKm[idx];
  }

  // Finds the official stop on this route closest (great-circle distance)
  // to an arbitrary searched location, e.g. one resolved from Google Places.
  StopMatch? nearestStopMatch(double lat, double lng) {
    if (stopCoordinates.length != stops.length || stops.isEmpty) return null;

    int bestIndex = 0;
    double bestDistance = double.infinity;
    for (var i = 0; i < stops.length; i++) {
      final d = _haversineKm(lat, lng, stopCoordinates[i].lat, stopCoordinates[i].lng);
      if (d < bestDistance) {
        bestDistance = d;
        bestIndex = i;
      }
    }
    return StopMatch(stops[bestIndex], bestDistance);
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  // Interpolates a real-world lat/lng between the two stops a bus is
  // currently between, given a fractional stop index (e.g. 4.3 = 30% of the
  // way from stop 4 to stop 5) such as the one produced by the timetable-
  // based progress simulation used on the Journey and Track-My-Bus screens.
  // Returns null if this route has no coordinate data.
  StopLocation? interpolatedLocation(double fullIndex) {
    if (stopCoordinates.length != stops.length || stopCoordinates.isEmpty) return null;
    final lower = fullIndex.floor().clamp(0, stopCoordinates.length - 1);
    final upper = (lower + 1 < stopCoordinates.length) ? lower + 1 : lower;
    final frac = (fullIndex - lower).clamp(0.0, 1.0);
    final a = stopCoordinates[lower];
    final b = stopCoordinates[upper];
    return StopLocation(a.lat + (b.lat - a.lat) * frac, a.lng + (b.lng - a.lng) * frac);
  }

  Map<String, dynamic> toMap() {
    return {
      'route_id': routeId,
      'route_name': routeName,
      'start_point': startPoint,
      'end_point': endPoint,
      'total_stops': totalStops,
      'distance_km': distanceKm,
      'route_type': routeType,
      'status': status,
      'stops': stops,
      'stop_distances_km': stopDistancesKm,
      'stop_coordinates': stopCoordinates.map((c) => {'lat': c.lat, 'lng': c.lng}).toList(),
    };
  }

  factory RouteModel.fromMap(Map<String, dynamic> map, String docId) {
    return RouteModel(
      routeId: map['route_id'] ?? docId,
      routeName: map['route_name'] ?? '',
      startPoint: map['start_point'] ?? '',
      endPoint: map['end_point'] ?? '',
      totalStops: map['total_stops'] ?? 0,
      distanceKm: (map['distance_km'] ?? 0.0).toDouble(),
      routeType: map['route_type'] ?? 'Normal',
      status: map['status'] ?? 'active',
      stops: List<String>.from(map['stops'] ?? []),
      stopDistancesKm: (map['stop_distances_km'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      stopCoordinates: (map['stop_coordinates'] as List<dynamic>?)
              ?.map((e) => StopLocation((e['lat'] as num).toDouble(), (e['lng'] as num).toDouble()))
              .toList() ??
          const [],
    );
  }
}
