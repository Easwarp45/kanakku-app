import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../core/theme/app_colors.dart';

class SetNewPasswordScreen extends ConsumerStatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  ConsumerState<SetNewPasswordScreen> createState() =>
      _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends ConsumerState<SetNewPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _passwordUpdated = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Why updateUser: After Supabase processes the deep link (recovery token),
      // the user is in a temporary PASSWORD_RECOVERY session. Calling updateUser
      // with a new password permanently updates the account and transitions the
      // session to a normal authenticated state.
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (mounted) {
        setState(() {
          _passwordUpdated = true;
          _isLoading = false;
        });
        _animController
          ..reset()
          ..forward();
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showError(e.message);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showError('Something went wrong. Please try again.');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.accentRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Password strength: 0 = weak, 1 = medium, 2 = strong
  int _strength(String pw) {
    if (pw.length < 6) return 0;
    final hasUpper = pw.contains(RegExp(r'[A-Z]'));
    final hasDigit = pw.contains(RegExp(r'[0-9]'));
    final hasSpecial = pw.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    final score = (hasUpper ? 1 : 0) + (hasDigit ? 1 : 0) + (hasSpecial ? 1 : 0);
    if (pw.length >= 12 && score >= 2) return 2;
    if (pw.length >= 8 && score >= 1) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background glows
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accentPurple.withValues(alpha: 0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accentCyan.withValues(alpha: 0.10),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // App bar — only show back button before success
                if (!_passwordUpdated)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.go('/login'),
                          icon: const Icon(LucideIcons.chevronLeft,
                              color: AppColors.textPrimary, size: 24),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: _passwordUpdated
                            ? _buildSuccessView()
                            : _buildFormView(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    final pw = _passwordController.text;
    final strength = _strength(pw);
    final strengthColors = [AppColors.accentRose, AppColors.accentAmber, AppColors.accentEmerald];
    final strengthLabels = ['Weak', 'Good', 'Strong'];

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon badge
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentPurple.withValues(alpha: 0.22),
                    AppColors.accentCyan.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: AppColors.accentPurple.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Icon(LucideIcons.lock,
                  color: AppColors.accentPurple, size: 34),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Set New Password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Create a strong new password\nfor your Kanakku account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          GlassCard(
            padding: const EdgeInsets.all(24),
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // New Password field
                _buildPasswordField(
                  label: 'New Password',
                  hint: 'Min. 8 characters',
                  controller: _passwordController,
                  obscure: _obscurePassword,
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}), // rebuild strength bar
                ),
                // Password strength indicator
                if (pw.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ...List.generate(3, (i) {
                        final active = i <= strength;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 4,
                            margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: active
                                  ? strengthColors[strength]
                                  : AppColors.border.withValues(alpha: 0.3),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          strengthLabels[strength],
                          key: ValueKey(strength),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: strengthColors[strength],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                // Confirm Password field
                _buildPasswordField(
                  label: 'Confirm Password',
                  hint: 'Re-enter your new password',
                  controller: _confirmController,
                  obscure: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                GradientButton(
                  text: 'Update Password',
                  icon: LucideIcons.shieldCheck,
                  isLoading: _isLoading,
                  onPressed: _updatePassword,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          cursorColor: AppColors.accentCyan,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(LucideIcons.lock,
                color: AppColors.textTertiary, size: 20),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentEmerald.withValues(alpha: 0.28),
                    AppColors.accentCyan.withValues(alpha: 0.16),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: AppColors.accentEmerald.withValues(alpha: 0.55),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentEmerald.withValues(alpha: 0.22),
                    blurRadius: 28,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Icon(LucideIcons.shieldCheck,
                  color: AppColors.accentEmerald, size: 40),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Password Updated!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Your Kanakku account password has been\nsuccessfully updated.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 40),
        GradientButton(
          text: 'Sign In Now',
          icon: LucideIcons.logIn,
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}
