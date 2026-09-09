import 'route_model.dart';

class BusSchedule {
  final String busId;
  final String busNumber;
  final String routeId;
  final String routeName;
  final String busType; // e.g., 'High Capacity AC', 'Semi-Express', 'Standard City'
  final DateTime departureDateTime;
  final DateTime arrivalDateTime;
  final String startPoint;
  final String endPoint;
  final List<String> stops;
  final int availablePrioritySeats;
  final int totalPrioritySeats;
  final int availableGeneralSeats;
  final int totalGeneralSeats;
  final int availableStanding;
  final int totalStanding;
  final String crowdingLevel; // 'low', 'moderate', 'high', 'critical'
  final double fareLkr;
  final int durationMinutes;
  final String conductorName;
  final double safetyRating; // e.g. 4.8

  BusSchedule({
    required this.busId,
    required this.busNumber,
    required this.routeId,
    required this.routeName,
    required this.busType,
    required this.departureDateTime,
    required this.arrivalDateTime,
    required this.startPoint,
    required this.endPoint,
    required this.stops,
    required this.availablePrioritySeats,
    this.totalPrioritySeats = 12,
    required this.availableGeneralSeats,
    this.totalGeneralSeats = 30,
    required this.availableStanding,
    this.totalStanding = 18,
    required this.crowdingLevel,
    required this.fareLkr,
    required this.durationMinutes,
    this.conductorName = 'K. Perera',
    this.safetyRating = 4.8,
  });

  String get departureTimeFormatted {
    final hour = departureDateTime.hour;
    final minute = departureDateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${formattedHour.toString().padLeft(2, '0')}:$minute $period';
  }

  String get arrivalTimeFormatted {
    final hour = arrivalDateTime.hour;
    final minute = arrivalDateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${formattedHour.toString().padLeft(2, '0')}:$minute $period';
  }

  int minutesDifferenceFrom(DateTime target) {
    return departureDateTime.difference(target).inMinutes;
  }

  // [stops] is always listed in the same fixed geographic order (Colombo -> Jaffna),
  // regardless of which direction this particular bus travels. So "serves the
  // journey" depends on whether this bus's own direction (startPoint -> endPoint)
  // agrees with the boarding -> alighting order the user asked for.
  bool servesJourney(String boarding, String alighting) {
    final bIndex = stops.indexWhere((s) => s.toLowerCase() == boarding.toLowerCase());
    final aIndex = stops.indexWhere((s) => s.toLowerCase() == alighting.toLowerCase());
    if (bIndex == -1 || aIndex == -1) return false;

    final startIndex = stops.indexWhere((s) => s.toLowerCase() == startPoint.toLowerCase());
    final endIndex = stops.indexWhere((s) => s.toLowerCase() == endPoint.toLowerCase());
    if (startIndex == -1 || endIndex == -1) return bIndex < aIndex;

    return startIndex <= endIndex ? bIndex < aIndex : bIndex > aIndex;
  }

  // Estimated date/time this specific bus reaches [stopName], based on this
  // bus's own departure time and duration, prorated by how far along the
  // route (by distance) that stop is in this bus's direction of travel.
  // Returns null if the stop isn't on this bus's route/direction.
  DateTime? timeAtStop(String stopName, RouteModel route) {
    final stopIndex = route.stops.indexWhere((s) => s.toLowerCase() == stopName.toLowerCase());
    final startIndex = route.stops.indexWhere((s) => s.toLowerCase() == startPoint.toLowerCase());
    final endIndex = route.stops.indexWhere((s) => s.toLowerCase() == endPoint.toLowerCase());
    if (stopIndex == -1 || startIndex == -1 || endIndex == -1) return null;

    final isForward = startIndex <= endIndex;
    if (isForward && (stopIndex < startIndex || stopIndex > endIndex)) return null;
    if (!isForward && (stopIndex > startIndex || stopIndex < endIndex)) return null;

    if (route.distanceKm <= 0 || route.stopDistancesKm.length != route.stops.length) {
      return stopIndex == startIndex ? departureDateTime : null;
    }

    final distFromRouteOrigin = route.stopDistancesKm[stopIndex];
    final distFromBusStart =
        isForward ? distFromRouteOrigin : route.distanceKm - distFromRouteOrigin;

    final fraction = (distFromBusStart / route.distanceKm).clamp(0.0, 1.0);
    final offsetMinutes = (fraction * durationMinutes).round();
    return departureDateTime.add(Duration(minutes: offsetMinutes));
  }

  // [fareLkr] is the full end-to-end route fare. A passenger travelling
  // only part of the route pays proportionally to the distance they
  // actually cover, rounded to a realistic fare increment with a small
  // minimum floor.
  double journeyFareLkr(RouteModel route, String boardingStop, String alightingStop) {
    final boardKm = route.distanceToStopKm(boardingStop);
    final alightKm = route.distanceToStopKm(alightingStop);
    if (boardKm == null || alightKm == null || route.distanceKm <= 0) return fareLkr;

    final tripKm = (alightKm - boardKm).abs();
    final fraction = (tripKm / route.distanceKm).clamp(0.0, 1.0);
    final rounded = ((fareLkr * fraction) / 10).round() * 10;
    return rounded < 50 ? 50.0 : rounded.toDouble();
  }

  // Always renders with both hours and minutes (e.g. "8h 20m"), never just
  // a raw minute count.
  static String formatDuration(int minutes) {
    final total = minutes < 0 ? 0 : minutes;
    final hours = total ~/ 60;
    final mins = total % 60;
    if (hours <= 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}
