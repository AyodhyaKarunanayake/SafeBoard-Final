import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/colors.dart';

class _NotificationItem {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  final bool unread;

  const _NotificationItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    this.unread = false,
  });
}

// Sample notification feed - there's no push-notification backend wired up
// in this app, so this illustrates the kind of alerts SafeBoard would send
// (seat confirmations, departure reminders, safety tips) rather than
// reflecting real delivered notifications.
const List<_NotificationItem> _today = [
  _NotificationItem(
    icon: Icons.event_seat_rounded,
    color: AppColors.priorityAccent,
    title: 'Seat confirmed',
    body: 'Your Priority Zone seat on Route 87 has been allocated.',
    time: '10 min ago',
    unread: true,
  ),
  _NotificationItem(
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.generalAccent,
    title: 'Departure reminder',
    body: 'Your bus departs from Colombo (Pettah) in 30 minutes.',
    time: '32 min ago',
    unread: true,
  ),
  _NotificationItem(
    icon: Icons.shield_rounded,
    color: AppColors.standingAccent,
    title: 'Safety tip',
    body: 'Priority seats sit near the front door for easy exit and conductor oversight.',
    time: '3 hr ago',
  ),
];

const List<_NotificationItem> _earlier = [
  _NotificationItem(
    icon: Icons.qr_code_2_rounded,
    color: AppColors.primaryNavy,
    title: 'Payment successful',
    body: 'Your fare was paid and your boarding QR is ready in My Ticket.',
    time: 'Yesterday',
  ),
  _NotificationItem(
    icon: Icons.star_rounded,
    color: AppColors.standingAccent,
    title: 'Rate your last trip',
    body: 'Tell us how your Route 87 journey went - it only takes a moment.',
    time: '2 days ago',
  ),
];

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Today', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  for (final n in _today) ...[_buildTile(n), const SizedBox(height: 10)],
                  const SizedBox(height: 12),
                  const Text('Earlier', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  for (final n in _earlier) ...[_buildTile(n), const SizedBox(height: 10)],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF12163F), AppColors.primaryNavy, Color(0xFF2D4A9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).canPop() ? context.pop() : context.go('/home'),
          ),
          const SizedBox(width: 12),
          const Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildTile(_NotificationItem n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: n.color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(n.icon, color: n.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark))),
                    if (n.unread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.priorityAccent, shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(n.body, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4)),
                const SizedBox(height: 6),
                Text(n.time, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
