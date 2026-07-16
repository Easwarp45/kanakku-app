import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/database/local_cache_service.dart';
import '../../../../core/utils/error_mapper.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _goToDashboard() async {
    await LocalCacheService.cacheData('is_logged_in', true);
    if (mounted) context.go('/dashboard');
  }

  Future<bool> _tryRecoverSession(String email, String password) async {
    try {
      debugPrint('[SIGNUP FLOW] Attempting session recovery via sign-in');
      final login = await ref
          .read(authServiceProvider)
          .signIn(email, password)
          .timeout(const Duration(seconds: 15));
      if (login.session != null) {
        debugPrint('[SIGNUP FLOW] Recovery sign-in succeeded');
        await _goToDashboard();
        return true;
      }
    } catch (e) {
      debugPrint('[SIGNUP FLOW] Recovery sign-in failed: $e');
    }
    return false;
  }

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    debugPrint('[SIGNUP FLOW] 1. Button pressed');
    try {
      debugPrint('[SIGNUP FLOW] 2. Signup request started');
      final res = await ref
          .read(authServiceProvider)
          .signUp(email, password, displayName: name)
          .timeout(const Duration(seconds: 45));

      debugPrint('[SIGNUP FLOW] 3. Signup response user_id=${res.user?.id}');

      if (res.session != null) {
        debugPrint('[SIGNUP FLOW] 4. Session present — navigating');
        await _goToDashboard();
        return;
      }

      // Account may exist without a session (email confirmation required).
      if (res.user != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created. Check your email to verify, then sign in.',
              ),
              backgroundColor: AppColors.accentEmerald,
              duration: Duration(seconds: 5),
            ),
          );
          context.go('/login');
        }
        return;
      }

      // Rare: empty user + empty session. Try sign-in recovery.
      if (await _tryRecoverSession(email, password)) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to create your account. Please try again.'),
            backgroundColor: AppColors.accentRose,
          ),
        );
      }
    } on TimeoutException catch (e) {
      debugPrint('[SIGNUP FLOW] Timeout: $e');
      // Server often finishes creating the user even when the HTTP response hangs.
      if (await _tryRecoverSession(email, password)) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Signup is taking too long. If the account was created, try Sign In. '
              'Otherwise run the unblock SQL in Supabase and retry.',
            ),
            backgroundColor: AppColors.accentRose,
            duration: Duration(seconds: 6),
          ),
        );
      }
    } on AuthException catch (e) {
      debugPrint('[SIGNUP FLOW] AuthException: ${e.message}');
      final msg = e.message.toLowerCase();

      // User already exists — try signing them in.
      if (msg.contains('already') || msg.contains('registered')) {
        if (await _tryRecoverSession(email, password)) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('An account with this email already exists. Please sign in.'),
              backgroundColor: AppColors.accentRose,
            ),
          );
          context.go('/login');
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMapper.userMessage(e, fallback: 'Unable to create your account.'),
            ),
            backgroundColor: AppColors.accentRose,
          ),
        );
      }
    } catch (e) {
      debugPrint('[SIGNUP FLOW] Error: $e');
      if (await _tryRecoverSession(email, password)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMapper.userMessage(e, fallback: 'Unable to create your account.'),
            ),
            backgroundColor: AppColors.accentRose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/icons/kanakku_logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Start your financial journey with Kanakku',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CustomTextField(
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          controller: _nameController,
                          prefixIcon: const Icon(LucideIcons.user, color: AppColors.textTertiary),
                          validator: (value) => value!.isEmpty ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          label: 'Email Address',
                          hint: 'Enter your email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(LucideIcons.mail, color: AppColors.textTertiary),
                          validator: (value) => value!.isEmpty ? 'Email is required' : null,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          label: 'Password',
                          hint: 'Create a secure password',
                          controller: _passwordController,
                          obscureText: true,
                          prefixIcon: const Icon(LucideIcons.lock, color: AppColors.textTertiary),
                          validator: (value) =>
                              value!.length < 6 ? 'Password must be at least 6 chars' : null,
                        ),
                        const SizedBox(height: 32),
                        GradientButton(
                          text: 'Initialize Core',
                          icon: LucideIcons.shieldCheck,
                          isLoading: _isLoading,
                          onPressed: _signup,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account?',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Sign In'),
                      ),
                    ],
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textTertiary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot your password?',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
