import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';

class UpiScreen extends StatelessWidget {
  const UpiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Column(
          children: [
            Text('FINANCIAL INTELLIGENCE', style: TextStyle(fontSize: 10, color: AppColors.accentCyan, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            Text('Payment Infrastructure', style: TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSecurityBadge(),
              const SizedBox(height: 24),
              _buildLinkedAccounts(),
              const SizedBox(height: 24),
              _buildFeatures(),
              const SizedBox(height: 24),
              _buildQrSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Text(
      'Link your financial institutions for instantaneous settlement and unified liquidity management.',
      style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6),
    );
  }

  Widget _buildSecurityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentEmerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.shieldCheck, color: AppColors.accentEmerald, size: 16),
          const SizedBox(width: 8),
          const Text('FEDERAL RESERVE SECURE', style: TextStyle(color: AppColors.accentEmerald, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildLinkedAccounts() {
    final accounts = [
      {'id': 'ex-ceo@intel', 'bank': 'GLOBAL ASSET BANK', 'color': AppColors.accentCyan},
      {'id': 'vault.alpha@intel', 'bank': 'QUANTUM VAULT TRUST', 'color': AppColors.accentPurple},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Linked UPI Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        ...accounts.map((a) {
          final color = a['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              margin: EdgeInsets.zero,
              borderColor: color.withValues(alpha: 0.25),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(LucideIcons.smartphone, color: AppColors.accentCyan, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['id'] as String, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(a['bank'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 0.5)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.accentEmerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: const Text('ACTIVE', style: TextStyle(color: AppColors.accentEmerald, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        }),
        GradientButton(
          text: 'Link New Account',
          icon: LucideIcons.plusCircle,
          isSecondary: true,
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildFeatures() {
    final features = [
      {'icon': LucideIcons.zap, 'title': 'Real-time Settlement', 'desc': 'Leverage our direct gateway to the central node for sub-second transaction validation and liquidity routing.', 'color': AppColors.accentCyan},
      {'icon': LucideIcons.lock, 'title': 'Encrypted Vaulting', 'desc': 'Hardware-level security modules ensure your payment credentials never touch the public internet layer.', 'color': AppColors.accentPurple},
    ];
    return Column(
      children: features.map((f) {
        final color = f['color'] as Color;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            margin: EdgeInsets.zero,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(f['icon'] as IconData, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f['title'] as String, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(f['desc'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQrSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          const Text('Quick-Receive', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Share this code for instant deposits into your primary vault.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(LucideIcons.qrCode, size: 80, color: AppColors.bgPrimary),
            ),
          ),
          const SizedBox(height: 16),
          const Text('ex-ceo@intel', style: TextStyle(color: AppColors.accentCyan, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
