import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../core/theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _haptics = true;
  bool _highPriorityNotifs = true;
  int _themeIndex = 0;
  int _languageIndex = 0; // 0: English, 1: Spanish
  int _loggingIndex = 1; // 0: Debug, 1: Info, 2: Warning
  bool _betaFeatures = false;
  bool _highContrast = false;
  final double _textScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildProfileBanner(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSection('Security & Privacy', _buildSecurityItems())),
            SliverToBoxAdapter(child: _buildSection('Financial Configuration', _buildFinancialItems(context))),
            SliverToBoxAdapter(child: _buildSection('App Customization & Features', _buildAppCustomItems())),
            SliverToBoxAdapter(child: _buildSection('Localization & Accessibility', _buildLocalizationItems())),
            SliverToBoxAdapter(child: _buildSection('Developer Options', _buildDeveloperItems())),
            SliverToBoxAdapter(child: _buildSection('Account Management', _buildAccountItems(context))),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
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
                Text('EXECUTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentCyan, letterSpacing: 2)),
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
              CircleAvatar(radius: 26, backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: const Text('MV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18))),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Marcus Vane', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                    Text('Chief Controller • Premium Account', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    SizedBox(height: 4),
                    Text('Aetheric Ledger v4.8.2-Enterprise', style: TextStyle(color: Colors.white54, fontSize: 11)),
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
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          GlassCard(margin: EdgeInsets.zero, padding: EdgeInsets.zero, child: Column(children: items)),
        ],
      ),
    );
  }

  List<Widget> _buildSecurityItems() {
    return [
      _buildSettingsTile(LucideIcons.fingerprint, 'Biometric Authentication', 'FaceID & TouchID', AppColors.accentCyan, trailing: Switch(value: true, onChanged: (_) {}, activeThumbColor: AppColors.accentCyan)),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.shieldCheck, 'Encrypted Ledger Access', 'AES-256 Quantum Shield', AppColors.accentEmerald),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.lock, 'Two-Factor Auth', 'TOTP enabled', AppColors.accentPurple),
    ];
  }

  List<Widget> _buildFinancialItems(BuildContext context) {
    return [
      _buildSettingsTile(LucideIcons.creditCard, 'Linked Accounts', 'Corporate Centurion •••• 9002', AppColors.accentCyan, onTap: () => context.push('/upi')),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.qrCode, 'UPI Integration', 'Quick-Receive enabled', AppColors.accentPurple, onTap: () => context.push('/upi')),
    ];
  }

  List<Widget> _buildAppCustomItems() {
    final themes = ['Midnight Glass', 'Aurora Dark', 'Solar Flare'];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(LucideIcons.palette, color: AppColors.accentCyan, size: 22),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Theme', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
            ])),
            DropdownButton<int>(
              value: _themeIndex,
              dropdownColor: AppColors.bgElevated,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              underline: const SizedBox(),
              items: List.generate(themes.length, (i) => DropdownMenuItem(value: i, child: Text(themes[i]))),
              onChanged: (v) => setState(() => _themeIndex = v!),
            ),
          ],
        ),
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.vibrate, 'Haptics', 'High Precision', AppColors.accentPurple, trailing: Switch(value: _haptics, onChanged: (v) => setState(() => _haptics = v), activeThumbColor: AppColors.accentCyan)),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.bell, 'Notifications', 'High Priority Only', AppColors.accentRose, trailing: Switch(value: _highPriorityNotifs, onChanged: (v) => setState(() => _highPriorityNotifs = v), activeThumbColor: AppColors.accentCyan)),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.zap, 'Beta Features', 'Experimental tools', AppColors.accentPurple, trailing: Switch(value: _betaFeatures, onChanged: (v) => setState(() => _betaFeatures = v), activeThumbColor: AppColors.accentCyan)),
    ];
  }

  List<Widget> _buildLocalizationItems() {
    final languages = ['English', 'Español'];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(LucideIcons.globe, color: AppColors.accentEmerald, size: 22),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Language', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
            ])),
            DropdownButton<int>(
              value: _languageIndex,
              dropdownColor: AppColors.bgElevated,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              underline: const SizedBox(),
              items: List.generate(languages.length, (i) => DropdownMenuItem(value: i, child: Text(languages[i]))),
              onChanged: (v) => setState(() => _languageIndex = v!),
            ),
          ],
        ),
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.textCursorInput, 'Text Scale', '${(_textScale * 100).toStringAsFixed(0)}%', AppColors.accentCyan),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.eye, 'High Contrast', 'Enhanced visibility', AppColors.accentRose, trailing: Switch(value: _highContrast, onChanged: (v) => setState(() => _highContrast = v), activeThumbColor: AppColors.accentCyan)),
    ];
  }

  List<Widget> _buildDeveloperItems() {
    final loggingLevels = ['Debug', 'Info', 'Warning'];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(LucideIcons.terminalSquare, color: AppColors.accentPurple, size: 22),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Logging Level', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
            ])),
            DropdownButton<int>(
              value: _loggingIndex,
              dropdownColor: AppColors.bgElevated,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              underline: const SizedBox(),
              items: List.generate(loggingLevels.length, (i) => DropdownMenuItem(value: i, child: Text(loggingLevels[i]))),
              onChanged: (v) => setState(() => _loggingIndex = v!),
            ),
          ],
        ),
      ),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.activity, 'Performance Monitor', 'View app metrics', AppColors.accentCyan, onTap: () {}),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.database, 'App Storage', 'Cache & database size', AppColors.accentEmerald, onTap: () {}),
    ];
  }

  List<Widget> _buildAccountItems(BuildContext context) {
    return [
      _buildSettingsTile(LucideIcons.user, 'Executive Profile', 'Marcus Vane', AppColors.accentCyan, onTap: () => context.push('/profile')),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.helpCircle, 'Install Guide', 'Setup & onboarding', AppColors.accentEmerald, onTap: () => context.push('/install-guide')),
      Divider(color: AppColors.borderSubtle, height: 1),
      _buildSettingsTile(LucideIcons.logOut, 'Sign Out', 'Exit secure session', AppColors.accentRose, onTap: () => context.go('/login')),
    ];
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
