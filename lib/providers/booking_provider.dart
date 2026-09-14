import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../models/seat_allocation.dart';
import '../models/passenger.dart';
import '../models/bus_schedule.dart';
import '../services/allocation_service.dart';

// Algorithm-relevant details for an extra passenger in a group booking -
// deliberately scoped to just what allocateSeat() actually consumes
// (gender, mobility, safety preference, pregnancy), not a full passenger
// profile.
class CompanionPreference {
  final String gender;
  final String mobilityStatus;
  final bool safetyPreference;
  final bool pregnant;

  const CompanionPreference({
    this.gender = 'female',
    this.mobilityStatus = 'none',
    this.safetyPreference = false,
    this.pregnant = false,
  });

  CompanionPreference copyWith({String? gender, String? mobilityStatus, bool? safetyPreference, bool? pregnant}) {
    return CompanionPreference(
      gender: gender ?? this.gender,
      mobilityStatus: mobilityStatus ?? this.mobilityStatus,
      safetyPreference: safetyPreference ?? this.safetyPreference,
      pregnant: pregnant ?? this.pregnant,
    );
  }
}

class BookingProvider with ChangeNotifier {
  final AllocationService _allocationService = AllocationService();

  RouteModel? _selectedRoute;
  BusSchedule? _selectedBus;
  String? _boardingStop;
  String? _alightingStop;
  bool _isAllocating = false;
  SeatAllocation? _lastAllocation;

  // Group booking (more than 1 seat at a time). Capped well under the
  // 6-seat rear bench (the largest single contiguous block in the bus), so
  // a group can always be tried for adjacent seating in one row.
  static const int maxSeatCount = 5;
  int _seatCount = 1;
  final List<CompanionPreference> _companions = [];
  List<SeatAllocation> _groupAllocations = [];
  // Whole-group opt-in: everyone in this booking is comfortable being
  // seated adjacent to a different gender - see
  // AllocationService.findAdjacentBlock's traveling-together exemption.
  bool _travelingTogether = false;

  int get seatCount => _seatCount;
  bool get isGroupBooking => _seatCount > 1;
  List<CompanionPreference> get companions => List.unmodifiable(_companions);
  List<SeatAllocation> get groupAllocations => List.unmodifiable(_groupAllocations);
  bool get travelingTogether => _travelingTogether;

  void setTravelingTogether(bool value) {
    _travelingTogether = value;
    notifyListeners();
  }

  // Seat-suggestion history for the current booking: index 0 is the
  // original allocation; each "request another seat" appends one more, up
  // to [maxSeatChanges] times. Browsing back/forward through already-seen
  // suggestions is free and doesn't consume a change.
  static const int maxSeatChanges = 2;
  final List<SeatAllocation> _allocationHistory = [];
  int _allocationHistoryIndex = -1;
  int _seatChangeCount = 0;

  List<SeatAllocation> get allocationHistory => List.unmodifiable(_allocationHistory);
  int get currentSuggestionNumber => _allocationHistoryIndex + 1;
  int get remainingSeatChanges => (maxSeatChanges - _seatChangeCount).clamp(0, maxSeatChanges);
  bool get canRequestAnotherSeat => _seatChangeCount < maxSeatChanges;
  bool get canGoToPreviousSuggestion => _allocationHistoryIndex > 0;
  bool get canGoToNextSuggestion =>
      _allocationHistoryIndex >= 0 && _allocationHistoryIndex < _allocationHistory.length - 1;

  // Search parameters for Route 87. All four must be explicitly chosen by the
  // user before a search can run - none of them carry a usable default, so
  // the UI is forced to show "Select..." placeholders until the user picks.
  DateTime? _searchDate;
  TimeOfDay? _searchTime;
  String? _searchBoardingStop;
  String? _searchAlightingStop;

  RouteModel? get selectedRoute => _selectedRoute;
  BusSchedule? get selectedBus => _selectedBus;
  String? get boardingStop => _boardingStop;
  String? get alightingStop => _alightingStop;
  bool get isAllocating => _isAllocating;
  SeatAllocation? get lastAllocation => _lastAllocation;

  DateTime? get searchDate => _searchDate;
  TimeOfDay? get searchTime => _searchTime;
  String? get searchBoardingStop => _searchBoardingStop;
  String? get searchAlightingStop => _searchAlightingStop;

