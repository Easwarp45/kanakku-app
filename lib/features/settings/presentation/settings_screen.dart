import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _themeIndex = 0;
  int _currencyIndex = 0;
  bool _dailyReminders = true;
  bool _appLock = true;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 4)),
            SliverToBoxAdapter(child: _buildProfileBanner(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSection('Preferences', _buildPreferencesItems())),
            SliverToBoxAdapter(child: _buildSection('Categories & Budgets', _buildCategoryItems(context))),
            SliverToBoxAdapter(child: _buildSection('Groups', _buildGroupsItems(context))),
            SliverToBoxAdapter(child: _buildSection('Data & Security', _buildDataSecurityItems())),
            SliverToBoxAdapter(child: _buildSection('Support & About', _buildSupportItems())),
            SliverToBoxAdapter(child: const SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: Text('Kanakku Tracker v1.0.0', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                ),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 5),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PREFERENCES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentCyan, letterSpacing: 2)),
                SizedBox(height: 2),
                Text('Settings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileBanner(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    String name = 'User';
    String initials = 'U';

    profileAsync.whenData((profile) {
      if (profile != null && profile['display_name'] != null && profile['display_name'].toString().isNotEmpty) {
        name = profile['display_name'];
        initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
      }
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () => context.push('/profile'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.accentCyan, AppColors.accentPurple], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26, 
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18))
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                    const Text('Manage Personal Info', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          GlassCard(margin: EdgeInsets.zero, padding: EdgeInsets.zero, child: Column(children: items)),
        ],
      ),
    );
  }

  List<Widget> _buildPreferencesItems() {
    final themes = ['System Default', 'Dark Mode', 'Light Mode'];
    final currencies = ['INR (₹)', 'USD (\$)', 'EUR (€)', 'GBP (£)'];
    
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(LucideIcons.indianRupee, color: AppColors.accentEmerald, size: 22),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Base Currency', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
            ])),
            TextButton(
              onPressed: () => _showPickerSheet(context, 'Currency', currencies, _currencyIndex, (i) => setState(() => _currencyIndex = i)),
              child: Text(currencies[_currencyIndex], style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            ),
          ],
        ),
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(LucideIcons.palette, color: AppColors.accentCyan, size: 22),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('App Theme', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
            ])),
            TextButton(
              onPressed: () => _showPickerSheet(context, 'Theme', themes, _themeIndex, (i) => setState(() => _themeIndex = i)),
              child: Text(themes[_themeIndex], style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            ),
          ],
        ),
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.bellRing, 'Daily Reminder', 'Remind to log expenses', AppColors.accentPurple, trailing: Switch(value: _dailyReminders, onChanged: (v) => setState(() => _dailyReminders = v), activeThumbColor: AppColors.accentCyan)),
    ];
  }

  List<Widget> _buildCategoryItems(BuildContext context) {
    return [
      _buildSettingsTile(LucideIcons.tags, 'Manage Categories', 'Add/edit expense tags', AppColors.accentEmerald, onTap: () {}),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.target, 'Budget Limits', 'Set monthly caps', AppColors.accentCyan, onTap: () => context.push('/budget')),
    ];
  }

  List<Widget> _buildGroupsItems(BuildContext context) {
    return [
      _buildSettingsTile(LucideIcons.users, 'Manage Groups', 'View active groups', AppColors.accentPurple, onTap: () => context.push('/groups')),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.gitMerge, 'Default Split Rule', 'Currently: Equal Split', AppColors.accentCyan, onTap: () {}),
    ];
  }

  List<Widget> _buildDataSecurityItems() {
    return [
      _buildSettingsTile(LucideIcons.fingerprint, 'App Lock', 'Biometric security', AppColors.accentCyan, trailing: Switch(value: _appLock, onChanged: (v) => setState(() => _appLock = v), activeThumbColor: AppColors.accentCyan)),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.cloudLightning, 'Cloud Backup', 'Sync data to cloud', AppColors.accentEmerald, onTap: () {}),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.download, 'Export Data', 'Download CSV report', AppColors.accentPurple, onTap: () {}),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.trash2, 'Clear Cache', 'Free up space', AppColors.textSecondary, onTap: () {}),
    ];
  }

  List<Widget> _buildSupportItems() {
    return [
      _buildSettingsTile(LucideIcons.helpCircle, 'Help & Support', 'FAQs and Contact', AppColors.accentEmerald, onTap: () {}),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.logOut, 'Sign Out', 'Disconnect this device', AppColors.accentRose, onTap: () => context.go('/login')),
    ];
  }

  void _showPickerSheet(BuildContext context, String title, List<String> items, int selectedIndex, ValueChanged<int> onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => Divider(color: AppColors.borderSubtle.withValues(alpha: 0.5)),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            );
          }
          final actualIndex = index - 1;
          return ListTile(
            title: Text(items[actualIndex], style: const TextStyle(color: AppColors.textPrimary)),
            trailing: actualIndex == selectedIndex ? const Icon(LucideIcons.check, color: AppColors.accentCyan) : null,
            onTap: () {
              onSelected(actualIndex);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, Color color, {Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: trailing ?? (onTap != null ? const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary, size: 18) : null),
    );
  }
}
