import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildBalanceCard()),
            SliverToBoxAdapter(child: const SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildIncomeExpenseRow()),
            SliverToBoxAdapter(child: const SizedBox(height: 28)),
            SliverToBoxAdapter(child: _buildQuickActions(context)),
            SliverToBoxAdapter(child: const SizedBox(height: 28)),
            SliverToBoxAdapter(child: _buildRecentMatrix()),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-expense'),
        backgroundColor: AppColors.accentCyan,
        foregroundColor: AppColors.bgPrimary,
        child: const Icon(LucideIcons.plus),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EXECUTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentCyan, letterSpacing: 2)),
              const SizedBox(height: 2),
              const Text('AETHERIC LEDGER', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.bgElevated,
              child: Text('MV', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [AppColors.accentCyan, AppColors.accentPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.wallet, color: AppColors.bgPrimary.withValues(alpha: 0.8), size: 16),
                const SizedBox(width: 8),
                Text('Total Capital', style: TextStyle(fontSize: 12, color: AppColors.bgPrimary.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            Text('\$24,562.00', style: AppTheme.moneyStyle.copyWith(fontSize: 38, color: AppColors.bgPrimary)),
            const SizedBox(height: 4),
            Text('+12.4% this month', style: TextStyle(fontSize: 12, color: AppColors.bgPrimary.withValues(alpha: 0.75))),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: _buildMiniStatCard('Income', '+\$5,240.00', LucideIcons.arrowDownLeft, AppColors.accentEmerald)),
          const SizedBox(width: 12),
          Expanded(child: _buildMiniStatCard('Expenses', '-\$1,840.00', LucideIcons.arrowUpRight, AppColors.accentRose)),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String label, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(amount, style: AppTheme.moneyStyle.copyWith(fontSize: 14, color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildActionChip(context, LucideIcons.minus, 'Log Expense', AppColors.accentRose, '/add-expense'),
          const SizedBox(width: _actionChipSpacing),
          _buildActionChip(context, LucideIcons.plus, 'Add Income', AppColors.accentEmerald, '/income-list'),
          const SizedBox(width: _actionChipSpacing),
          _buildActionChip(context, LucideIcons.users, 'Groups', AppColors.accentPurple, '/groups'),
          const SizedBox(width: _actionChipSpacing),
          _buildActionChip(context, LucideIcons.target, 'Budget', AppColors.accentCyan, '/budget'),
        ],
      ),
    );
  }

  Widget _buildActionChip(BuildContext context, IconData icon, String label, Color color, String route) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(route),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _actionChipSpacing = 12.0;

  Widget _buildRecentMatrix() {
    final transactions = [
      {'name': 'Le Bernardin Dinner', 'sub': 'Oct 24 • Food & Dining', 'amount': '-\$1,480.00', 'income': false},
      {'name': 'Global Tech Solutions', 'sub': 'Oct 23 • Salary Deposit', 'amount': '+\$16,500.00', 'income': true},
      {'name': 'Alpine Lodge Booking', 'sub': 'Oct 22 • Travel', 'amount': '-\$4,200.00', 'income': false},
      {'name': 'Dividend Yield', 'sub': 'Oct 21 • Portfolio', 'amount': '+\$2,710.00', 'income': true},
      {'name': 'Chauffeur Fuel', 'sub': 'Oct 18 • Transport', 'amount': '-\$312.00', 'income': false},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Matrix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              TextButton(onPressed: () {}, child: const Text('View All')),
            ],
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => Divider(color: AppColors.borderSubtle, height: 1),
              itemBuilder: (context, i) => _buildTransactionItem(transactions[i]),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTransactionItem(Map<String, dynamic> t) {
    final isIncome = t['income'] as bool;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isIncome ? AppColors.accentEmerald : AppColors.accentRose).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isIncome ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
          color: isIncome ? AppColors.accentEmerald : AppColors.accentRose,
          size: 18,
        ),
      ),
      title: Text(t['name'] as String, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(t['sub'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: Text(
        t['amount'] as String,
        style: AppTheme.moneyStyle.copyWith(
          color: isIncome ? AppColors.accentEmerald : AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