  bool get hasCompleteSearchCriteria =>
      _searchBoardingStop != null &&
      _searchAlightingStop != null &&
      _searchBoardingStop != _searchAlightingStop &&
      _searchDate != null &&
      _searchTime != null;

  // Route 87 (Colombo - Jaffna Inter-Provincial Corridor)
  // stopDistancesKm are cumulative km from Colombo, and stopCoordinates are
  // approximate real-world lat/lng - both in the same order as stops - and
  // are used to estimate when a bus reaches any intermediate stop (in either
  // direction of travel) and to snap a Google Places search result to the
  // nearest stop this bus actually halts at.
  final List<RouteModel> sampleRoutes = [
    RouteModel(
      routeId: 'R_87',
      routeName: 'Route 87',
      startPoint: 'Colombo (Pettah)',
      endPoint: 'Jaffna Main Bus Stand',
      totalStops: 37,
      distanceKm: 396.0,
      routeType: 'Inter-Provincial · Semi Luxury & Normal',
      status: 'active',
      stops: const [
        'Colombo (Pettah)',
        'Kelaniya',
        'Peliyagoda Interchange',
        'Wattala',
        'Kandana Junction',
        'Ja-Ela',
        'Seeduwa',
        'Katunayake Junction',
        'Negombo Bus Stand',
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
        'Anamaduwa',
        'Saliyawewa Junction',
        'Nochchiyagama',
        'Tirappane Junction',
        'Anuradhapura New Town',
        'Medawachchiya Junction',
        'Cheddikulam',
        'Vavuniya Bus Terminal',
        'Omanthai',
        'Puliyankulam',
        'Mankulam Junction',
        'Akkarayankulam',
        'Kilinochchi Central Stand',
        'Elephant Pass',
        'Pallai',
        'Chavakachcheri',
        'Kaithady',
        'Jaffna Main Bus Stand',
      ],
      stopDistancesKm: const [
        0.0,
        5.0,
        8.0,
        12.0,
        16.0,
        20.0,
        25.0,
        29.0,
        37.0,
        43.0,
        50.0,
        56.0,
        62.0,
        70.0,
        80.0,
        92.0,
        105.0,
        117.0,
        130.0,
        143.0,
        155.0,
        180.0,
        205.0,
        230.0,
        260.0,
        280.0,
        300.0,
        312.0,
        322.0,
        335.0,
        348.0,
        360.0,
        368.0,
        373.0,
        380.0,
        390.0,
        396.0,
      ],
      stopCoordinates: const [
        StopLocation(6.9344, 79.8428), // Colombo (Pettah)
        StopLocation(6.9553, 79.9217), // Kelaniya
        StopLocation(6.9667, 79.8931), // Peliyagoda Interchange
        StopLocation(6.9891, 79.8917), // Wattala
        StopLocation(7.0453, 79.8908), // Kandana Junction
        StopLocation(7.0744, 79.8917), // Ja-Ela
        StopLocation(7.1167, 79.8833), // Seeduwa
        StopLocation(7.1697, 79.8842), // Katunayake Junction
        StopLocation(7.2083, 79.8358), // Negombo Bus Stand
        StopLocation(7.2600, 79.8450), // Kochchikade
        StopLocation(7.3500, 79.8394), // Wennappuwa
        StopLocation(7.3900, 79.8370), // Madampe
        StopLocation(7.4239, 79.8347), // Marawila Junction
        StopLocation(7.4064, 79.8567), // Nattandiya
        StopLocation(7.5758, 79.7953), // Chilaw Bus Stand
        StopLocation(7.6500, 79.8100), // Battuluoya
        StopLocation(7.7500, 79.8500), // Madurankuli
        StopLocation(7.8700, 79.8300), // Mundel
        StopLocation(8.0362, 79.8283), // Puttalam Main Stand
        StopLocation(8.0700, 80.0300), // Anamaduwa
        StopLocation(8.2000, 80.0000), // Saliyawewa Junction
        StopLocation(8.3167, 80.1000), // Nochchiyagama
        StopLocation(8.3130, 80.2800), // Tirappane Junction
        StopLocation(8.3114, 80.4037), // Anuradhapura New Town
        StopLocation(8.5372, 80.4897), // Medawachchiya Junction
        StopLocation(8.7000, 80.3500), // Cheddikulam
        StopLocation(8.7514, 80.4971), // Vavuniya Bus Terminal
        StopLocation(8.8667, 80.4833), // Omanthai
        StopLocation(8.9833, 80.4833), // Puliyankulam
        StopLocation(9.0333, 80.4333), // Mankulam Junction
        StopLocation(9.1500, 80.4000), // Akkarayankulam
        StopLocation(9.3803, 80.3770), // Kilinochchi Central Stand
        StopLocation(9.5333, 80.3167), // Elephant Pass
        StopLocation(9.5500, 80.2500), // Pallai
        StopLocation(9.6572, 80.1614), // Chavakachcheri
        StopLocation(9.6600, 80.0500), // Kaithady
        StopLocation(9.6615, 80.0255), // Jaffna Main Bus Stand
      ],
    ),
  ];

