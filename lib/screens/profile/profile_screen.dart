import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/passenger.dart';
import '../../constants/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/tonal_button.dart';
import '../../widgets/gradient_button.dart';

// Stands in for a real uploaded profile photo - see Passenger.avatarColorIndex.
const List<List<Color>> _avatarPalettes = [
  [AppColors.primaryNavy, Color(0xFF2D4A9A)],
  [Color(0xFFB71C1C), Color(0xFFEF5350)],
  [Color(0xFF00695C), Color(0xFF26A69A)],
  [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
  [Color(0xFFE65100), Color(0xFFFFA726)],
  [Color(0xFF2E7D32), Color(0xFF66BB6A)],
  [Color(0xFFAD1457), Color(0xFFEC407A)],
  [Color(0xFF37474F), Color(0xFF78909C)],
];

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

const List<Map<String, String>> _mobilityOptions = [
  {'value': 'none', 'label': 'None'},
  {'value': 'wheelchair', 'label': 'Wheelchair'},
  {'value': 'walking_aid', 'label': 'Walking aid'},
  {'value': 'elderly', 'label': 'Elderly'},
];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showAvatarPicker(BuildContext context, Passenger passenger) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose your avatar color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
            const SizedBox(height: 4),
            const Text('Your initials stay the same, just pick a color that feels like you.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (var i = 0; i < _avatarPalettes.length; i++)
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await authProvider.updateProfile(
                        name: passenger.name,
                        phoneNumber: passenger.phoneNumber,
                        mobilityStatus: passenger.mobilityStatus,
                        avatarColorIndex: i,
                      );
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: _avatarPalettes[i], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: passenger.avatarColorIndex == i ? AppColors.primaryNavy : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: passenger.avatarColorIndex == i ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, Passenger passenger) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditProfileSheet(passenger: passenger),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  String _formatMemberSince(DateTime? date) {
    if (date == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final passenger = authProvider.passenger;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context, passenger),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Safety Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                  const SizedBox(height: 10),
                  _card(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.shield_rounded, color: AppColors.priorityAccent, size: 20),
                                SizedBox(width: 10),
                                Text('Priority Zone Preference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            Switch(
                              value: passenger?.safetyPreference ?? true,
                              activeColor: AppColors.priorityAccent,
                              onChanged: (val) {
                                authProvider.updatePreferences(
                                  safetyPreference: val,
                                  mobilityStatus: passenger?.mobilityStatus ?? 'none',
                                );
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Registered Gender', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.generalBg, borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                (passenger?.gender ?? 'female').toUpperCase(),
                                style: const TextStyle(color: AppColors.generalText, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Personal Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                      if (passenger != null)
                        TonalButton(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          color: AppColors.primaryNavy,
                          dense: true,
                          expand: false,
                          onPressed: () => _showEditProfileSheet(context, passenger),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _card(
                    child: Column(
                      children: [
                        _buildInfoRow('Full Name', passenger?.name ?? 'Passenger'),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Email Address', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                            Row(
                              children: [
                                Text(passenger?.email ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 4),
                                const Icon(Icons.lock_outline, size: 12, color: AppColors.textMuted),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _buildInfoRow('Phone Number', passenger?.phoneNumber ?? '—'),
                        const Divider(height: 20),
                        _buildInfoRow(
                          'Mobility Needs',
                          _mobilityOptions.firstWhere(
                            (o) => o['value'] == (passenger?.mobilityStatus ?? 'none'),
                            orElse: () => _mobilityOptions.first,
                          )['label']!,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  const Text('Account Security', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                  const SizedBox(height: 10),
                  _card(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primaryNavy.withOpacity(0.08), shape: BoxShape.circle),
                        child: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryNavy, size: 18),
                      ),
                      title: const Text('Change Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      onTap: () => _showChangePasswordSheet(context),
                    ),
                  ),
                  const SizedBox(height: 22),

                  const Text('More', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                  const SizedBox(height: 10),
                  _card(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _linkTile(
                          icon: Icons.history_rounded,
                          color: AppColors.generalAccent,
                          title: 'Journey History',
                          onTap: () => context.go('/history'),
                        ),
                        const Divider(height: 1, indent: 60),
                        _linkTile(
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.emergencyRed,
                          title: 'Incident Log',
                          onTap: () => context.go('/incident-history'),
                        ),
                        const Divider(height: 1, indent: 60),
                        _linkTile(
                          icon: Icons.help_outline_rounded,
                          color: AppColors.standingAccent,
                          title: 'Help & Support',
                          subtitle: '1912 Helpline',
                          onTap: () => context.go('/help-support'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  TonalButton(
                    icon: Icons.logout_rounded,
                    label: 'Sign out',
                    color: AppColors.emergencyRed,
                    onPressed: () async {
                      await authProvider.signOut();
                      if (context.mounted) {
                        context.go('/welcome');
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 4),
    );
  }

  Widget _buildHeader(BuildContext context, Passenger? passenger) {
    final palette = _avatarPalettes[(passenger?.avatarColorIndex ?? 0) % _avatarPalettes.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, right: 20, top: 56, bottom: 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF12163F), AppColors.primaryNavy, Color(0xFF2D4A9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: passenger == null ? null : () => _showAvatarPicker(context, passenger),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: palette, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  child: Text(
                    _initialsFor(passenger?.name ?? 'Passenger'),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryNavy, width: 1.5),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 14, color: AppColors.primaryNavy),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            passenger?.name ?? 'Passenger',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            passenger?.email ?? '',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          if (passenger?.createdDate != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(
                'Member since ${_formatMemberSince(passenger!.createdDate)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  Widget _linkTile({required IconData icon, required Color color, required String title, String? subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)) : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      ],
    );
  }
}

InputDecoration _sheetFieldDecoration({required String hint, IconData? icon, bool enabled = true}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5), fontWeight: FontWeight.normal, fontSize: 13),
    prefixIcon: icon != null ? Icon(icon, color: AppColors.textMuted, size: 20) : null,
    filled: true,
    fillColor: enabled ? AppColors.backgroundLight : AppColors.borderLight.withOpacity(0.4),
    contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.5)),
  );
}

Widget _sheetLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
  );
}

Widget _sheetHandle() {
  return Center(
    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2))),
  );
}

class _EditProfileSheet extends StatefulWidget {
  final Passenger passenger;
  const _EditProfileSheet({required this.passenger});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late String _mobilityStatus;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.passenger.name);
    _phoneController = TextEditingController(text: widget.passenger.phoneNumber);
    _mobilityStatus = widget.passenger.mobilityStatus;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          const SizedBox(height: 18),
          const Text('Edit Personal Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
          const SizedBox(height: 18),
          _sheetLabel('Full Name'),
          TextField(controller: _nameController, textCapitalization: TextCapitalization.words, decoration: _sheetFieldDecoration(hint: 'Your full name', icon: Icons.person_outline)),
          const SizedBox(height: 14),
          _sheetLabel('Email Address'),
          TextField(
            enabled: false,
            controller: TextEditingController(text: widget.passenger.email),
            decoration: _sheetFieldDecoration(hint: '', icon: Icons.email_outlined, enabled: false),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Your sign-up email can\'t be changed', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ),
          const SizedBox(height: 14),
          _sheetLabel('Phone Number'),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: _sheetFieldDecoration(hint: 'e.g. +94 77 123 4567', icon: Icons.phone_outlined),
          ),
          const SizedBox(height: 14),
          _sheetLabel('Mobility Needs'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _mobilityOptions.map((opt) {
              final isSelected = _mobilityStatus == opt['value'];
              return ChoiceChip(
                label: Text(opt['label']!),
                selected: isSelected,
                showCheckmark: false,
                selectedColor: AppColors.primaryNavy,
                backgroundColor: AppColors.backgroundLight,
                side: BorderSide(color: isSelected ? AppColors.primaryNavy : AppColors.borderLight),
                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textDark, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 13),
                onSelected: (selected) {
                  if (selected) setState(() => _mobilityStatus = opt['value']!);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 26),
          GradientButton(
            label: 'Save changes',
            isLoading: authProvider.isLoading,
            onPressed: () async {
              await authProvider.updateProfile(
                name: _nameController.text.trim().isEmpty ? widget.passenger.name : _nameController.text.trim(),
                phoneNumber: _phoneController.text.trim(),
                mobilityStatus: _mobilityStatus,
                avatarColorIndex: widget.passenger.avatarColorIndex,
              );
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider authProvider) async {
    setState(() => _error = null);
    if (_newController.text != _confirmController.text) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }
    final error = await authProvider.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          const SizedBox(height: 18),
          const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
          const SizedBox(height: 18),
          _sheetLabel('Current Password'),
          TextField(
            controller: _currentController,
            obscureText: _obscureCurrent,
            decoration: _sheetFieldDecoration(hint: 'Enter your current password', icon: Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted, size: 20),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _sheetLabel('New Password'),
          TextField(
            controller: _newController,
            obscureText: _obscureNew,
            inputFormatters: [LengthLimitingTextInputFormatter(32)],
            decoration: _sheetFieldDecoration(hint: 'Minimum 6 characters', icon: Icons.lock_reset_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted, size: 20),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _sheetLabel('Confirm New Password'),
          TextField(
            controller: _confirmController,
            obscureText: _obscureNew,
            decoration: _sheetFieldDecoration(hint: 'Re-enter new password', icon: Icons.lock_reset_rounded),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 24),
          GradientButton(
            label: 'Update password',
            isLoading: authProvider.isLoading,
            onPressed: () => _submit(authProvider),
          ),
        ],
      ),
    );
  }
}
