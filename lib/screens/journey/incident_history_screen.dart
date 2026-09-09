import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/journey_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/incident_report.dart';
import '../../constants/colors.dart';

// "My reports" - a quiet place for a passenger to review anything they've
// filed before, including SOS alerts, without it being prominent on the
// main Journey screen.
class IncidentHistoryScreen extends StatelessWidget {
  const IncidentHistoryScreen({super.key});

  String _typeLabel(String type) {
    switch (type) {
      case 'unwanted_contact':
        return 'Unwanted contact / SOS';
      case 'verbal_harassment':
        return 'Verbal harassment';
      case 'physical_assault':
        return 'Physical assault';
      case 'unsafe_crowding':
        return 'Unsafe crowding';
      default:
        return 'Other';
    }
  }

  Color _severityColor(String level) {
    switch (level) {
      case 'high':
        return AppColors.emergencyRed;
      case 'medium':
        return AppColors.standingAccent;
      default:
        return AppColors.generalAccent;
    }
  }

  String _formatDate(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${dt.day}/${dt.month}/${dt.year} · ${formattedHour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final journeyProvider = Provider.of<JourneyProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final passengerId = authProvider.passenger?.passengerId ?? 'p_28745';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).canPop() ? context.pop() : context.go('/journey'),
        ),
      ),
      body: FutureBuilder<List<IncidentReport>>(
        future: journeyProvider.getMyIncidents(passengerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 44, color: AppColors.textMuted.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'No reports yet',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Anything you report during a journey - including SOS alerts - will show up here so you can follow up later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final report = reports[index];
              final color = _severityColor(report.severityLevel);
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _typeLabel(report.incidentType),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            report.status.toUpperCase(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_formatDate(report.incidentDatetime), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text('Seat ${report.seatLocation}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    if (report.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(report.description, style: const TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.4)),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
