import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/journey_provider.dart';
import '../../constants/colors.dart';
import '../../widgets/gradient_button.dart';

class RequestingScreen extends StatefulWidget {
  const RequestingScreen({super.key});

  @override
  State<RequestingScreen> createState() => _RequestingScreenState();
}

class _RequestingScreenState extends State<RequestingScreen> {
  int _currentStep = 0;
  bool _isComplete = false;
  Timer? _timer;

  final List<String> _steps = [
    'Checking zone availability',
    'Applying safety rules & preferences',
    'Optimising passenger proximity',
    'Seat confirmed',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startSequence();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSequence() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final journeyProvider = Provider.of<JourneyProvider>(context, listen: false);

    // Step-by-step timer animation
    _timer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentStep < _steps.length - 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        timer.cancel();
        setState(() {
          _isComplete = true;
        });
      }
    });

    // Trigger Allocation - group bookings (seatCount > 1) run the engine
    // once per passenger; a single seat (the default) is untouched.
    final passenger = authProvider.passenger;
    if (passenger != null) {
      if (bookingProvider.isGroupBooking) {
        final results = await bookingProvider.requestGroupAllocation(passenger);
        if (mounted) {
          journeyProvider.setCurrentAllocation(results.first);
        }
      } else {
        final alloc = await bookingProvider.requestAllocation(passenger);
        if (mounted) {
          journeyProvider.setCurrentAllocation(alloc);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStep + (_isComplete ? 1 : 0)) / _steps.length;
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final title = bookingProvider.isGroupBooking ? 'Finding Your Seats' : 'Finding Your Seat';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Slim progress bar in place of a decorative logo mark.
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    backgroundColor: AppColors.borderLight,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primaryNavy),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Our rule-based engine is applying 3-zone safety and proximity rules...',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Minimal connected-dot timeline instead of boxed cards.
              Column(
                children: List.generate(_steps.length, (index) {
                  final bool isDone = index <= _currentStep && (index < _currentStep || _isComplete);
                  final bool isCurrent = index == _currentStep && !_isComplete;
                  final bool isLast = index == _steps.length - 1;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDone ? AppColors.primaryNavy : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDone || isCurrent ? AppColors.primaryNavy : AppColors.borderLight,
                                  width: 1.5,
                                ),
                              ),
                              child: isDone
                                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                                  : isCurrent
                                      ? const Padding(
                                          padding: EdgeInsets.all(3),
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryNavy),
                                        )
                                      : null,
                            ),
                            if (!isLast) Expanded(child: Container(width: 1.5, color: isDone ? AppColors.primaryNavy.withOpacity(0.3) : AppColors.borderLight)),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 22),
                            child: Text(
                              _steps[index],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: (isDone || isCurrent) ? FontWeight.w700 : FontWeight.w500,
                                color: (isDone || isCurrent) ? AppColors.textDark : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),

              const Spacer(flex: 3),

              // "See my seat" button appears once allocation completes.
              if (_isComplete)
                GradientButton(
                  label: 'See my seat',
                  onPressed: () => context.go('/allocation'),
                )
              else
                const SizedBox(height: 54),
            ],
          ),
        ),
      ),
    );
  }
}
