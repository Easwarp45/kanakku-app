import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../expenses/data/expense_service.dart';
import '../../income/data/income_service.dart' as inc;
import '../../../core/providers/auth_provider.dart';
import '../../groups/data/group_service.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/multi_currency_helper.dart';
import '../../notifications/providers/notification_provider.dart';

// Why recentCombinedTransactionsProvider: Instead of combining, sorting, and filtering 
// raw streams (expenses and income) on every build call of the dashboard or parent tree 
// (which gets rebuilt frequently on navigation and wallet status updates), we cache 
// the computed list in this Riverpod autoDispose provider. Re-evaluation only occurs 
// when the underlying database stream values change. This dramatically reduces layout phase 
// sorting overhead and avoids redundant garbage collection of temporary mapped maps.
final recentCombinedTransactionsProvider = Provider.autoDispose<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  final incomeAsync = ref.watch(inc.incomeStreamProvider);

  if (expensesAsync.isLoading || incomeAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (expensesAsync.hasError) {
    return AsyncValue.error(expensesAsync.error!, expensesAsync.stackTrace!);
  }
  if (incomeAsync.hasError) {
    return AsyncValue.error(incomeAsync.error!, incomeAsync.stackTrace!);
  }

  final expenses = expensesAsync.value ?? [];
  final income = incomeAsync.value ?? [];

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

  return AsyncValue.data(filtered);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> handleRefresh() async {
      ref.invalidate(expensesStreamProvider);
      ref.invalidate(inc.incomeStreamProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(inc.monthlyIncomeProvider);
      ref.invalidate(monthlyExpensesProvider);
      ref.invalidate(recentSettlementsProvider);
      // Wait a tiny moment for smooth visual feedback
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentCyan,
          backgroundColor: AppColors.bgElevated,
          onRefresh: handleRefresh,
          child: const CustomScrollView(
            physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _DashboardHeader()),
              SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: _BalanceCard()),
              SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(child: _IncomeExpenseRow()),
              SliverToBoxAdapter(child: SizedBox(height: 28)),
              SliverToBoxAdapter(child: _QuickActions()),
              SliverToBoxAdapter(child: SizedBox(height: 28)),
              SliverToBoxAdapter(child: _SmartInsightCard()),
              SliverToBoxAdapter(child: SizedBox(height: 28)),
              SliverToBoxAdapter(child: _RecentTransactionsList()),
              SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-expense'),
        backgroundColor: AppColors.accentCyan,
        foregroundColor: AppColors.bgPrimary,
        child: const Icon(LucideIcons.plus),
      ),
    );
  }
}

// Greeting Header Widget
class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final hasUnread = unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/icons/kanakku_logo.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 6),
                  Text(greeting, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 2)),
                ],
              ),
              const SizedBox(height: 2),
              Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.bell, color: AppColors.textPrimary, size: 24),
                    onPressed: () {
                      context.push('/notifications');
                    },
                  ),
                  if (hasUnread)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentRose,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentRose.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
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
        ],
      ),
    );
  }
}


// Total Balance Card Widget
class _BalanceCard extends ConsumerWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final currencySymbol = prefs.currencyIndex == 1
        ? '\$'
        : prefs.currencyIndex == 2
            ? '€'
            : prefs.currencyIndex == 3
                ? '£'
                : '₹';
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
            Text('$currencySymbol${balance.toStringAsFixed(2)}', style: AppTheme.moneyStyle.copyWith(fontSize: 40, color: AppColors.bgPrimary)),
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
}

// Income Expense Row Widget
class _IncomeExpenseRow extends ConsumerWidget {
  const _IncomeExpenseRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final currencySymbol = prefs.currencyIndex == 1
        ? '\$'
        : prefs.currencyIndex == 2
            ? '€'
            : prefs.currencyIndex == 3
                ? '£'
                : '₹';
    final totalIncome = ref.watch(inc.monthlyIncomeProvider);
    final expenses = ref.watch(monthlyExpensesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: _buildMiniStatCard('Income', '+$currencySymbol${totalIncome.toStringAsFixed(2)}', LucideIcons.arrowDownLeft, AppColors.accentEmerald)),
          const SizedBox(width: 12),
          Expanded(child: _buildMiniStatCard('Expenses', '-$currencySymbol${expenses.toStringAsFixed(2)}', LucideIcons.arrowUpRight, AppColors.accentRose)),
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
}

// Quick Actions Widget
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
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
}

// Smart Insight Card Widget
class _SmartInsightCard extends ConsumerWidget {
  const _SmartInsightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalIncome = ref.watch(inc.monthlyIncomeProvider);
    final expenses = ref.watch(monthlyExpensesProvider);
    final balance = totalIncome - expenses;
    final expensesAsync = ref.watch(expensesStreamProvider);

    double parseAmount(dynamic amount) {
      if (amount is num) return amount.toDouble();
      return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
    }

    String topCategory = 'Other';
    double topCategoryAmount = 0;

    expensesAsync.whenData((list) {
      final now = DateTime.now();
      final Map<String, double> categorySums = {};
      for (final e in list) {
        final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
        final date = DateTime.tryParse(dateStr);
        if (date != null && date.year == now.year && date.month == now.month) {
          final cat = e['category']?.toString() ?? 'Other';
          final amt = parseAmount(e['amount']);
          categorySums[cat] = (categorySums[cat] ?? 0.0) + amt;
        }
      }
      if (categorySums.isNotEmpty) {
        final sorted = categorySums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        topCategory = sorted.first.key;
        topCategoryAmount = sorted.first.value;
      }
    });