  BookingProvider() {
    _selectedRoute = sampleRoutes.first;
  }

  List<String> get allUniqueStops {
    return sampleRoutes.first.stops;
  }

  void setSearchCriteria({
    DateTime? date,
    TimeOfDay? time,
    String? boardingStop,
    String? alightingStop,
  }) {
    if (date != null) _searchDate = date;
    if (time != null) _searchTime = time;
    if (boardingStop != null) {
      _searchBoardingStop = boardingStop;
      _boardingStop = boardingStop;
    }
    if (alightingStop != null) {
      _searchAlightingStop = alightingStop;
      _alightingStop = alightingStop;
    }
    notifyListeners();
  }

  void swapStops() {
    final temp = _searchBoardingStop;
    _searchBoardingStop = _searchAlightingStop;
    _searchAlightingStop = temp;
    _boardingStop = _searchBoardingStop;
    _alightingStop = _searchAlightingStop;
    notifyListeners();
  }

  void selectRoute(RouteModel route) {
    _selectedRoute = route;
    _boardingStop = route.stops.isNotEmpty ? route.stops.first : null;
    _alightingStop = route.stops.length > 1 ? route.stops.last : null;
    _searchBoardingStop = _boardingStop;
    _searchAlightingStop = _alightingStop;
    notifyListeners();
  }

  // Sets how many seats this booking covers (1 = just the signed-in
  // passenger, unchanged behaviour). Growing the count adds blank companion
  // preference slots; shrinking it trims from the end, preserving whatever
  // was already filled in for the remaining slots.
  void setSeatCount(int count) {
    final clamped = count.clamp(1, maxSeatCount);
    _seatCount = clamped;
    final neededCompanions = clamped - 1;
    while (_companions.length < neededCompanions) {
      _companions.add(const CompanionPreference());
    }
    while (_companions.length > neededCompanions) {
      _companions.removeLast();
    }
    if (clamped == 1) _travelingTogether = false;
    notifyListeners();
  }

  void updateCompanion(int index, {String? gender, String? mobilityStatus, bool? safetyPreference, bool? pregnant}) {
    if (index < 0 || index >= _companions.length) return;
    _companions[index] = _companions[index].copyWith(
      gender: gender,
      mobilityStatus: mobilityStatus,
      safetyPreference: safetyPreference,
      pregnant: pregnant,
    );
    notifyListeners();
  }

  void selectBus(BusSchedule bus) {
    _selectedBus = bus;
    final matchingRoute = sampleRoutes.firstWhere(
      (r) => r.routeId == bus.routeId,
      orElse: () => sampleRoutes.first,
    );
    _selectedRoute = matchingRoute;
    if (_searchBoardingStop != null) _boardingStop = _searchBoardingStop;
    if (_searchAlightingStop != null) _alightingStop = _searchAlightingStop;
    notifyListeners();
  }

  // Clears every search/selection/allocation field back to its untouched
  // startup state, so the Search ("Routes") tab is ready for a fresh
  // booking rather than carrying forward a just-completed trip's stops,
  // date/time, bus, or seat suggestions. Called once a journey finishes.
  void resetSearch() {
    _selectedRoute = sampleRoutes.first;
    _selectedBus = null;
    _boardingStop = null;
    _alightingStop = null;
    _lastAllocation = null;
    _allocationHistory.clear();
    _allocationHistoryIndex = -1;
    _seatChangeCount = 0;
    _seatCount = 1;
    _companions.clear();
    _groupAllocations = [];
    _travelingTogether = false;
    _searchDate = null;
    _searchTime = null;
    _searchBoardingStop = null;
    _searchAlightingStop = null;
    notifyListeners();
  }

