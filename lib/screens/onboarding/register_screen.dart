import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../widgets/gradient_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  String _selectedGender = 'female';

  final List<Map<String, String>> _genderOptions = [
    {'value': 'female', 'label': 'Female'},
    {'value': 'male', 'label': 'Male'},
    {'value': 'prefer_not_to_say', 'label': 'Prefer not to say'},
  ];

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_onFocusChange);
    _emailFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.emergencyRed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField(
                    label: 'Full name',
                    controller: _nameController,
                    focusNode: _nameFocus,
                    icon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 22),

                  _buildField(
                    label: 'Email address',
                    controller: _emailController,
                    focusNode: _emailFocus,
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 22),

                  _buildField(
                    label: 'Password',
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 26),

                  const Padding(
                    padding: EdgeInsets.only(left: 2, bottom: 10),
                    child: Text(
                      'Gender',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textMuted, letterSpacing: 0.3),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _genderOptions.map((opt) {
                      final isSelected = _selectedGender == opt['value'];
                      return ChoiceChip(
                        label: Text(opt['label']!),
                        selected: isSelected,
                        showCheckmark: false,
                        selectedColor: AppColors.primaryNavy,
                        backgroundColor: const Color(0xFFF1F4FA),
                        elevation: 0,
                        pressElevation: 0,
                        shadowColor: Colors.transparent,
                        side: BorderSide(color: isSelected ? AppColors.primaryNavy : Colors.transparent),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textDark,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedGender = opt['value']!;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.generalBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.generalAccent.withOpacity(0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.generalAccent, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your gender informs how our rule-based algorithm allocates your seat safely and respects proximity constraints.',
                            style: TextStyle(fontSize: 12, color: AppColors.generalText, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  GradientButton(
                    label: 'Continue to preferences',
                    isLoading: authProvider.isLoading,
                    onPressed: () async {
                      if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
                        _showError('Please fill in all required fields.');
                        return;
                      }

                      if (_passwordController.text.trim().length < 6) {
                        _showError('Password must be at least 6 characters.');
                        return;
                      }

                      final error = await authProvider.register(
                        name: _nameController.text.trim(),
                        email: _emailController.text.trim(),
                        password: _passwordController.text.trim(),
                        gender: _selectedGender,
                      );
                      if (!context.mounted) return;
                      if (error != null) {
                        _showError(error);
                        return;
                      }
                      context.go('/preferences');
                    },
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? ', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text(
                          'Sign in',
                          style: TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
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
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
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
            onPressed: () => context.go('/welcome'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Create your account',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join SafeBoard for safer, rule-allocated seating on Sri Lankan public transport.',
            style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  // A labeled credential field: a small muted label above a rounded input
  // that lifts with a soft navy shadow and a solid border while focused.
  // No placeholder/example text is ever shown - the label above the box is
  // the only description of what belongs in it.
  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final isFocused = focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textMuted, letterSpacing: 0.3),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isFocused
                ? [BoxShadow(color: AppColors.primaryNavy.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 6))]
                : const [],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            obscureText: obscureText,
            style: const TextStyle(fontSize: 15, color: AppColors.textDark, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: isFocused ? AppColors.primaryNavy : AppColors.textMuted, size: 20),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: isFocused ? Colors.white : const Color(0xFFF1F4FA),
              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
