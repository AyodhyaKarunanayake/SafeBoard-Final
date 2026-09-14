import 'package:flutter/material.dart';
import '../constants/colors.dart';

class _RowZone {
  final Color bg;
  final Color accent;
  final Color text;

  const _RowZone({required this.bg, required this.accent, required this.text});
}

// All geometry for one build pass, scaled to the available width so the
// diagram grows/shrinks along with the rest of the page (e.g. resizing a
// browser window) instead of staying a fixed pixel size.
class _Dims {
  final double scale;

  const _Dims(this.scale);

  double get seatWidth => 48.0 * scale;
  double get seatHeight => 40.0 * scale;
  double get aisleWidth => 26.0 * scale;
  double get smallGap => 4.0 * scale;
  double get rowSpacing => 4.0 * scale;
  double get standingSize => 20.0 * scale;
  double get leftBlockWidth => seatWidth * 2 + smallGap;
  double get rightBlockWidth => seatWidth * 3 + smallGap * 2;
  double get contentWidth => leftBlockWidth + aisleWidth + rightBlockWidth;
}

// Physical seat map for a Route 87 bus, drawn top (front) to bottom (rear) -
// see lib/services/allocation_service.dart, which allocates against this
// same structure:
//   PRIORITY zone - rows 1-3, 5 seats/row (A,B left / C,D,E right) = 15
//   GENERAL zone  - rows 4-6, same layout                          = 15
//   LIMITED zone  - rows 7-11 same layout (25) + row 12, a right-only
//                   3-seat row (C,D,E) beside the rear door, since the
//                   left side is taken up by the door itself (3) + row
//                   13, a 6-seat rear bench A-F with no left/right
//                   split (6)                                     = 34
//   STANDING      - a separate 6-person cap, not extra seats - 6 spots
//                   spread down the aisle alongside the Limited rows
//                   (7-11), filling from the rearmost spot first
// Driver seat + front door sit at the very front (door on the left, the
// boarding side); a rear door sits after row 11, under the left column.
class BusDiagram extends StatelessWidget {
  final String allocatedSeat; // e.g. "5B", "3A", or "Standing-4"
  // Extra seats to highlight alongside allocatedSeat - used for group
  // bookings where several passengers were allocated in one go. Empty by
  // default, so single-seat callers behave exactly as before.
  final List<String> extraAllocatedSeats;
  final int standingCapacity;

  const BusDiagram({
    super.key,
    required this.allocatedSeat,
    this.extraAllocatedSeats = const [],
    this.standingCapacity = 6,
  });

  static const List<int> _regularRows = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
  // Right-only row (no left pair - "Rear Door" occupies that space on the
  // left) that fills the space beside the rear door.
  static const int _extraRightRow = 12;
  static const int _rearBenchRow = 13;
  // Standing spots sit in the aisle alongside the Limited rows (7-11),
  // filling from the rearmost spot first.
  static const int _standingRowsStart = 7;
  static const double _baseContentWidth = 100.0 + 26.0 + 152.0; // reference width at scale 1.0

  List<String> get _allAllocatedSeats => [allocatedSeat, ...extraAllocatedSeats];

  Set<String> get _regularAllocatedSeats => _allAllocatedSeats
      .where((s) => !s.toUpperCase().startsWith('STANDING'))
      .map((s) => s.toUpperCase())
      .toSet();

  // Every standing slot index (1..standingCapacity) allocated to any of
  // this booking's passengers.
  Set<int> get _standingAllocatedIndices {
    final indices = <int>{};
    for (final s in _allAllocatedSeats) {
      if (!s.toUpperCase().startsWith('STANDING')) continue;
      final match = RegExp(r'(\d+)').firstMatch(s);
      final parsed = match != null ? int.tryParse(match.group(1)!) : null;
      if (parsed != null && parsed >= 1 && parsed <= standingCapacity) {
        indices.add(parsed);
      } else {
        indices.add(1); // Legacy/non-numeric label highlights the first slot.
      }
    }
    return indices;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth.isFinite
              ? (constraints.maxWidth / _baseContentWidth).clamp(0.8, 1.6)
              : 1.0;
          final dims = _Dims(scale);

          return Column(
            children: [
              _buildLegend(),
              const SizedBox(height: 12),
              _buildFrontCap(dims),
              const SizedBox(height: 6),
              _buildSeatBody(dims),
              const SizedBox(height: 10),
              _buildRearBench(dims),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        _legendChip('PRIORITY', AppColors.priorityAccent, AppColors.priorityBg),
        _legendChip('GENERAL', AppColors.generalAccent, AppColors.generalBg),
        _legendChip('LIMITED', AppColors.limitedAccent, AppColors.limitedBg),
        _legendChip('STANDING', AppColors.standingIconAccent, AppColors.standingIconBg),
      ],
    );
  }