  // Used by "Book again" on a past trip in History: pre-fills only the
  // boarding/alighting stops, leaving date and time unset so the passenger
  // still has to explicitly choose a fresh date/time rather than silently
  // re-using an old one.
  void prefillStops({required String boardingStop, required String alightingStop}) {
    resetSearch();
    _searchBoardingStop = boardingStop;
    _searchAlightingStop = alightingStop;
    _boardingStop = boardingStop;
    _alightingStop = alightingStop;
    notifyListeners();
  }

  void setBoardingStop(String stop) {
    _boardingStop = stop;
    _searchBoardingStop = stop;
    notifyListeners();
  }

  void setAlightingStop(String stop) {
    _alightingStop = stop;
    _searchAlightingStop = stop;
    notifyListeners();
  }

  // Generates the complete two-directional Route 87 timetable for the
  // selected date: Colombo -> Jaffna departures and Jaffna -> Colombo
  // departures. Every bus on both sides physically passes through all 14
  // stops, so filtering/ranking by intermediate stop works symmetrically.
  List<BusSchedule> getAllBusSchedulesForDate(DateTime date) {
    final y = date.year;
    final m = date.month;
    final d = date.day;
    final route87 = sampleRoutes.first;
    DateTime dep(int h, int min) => DateTime(y, m, d, h, min);

    final forward = <BusSchedule>[
      _trip(route87, 'BUS_NB_8701', 'NB-8701 (Northern Sunrise Express)', 'Semi Luxury',
          dep(5, 30), 480, route87.startPoint, route87.endPoint, 11, 13, 24, 5, 'low', 2400, 'K. Sivalingam', 4.9),
      _trip(route87, 'BUS_NB_8705', 'NB-8705 (Jaffna Highway Cruiser)', 'Normal',
          dep(7, 0), 480, route87.startPoint, route87.endPoint, 9, 11, 20, 4, 'low', 2400, 'R. Thevarajah', 4.9),
      _trip(route87, 'BUS_NB_8710', 'NB-8710 (SafeBoard Shield Express)', 'Semi Luxury',
          dep(8, 30), 480, route87.startPoint, route87.endPoint, 7, 8, 14, 2, 'moderate', 2400, 'M. Fernando', 4.9),
      _trip(route87, 'BUS_NB_8715', 'NB-8715 (Yal Devi Semi-Express)', 'Normal',
          dep(10, 15), 510, route87.startPoint, route87.endPoint, 5, 6, 10, 2, 'moderate', 2200, 'A. Tharmalingam', 4.8),
      _trip(route87, 'BUS_NB_8720', 'NB-8720 (Northern Highway Flyer)', 'Semi Luxury',
          dep(13, 0), 480, route87.startPoint, route87.endPoint, 12, 14, 26, 6, 'low', 2400, 'T. Pathmanathan', 4.9),
      _trip(route87, 'BUS_NB_8725', 'NB-8725 (Vanni Inter-Provincial)', 'Normal',
          dep(16, 30), 480, route87.startPoint, route87.endPoint, 6, 7, 12, 2, 'moderate', 2400, 'S. Shanmugam', 4.8),
      _trip(route87, 'BUS_NB_8730', 'NB-8730 (Night Mail Express)', 'Semi Luxury Sleeper',
          dep(20, 0), 480, route87.startPoint, route87.endPoint, 10, 12, 22, 5, 'low', 2600, 'N. Gnanavel', 4.9),
      _trip(route87, 'BUS_NB_8735', 'NB-8735 (SafeBoard Night Shield)', 'Semi Luxury',
          dep(21, 30), 480, route87.startPoint, route87.endPoint, 6, 8, 13, 3, 'moderate', 2600, 'V. Ratnam', 4.9),
      _trip(route87, 'BUS_NB_8740', 'NB-8740 (Midnight Highway Cruiser)', 'Normal',
          dep(23, 0), 480, route87.startPoint, route87.endPoint, 9, 12, 21, 4, 'low', 2600, 'D. Senanayake', 4.8),
    ];

    final reverse = <BusSchedule>[
      _trip(route87, 'BUS_JN_8702', 'JN-8702 (Jaffna Sunrise Express)', 'Semi Luxury',
          dep(5, 0), 480, route87.endPoint, route87.startPoint, 11, 12, 23, 5, 'low', 2400, 'P. Kumaraswamy', 4.9),
      _trip(route87, 'BUS_JN_8706', 'JN-8706 (Southbound Highway Cruiser)', 'Normal',
          dep(6, 45), 480, route87.endPoint, route87.startPoint, 10, 11, 21, 4, 'low', 2400, 'S. Rajendran', 4.9),
      _trip(route87, 'BUS_JN_8711', 'JN-8711 (SafeBoard Shield Return)', 'Semi Luxury',
          dep(8, 15), 480, route87.endPoint, route87.startPoint, 6, 8, 14, 3, 'moderate', 2400, 'L. Wickramasinghe', 4.9),
      _trip(route87, 'BUS_JN_8716', 'JN-8716 (Yal Devi Semi-Express Return)', 'Normal',
          dep(10, 30), 510, route87.endPoint, route87.startPoint, 5, 6, 11, 2, 'moderate', 2200, 'C. Ganeshamoorthy', 4.8),
      _trip(route87, 'BUS_JN_8721', 'JN-8721 (Vanni Southbound)', 'Semi Luxury',
          dep(13, 30), 480, route87.endPoint, route87.startPoint, 12, 14, 25, 6, 'low', 2400, 'R. Balasingham', 4.9),
      _trip(route87, 'BUS_JN_8726', 'JN-8726 (Colombo Highway Flyer)', 'Normal',
          dep(16, 0), 480, route87.endPoint, route87.startPoint, 6, 7, 12, 2, 'moderate', 2400, 'H. Jayasuriya', 4.8),
      _trip(route87, 'BUS_JN_8731', 'JN-8731 (Night Mail Southbound)', 'Semi Luxury Sleeper',
          dep(19, 30), 480, route87.endPoint, route87.startPoint, 10, 11, 20, 4, 'low', 2600, 'T. Nadarajah', 4.9),
      _trip(route87, 'BUS_JN_8736', 'JN-8736 (SafeBoard Night Shield Return)', 'Semi Luxury',
          dep(21, 0), 480, route87.endPoint, route87.startPoint, 7, 8, 13, 3, 'moderate', 2600, 'A. Perera', 4.9),
      _trip(route87, 'BUS_JN_8741', 'JN-8741 (Midnight Colombo Cruiser)', 'Normal',
          dep(22, 45), 480, route87.endPoint, route87.startPoint, 9, 13, 22, 5, 'low', 2600, 'M. Wijesekara', 4.8),
    ];

    return [...forward, ...reverse];
  }

