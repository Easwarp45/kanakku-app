import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../expenses/data/expense_service.dart';
import '../../income/data/income_service.dart' as inc;
import '../../../core/providers/auth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final incomeAsync = ref.watch(inc.incomeStreamProvider);
    
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, ref)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildBalanceCard(ref)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildIncomeExpenseRow(ref)),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(child: _buildQuickActions(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(child: _buildSmartInsightCard(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(
              child: _buildCombinedRecentTransactions(context, ref, expensesAsync, incomeAsync),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
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

  // Greeting Header
  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    String name = 'User';
    String initials = 'U';

    profileAsync.whenData((profile) {
      if (profile != null && profile['display_name'] != null && profile['display_name'].toString().isNotEmpty) {
        name = profile['display_name'];
        initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
      }
    });

    // Dynamic greeting based on time of day
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'GOOD MORNING';
    } else if (hour < 17) {
      greeting = 'GOOD AFTERNOON';
    } else {
      greeting = 'GOOD EVENING';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 2)),
              const SizedBox(height: 2),
              Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accentCyan.withValues(alpha: 0.1),
              child: Text(initials, style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  // Total Balance Card
  Widget _buildBalanceCard(WidgetRef ref) {
    final totalIncome = ref.watch(inc.monthlyIncomeProvider);
    final expenses = ref.watch(monthlyExpensesProvider);
    final balance = totalIncome - expenses;

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
                Text('Monthly Balance', style: TextStyle(fontSize: 13, color: AppColors.bgPrimary.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            Text('₹${balance.toStringAsFixed(2)}', style: AppTheme.moneyStyle.copyWith(fontSize: 40, color: AppColors.bgPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.calendar, color: AppColors.bgPrimary, size: 14),
                  const SizedBox(width: 6),
                  Text('Current Month: ${_getMonthName()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.bgPrimary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName() {
    final now = DateTime.now();
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[now.month - 1];
  }

  // Expense Summary
  Widget _buildIncomeExpenseRow(WidgetRef ref) {
    final totalIncome = ref.watch(inc.monthlyIncomeProvider);
    final expenses = ref.watch(monthlyExpensesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: _buildMiniStatCard('Income', '+₹${totalIncome.toStringAsFixed(2)}', LucideIcons.arrowDownLeft, AppColors.accentEmerald)),
          const SizedBox(width: 12),
          Expanded(child: _buildMiniStatCard('Expenses', '-₹${expenses.toStringAsFixed(2)}', LucideIcons.arrowUpRight, AppColors.accentRose)),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(amount, style: AppTheme.moneyStyle.copyWith(fontSize: 16, color: AppColors.textPrimary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Quick Actions Row
  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionItem(context, LucideIcons.receipt, 'Add Expense', AppColors.accentRose, '/add-expense'),
          _buildActionItem(context, LucideIcons.download, 'Add Income', AppColors.accentEmerald, '/income-list'),
          _buildActionItem(context, LucideIcons.pieChart, 'Budgets', AppColors.accentCyan, '/budget'),
          _buildActionItem(context, LucideIcons.users, 'Split Bill', AppColors.accentPurple, '/groups'),
        ],
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, IconData icon, String label, Color color, String route) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Single Smart Insight Card (Combines Alerts & Analytics intelligently)
  Widget _buildSmartInsightCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () => context.push('/insights'),
        child: GlassCard(
          margin: EdgeInsets.zero,
          borderColor: AppColors.accentPurple.withValues(alpha: 0.3),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.accentPurple, AppColors.accentCyan]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Smart Insight', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    SizedBox(height: 4),
                    Text('You spent 15% less on Food this week. Keep it up!', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCombinedRecentTransactions(
    BuildContext context, 
    WidgetRef ref, 
    AsyncValue<List<Map<String, dynamic>>> expensesAsync,
    AsyncValue<List<Map<String, dynamic>>> incomeAsync,
  ) {
    return expensesAsync.when(
      data: (expenses) {
        return incomeAsync.when(
          data: (income) {
            // Combine both lists
            final combined = [
              ...expenses.map((e) => {...e, 'is_legacy_expense': true}),
              ...income.map((e) => {...e, 'is_new_income': true, 'is_income': true}),
            ];

            // Sort by the specific domain date (expense_date/income_date) descending
            combined.sort((a, b) {
              final dateAStr = a['expense_date']?.toString() ?? a['income_date']?.toString() ?? a['created_at']?.toString() ?? '';
              final dateBStr = b['expense_date']?.toString() ?? b['income_date']?.toString() ?? b['created_at']?.toString() ?? '';
              final dateA = DateTime.tryParse(dateAStr) ?? DateTime(1970);
              final dateB = DateTime.tryParse(dateBStr) ?? DateTime(1970);
              return dateB.compareTo(dateA);
            });

            // Filter to current month
            final now = DateTime.now();
            final filtered = combined.where((e) {
              final dateStr = e['expense_date']?.toString() ?? e['income_date']?.toString() ?? e['created_at']?.toString() ?? '';
              final date = DateTime.tryParse(dateStr);
              return date != null && date.year == now.year && date.month == now.month;
            }).take(5).toList();

            if (filtered.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: Text('No transactions this month', style: TextStyle(color: AppColors.textSecondary)),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      TextButton(onPressed: () => context.push('/transactions'), child: const Text('See All', style: TextStyle(color: AppColors.accentCyan))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    margin: EdgeInsets.zero,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(color: AppColors.borderSubtle, height: 1),
                      itemBuilder: (context, i) => _buildTransactionItem(filtered[i]),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
          error: (e, _) => Center(child: Text('Error loading income: $e', style: const TextStyle(color: AppColors.accentRose))),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
      error: (e, _) => Center(child: Text('Error loading expenses: $e', style: const TextStyle(color: AppColors.accentRose))),
    );
  }

  // Remove the old _buildRecentTransactions method if it's no longer needed
  // (I'll keep it for now but it's superseded by _buildCombinedRecentTransactions)

  static Widget _buildTransactionItem(Map<String, dynamic> t) {
    final isIncome = t['is_income'] == true;
    final amount = t['amount'] is num ? (t['amount'] as num).toDouble() : double.tryParse(t['amount'].toString()) ?? 0.0;
    
    // For income: DB has 'description' and 'source'
    // For expenses: DB has 'description' and 'category'
    final displayTitle = t['description']?.toString() ?? (isIncome ? 'Income' : 'Expense');
    final subText = isIncome 
        ? (t['source']?.toString() ?? 'income')
        : (t['category']?.toString() ?? 'expense');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isIncome ? AppColors.accentEmerald : AppColors.accentRose).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isIncome ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
          color: isIncome ? AppColors.accentEmerald : AppColors.accentRose,
          size: 18,
        ),
      ),
      title: Text(
        displayTitle.isNotEmpty ? displayTitle : (isIncome ? 'Income' : 'Expense'), 
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)
      ),
      subtitle: Text(subText, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: Text(
        '${isIncome ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
        style: AppTheme.moneyStyle.copyWith(
          color: isIncome ? AppColors.accentEmerald : AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
