import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';

class InstallGuideScreen extends StatelessWidget {
  const InstallGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Text('Install Guide', style: TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(),
              const SizedBox(height: 24),
              _buildStepsSection(),
              const SizedBox(height: 24),
              _buildPlatformSection(),
              const SizedBox(height: 32),
              GradientButton(text: 'Begin Setup', icon: LucideIcons.download, onPressed: () => context.go('/dashboard')),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.accentCyan, AppColors.accentPurple], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.hexagon, color: Colors.white, size: 40),
          SizedBox(height: 16),
          Text('KANAKKU', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 3)),
          Text('AETHERIC LEDGER', style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 2)),
          SizedBox(height: 12),
          Text('Your premium financial intelligence suite. Follow the steps below to complete your onboarding.', style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildStepsSection() {
    final steps = [
      {'icon': LucideIcons.user, 'step': '01', 'title': 'Create Your Executive Profile', 'desc': 'Register your identity matrix and configure your financial persona.', 'color': AppColors.accentCyan},
      {'icon': LucideIcons.creditCard, 'step': '02', 'title': 'Link Financial Institutions', 'desc': 'Connect your banks and UPI IDs for unified liquidity management.', 'color': AppColors.accentPurple},
      {'icon': LucideIcons.target, 'step': '03', 'title': 'Set Budget & Savings Goals', 'desc': 'Define your financial targets and allocation strategy.', 'color': AppColors.accentEmerald},
      {'icon': LucideIcons.users, 'step': '04', 'title': 'Create Financial Collectives', 'desc': 'Invite members and start tracking shared expenses in groups.', 'color': AppColors.accentRose},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Setup Steps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        ...steps.map((s) {
          final color = s['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s['step'] as String, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                        Icon(s['icon'] as IconData, color: color, size: 16),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['title'] as String, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(s['desc'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPlatformSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available Platforms', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildPlatformChip(LucideIcons.smartphone, 'Android', AppColors.accentEmerald),
              const SizedBox(width: 12),
              _buildPlatformChip(LucideIcons.apple, 'iOS', AppColors.accentCyan),
              const SizedBox(width: 12),
              _buildPlatformChip(LucideIcons.globe, 'Web', AppColors.accentPurple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
