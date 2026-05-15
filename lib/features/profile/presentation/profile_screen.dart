import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Text('EXECUTIVE', style: TextStyle(fontSize: 12, color: AppColors.accentCyan, fontWeight: FontWeight.w700, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              _buildHeroSection(),
              const SizedBox(height: 24),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildBioCard(),
              const SizedBox(height: 24),
              _buildSecurityCard(),
              const SizedBox(height: 24),
              _buildLinkedAccountsCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [AppColors.accentCyan, AppColors.accentPurple]),
            boxShadow: [BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.4), blurRadius: 20)],
          ),
          child: const Center(child: Text('MV', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(height: 16),
        const Text('Marcus Vane', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Chief Financial Controller', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Global Limit', '\$2.5M', AppColors.accentCyan)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Risk Score', 'AAA', AppColors.accentEmerald)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: AppTheme.moneyStyle.copyWith(fontSize: 22, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBioCard() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Financial Bio', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          const Text(
            'Senior treasury strategist specializing in liquidity optimization and high-frequency ledger management. Overseeing multi-currency accounts across EMEA and APAC regions. Marcus maintains a strictly audited digital footprint with a focus on cryptographic integrity.',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security Settings', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          _buildSecItem(LucideIcons.fingerprint, 'Biometric Authentication', 'FaceID & TouchID enabled', AppColors.accentCyan),
          const SizedBox(height: 12),
          _buildSecItem(LucideIcons.shieldCheck, 'Encrypted Ledger Access', 'AES-256 Quantum Shield', AppColors.accentEmerald),
        ],
      ),
    );
  }

  Widget _buildSecItem(IconData icon, String title, String sub, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            Text(sub, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildLinkedAccountsCard() {
    final accounts = [
      {'label': 'Corporate Centurion', 'num': '•••• 9002', 'color': AppColors.accentCyan},
      {'label': 'Private Reserve', 'num': '•••• 4410', 'color': AppColors.accentPurple},
    ];
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Linked Accounts', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          ...accounts.map((a) {
            final color = a['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(LucideIcons.creditCard, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['label'] as String, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(a['num'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
