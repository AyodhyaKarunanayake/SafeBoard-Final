import 'package:flutter/material.dart';

// A soft, filled "tonal" button - a tinted background in the action's own
// color with no hard border, colored icon + label, and a ripple on tap.
// This is the modern Material 3 / iOS-tinted-button look used throughout
// the Journey tab's action buttons, in place of flat outlined boxes.
class TonalButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool dense;
  final bool expand;

  const TonalButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.dense = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(dense ? 10 : 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(dense ? 10 : 14),
        onTap: onPressed,
        child: Padding(
          padding: dense ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: dense ? 15 : 18, color: color),
              SizedBox(width: dense ? 6 : 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: dense ? 12 : 13.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
