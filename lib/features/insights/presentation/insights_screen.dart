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
            SliverToBoxAdapter(child: const SizedBox(height: 12)),
            SliverToBoxAdapter(child: _buildOptionsList(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 32)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INTELLIGENCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentCyan, letterSpacing: 2)),
          const SizedBox(height: 2),
          const Text('Financial Brain', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text(
            'Tap on any intelligence module below to run analysis and view detailed interactive reports.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategory(context, 'Core Analytics', [
            _FeatureItem('Financial Health Score', 'Calculate your overall financial wellness', LucideIcons.heartPulse, AppColors.accentEmerald, _buildHealthScoreModal),
            _FeatureItem('Spending Pattern Analysis', 'Deep dive into category spending', LucideIcons.pieChart, AppColors.accentCyan, _buildPatternModal),
            _FeatureItem('Spending Heatmap', 'Visualize spending intensity by day', LucideIcons.map, AppColors.accentRose, _buildHeatmapModal),
            _FeatureItem('Lifestyle Analysis', 'Understand your spending persona', LucideIcons.coffee, AppColors.accentAmber, _buildLifestyleModal),
          ]),
          const SizedBox(height: 24),
          _buildCategory(context, 'Predictive & AI', [
            _FeatureItem('AI Insights', 'Personalized financial observations', LucideIcons.brain, AppColors.accentPurple, _buildAIInsightsModal),
            _FeatureItem('Prediction Engine', 'Forecast next month\'s cashflow', LucideIcons.trendingUp, AppColors.accentCyan, _buildPredictionModal),
            _FeatureItem('Smart Recommendations', 'Actionable steps to improve wealth', LucideIcons.lightbulb, AppColors.accentAmber, _buildRecommendationsModal),
            _FeatureItem('Risk Alerts', 'Warnings for unusual financial activity', LucideIcons.alertTriangle, AppColors.accentRose, _buildRiskAlertsModal),
          ]),
          const SizedBox(height: 24),
          _buildCategory(context, 'Wealth & Tracking', [
            _FeatureItem('Subscription Detection', 'Find and manage recurring charges', LucideIcons.refreshCcw, AppColors.accentCyan, _buildSubscriptionModal),
            _FeatureItem('Budget Intelligence', 'Smart tracking of budget limits', LucideIcons.target, AppColors.accentEmerald, _buildBudgetModal),
            _FeatureItem('Savings Intelligence', 'Optimize your idle cash', LucideIcons.piggyBank, AppColors.accentPurple, _buildSavingsModal),
            _FeatureItem('Goal Trajectory', 'Track progress of major purchases', LucideIcons.flag, AppColors.accentAmber, _buildGoalsModal),
          ]),
          const SizedBox(height: 24),
          _buildCategory(context, 'Journey & Gamification', [
            _FeatureItem('Monthly Financial Story', 'Your financial month wrapped', LucideIcons.bookOpen, AppColors.accentCyan, _buildStoryModal),
            _FeatureItem('Achievements & Streaks', 'View your financial milestones', LucideIcons.award, AppColors.accentEmerald, _buildAchievementsModal),
          ]),
        ],
      ),
    );
  }

  Widget _buildCategory(BuildContext context, String title, List<_FeatureItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        GlassCard(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(color: AppColors.borderSubtle, height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: item.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                title: Text(item.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(item.subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary, size: 18),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => _buildModalWrapper(context, item.title, item.builder(context)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModalWrapper(BuildContext context, String title, Widget child) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderSubtle, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(LucideIcons.x, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Divider(color: AppColors.borderSubtle),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  // --- Modal Builders ---

  Widget _buildHealthScoreModal(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          width: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(value: 0.85, strokeWidth: 12, color: AppColors.accentEmerald, backgroundColor: AppColors.accentEmerald.withValues(alpha: 0.1)),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('85', style: TextStyle(color: AppColors.accentEmerald, fontSize: 48, fontWeight: FontWeight.w800)),
                  Text('EXCELLENT', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildDetailRow('Debt-to-Income Ratio', 'Healthy (12%)', LucideIcons.checkCircle, AppColors.accentEmerald),
        const SizedBox(height: 16),
        _buildDetailRow('Emergency Fund', 'Fully Funded', LucideIcons.checkCircle, AppColors.accentEmerald),
        const SizedBox(height: 16),
        _buildDetailRow('Credit Utilization', 'Action Needed (45%)', LucideIcons.alertTriangle, AppColors.accentAmber),
      ],
    );
  }

  Widget _buildPatternModal(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your spending is heavily skewed towards weekends.', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        _buildDetailRow('Food & Dining', '₹12,400 (45%)', LucideIcons.pizza, AppColors.accentRose),
        const SizedBox(height: 16),
        _buildDetailRow('Transportation', '₹4,200 (15%)', LucideIcons.car, AppColors.accentCyan),
        const SizedBox(height: 16),
        _buildDetailRow('Entertainment', '₹3,800 (12%)', LucideIcons.film, AppColors.accentPurple),
      ],
    );
  }

  Widget _buildHeatmapModal(BuildContext context) {
    return Column(
      children: [
        const Text('Intensity of spending over the last 30 days', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(30, (index) {
            final intensity = (index % 5 == 0) ? 0.8 : (index % 3 == 0) ? 0.4 : 0.1;
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentRose.withValues(alpha: intensity),
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildLifestyleModal(BuildContext context) {
    return Column(
      children: [
        const Icon(LucideIcons.coffee, color: AppColors.accentAmber, size: 64),
        const SizedBox(height: 16),
        const Text('The Urban Foodie', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        const Text('You spend 30% more on dining out than the average user in your bracket. Consider cooking 2 more meals at home per week to save ₹4,000 monthly.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
      ],
    );
  }

  Widget _buildAIInsightsModal(BuildContext context) {
    return Column(
      children: [
        _buildInsightCard('Duplicate Charges', 'It looks like you paid for Spotify twice this month. Check your linked cards.', LucideIcons.copy, AppColors.accentRose),
        const SizedBox(height: 16),
        _buildInsightCard('Optimized Cashflow', 'You usually run low on cash around the 24th. Consider delaying your Amazon purchases.', LucideIcons.trendingDown, AppColors.accentCyan),
      ],
    );
  }

  Widget _buildPredictionModal(BuildContext context) {
    return Column(
      children: [
        const Text('Based on historical data, here is your projected cash flow for next month.', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        _buildDetailRow('Expected Income', '₹85,000', LucideIcons.arrowDownLeft, AppColors.accentEmerald),
        const SizedBox(height: 16),
        _buildDetailRow('Predicted Expenses', '₹62,400', LucideIcons.arrowUpRight, AppColors.accentRose),
        const SizedBox(height: 16),
        _buildDetailRow('Estimated Savings', '₹22,600', LucideIcons.piggyBank, AppColors.accentCyan),
      ],
    );
  }

  Widget _buildRecommendationsModal(BuildContext context) {
    return Column(
      children: [
        _buildInsightCard('Invest Idle Cash', 'You have ₹45,000 sitting in your checking account. Moving this to a Liquid Mutual Fund can yield ₹2,500/year.', LucideIcons.trendingUp, AppColors.accentEmerald),
        const SizedBox(height: 16),
        _buildInsightCard('Pay off Credit Card', 'Clear your outstanding ₹12,000 balance to avoid ₹450 in interest charges this week.', LucideIcons.creditCard, AppColors.accentRose),
      ],
    );
  }

  Widget _buildRiskAlertsModal(BuildContext context) {
    return Column(
      children: [
        _buildInsightCard('High Burn Rate', 'You have spent 80% of your monthly budget in the first 12 days.', LucideIcons.flame, AppColors.accentRose),
        const SizedBox(height: 16),
        _buildInsightCard('Unusual Location', 'A charge of ₹4,500 was detected in Mumbai. If this wasn\'t you, freeze your card.', LucideIcons.mapPin, AppColors.accentAmber),
      ],
    );
  }

  Widget _buildSubscriptionModal(BuildContext context) {
    return Column(
      children: [
        const Text('We found 4 active recurring charges.', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        _buildSubscriptionItem('Netflix Premium', '₹649/mo', AppColors.accentRose),
        _buildSubscriptionItem('Spotify Premium', '₹119/mo', AppColors.accentEmerald),
        _buildSubscriptionItem('Amazon Prime', '₹1,499/yr', AppColors.accentCyan),
        _buildSubscriptionItem('Gym Membership', '₹2,500/mo', AppColors.textPrimary),
      ],
    );
  }

  Widget _buildBudgetModal(BuildContext context) {
    return Column(
      children: [
        _buildBudgetBar('Housing', 0.95, AppColors.accentRose),
        const SizedBox(height: 24),
        _buildBudgetBar('Food', 0.60, AppColors.accentAmber),
        const SizedBox(height: 24),
        _buildBudgetBar('Transport', 0.30, AppColors.accentEmerald),
      ],
    );
  }

  Widget _buildSavingsModal(BuildContext context) {
    return Column(
      children: [
        const Text('Total Savings Rate: 22%', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        const Text('You are in the top 15% of savers in your income bracket!', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 32),
        _buildDetailRow('Emergency Fund', '₹1.5L', LucideIcons.shieldCheck, AppColors.accentCyan),
        const SizedBox(height: 16),
        _buildDetailRow('Investments', '₹4.2L', LucideIcons.trendingUp, AppColors.accentPurple),
      ],
    );
  }

  Widget _buildGoalsModal(BuildContext context) {
    return Column(
      children: [
        _buildGoalItem('Buy a Car', '₹2L / ₹5L', 0.4, AppColors.accentCyan),
        const SizedBox(height: 24),
        _buildGoalItem('Europe Trip', '₹80K / ₹1.5L', 0.53, AppColors.accentPurple),
      ],
    );
  }

  Widget _buildStoryModal(BuildContext context) {
    return Column(
      children: [
        const Icon(LucideIcons.sparkles, color: AppColors.accentPurple, size: 48),
        const SizedBox(height: 24),
        const Text('October Recap', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        const Text(
          'You started October strong, saving 15% right off the bat. Mid-month, your dining expenses spiked by ₹4,000 due to Diwali celebrations. However, you successfully stayed under your transport budget. Overall, you grew your net worth by 2.4% this month!',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildAchievementsModal(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBadge('7 Day Streak', LucideIcons.flame, AppColors.accentRose),
            _buildBadge('Super Saver', LucideIcons.piggyBank, AppColors.accentEmerald),
            _buildBadge('Budget Boss', LucideIcons.target, AppColors.accentCyan),
          ],
        ),
      ],
    );
  }

  // --- Helpers for Modals ---

  Widget _buildDetailRow(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 16),
        Expanded(child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16))),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildInsightCard(String title, String body, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSubscriptionItem(String title, String cost, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: Icon(LucideIcons.playCircle, color: color)),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16))),
          Text(cost, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(width: 16),
          TextButton(onPressed: () {}, child: const Text('Cancel', style: TextStyle(color: AppColors.accentRose))),
        ],
      ),
    );
  }

  Widget _buildBudgetBar(String title, double fill, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            Text('${(fill * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: fill, backgroundColor: AppColors.bgPrimary, color: color, minHeight: 8, borderRadius: BorderRadius.circular(4)),
      ],
    );
  }

  Widget _buildGoalItem(String title, String progress, double fill, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
            Text(progress, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: fill, backgroundColor: AppColors.bgPrimary, color: color, minHeight: 12, borderRadius: BorderRadius.circular(6)),
      ],
    );
  }

  Widget _buildBadge(String title, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: color)),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _FeatureItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function(BuildContext) builder;

  _FeatureItem(this.title, this.subtitle, this.icon, this.color, this.builder);
}