  BusSchedule _trip(
    RouteModel route,
    String busId,
    String busNumber,
    String busType,
    DateTime departure,
    int durationMinutes,
    String startPoint,
    String endPoint,
    int availablePrioritySeats,
    int availableGeneralSeats,
    int availableLimitedSeats,
    int availableStanding,
    String crowdingLevel,
    double fareLkr,
    String conductorName,
    double safetyRating,
  ) {
    return BusSchedule(
      busId: busId,
      busNumber: busNumber,
      routeId: route.routeId,
      routeName: route.routeName,
      busType: busType,
      departureDateTime: departure,
      arrivalDateTime: departure.add(Duration(minutes: durationMinutes)),
      startPoint: startPoint,
      endPoint: endPoint,
      stops: route.stops,
      availablePrioritySeats: availablePrioritySeats,
      availableGeneralSeats: availableGeneralSeats,
      availableLimitedSeats: availableLimitedSeats,
      availableStanding: availableStanding,
      crowdingLevel: crowdingLevel,
      fareLkr: fareLkr,
      durationMinutes: durationMinutes,
      conductorName: conductorName,
      safetyRating: safetyRating,
    );
  }

  // Returns buses filtered by boarding & alighting stops (in the requested
  // direction) for the selected date. Empty until the user has explicitly
  // chosen boarding stop, alighting stop, date and time.
  List<BusSchedule> get filteredBuses {
    if (!hasCompleteSearchCriteria) return [];

    final all = getAllBusSchedulesForDate(_searchDate!);
    final boarding = _searchBoardingStop!;
    final alighting = _searchAlightingStop!;

    return all.where((bus) => bus.servesJourney(boarding, alighting)).toList();
  }

