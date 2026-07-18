import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/multi_currency_helper.dart';
import '../../../core/providers/financial_summary_provider.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/database/local_cache_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

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

      if (mounted) {
        setState(() {
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

    try {
      // Update remote DB profiles table
      await ref.read(authServiceProvider).updateProfile(user.id, {
        'display_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
      });

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
          SnackBar(
            content: Text(ErrorMapper.userMessage(e, fallback: 'Unable to update profile.')),
            backgroundColor: AppColors.accentRose,
          ),
        );
      }
    }
  }

  void _logout() async {
    final pendingCount = LocalCacheService.getPendingActions().length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          pendingCount > 0
              ? 'You have $pendingCount unsynced changes. Signing out will discard them permanently. Are you sure you want to sign out?'
              : 'Are you sure you want to sign out?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRose),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await ref.read(authServiceProvider).signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.accentCyan)));
    }

    final user = ref.watch(currentUserProvider);
    final initials = _nameController.text.isNotEmpty 
        ? _nameController.text.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(user, initials),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _buildFinancialSummary(),
                  const SizedBox(height: 24),
                  
                  _buildCompactSection(
                    'ACCOUNT',
                    [
                      _buildActionRow(
                        LucideIcons.user, 
                        'Display Name', 
                        _nameController.text.isEmpty ? 'Set Name' : _nameController.text, 
                        onTap: () => _editField('Display Name', _nameController),
                      ),
                      _buildActionRow(
                        LucideIcons.phone, 
                        'Phone', 
                        _phoneController.text.isEmpty ? 'Add Phone' : _phoneController.text, 
                        onTap: () => _editField('Phone Number', _phoneController),
                      ),
                      _buildActionRow(
                        LucideIcons.mail, 
                        'Email', 
                        _emailController.text, 
                        isLocked: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  _buildLogoutButton(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(User? user, String initials) {
    return SliverAppBar(
      expandedHeight: 220,
      backgroundColor: AppColors.bgPrimary,
      elevation: 0,
      pinned: true,
      stretch: true,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      actions: const [],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        expandedTitleScale: 1.2,
        title: const Text(
          'ME',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: AppColors.textPrimary,
          ),
        ),
        background: Stack(
          alignment: Alignment.center,
          children: [
            // Subtle Radial Glow
            Positioned(
              top: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accentCyan.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: _showAvatarPicker,
                  child: Hero(
                    tag: 'profile_avatar',
                    child: _buildCompactAvatar(initials),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _nameController.text.isEmpty ? 'Setup Profile' : _nameController.text,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactAvatar(String initials) {
    final prefs = ref.watch(preferencesProvider);
    Gradient? avatarGradient = LinearGradient(colors: _avatarPresets[1]['colors'] as List<Color>);
    DecorationImage? avatarImage;

    if (prefs.avatarUrl.isNotEmpty) {
      if (prefs.avatarUrl.startsWith('preset:')) {
        final idx = int.tryParse(prefs.avatarUrl.split(':').last) ?? 1;
        avatarGradient = LinearGradient(colors: _avatarPresets[idx]['colors'] as List<Color>);
      } else if (prefs.avatarUrl.startsWith('assets/')) {
        avatarImage = DecorationImage(image: AssetImage(prefs.avatarUrl));
      } else {
        avatarImage = DecorationImage(image: FileImage(File(prefs.avatarUrl)), fit: BoxFit.cover);
      }
    }

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: avatarGradient,
        image: avatarImage,
        border: Border.all(color: AppColors.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: -5,
          )
        ],
      ),
      child: avatarImage == null
          ? Center(
              child: Text(
                initials,
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
              ),
            )
          : null,
    );
  }

  Widget _buildFinancialSummary() {
    final summary = ref.watch(financialSummaryProvider);
    final prefs = ref.watch(preferencesProvider);
    final currencyCode = supportedCurrencies[prefs.currencyIndex].code;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildSummaryItem(
            LucideIcons.wallet, 
            'Wallet', 
            CurrencyFormatter.format(summary.walletBalance, currencyCode),
          ),
          Container(width: 1, height: 30, color: AppColors.borderSubtle),
          _buildSummaryItem(
            LucideIcons.trendingUp, 
            'Budget', 
            CurrencyFormatter.format(summary.monthlyBudget, currencyCode),
          ),
          Container(width: 1, height: 30, color: AppColors.borderSubtle),
          _buildSummaryItem(
            LucideIcons.award, 
            'Score', 
            summary.healthScore.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.accentCyan),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCompactSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textTertiary,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSecondary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: List.generate(items.length, (index) {
              return Column(
                children: [
                  items[index],
                  if (index != items.length - 1)
                    Divider(color: AppColors.borderSubtle, height: 1, indent: 52),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildActionRow(IconData icon, String title, String value, {VoidCallback? onTap, bool isLocked = false}) {
    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bgTertiary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 12, color: isLocked ? AppColors.textTertiary : AppColors.accentCyan, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (!isLocked)
              const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: _logout,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.accentRose.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentRose.withValues(alpha: 0.2)),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.logOut, size: 18, color: AppColors.accentRose),
              SizedBox(width: 12),
              Text(
                'Sign Out',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accentRose),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editField(String field, TextEditingController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update $field', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 24),
            CustomTextField(
              label: field,
              controller: controller,
              autoFocus: true,
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Confirm',
              onPressed: () {
                _saveProfile();
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
