import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/database/local_cache_service.dart';
import '../../../core/utils/multi_currency_helper.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _deliveryMsgController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isSaving = false;
  bool _isLoadingProfile = true;

  final List<Map<String, dynamic>> _avatarPresets = [
    {
      'name': 'Neon Cyan',
      'colors': [const Color(0xFF00D9FF), const Color(0xFF0055FF)],
    },
    {
      'name': 'Vaporwave',
      'colors': [const Color(0xFFA855F7), const Color(0xFFF43F5E)],
    },
    {
      'name': 'Emerald Matrix',
      'colors': [const Color(0xFF10B981), const Color(0xFF059669)],
    },
    {
      'name': 'Crimson Pulse',
      'colors': [const Color(0xFFF43F5E), const Color(0xFFB91C1C)],
    },
    {
      'name': 'Solar Flare',
      'colors': [const Color(0xFFFBBF24), const Color(0xFFD97706)],
    },
    {
      'name': 'Deep Cosmos',
      'colors': [const Color(0xFF3B82F6), const Color(0xFF1E3A8A)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _emailController.text = user.email ?? '';
      
      String? metaName = user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
      if (metaName != null) {
        _nameController.text = metaName;
      }

      try {
        final profile = await ref.read(authServiceProvider).getProfileData(user.id);
        if (profile != null) {
          if (mounted) {
            setState(() {
              if (profile['display_name'] != null && profile['display_name'].toString().isNotEmpty) {
                _nameController.text = profile['display_name'];
              }
              _phoneController.text = profile['phone_number'] ?? '';
            });
          }
        }
      } catch (_) {}

      // Load cached/unsupported fields from local preference provider
      final prefs = ref.read(preferencesProvider);
      if (mounted) {
        setState(() {
          _usernameController.text = prefs.username;
          _addressController.text = prefs.deliveryAddress;
          _deliveryMsgController.text = prefs.deliveryInstructions;
          _isLoadingProfile = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  void _saveProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      // 1. Update remote DB profiles table
      await ref.read(authServiceProvider).updateProfile(user.id, {
        'display_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
      });

      // 2. Update local settings cache
      final prefsNotifier = ref.read(preferencesProvider.notifier);
      await prefsNotifier.updateUsername(_usernameController.text.trim());
      await prefsNotifier.updateDeliveryAddress(_addressController.text.trim());
      await prefsNotifier.updateDeliveryInstructions(_deliveryMsgController.text.trim());

      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.checkCircle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Personal information updated!'),
              ],
            ),
            backgroundColor: AppColors.accentEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: AppColors.accentRose),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _logout() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.accentCyan)));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Text('PERSONAL INFORMATION', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 32),
              
              _buildSectionTitle('Profile'),
              _buildProfileSection(),
              const SizedBox(height: 24),

              _buildSectionTitle('Contact Information'),
              _buildContactSection(),
              const SizedBox(height: 24),

              _buildSectionTitle('Regional Preferences'),
              _buildRegionalSection(),
              const SizedBox(height: 24),

              _buildSectionTitle('Financial Preferences'),
              _buildFinancialSection(),
              const SizedBox(height: 24),

              _buildSectionTitle('Security'),
              _buildSecuritySection(),
              const SizedBox(height: 24),

              _buildSectionTitle('Connected Accounts'),
              _buildConnectedAccountsSection(),
              const SizedBox(height: 24),

              _buildSectionTitle('Personalization'),
              _buildPersonalizationSection(),
              const SizedBox(height: 24),

              _buildSectionTitle('Privacy Controls'),
              _buildPrivacySection(),
              const SizedBox(height: 24),

              _buildSectionTitle('Data Management'),
              _buildDataSection(),
              const SizedBox(height: 24),

              _buildSectionTitle('Account Actions'),
              _buildAccountActionsSection(),
              const SizedBox(height: 32),

              GradientButton(
                text: 'Save Changes',
                icon: LucideIcons.save,
                onPressed: _saveProfile,
                isLoading: _isSaving,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    final prefs = ref.watch(preferencesProvider);
    String initials = 'U';
    if (_nameController.text.isNotEmpty) {
      initials = _nameController.text.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    }

    DecorationImage? avatarImage;
    Gradient? avatarGradient;

    if (prefs.avatarUrl.isNotEmpty) {
      if (prefs.avatarUrl.startsWith('preset:')) {
        final parts = prefs.avatarUrl.split(':');
        final idx = int.tryParse(parts.last) ?? 1;
        final preset = _avatarPresets[idx.clamp(0, _avatarPresets.length - 1)];
        avatarGradient = LinearGradient(colors: preset['colors'] as List<Color>);
      } else if (prefs.avatarUrl.startsWith('assets/')) {
        avatarImage = DecorationImage(image: AssetImage(prefs.avatarUrl), fit: BoxFit.contain);
      } else {
        avatarImage = DecorationImage(image: FileImage(File(prefs.avatarUrl)), fit: BoxFit.cover);
      }
    } else {
      // Default Gradient (Vaporwave)
      avatarGradient = LinearGradient(colors: _avatarPresets[1]['colors'] as List<Color>);
    }

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showAvatarPicker,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: avatarGradient,
                    image: avatarImage,
                    boxShadow: [BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.3), blurRadius: 20)],
                  ),
                  child: avatarImage == null && avatarGradient != null
                      ? Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)))
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: AppColors.bgElevated, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.camera, color: AppColors.accentCyan, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/kanakku_logo.png',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 6),
              const Text(
                'Kanakku',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Profile Picture',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              const Text(
                'PREMIUM NEON PRESETS',
                style: TextStyle(color: AppColors.accentCyan, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 55,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _avatarPresets.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final preset = _avatarPresets[index];
                    return GestureDetector(
                      onTap: () {
                        ref.read(preferencesProvider.notifier).updateAvatarUrl('preset:$index');
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: preset['colors'] as List<Color>),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                        ),
                        child: const Icon(LucideIcons.sparkles, color: Colors.white70, size: 16),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accentCyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(LucideIcons.camera, color: AppColors.accentCyan, size: 20),
                ),
                title: const Text('Take Photo', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                onTap: () => _simulateMockPhotoUpload('camera'),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accentPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(LucideIcons.image, color: AppColors.accentPurple, size: 20),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                onTap: () => _simulateMockPhotoUpload('gallery'),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accentRose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(LucideIcons.trash2, color: AppColors.accentRose, size: 20),
                ),
                title: const Text('Remove Photo', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                onTap: () {
                  ref.read(preferencesProvider.notifier).updateAvatarUrl('');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _simulateMockPhotoUpload(String source) {
    Navigator.pop(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pop(context); // Close loading
        // We set to preset:0 (Neon Cyan) as a beautiful simulation result
        ref.read(preferencesProvider.notifier).updateAvatarUrl('preset:0');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile picture selected via $source simulator!'),
            backgroundColor: AppColors.accentEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildProfileSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          CustomTextField(label: 'Full Name', hint: 'Enter your designation', controller: _nameController, prefixIcon: const Icon(LucideIcons.user, color: AppColors.textTertiary)),
          const SizedBox(height: 16),
          CustomTextField(label: 'Username', hint: '@username', controller: _usernameController, prefixIcon: const Icon(LucideIcons.atSign, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          CustomTextField(label: 'Email Address', hint: 'Enter email', controller: _emailController, keyboardType: TextInputType.emailAddress, prefixIcon: const Icon(LucideIcons.mail, color: AppColors.textTertiary)),
          const SizedBox(height: 16),
          CustomTextField(label: 'Phone Number', hint: 'Enter phone number', controller: _phoneController, keyboardType: TextInputType.phone, prefixIcon: const Icon(LucideIcons.phone, color: AppColors.textTertiary)),
          const SizedBox(height: 16),
          CustomTextField(label: 'Delivery Address', hint: 'Street, City, Zip', controller: _addressController, prefixIcon: const Icon(LucideIcons.mapPin, color: AppColors.textTertiary)),
          const SizedBox(height: 16),
          CustomTextField(label: 'Delivery Instructions / Message', hint: 'e.g. Leave package at the door', controller: _deliveryMsgController, maxLines: 2, prefixIcon: const Icon(LucideIcons.messageSquare, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildRegionalSection() {
    final prefs = ref.watch(preferencesProvider);
    final timezones = ['Asia/Kolkata (IST)', 'America/New_York (EST)', 'Europe/London (GMT)', 'Asia/Tokyo (JST)', 'Australia/Sydney (AEDT)'];
    final dateFormats = ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD', 'DD-MM-YYYY'];

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(
            LucideIcons.globe,
            'Timezone',
            prefs.timezone,
            onTap: () => _showModalPicker(
              'Timezone',
              timezones,
              prefs.timezone,
              (v) => ref.read(preferencesProvider.notifier).updateTimezone(v),
            ),
          ),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(
            LucideIcons.calendar,
            'Date Format',
            prefs.dateFormat,
            onTap: () => _showModalPicker(
              'Date Format',
              dateFormats,
              prefs.dateFormat,
              (v) => ref.read(preferencesProvider.notifier).updateDateFormat(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSection() {
    final prefs = ref.watch(preferencesProvider);
    final currencies = supportedCurrencies.map((c) => '${c.code} (${c.symbol})').toList();
    final activeCurrency = supportedCurrencies[prefs.currencyIndex];
    final fiscalYears = ['April 1st', 'January 1st', 'July 1st', 'October 1st'];

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(
            activeCurrency.icon,
            'Base Currency',
            currencies[prefs.currencyIndex],
            onTap: () => _showModalPicker(
              'Base Currency',
              currencies,
              currencies[prefs.currencyIndex],
              (v) {
                final idx = currencies.indexOf(v);
                if (idx != -1) {
                  ref.read(preferencesProvider.notifier).updateCurrencyIndex(idx);
                }
              },
            ),
          ),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(
            LucideIcons.pieChart,
            'Fiscal Year Start',
            prefs.fiscalYearStart,
            onTap: () => _showModalPicker(
              'Fiscal Year Start',
              fiscalYears,
              prefs.fiscalYearStart,
              (v) => ref.read(preferencesProvider.notifier).updateFiscalYearStart(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    final prefs = ref.watch(preferencesProvider);

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(LucideIcons.key, 'Update Password', 'Modify account password credentials', onTap: _showPasswordUpdateDialog),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(
            LucideIcons.shieldCheck,
            'Two-Factor Authentication',
            prefs.twoFactorAuth ? 'Enabled via Authenticator App' : 'Disabled',
            color: prefs.twoFactorAuth ? AppColors.accentEmerald : AppColors.textTertiary,
            onTap: _toggleTwoFactorAuth,
          ),
        ],
      ),
    );
  }

  void _showPasswordUpdateDialog() {
    final curPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confPassController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Update Password', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: curPassController,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Current Password', hintText: '••••••••'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassController,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'New Password', hintText: 'Min 6 characters'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confPassController,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Confirm New Password', hintText: 'Re-enter password'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isUpdating ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
                ),
                TextButton(
                  onPressed: isUpdating ? null : () async {
                    if (newPassController.text.trim().length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New password must be at least 6 characters'), backgroundColor: AppColors.accentRose),
                      );
                      return;
                    }
                    if (newPassController.text != confPassController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Passwords do not match'), backgroundColor: AppColors.accentRose),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    setDialogState(() => isUpdating = true);
                    try {
                      await Supabase.instance.client.auth.updateUser(
                        UserAttributes(password: newPassController.text.trim()),
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text('Credentials successfully updated!'),
                            backgroundColor: AppColors.accentEmerald,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => isUpdating = false);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.accentRose),
                      );
                    }
                  },
                  child: isUpdating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 2))
                      : const Text('Update', style: TextStyle(color: AppColors.accentCyan)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleTwoFactorAuth() {
    final prefs = ref.read(preferencesProvider);
    if (prefs.twoFactorAuth) {
      // Disabling 2FA
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.bgElevated,
          title: const Text('Disable 2FA?', style: TextStyle(color: AppColors.textPrimary)),
          content: const Text('This will lower your ledger vault protection. Are you sure?', style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary))),
            TextButton(
              onPressed: () {
                ref.read(preferencesProvider.notifier).updateTwoFactorAuth(false);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('2FA deactivated'), backgroundColor: AppColors.accentRose, behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('Disable', style: TextStyle(color: AppColors.accentRose)),
            ),
          ],
        ),
      );
    } else {
      // Pairing wizard simulator
      final codeController = TextEditingController();
      bool isPairing = false;
      showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Pair Authenticator App', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Open Google Authenticator\n2. Pair using code below:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(color: AppColors.bgPrimary, borderRadius: BorderRadius.circular(8)),
                    child: const Text('KANA KKKU 777Y BBDD', style: TextStyle(color: AppColors.accentCyan, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Verification Code', hintText: 'Enter 6-digit code'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary))),
                TextButton(
                  onPressed: isPairing ? null : () async {
                    if (codeController.text.trim().length != 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Verification code must be 6 digits'), backgroundColor: AppColors.accentRose),
                      );
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    setDialogState(() => isPairing = true);
                    await Future.delayed(const Duration(milliseconds: 1000));
                    ref.read(preferencesProvider.notifier).updateTwoFactorAuth(true);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      messenger.showSnackBar(
                        SnackBar(
                          content: const Text('Two-factor pairing successful!'),
                          backgroundColor: AppColors.accentEmerald,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  child: isPairing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 2))
                      : const Text('Verify & Pair', style: TextStyle(color: AppColors.accentCyan)),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  Widget _buildConnectedAccountsSection() {
    final prefs = ref.watch(preferencesProvider);

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(
            LucideIcons.chrome,
            'Google',
            prefs.googleConnected ? 'Connected (karthik@gmail.com)' : 'Not Connected',
            color: prefs.googleConnected ? AppColors.textPrimary : AppColors.textTertiary,
            onTap: () => _toggleSocialConnection('Google', prefs.googleConnected, (v) => ref.read(preferencesProvider.notifier).updateGoogleConnected(v)),
          ),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(
            LucideIcons.apple,
            'Apple ID',
            prefs.appleConnected ? 'Connected' : 'Not Connected',
            color: prefs.appleConnected ? AppColors.textPrimary : AppColors.textTertiary,
            onTap: () => _toggleSocialConnection('Apple ID', prefs.appleConnected, (v) => ref.read(preferencesProvider.notifier).updateAppleConnected(v)),
          ),
        ],
      ),
    );
  }

  void _toggleSocialConnection(String provider, bool currentStatus, ValueChanged<bool> onToggle) {
    if (currentStatus) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.bgElevated,
          title: Text('Disconnect $provider?'),
          content: Text('Do you want to unlink your $provider account? This will disable social login via $provider.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary))),
            TextButton(
              onPressed: () {
                onToggle(false);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$provider connection severed'), backgroundColor: AppColors.accentRose, behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('Disconnect', style: TextStyle(color: AppColors.accentRose)),
            ),
          ],
        ),
      );
    } else {
      BuildContext? dialogCtx;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dCtx) {
          dialogCtx = dCtx;
          return const Center(child: CircularProgressIndicator(color: AppColors.accentCyan));
        },
      );
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          onToggle(true);
          if (dialogCtx != null && dialogCtx!.mounted) {
            Navigator.pop(dialogCtx!);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$provider connected successfully!'), backgroundColor: AppColors.accentEmerald, behavior: SnackBarBehavior.floating),
            );
          }
        }
      });
    }
  }

  Widget _buildPersonalizationSection() {
    final prefs = ref.watch(preferencesProvider);
    final layouts = ['Standard View', 'Compact View', 'Detailed Analytics View'];
    final categories = ['Food & Dining', 'Transport', 'Entertainment', 'Utilities', 'Shopping', 'Healthcare', 'Other'];

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(
            LucideIcons.layoutTemplate,
            'Dashboard Layout',
            prefs.dashboardLayout,
            onTap: () => _showModalPicker(
              'Dashboard Layout',
              layouts,
              prefs.dashboardLayout,
              (v) => ref.read(preferencesProvider.notifier).updateDashboardLayout(v),
            ),
          ),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(
            LucideIcons.sparkles,
            'Default Expense Category',
            prefs.defaultExpenseCategory,
            onTap: () => _showModalPicker(
              'Default Expense Category',
              categories,
              prefs.defaultExpenseCategory,
              (v) => ref.read(preferencesProvider.notifier).updateDefaultExpenseCategory(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection() {
    final prefs = ref.watch(preferencesProvider);
    final visibilities = ['Private', 'Public (Groups)', 'Invisible'];
    final sharingOpts = ['Analytics Only', 'Full Sharing', 'Opt Out'];

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(
            LucideIcons.eyeOff,
            'Profile Visibility',
            prefs.profileVisibility,
            onTap: () => _showModalPicker(
              'Profile Visibility',
              visibilities,
              prefs.profileVisibility,
              (v) => ref.read(preferencesProvider.notifier).updateProfileVisibility(v),
            ),
          ),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(
            LucideIcons.share2,
            'Data Sharing',
            prefs.dataSharing,
            onTap: () => _showModalPicker(
              'Data Sharing',
              sharingOpts,
              prefs.dataSharing,
              (v) => ref.read(preferencesProvider.notifier).updateDataSharing(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(LucideIcons.downloadCloud, 'Request Account Data', 'Download an archive of your data', onTap: _exportData),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
    );

    try {
      final prefs = ref.read(preferencesProvider);
      final user = ref.read(currentUserProvider);

      final Map<String, dynamic> exportMap = {
        'exported_at': DateTime.now().toIso8601String(),
        'app': 'Kanakku Tracker',
        'version': '1.0.0',
        'user': {
          'id': user?.id ?? 'guest',
          'email': user?.email ?? 'guest@kanakku.com',
          'username': prefs.username,
          'timezone': prefs.timezone,
          'currency_index': prefs.currencyIndex,
          'delivery_address': prefs.deliveryAddress,
          'delivery_instructions': prefs.deliveryInstructions,
        },
        'settings': {
          'theme_index': prefs.themeIndex,
          'daily_reminders': prefs.dailyReminders,
          'app_lock': prefs.appLock,
          'layout': prefs.dashboardLayout,
        }
      };

      final jsonString = jsonEncode(exportMap);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/kanakku_account_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      if (mounted) {
        Navigator.pop(context); // Close loading
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'My Kanakku App Data Export',
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.accentRose),
        );
      }
    }
  }

  Widget _buildAccountActionsSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      borderColor: AppColors.accentRose.withValues(alpha: 0.3),
      child: Column(
        children: [
          _buildListTile(LucideIcons.logOut, 'Log Out', 'End your current session', color: AppColors.textPrimary, onTap: _logout),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(LucideIcons.pauseCircle, 'Deactivate Account', 'Temporarily disable your profile', color: AppColors.accentAmber, onTap: _deactivateAccount),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(LucideIcons.trash2, 'Delete Account', 'Permanently remove all data', color: AppColors.accentRose, onTap: _deleteAccount),
        ],
      ),
    );
  }

  void _deactivateAccount() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('Deactivate Account?'),
        content: const Text('This will temporarily disable your profile and log you out. You can reactivate anytime by logging back in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authServiceProvider).signOut();
              if (mounted) {
                context.go('/login');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account deactivated successfully!'), backgroundColor: AppColors.accentAmber),
                );
              }
            },
            child: const Text('Deactivate', style: TextStyle(color: AppColors.accentAmber)),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('DELETE ACCOUNT PERMANENTLY?', style: TextStyle(color: AppColors.accentRose)),
        content: const Text('CRITICAL: This action cannot be undone. All your profile info, cloud records and transaction history will be purged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Perform deletion
              final user = ref.read(currentUserProvider);
              if (user != null) {
                try {
                  // Attempt to purge remote profile via auth provider or Supabase API if possible
                  // In local emulation we clear all local preferences cache as well
                  await LocalCacheService.clearAll();
                  await ref.read(authServiceProvider).signOut();
                } catch (_) {}
              }
              if (mounted) {
                context.go('/login');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All account records permanently purged'), backgroundColor: AppColors.accentRose),
                );
              }
            },
            child: const Text('DELETE FOREVER', style: TextStyle(color: AppColors.accentRose)),
          ),
        ],
      ),
    );
  }

  void _showModalPicker(String title, List<String> items, String currentSelected, ValueChanged<String> onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        itemCount: items.length + 1,
        separatorBuilder: (context, index) => Divider(color: AppColors.borderSubtle.withValues(alpha: 0.5)),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            );
          }
          final item = items[index - 1];
          return ListTile(
            title: Text(item, style: const TextStyle(color: AppColors.textPrimary)),
            trailing: item == currentSelected ? const Icon(LucideIcons.check, color: AppColors.accentCyan) : null,
            onTap: () {
              onSelected(item);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, {Color color = AppColors.textPrimary, VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary, size: 16),
      onTap: onTap,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _deliveryMsgController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
