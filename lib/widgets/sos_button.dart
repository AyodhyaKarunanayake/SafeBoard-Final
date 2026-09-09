import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';

// Emergency trigger: tap -> a quick Yes/Cancel confirmation (so a stray
// touch on a crowded, moving bus can't fire it by accident) -> on "Yes",
// notify the conductor and show a brief "Alert sent" confirmation so the
// passenger knows it went through. A shield icon reads as protection/safety
// rather than a medical emergency, per the harassment-reporting use case
// this button is for.
class SOSButton extends StatefulWidget {
  final Future<void> Function() onTrigger;
  final double size;

  const SOSButton({
    super.key,
    required this.onTrigger,
    this.size = 64.0,
  });

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> {
  bool _sending = false;

  Future<void> _handleTap() async {
    if (_sending) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.emergencyRed),
            SizedBox(width: 10),
            Expanded(child: Text('Alert the conductor?')),
          ],
        ),
        content: const Text(
          'This immediately sends your seat number and location to the conductor.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergencyRed),
            child: const Text('Yes, alert'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sending = true);
    HapticFeedback.heavyImpact();
    await widget.onTrigger();
    if (!mounted) return;
    setState(() => _sending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('Alert sent to the conductor')),
          ],
        ),
        backgroundColor: AppColors.emergencyRed,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Emergency safety button. Tap to alert the conductor with your seat and location, after a quick confirmation.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Container(
          width: widget.size + 12,
          height: widget.size + 12,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.emergencyRed.withOpacity(0.12),
          ),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE5484D), Color(0xFFA8231A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA8231A).withOpacity(0.45),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: _sending
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Icon(Icons.shield_rounded, color: Colors.white, size: widget.size * 0.44),
          ),
        ),
      ),
    );
  }
}
