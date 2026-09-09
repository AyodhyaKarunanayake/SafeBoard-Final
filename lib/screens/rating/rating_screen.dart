import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/tickets_provider.dart';
import '../../constants/colors.dart';
import '../../widgets/zone_pill.dart';
import '../../widgets/gradient_button.dart';

class RatingScreen extends StatefulWidget {
  final String? ticketId;

  const RatingScreen({super.key, this.ticketId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _stars = 5;
  final List<String> _tags = [
    'Felt safe',
    'Seat well allocated',
    'Conductor helpful',
    'Clear QR process',
    'No issues',
  ];
  final Set<String> _selectedTags = {'Felt safe', 'Seat well allocated'};
  final _commentsController = TextEditingController();

  String get _safetyLabel {
    switch (_stars) {
      case 1:
        return 'Not safe';
      case 2:
        return 'Uncomfortable';
      case 3:
        return 'Acceptable';
      case 4:
        return 'Good';
      case 5:
        return 'Very safe';
      default:
        return 'Very safe';
    }
  }

  Color get _safetyColor {
    if (_stars <= 2) return AppColors.emergencyRed;
    if (_stars == 3) return Colors.orange.shade700;
    return AppColors.generalAccent;
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketsProvider = Provider.of<TicketsProvider>(context, listen: false);
    final ticket = widget.ticketId != null ? ticketsProvider.ticketById(widget.ticketId!) : null;

    final routeLabel = ticket != null ? '${ticket.route.routeName} Complete' : 'Journey Complete';
    final journeyLabel = ticket != null ? '${ticket.allocation.boardingStop} → ${ticket.allocation.alightingStop}' : '';
    final zoneKey = ticket == null
        ? 'general'
        : ticket.allocation.seatNumber.toUpperCase().startsWith('STANDING')
            ? 'standing'
            : (int.tryParse(RegExp(r'^(\d+)').firstMatch(ticket.allocation.seatNumber)?.group(1) ?? '') ?? 99) <= 3
                ? 'priority'
                : 'general';

    void finish() {
      if (ticket != null) {
        ticketsProvider.rateTicket(ticket.ticketId, _stars);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you! Feedback logged to analytics.')),
      );
      context.go('/home');
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, routeLabel, journeyLabel, zoneKey, finish),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                children: [
                  _buildStarCard(),
                  const SizedBox(height: 16),
                  _buildTagsCard(),
                  const SizedBox(height: 16),
                  _buildCommentsCard(),
                  const SizedBox(height: 28),
                  GradientButton(label: 'Submit Feedback', onPressed: finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String routeLabel,
    String journeyLabel,
    String zoneKey,
    VoidCallback finish,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF12163F), AppColors.primaryNavy, Color(0xFF2D4A9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Journey Feedback',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.4),
              ),
              TextButton(
                onPressed: finish,
                style: TextButton.styleFrom(foregroundColor: Colors.white70, padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: const Text('Skip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            routeLabel,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          if (journeyLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(journeyLabel, style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
          ],
          const SizedBox(height: 14),
          ZonePill(zone: zoneKey, small: true),
        ],
      ),
    );
  }

  Widget _buildStarCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primaryNavy.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          const Text(
            'How safe did you feel?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starVal = index + 1;
              final filled = starVal <= _stars;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _stars = starVal),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.all(6),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 150),
                    scale: filled ? 1.0 : 0.88,
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 38,
                      color: filled ? AppColors.standingAccent : AppColors.borderLight,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _safetyLabel,
              key: ValueKey(_stars),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _safetyColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primaryNavy.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What made your journey safe?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select all that apply.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryNavy : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? AppColors.primaryNavy : AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primaryNavy.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Anything else to add?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 4),
          const Text(
            'Optional - help us improve allocation rules and bus safety.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentsController,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Share any details about your trip...',
              hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.normal),
              isDense: true,
              filled: true,
              fillColor: AppColors.backgroundLight,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}
