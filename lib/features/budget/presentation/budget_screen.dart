import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary), onPressed: () => context.pop()),
        title: const Text('Budget Planning', style: TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [TextButton(onPressed: () {}, child: const Text('Aetheric Ledger'))],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 24),
              _buildInsightBanner(),
              const SizedBox(height: 24),
              _buildSavingsGoals(),
              const SizedBox(height: 24),
              _buildCategoriesSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1e1b4b), Color(0xFF312e81)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.accentPurple.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Budget', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          const SizedBox(height: 8),
          Text('\$4,250.00', style: AppTheme.moneyStyle.copyWith(fontSize: 38, color: Colors.white)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildBudgetStat('Spent Capital', '\$2,840.45', AppColors.accentRose)),
              const SizedBox(width: 16),
              Expanded(child: _buildBudgetStat('Remaining Vault', '\$1,409.55', AppColors.accentEmerald)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.668,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentRose),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.moneyStyle.copyWith(fontSize: 18, color: color)),
      ],
    );
  }

  Widget _buildInsightBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentEmerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.trendingUp, color: AppColors.accentEmerald, size: 20),
          const SizedBox(width: 12),
          const Expanded(child: Text('Budget Insights: On track to save \$450 this month.', style: TextStyle(color: AppColors.accentEmerald, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildSavingsGoals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Savings Goals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            TextButton(onPressed: () {}, child: const Text('View All')),
          ],
        ),
        const SizedBox(height: 12),
        _buildGoalCard('Emergency Fund', 0.72, '\$18,000', '\$25,000', AppColors.accentCyan),
        const SizedBox(height: 12),
        _buildGoalCard('New Tech Vault', 0.45, '\$2,250', '\$5,000', AppColors.accentPurple),
      ],
    );
  }

  Widget _buildGoalCard(String name, double progress, String current, String target, Color color) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
              Text('${(progress * 100).toInt()}%', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.bgSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(current, style: AppTheme.moneyStyle.copyWith(fontSize: 14, color: color)),
              Text('of $target', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final cats = [
      {'name': 'Food & Drinks', 'spent': 380.50, 'budget': 500.00, 'surplus': true, 'note': '\$120.50 Surplus', 'color': AppColors.accentEmerald},
      {'name': 'Transport', 'spent': 155.00, 'budget': 400.00, 'surplus': true, 'note': '\$245.00 Surplus', 'color': AppColors.accentCyan},
      {'name': 'Housing', 'spent': 2200.00, 'budget': 1800.00, 'surplus': false, 'note': 'Critical: Over Budget', 'color': AppColors.accentRose},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        ...cats.map((c) {
          final color = c['color'] as Color;
          final spent = c['spent'] as double;
          final budget = c['budget'] as double;
          final progress = (spent / budget).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              margin: EdgeInsets.zero,
              borderColor: c['surplus'] as bool ? AppColors.border : (color).withValues(alpha: 0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c['name'] as String, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                      if (!(c['surplus'] as bool))
                        Row(children: [const Icon(LucideIcons.alertTriangle, color: AppColors.accentRose, size: 14), const SizedBox(width: 4),
                          const Text('Over Budget', style: TextStyle(color: AppColors.accentRose, fontSize: 11, fontWeight: FontWeight.w600))]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: progress, backgroundColor: AppColors.bgSecondary, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\$${spent.toStringAsFixed(2)} / \$${budget.toStringAsFixed(2)}', style: AppTheme.moneyStyle.copyWith(fontSize: 13, color: AppColors.textSecondary)),
                      Text(c['note'] as String, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
