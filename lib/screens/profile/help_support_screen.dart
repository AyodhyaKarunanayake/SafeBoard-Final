import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _call(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the dialer. Please call $number manually.')),
      );
    }
  }

  Future<void> _email(BuildContext context, String address) async {
    final uri = Uri(scheme: 'mailto', path: address);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open a mail app. Please email $address manually.')),
      );
    }
  }

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
                  // Primary: NTC 1912 helpline, one tap to call.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primaryNavy, Color(0xFF2D4A9A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppColors.primaryNavy.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                              child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text('National Transport Commission Helpline', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text('1912', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        const Text('Toll-free · Available 24 hours', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _call(context, '1912'),
                            icon: const Icon(Icons.call_rounded, size: 18),
                            label: const Text('Call 1912 now', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryNavy,
                              minimumSize: const Size(double.infinity, 50),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Other ways to reach us', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                  const SizedBox(height: 10),
                  _contactTile(
                    context,
                    icon: Icons.local_police_outlined,
                    color: AppColors.emergencyRed,
                    title: 'Police Emergency',
                    subtitle: '119 · For immediate physical danger',
                    onTap: () => _call(context, '119'),
                  ),
                  const SizedBox(height: 10),
                  _contactTile(
                    context,
                    icon: Icons.support_agent_rounded,
                    color: AppColors.generalAccent,
                    title: 'SafeBoard Support Team',
                    subtitle: 'support@safeboard.lk',
                    onTap: () => _email(context, 'support@safeboard.lk'),
                  ),
                  const SizedBox(height: 10),
                  _contactTile(
                    context,
                    icon: Icons.woman_rounded,
                    color: AppColors.priorityAccent,
                    title: 'Women\'s Helpline',
                    subtitle: '1938 · Counselling & safety support',
                    onTap: () => _call(context, '1938'),
                  ),
                  const SizedBox(height: 28),

                  const Text('Frequently asked', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                  const SizedBox(height: 10),
                  _faqTile('How does gender-aware seating work?',
                      'SafeBoard allocates Priority Zone seats (rows 1-3, near the front door) first to passengers who\'ve opted in for extra safety, using proximity rules to keep a comfortable distance between passengers.'),
                  _faqTile('What happens when I press the SOS button?',
                      'After a quick confirmation, your seat number and location are sent straight to the conductor, and you get a short "Alert sent" confirmation.'),
                  _faqTile('Can I get a refund if I paid in the app?',
                      'Refunds for in-app payments are handled by the National Transport Commission - call the 1912 helpline above and have your booking reference ready.'),
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
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).canPop() ? context.pop() : context.go('/profile'),
          ),
          const SizedBox(height: 16),
          const Text('Help & Support', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          const Text(
            'Safety concerns, questions, or feedback - here\'s how to reach the right people.',
            style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _contactTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderLight)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faqTile(String question, String answer) {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 14),
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(answer, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