  Widget _legendChip(String label, Color accent, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: accent)),
        ],
      ),
    );
  }

  // Front door (left, the boarding side) and driver seat (right) - both
  // drawn with the same seat-cell treatment, aligned to the same
  // left/right block widths as every row beneath them.
  Widget _buildFrontCap(_Dims dims) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: dims.leftBlockWidth, child: _buildDoorCell(dims, label: 'Front Door', icon: Icons.sensor_door_outlined)),
        SizedBox(width: dims.aisleWidth),
        SizedBox(width: dims.rightBlockWidth, child: _buildDriverSeatCell(dims)),
      ],
    );
  }

  Widget _buildDoorCell(_Dims dims, {required String label, required IconData icon}) {
    return Container(
      height: 48 * dims.scale,
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: AppColors.primaryNavy.withOpacity(0.5), width: 3)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16 * dims.scale, color: AppColors.primaryNavy),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10 * dims.scale, fontWeight: FontWeight.bold, color: AppColors.primaryNavy.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  // Driver is a seat too - same rounded seat-icon cell as every passenger
  // seat, but in a neutral grey so it's never mistaken for a bookable seat
  // or for the navy "this is your seat" highlight used elsewhere.
  Widget _buildDriverSeatCell(_Dims dims) {
    return Container(
      height: 48 * dims.scale,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_seat, size: 18 * dims.scale, color: Colors.grey.shade700),
          const SizedBox(height: 2),
          Text('Driver', style: TextStyle(fontSize: 10 * dims.scale, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  _RowZone _zoneForRow(int rowNum) {
    if (rowNum <= 3) {
      return const _RowZone(bg: AppColors.priorityBg, accent: AppColors.priorityAccent, text: AppColors.priorityText);
    }
    if (rowNum <= 6) {
      return const _RowZone(bg: AppColors.generalBg, accent: AppColors.generalAccent, text: AppColors.generalText);
    }
    return const _RowZone(bg: AppColors.limitedBg, accent: AppColors.limitedAccent, text: AppColors.limitedText);
  }

  // Left (2-seat) and right (3-seat) blocks are built as independent
  // stacked columns - same row numbering, same height per row, just laid
  // out side by side with the aisle (and its standing spots) between them,
  // plus "Rear Door" appended under the left column only.
  Widget _buildSeatBody(_Dims dims) {
    return IntrinsicHeight(
      key: const Key('busSeatBody'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              for (final row in _regularRows) ...[
                _buildLeftPair(dims, row),
                SizedBox(height: dims.rowSpacing),
              ],
              SizedBox(
                width: dims.leftBlockWidth,
                child: _buildDoorCell(dims, label: 'Rear Door', icon: Icons.door_back_door_outlined),
              ),
            ],
          ),
          SizedBox(width: dims.aisleWidth, child: _buildAisleColumn(dims)),
          Column(
            children: [
              for (final row in _regularRows) ...[
                _buildRightTriple(dims, row),
                SizedBox(height: dims.rowSpacing),
              ],
              // The right column has no rear door to make room for, so it
              // fits one extra 3-seat row (12) in next to it - the space
              // that would otherwise go to waste beside "Rear Door".
              _buildRightTriple(dims, _extraRightRow),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPair(_Dims dims, int rowNum) {
    final zone = _zoneForRow(rowNum);
    return SizedBox(
      width: dims.leftBlockWidth,
      height: dims.seatHeight,
      child: Row(
        children: [
          Expanded(child: _buildSeatCell(dims, '${rowNum}A', zone.bg, zone.accent)),
          SizedBox(width: dims.smallGap),
          Expanded(child: _buildSeatCell(dims, '${rowNum}B', zone.bg, zone.accent)),
        ],
      ),
    );
  }

  Widget _buildRightTriple(_Dims dims, int rowNum) {
    final zone = _zoneForRow(rowNum);
    return SizedBox(
      width: dims.rightBlockWidth,
      height: dims.seatHeight,
      child: Row(
        children: [
          Expanded(child: _buildSeatCell(dims, '${rowNum}C', zone.bg, zone.accent)),
          SizedBox(width: dims.smallGap),
          Expanded(child: _buildSeatCell(dims, '${rowNum}D', zone.bg, zone.accent)),
          SizedBox(width: dims.smallGap),
          Expanded(child: _buildSeatCell(dims, '${rowNum}E', zone.bg, zone.accent)),
        ],
      ),
    );
  }

  // 6 standing spots, spread down the aisle alongside the Limited rows
  // (7-11) - a hard headcount cap, not extra seats. All styled identically,
  // no side to choose. Slot 1 (rendered last/lowest, nearest the rear
  // door) fills first.
  Widget _buildAisleColumn(_Dims dims) {
    return Column(
      children: [
        SizedBox(height: (dims.seatHeight + dims.rowSpacing) * (_standingRowsStart - 1)),
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < standingCapacity; i++)
                Expanded(
                  child: Center(
                    child: _buildStandingIcon(dims, isMine: _standingAllocatedIndices.contains(standingCapacity - i)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Rear bench (row 13): 6 seats spanning the same width as every other
  // row, same height as every other seat in the bus, no left/right split.
  Widget _buildRearBench(_Dims dims) {
    final zone = _zoneForRow(_rearBenchRow);
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    assert(letters.length == 6, 'Rear bench must render exactly 6 seats');

    // Fits within the exact same left/right margins as every row above it -
    // starts where the left column starts, ends where the right column
    // ends - instead of stretching wider than the rest of the bus.
    final benchSeatWidth = (dims.contentWidth - dims.smallGap * 5) / 6;

    return SizedBox(
      key: const Key('rearBench'),
      width: dims.contentWidth,
      child: Row(
        children: [
          for (var i = 0; i < letters.length; i++) ...[
            if (i > 0) SizedBox(width: dims.smallGap),
            SizedBox(
              width: benchSeatWidth,
              height: dims.seatHeight,
              child: _buildSeatCell(dims, '$_rearBenchRow${letters[i]}', zone.bg, zone.accent),
            ),
          ],
        ],
      ),
    );
  }

  // Every seat - regular or driver - is drawn as a seat icon with its code
  // as a small caption, so the whole map reads visually as "seats" rather
  // than text-labelled boxes. The allocated seat is marked simply: a solid
  // navy fill with a white ring and a small white checkmark badge - no
  // glow, star, or size pop, so it stays clean and reads at a glance
  // without looking like a decoration.
  Widget _buildSeatCell(_Dims dims, String seatNo, Color bg, Color accent) {
    final bool isAllocated = _regularAllocatedSeats.contains(seatNo.toUpperCase());

    if (isAllocated) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.primaryNavy,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: AppColors.primaryNavy.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_seat, size: 16 * dims.scale, color: Colors.white),
                Text(seatNo, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10 * dims.scale)),
              ],
            ),
            Positioned(
              top: -5 * dims.scale,
              right: -5 * dims.scale,
              child: Container(
                width: 14 * dims.scale,
                height: 14 * dims.scale,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryNavy, width: 1.2),
                ),
                child: Icon(Icons.check, size: 9 * dims.scale, color: AppColors.primaryNavy),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_seat, size: 15 * dims.scale, color: accent),
          Text(seatNo, style: TextStyle(color: accent, fontSize: 10 * dims.scale, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // A standing spot is a plain circle - every spot looks the same, no side
  // to choose, no filled/empty distinction. The passenger's own spot (if
  // any) gets the same clean navy-fill-plus-checkmark marker as an
  // allocated seat, not a glowing/starred highlight.
  Widget _buildStandingIcon(_Dims dims, {required bool isMine}) {
    if (isMine) {
      return Container(
        width: dims.standingSize,
        height: dims.standingSize,
        decoration: BoxDecoration(
          color: AppColors.primaryNavy,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(color: AppColors.primaryNavy.withOpacity(0.25), blurRadius: 5, offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.accessibility_new, size: 12 * dims.scale, color: Colors.white),
            Positioned(
              top: -5 * dims.scale,
              right: -5 * dims.scale,
              child: Container(
                width: 12 * dims.scale,
                height: 12 * dims.scale,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.primaryNavy, width: 1)),
                child: Icon(Icons.check, size: 8 * dims.scale, color: AppColors.primaryNavy),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: dims.standingSize,
      height: dims.standingSize,
      decoration: BoxDecoration(
        color: AppColors.standingIconAccent.withOpacity(0.3),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.standingIconAccent.withOpacity(0.7)),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.accessibility_new, size: 11 * dims.scale, color: AppColors.standingIconAccent),
    );
  }
}
