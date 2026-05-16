import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class MonthlyWrapScreen extends StatelessWidget {
  const MonthlyWrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Text('Monthly Wrap', style: TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroMessage(),
              const SizedBox(height: 24),
              _buildGoalAchievement(),
              const SizedBox(height: 24),
              _buildSecuredAssets(),
              const SizedBox(height: 24),
              _buildNextMonthStrategy(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF0e3a4a), AppColors.accentCyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.trendingUp, color: AppColors.accentCyan, size: 28),
          const SizedBox(height: 16),
          const Text('A stellar performance, Executive.', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
          const SizedBox(height: 8),
          const Text('Your net worth surged by', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text('+12.4%', style: AppTheme.moneyStyle.copyWith(fontSize: 36, color: AppColors.accentEmerald)),
          const SizedBox(height: 4),
          const Text('this month', style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 16),
          const Text(
            'You effectively managed liquidity while accelerating long-term positions. Here is how your capital moved through the ecosystem.',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalAchievement() {
    return GlassCard(
      margin: EdgeInsets.zero,
      borderColor: AppColors.accentEmerald.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.accentEmerald.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.trophy, color: AppColors.accentEmerald, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Global Acquisitions', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('You reached your "Q4 Resilience" goal 14 days early.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.accentEmerald.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.checkCircle, color: AppColors.accentEmerald, size: 20),
                const SizedBox(width: 8),
                const Text('Q4 Resilience Goal — ACHIEVED', style: TextStyle(color: AppColors.accentEmerald, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuredAssets() {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.accentCyan.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.database, color: AppColors.accentCyan, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Secured Assets', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Your emergency and strategic liquidity reserves are currently yielding 4.2% APY across primary glass accounts.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          Text('4.2% APY', style: AppTheme.moneyStyle.copyWith(fontSize: 24, color: AppColors.accentCyan)),
        ],
      ),
    );
  }

  Widget _buildNextMonthStrategy() {
    return GlassCard(
      margin: EdgeInsets.zero,
      borderColor: AppColors.accentPurple.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.accentPurple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.lightbulb, color: AppColors.accentPurple, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Next Month Strategy', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Based on current burn rates and dividend forecasts, we recommend reallocating ₹15,000 into the \'Vault\' to optimize tax efficiency before the year-end close.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(LucideIcons.arrowRight, color: AppColors.accentPurple, size: 16),
              const SizedBox(width: 8),
              Text('₹15,000 to Vault', style: AppTheme.moneyStyle.copyWith(fontSize: 18, color: AppColors.accentPurple)),
            ],
          ),
        ],
      ),
    );
  }
}