  DateTime? get targetSearchDateTime {
    if (_searchDate == null || _searchTime == null) return null;
    return DateTime(
      _searchDate!.year,
      _searchDate!.month,
      _searchDate!.day,
      _searchTime!.hour,
      _searchTime!.minute,
    );
  }

  // The time each candidate bus actually reaches the user's chosen boarding
  // stop - not its raw Colombo departure time. This is what "nearest bus"
  // suggestions are ranked against, so a Puttalam boarder sees suggestions
  // timed to when the bus reaches Puttalam, not Colombo.
  DateTime? boardingTimeFor(BusSchedule bus) {
    final route = _selectedRoute ?? sampleRoutes.first;
    final boarding = _searchBoardingStop;
    if (boarding == null) return null;
    return bus.timeAtStop(boarding, route);
  }

  DateTime? alightingTimeFor(BusSchedule bus) {
    final route = _selectedRoute ?? sampleRoutes.first;
    final alighting = _searchAlightingStop;
    if (alighting == null) return null;
    return bus.timeAtStop(alighting, route);
  }

  // Finds the single best fit bus based on closest arrival at the chosen
  // boarding stop to the exact search date/time.
  BusSchedule? get bestFitBus {
    if (!hasCompleteSearchCriteria) return null;
    final buses = filteredBuses;
    if (buses.isEmpty) return null;

    final target = targetSearchDateTime!;
    final withBoardingTime = buses
        .map((b) => MapEntry(b, boardingTimeFor(b)))
        .where((e) => e.value != null)
        .toList();
    if (withBoardingTime.isEmpty) return null;

    // First preference: buses reaching the boarding stop on or up to 10
    // minutes before the target time (i.e. the user can still catch it).
    final upcoming = withBoardingTime.where((e) {
      final diff = e.value!.difference(target).inMinutes;
      return diff >= -10;
    }).toList();

    final pool = upcoming.isNotEmpty ? upcoming : withBoardingTime;
    pool.sort((a, b) {
      final diffA = a.value!.difference(target).inMinutes.abs();
      final diffB = b.value!.difference(target).inMinutes.abs();
      return diffA.compareTo(diffB);
    });
    return pool.first.key;
  }

  // Returns up to 5 other upcoming buses (excluding the Best Fit bus),
  // sorted by their arrival time at the boarding stop. Buses that have
  // already passed the boarding stop before the target time are left out -
  // this list is for buses the passenger can still catch, not missed ones.
  static const int _maxOtherUpcomingBuses = 5;

  List<BusSchedule> get otherUpcomingBuses {
    if (!hasCompleteSearchCriteria) return [];
    final best = bestFitBus;
    final buses = filteredBuses;
    final target = targetSearchDateTime;
    if (target == null) return [];

    final others = buses.where((b) {
      if (best != null && b.busId == best.busId) return false;
      final t = boardingTimeFor(b);
      if (t == null) return false;
      return t.difference(target).inMinutes >= -10;
    }).toList();

    others.sort((a, b) {
      final ta = boardingTimeFor(a) ?? a.departureDateTime;
      final tb = boardingTimeFor(b) ?? b.departureDateTime;
      return ta.compareTo(tb);
    });
    return others.take(_maxOtherUpcomingBuses).toList();
  }

  Future<SeatAllocation> requestAllocation(Passenger passenger) async {
    _isAllocating = true;
    notifyListeners();

    try {
      final allocation = await _allocateSeat(passenger);
      _lastAllocation = allocation;
      _allocationHistory
        ..clear()
        ..add(allocation);
      _allocationHistoryIndex = 0;
      _seatChangeCount = 0;
      return allocation;
    } finally {
      _isAllocating = false;
      notifyListeners();
    }
  }