    final prefs = ref.watch(preferencesProvider);
    final code = supportedCurrencies[prefs.currencyIndex].code;
    final rate = prefs.rates[code] ?? 1.0;
    final displayTopAmount = topCategoryAmount * rate;
    final currencySymbol = prefs.currencyIndex == 1
        ? '\$'
        : prefs.currencyIndex == 2
            ? '€'
            : prefs.currencyIndex == 3
                ? '£'
                : '₹';

    String insightText = 'Your allocations are well-aligned. Tap here for deep financial health insights!';
    IconData insightIcon = LucideIcons.sparkles;
    Color iconColor = AppColors.accentCyan;

    if (totalIncome == 0 && expenses == 0) {
      insightText = 'Start logging your expenses and income to generate smart financial insights!';
      insightIcon = LucideIcons.sparkles;
      iconColor = AppColors.accentCyan;
    } else if (expenses > totalIncome && totalIncome > 0) {
      final diff = expenses - totalIncome;
      insightText = '⚠️ Spending exceeds income by $currencySymbol${diff.toStringAsFixed(0)}. Trim non-essential items.';
      insightIcon = LucideIcons.alertTriangle;
      iconColor = AppColors.accentRose;
    } else if (balance > 0 && balance < 1000 * rate) {
      insightText = '💡 Monthly balance is low ($currencySymbol${balance.toStringAsFixed(0)}). Avoid high non-essential purchases.';
      insightIcon = LucideIcons.lightbulb;
      iconColor = AppColors.accentAmber;
    } else if (totalIncome > 0 && (balance / totalIncome) >= 0.3) {
      final savingsRate = (balance / totalIncome) * 100;
      insightText = '🎉 Superb! You saved ${savingsRate.toStringAsFixed(0)}% of your income this month. Keep it up!';
      insightIcon = LucideIcons.trendingUp;
      iconColor = AppColors.accentEmerald;
    } else if (topCategoryAmount > 0) {
      insightText = '🍕 Top spending is on "$topCategory": $currencySymbol${displayTopAmount.toStringAsFixed(0)} this month.';
      insightIcon = LucideIcons.pieChart;
      iconColor = AppColors.accentPurple;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () => context.push('/insights'),
        child: GlassCard(
          margin: EdgeInsets.zero,
          borderColor: iconColor.withValues(alpha: 0.3),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [iconColor, iconColor.withValues(alpha: 0.6)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(insightIcon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Smart Insight', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(insightText, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
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
}

// Recent Transactions Section Widget
class _RecentTransactionsList extends ConsumerWidget {
  const _RecentTransactionsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentCombinedTransactionsProvider);

    return recentAsync.when(
      data: (filtered) {
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
                  separatorBuilder: (_, _) => Divider(color: AppColors.borderSubtle, height: 1),
                  itemBuilder: (context, i) {
                    // Why RepaintBoundary: Wrapping each transaction item in a RepaintBoundary 
                    // creates a separate display list/layer. When scrolling or performing 
                    // tap animations on a card, only this isolated layer repaints, preventing 
                    // paint invalidation from traversing up and repainting the entire dashboard.
                    return RepaintBoundary(
                      child: _TransactionListItem(t: filtered[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
      error: (e, _) => Center(child: Text('Error loading transactions: $e', style: const TextStyle(color: AppColors.accentRose))),
    );
  }
}

// Individual Transaction List Item Widget
class _TransactionListItem extends ConsumerWidget {
  final Map<String, dynamic> t;
  const _TransactionListItem({required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = t['is_income'] == true;
    final baseAmount = t['amount'] is num ? (t['amount'] as num).toDouble() : double.tryParse(t['amount'].toString()) ?? 0.0;
    
    final prefs = ref.watch(preferencesProvider);
    final preferredCurrencyCode = supportedCurrencies[prefs.currencyIndex].code;

    final rawDesc = t['description']?.toString() ?? '';
    final groupName = _parseGroupName(rawDesc);
    final cleanTitle = _stripGroupToken(rawDesc);
    final displayTitle = cleanTitle.isNotEmpty ? cleanTitle : (isIncome ? 'Income' : 'Expense');
    final subText = isIncome
        ? (t['source']?.toString() ?? 'income')
        : groupName != null
            ? 'via $groupName'
            : (t['category']?.toString() ?? 'expense');

    final mcData = MultiCurrencyData.parse(rawDesc);

    String formattedAmount = '';
    String sublabel = '';

    if (mcData != null) {
      formattedAmount = CurrencyFormatter.format(mcData.amount, mcData.currency);
      if (preferredCurrencyCode != mcData.currency) {
        final preferredVal = prefs.convertFromBaseline(baseAmount);
        sublabel = '≈ ${CurrencyFormatter.format(preferredVal, preferredCurrencyCode)}';
      } else if (mcData.currency != 'INR') {
        sublabel = '≈ ₹${baseAmount.toStringAsFixed(2)}';
      }
    } else {
      final converted = prefs.convertFromBaseline(baseAmount);
      formattedAmount = CurrencyFormatter.format(converted, preferredCurrencyCode);
      if (preferredCurrencyCode != 'INR') {
        sublabel = '≈ ₹${baseAmount.toStringAsFixed(2)}';
      }
    }

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
        displayTitle, 
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subText, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if (sublabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(sublabel, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
          ],
        ],
      ),
      trailing: Text(
        '${isIncome ? '+' : '-'}$formattedAmount',
        style: AppTheme.moneyStyle.copyWith(
          color: isIncome ? AppColors.accentEmerald : AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _stripGroupToken(String raw) {
    return raw.replaceFirst(RegExp(r'^\[GroupExpense:[^\]]+\]\s*'), '').trim();
  }

  static String? _parseGroupName(String raw) {
    final match = RegExp(r'^\[GroupExpense:[^|]+\|GroupName:\s*([^\]]+)\]').firstMatch(raw);
    return match?.group(1)?.trim();
  }
}
