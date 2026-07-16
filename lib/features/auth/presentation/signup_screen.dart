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

  void _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // WHY we pass displayName here:
        // AuthService.signUp() forwards it as data: {'full_name': displayName}.
        // The on_auth_user_created database trigger reads NEW.raw_user_meta_data->>'full_name'
        // to populate the profiles.display_name column atomically in the same transaction
        // as auth.users INSERT.
        await ref.read(authServiceProvider).signUp(
              _emailController.text.trim(),
              _passwordController.text,
              displayName: _nameController.text.trim(),
            );

        // WHY we removed profiles.upsert() that was previously here:
        //
        // The database has an on_auth_user_created trigger (SECURITY DEFINER)
        // that fires atomically when auth.users is inserted. It creates the
        // profiles row via SECURITY DEFINER, bypassing RLS.
        //
        // The old code also called profiles.upsert() immediately after signUp().
        // This caused a race condition: both the trigger AND Flutter tried to
        // INSERT the same user_id at the same millisecond inside the same
        // transaction window. The collision rolled back auth.users entirely,
        // producing the "Database error saving new user" (unexpected_failure) error.
        //
        // The trigger (now using ON CONFLICT DO NOTHING) handles profile creation.
        // Profile updates (currency, language) happen later via
        // AuthService.updateProfile() once the user is authenticated.

        await LocalCacheService.cacheData('is_logged_in', true);

        if (mounted) {
          context.go('/dashboard');
        }
      } on AuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: AppColors.accentRose,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration failed: ${e.toString()}'),
              backgroundColor: AppColors.accentRose,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
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
                  // ── Kanakku Logo ──────────────────────────────────
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
                          validator: (value) => value!.length < 6 ? 'Password must be at least 6 chars' : null,
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
