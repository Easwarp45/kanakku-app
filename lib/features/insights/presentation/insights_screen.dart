import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../core/theme/app_colors.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildStatsBanner()),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildVaultStatus()),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildChronologicalSection()),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Insights History', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text(
            'Retrospective analysis of your financial trajectory.\nAI-driven patterns identified across all holdings.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(
        margin: EdgeInsets.zero,
        borderColor: AppColors.accentCyan.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.brain, color: AppColors.accentCyan, size: 20),
                const SizedBox(width: 10),
                const Text('Projected Q4 Capital Efficiency Drop', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Based on your current burn rate and recurring vendor escalations, we project a 12.4% decrease in liquid capital by December. Immediate restructuring of AWS and Salesforce seat licenses is recommended.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatChip('Total Insights', '47', AppColors.accentCyan),
                const SizedBox(width: 12),
                _buildStatChip('Active Signals', '12', AppColors.accentPurple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildVaultStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(
        margin: EdgeInsets.zero,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.accentEmerald.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: const Icon(LucideIcons.shieldCheck, color: AppColors.accentEmerald, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('The Vault Status', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                  SizedBox(height: 4),
                  Text('Encryption integrity and asset isolation layers are active.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.accentEmerald.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: const Text('ACTIVE', style: TextStyle(color: AppColors.accentEmerald, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChronologicalSection() {
    final insights = [
      {'icon': LucideIcons.cloud, 'title': 'Subscription Spike: Cloud Infrastructure', 'body': 'Unusual +24% billing increase detected in GCP Compute Engine. No corresponding deployment tickets found.', 'color': AppColors.accentRose},
      {'icon': LucideIcons.piggyBank, 'title': 'Savings Opportunity: Treasury Bonds', 'body': 'Current idle cash in Operating Account (2.4M) could yield an additional 4.2% APY in short-term T-bills.', 'color': AppColors.accentEmerald},
      {'icon': LucideIcons.activity, 'title': 'Market Alert: Fintech Index Volatility', 'body': 'High-correlation indicators show potential 5-day bearish trend for sector holdings. Consider hedge positioning.', 'color': AppColors.accentPurple},
      {'icon': LucideIcons.fileText, 'title': 'September CFO Summary Report', 'body': 'Complete aggregation of performance, anomalies, and treasury movements for the previous fiscal month.', 'color': AppColors.accentCyan},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chronological Ledger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          ...insights.map((insight) {
            final color = insight['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                margin: EdgeInsets.zero,
                borderColor: color.withValues(alpha: 0.2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(insight['icon'] as IconData, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(insight['title'] as String, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 6),
                          Text(insight['body'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
