import 'package:flutter/material.dart';
import '../constants/colors.dart';

class OccupancyBar extends StatelessWidget {
  final double percentage; // 0.0 - 1.0
  final int priorityCount;
  final int generalCount;
  final int standingCount;

  const OccupancyBar({
    super.key,
    required this.percentage,
    required this.priorityCount,
    required this.generalCount,
    required this.standingCount,
  });

  Color get _statusColor {
    if (percentage >= 0.9) return AppColors.emergencyRed;
    if (percentage >= 0.75) return AppColors.standingAccent;
    return AppColors.generalAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bus Occupancy (${(percentage * 100).toInt()}%)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              percentage >= 0.9
                  ? 'CRITICAL'
                  : percentage >= 0.75
                      ? 'HIGH'
                      : 'MODERATE',
              style: TextStyle(
                color: _statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMiniCounter('Priority', '$priorityCount/12', AppColors.priorityAccent),
            _buildMiniCounter('General', '$generalCount/30', AppColors.generalAccent),
            _buildMiniCounter('Standing', '$standingCount/18', AppColors.standingAccent),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniCounter(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
