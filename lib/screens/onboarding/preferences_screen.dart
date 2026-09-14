import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../widgets/zone_pill.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool _safetyPreference = true;
  String _mobilityStatus = 'none';

  final List<Map<String, String>> _mobilityOptions = [
    {'value': 'none', 'label': 'None'},
    {'value': 'wheelchair', 'label': 'Wheelchair'},
    {'value': 'walking_aid', 'label': 'Walking aid'},
    {'value': 'elderly', 'label': 'Elderly'},
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Priority Zone Toggle Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _safetyPreference ? AppColors.priorityBg : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _safetyPreference ? AppColors.priorityAccent : AppColors.borderLight,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _safetyPreference
                          ? AppColors.priorityAccent
                          : AppColors.textMuted.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Priority Zone Preference',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Prioritises allocation in Rows 1-3 near the front door for enhanced safety.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _safetyPreference,
                    activeColor: AppColors.priorityAccent,
                    onChanged: (val) {
                      setState(() {
                        _safetyPreference = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mobility Needs Selector
            const Text(
              'Mobility Needs',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _mobilityOptions.map((opt) {
                final isSelected = _mobilityStatus == opt['value'];
                return ChoiceChip(
                  label: Text(opt['label']!),
                  selected: isSelected,
                  selectedColor: AppColors.priorityAccent,
                  backgroundColor: AppColors.borderLight.withOpacity(0.5),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textDark,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _mobilityStatus = opt['value']!;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Full Zone Guide Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SafeBoard Three-Zone System',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildZoneGuideRow(
                    'priority',
                    'Rows 1-3 (Front Door)',
                    'Allocated first to safety-preference & mobility passengers.',
                  ),
                  const Divider(height: 16),
                  _buildZoneGuideRow(
                    'general',
                    'Rows 4-8 (Standard)',
                    'Proximity rules maintain comfortable distance between passengers.',
                  ),
                  const Divider(height: 16),
                  _buildZoneGuideRow(
                    'standing',
                    'Rear Aisle (Standing)',
                    'Soft limit at 80% capacity; hard stop at 100% capacity.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Start Safe Journeys Button
            ElevatedButton(
              onPressed: authProvider.isLoading
                  ? null
                  : () async {
                      await authProvider.updatePreferences(
                        safetyPreference: _safetyPreference,
                        mobilityStatus: _mobilityStatus,
                      );
                      if (context.mounted) {
                        context.go('/home');
                      }
                    },
              child: authProvider.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Start safe journeys →'),
            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: const Text('Step 2 of 2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const Text('SafeBoard Setup', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Customize your allocation',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set your seating priority and mobility needs for automated rule matching.',
            style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneGuideRow(String zone, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZonePill(zone: zone, small: true),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
