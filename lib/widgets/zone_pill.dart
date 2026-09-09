import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ZonePill extends StatelessWidget {
  final String zone; // 'p' / 'g' / 's' or 'priority' / 'general' / 'standing'
  final bool small;

  const ZonePill({
    super.key,
    required this.zone,
    this.small = false,
  });

  String get _label {
    final z = zone.toLowerCase();
    if (z.startsWith('p')) return 'Priority Zone';
    if (z.startsWith('g')) return 'General Zone';
    if (z.startsWith('s')) return 'Standing Area';
    return 'General Zone';
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.getZoneBg(zone);
    final text = AppColors.getZoneText(zone);
    final accent = AppColors.getZoneAccent(zone);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: small ? 6 : 8,
            height: small ? 6 : 8,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: small ? 4 : 6),
          Text(
            _label,
            style: TextStyle(
              color: text,
              fontSize: small ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
