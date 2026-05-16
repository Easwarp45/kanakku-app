import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      // Set email from auth first
      _emailController.text = user.email ?? '';
      
      // Fallback name from metadata (Google/Social)
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
              
              // Note: The following fields are not in the current profiles schema
              // Keeping them for UI structure but they won't persist
              _usernameController.text = '';
              _addressController.text = '';
              _deliveryMsgController.text = '';
              
              _isLoadingProfile = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoadingProfile = false);
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingProfile = false);
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
      await ref.read(authServiceProvider).updateProfile(user.id, {
        'display_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        // Removed non-schema columns to avoid DB errors
      });

      // Refresh the profile provider so dashboard/settings pick up the new data
      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
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
    String initials = 'U';
    if (_nameController.text.isNotEmpty) {
      initials = _nameController.text.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    }

    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [AppColors.accentCyan, AppColors.accentPurple]),
                  boxShadow: [BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.3), blurRadius: 20)],
                ),
                child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800))),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: AppColors.bgElevated, shape: BoxShape.circle),
                child: const Icon(LucideIcons.camera, color: AppColors.accentCyan, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
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
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(LucideIcons.globe, 'Timezone', 'Asia/Kolkata (IST)'),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(LucideIcons.calendar, 'Date Format', 'DD/MM/YYYY'),
        ],
      ),
    );
  }

  Widget _buildFinancialSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(LucideIcons.indianRupee, 'Base Currency', 'INR (₹)'),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(LucideIcons.pieChart, 'Fiscal Year Start', 'April 1st'),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(LucideIcons.key, 'Update Password', 'Last changed 3 months ago'),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(LucideIcons.shieldCheck, 'Two-Factor Authentication', 'Enabled via Authenticator App', color: AppColors.accentEmerald),
        ],
      ),
    );
  }

  Widget _buildConnectedAccountsSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(LucideIcons.chrome, 'Google', 'Connected (karthik@gmail.com)'),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(LucideIcons.apple, 'Apple ID', 'Not Connected', color: AppColors.textTertiary),
        ],
      ),
    );
  }

  Widget _buildPersonalizationSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(LucideIcons.layoutTemplate, 'Dashboard Layout', 'Standard View'),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(LucideIcons.sparkles, 'Default Expense Category', 'Food & Dining'),
        ],
      ),
    );
  }

  Widget _buildPrivacySection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(LucideIcons.eyeOff, 'Profile Visibility', 'Private'),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(LucideIcons.share2, 'Data Sharing', 'Analytics Only'),
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
          _buildListTile(LucideIcons.downloadCloud, 'Request Account Data', 'Download an archive of your data'),
        ],
      ),
    );
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
          _buildListTile(LucideIcons.pauseCircle, 'Deactivate Account', 'Temporarily disable your profile', color: AppColors.accentAmber),
          Divider(color: AppColors.borderSubtle, height: 1),
          _buildListTile(LucideIcons.trash2, 'Delete Account', 'Permanently remove all data', color: AppColors.accentRose),
        ],
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
      onTap: onTap ?? () {},
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
