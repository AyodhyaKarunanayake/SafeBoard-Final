import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/journey_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/incident_report.dart';
import '../../constants/colors.dart';

class IncidentReportScreen extends StatefulWidget {
  final String? initialType;
  final String? initialSeverity;

  const IncidentReportScreen({
    super.key,
    this.initialType,
    this.initialSeverity,
  });

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  String? _selectedType;
  String _severity = 'medium';
  final _descriptionController = TextEditingController();

  final List<Map<String, dynamic>> _types = [
    {
      'id': 'unwanted_contact',
      'label': 'Unwanted contact',
      'icon': Icons.back_hand_outlined,
    },
    {
      'id': 'verbal_harassment',
      'label': 'Verbal harassment',
      'icon': Icons.mark_chat_read_outlined,
    },
    {
      'id': 'physical_assault',
      'label': 'Physical assault',
      'icon': Icons.warning_amber_rounded,
    },
    {
      'id': 'unsafe_crowding',
      'label': 'Unsafe crowding',
      'icon': Icons.groups_outlined,
    },
    {
      'id': 'other',
      'label': 'Other safety concern',
      'icon': Icons.more_horiz,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _selectedType = widget.initialType;
    }
    if (widget.initialSeverity != null) {
      _severity = widget.initialSeverity!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final journeyProvider = Provider.of<JourneyProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final seatNo = journeyProvider.currentAllocation?.seatNumber ?? '3A';
    final currentStop = journeyProvider.currentStop;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Incident Report'),
        backgroundColor: AppColors.emergencyRed,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/journey'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.emergencyRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emergencyRed),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield, color: AppColors.emergencyRed, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your conductor and authority log are notified immediately upon submission.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.emergencyRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Auto-filled Location Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LOGGED SEAT LOCATION',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                      Text('Seat $seatNo (Priority)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('CURRENT STOP',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                      Text(currentStop,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // What happened? 5 Tappable Rows
            const Text('What happened?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy)),
            const SizedBox(height: 10),
            Column(
              children: _types.map((type) {
                final isSelected = _selectedType == type['id'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedType = type['id'];
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.emergencyRed.withOpacity(0.12) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.emergencyRed : AppColors.borderLight,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(type['icon'],
                            color: isSelected ? AppColors.emergencyRed : AppColors.textMuted),
                        const SizedBox(width: 12),
                        Text(
                          type['label'],
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppColors.emergencyRed : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Severity Buttons
            const Text('Severity Level',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildSeverityBtn('Low', 'low', Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _buildSeverityBtn('Medium', 'medium', AppColors.standingAccent)),
                const SizedBox(width: 8),
                Expanded(child: _buildSeverityBtn('High', 'high', AppColors.emergencyRed)),
              ],
            ),
            const SizedBox(height: 24),

            // Description Textarea
            const Text('Description (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Provide additional details for the conductor or transport authority...',
              ),
            ),
            const SizedBox(height: 32),

            // Submit Danger Button
            ElevatedButton(
              onPressed: _selectedType != null
                  ? () async {
                      final report = IncidentReport(
                        incidentId: 'INC_${DateTime.now().millisecondsSinceEpoch}',
                        journeyId: journeyProvider.activeJourney?.journeyId ?? 'JRN_138_001',
                        reporterPassengerId: authProvider.passenger?.passengerId ?? 'p_28745',
                        incidentType: _selectedType!,
                        incidentDatetime: DateTime.now(),
                        seatLocation: seatNo,
                        severityLevel: _severity,
                        description: _descriptionController.text,
                        actionTaken: 'Conductor Notified via FCM',
                        status: 'escalated',
                      );

                      await journeyProvider.submitIncident(report);

                      if (context.mounted) {
                        context.go('/submitted');
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergencyRed,
              ),
              child: const Text('Submit report'),
            ),
            const SizedBox(height: 10),

            // Cancel Button
            OutlinedButton(
              onPressed: () => context.go('/journey'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textDark,
                side: const BorderSide(color: AppColors.borderLight),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityBtn(String label, String val, Color color) {
    bool isSelected = _severity == val;
    return GestureDetector(
      onTap: () {
        setState(() {
          _severity = val;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : AppColors.borderLight),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