  // Books one seat for the signed-in passenger plus one for each companion
  // in a single pass against the shared seat map, so the group is tried
  // together (adjacent seats in one zone) before falling back to seating
  // everyone individually. Only called when seatCount > 1 - the single-seat
  // path (requestAllocation) is untouched.
  Future<List<SeatAllocation>> requestGroupAllocation(Passenger primary) async {
    _isAllocating = true;
    notifyListeners();

    try {
      final passengers = <Passenger>[primary.copyWith(travelingTogether: _travelingTogether)];
      for (var i = 0; i < _companions.length; i++) {
        final c = _companions[i];
        passengers.add(Passenger(
          passengerId: '${primary.passengerId}_companion${i + 1}',
          name: 'Companion ${i + 1}',
          email: primary.email,
          gender: c.gender,
          ageGroup: 'adult',
          mobilityStatus: c.mobilityStatus,
          phoneNumber: primary.phoneNumber,
          safetyPreference: c.safetyPreference,
          pregnant: c.pregnant,
          travelingTogether: _travelingTogether,
          createdDate: DateTime.now(),
          updatedDate: DateTime.now(),
        ));
      }

      final route = _selectedRoute ?? sampleRoutes.first;
      final bus = _selectedBus;
      final bStop = _boardingStop ?? _searchBoardingStop ?? route.stops.first;
      final aStop = _alightingStop ?? _searchAlightingStop ?? route.stops.last;

      final results = await _allocationService.allocateGroup(
        passengers: passengers,
        journeyId: 'JRN_87_001',
        routeId: route.routeId,
        busId: _busId,
        boardingStop: bStop,
        alightingStop: aStop,
        availablePrioritySeats: bus?.availablePrioritySeats,
        availableGeneralSeats: bus?.availableGeneralSeats,
        availableLimitedSeats: bus?.availableLimitedSeats,
        availableStanding: bus?.availableStanding,
      );

      _groupAllocations = results;
      _lastAllocation = results.first;
      _allocationHistory
        ..clear()
        ..add(results.first);
      _allocationHistoryIndex = 0;
      _seatChangeCount = 0;
      return results;
    } finally {
      _isAllocating = false;
      notifyListeners();
    }
  }

  // Suggests a different seat than the current one (same eligible zone),
  // up to [maxSeatChanges] times. Returns the existing allocation unchanged
  // once that limit is reached. Every seat suggested so far this booking is
  // freed back to the pool and excluded from being offered again, so
  // browsing alternatives never leaks seats out of circulation.
  Future<SeatAllocation> requestAlternateSeat(Passenger passenger) async {
    if (!canRequestAnotherSeat) return _lastAllocation ?? await requestAllocation(passenger);

    _isAllocating = true;
    notifyListeners();

    try {
      final previouslySuggested = _allocationHistory.map((a) => a.seatNumber).toSet();
      for (final seatNumber in previouslySuggested) {
        _allocationService.releaseSeat(busId: _busId, seatNumber: seatNumber);
      }

      final allocation = await _allocateSeat(passenger, excludeSeats: previouslySuggested);
      _seatChangeCount++;
      _allocationHistory.add(allocation);
      _allocationHistoryIndex = _allocationHistory.length - 1;
      _lastAllocation = allocation;
      return allocation;
    } finally {
      _isAllocating = false;
      notifyListeners();
    }
  }

  // Free, unlimited browsing of already-generated suggestions - doesn't
  // consume a change.
  SeatAllocation? goToPreviousSuggestion() {
    if (!canGoToPreviousSuggestion) return null;
    _allocationHistoryIndex--;
    _lastAllocation = _allocationHistory[_allocationHistoryIndex];
    notifyListeners();
    return _lastAllocation;
  }

  SeatAllocation? goToNextSuggestion() {
    if (!canGoToNextSuggestion) return null;
    _allocationHistoryIndex++;
    _lastAllocation = _allocationHistory[_allocationHistoryIndex];
    notifyListeners();
    return _lastAllocation;
  }

  String get _busId => _selectedBus?.busId ?? 'BUS_NB_8710';

  Future<SeatAllocation> _allocateSeat(Passenger passenger, {Set<String> excludeSeats = const {}}) {
    final route = _selectedRoute ?? sampleRoutes.first;
    final bus = _selectedBus;
    final bStop = _boardingStop ?? _searchBoardingStop ?? route.stops.first;
    final aStop = _alightingStop ?? _searchAlightingStop ?? route.stops.last;

    return _allocationService.allocateSeat(
      passenger: passenger,
      journeyId: 'JRN_87_001',
      routeId: route.routeId,
      busId: _busId,
      boardingStop: bStop,
      alightingStop: aStop,
      availablePrioritySeats: bus?.availablePrioritySeats,
      availableGeneralSeats: bus?.availableGeneralSeats,
      availableLimitedSeats: bus?.availableLimitedSeats,
      availableStanding: bus?.availableStanding,
      excludeSeats: excludeSeats,
    );
  }
}
