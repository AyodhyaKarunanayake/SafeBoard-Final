// Single source of truth for "which zone is this seat number in" - every
// screen that needs to describe an allocated seat (Allocation Result,
// Journey, History, Rating) used to each hardcode its own row<=3 check,
// which drifted out of sync with the real seat map more than once. Route 87
// buses are laid out:
//   Priority  - rows 1-3  (15 seats: A,B left / C,D,E right)
//   General   - rows 4-6  (15 seats, same layout)
//   Limited   - rows 7-13 (34 seats: rows 7-11 same layout, row 12 is a
//               right-only 3-seat row beside the rear door, row 13 is a
//               6-seat rear bench A-F with no left/right split)
//   Standing  - a separate 6-person cap, not tied to any row (seat numbers
//               like "Standing-3")
class SeatZoneInfo {
  final String zoneKey; // priority | general | limited | standing
  final int? rowNumber; // null for standing

  const SeatZoneInfo(this.zoneKey, this.rowNumber);
}

SeatZoneInfo zoneForSeatNumber(String seatNumber) {
  if (seatNumber.toUpperCase().startsWith('STANDING')) {
    return const SeatZoneInfo('standing', null);
  }
  final rowNum = int.tryParse(RegExp(r'^(\d+)').firstMatch(seatNumber)?.group(1) ?? '');
  if (rowNum == null) return const SeatZoneInfo('general', null);
  if (rowNum <= 3) return SeatZoneInfo('priority', rowNum);
  if (rowNum <= 6) return SeatZoneInfo('general', rowNum);
  return SeatZoneInfo('limited', rowNum); // rows 7-13
}
