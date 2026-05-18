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
import '../../groups/data/group_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final incomeAsync = ref.watch(inc.incomeStreamProvider);
    
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
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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

    final settlementsAsync = ref.watch(recentSettlementsProvider);
    final hasUnread = settlementsAsync.when<bool>(
      data: (list) => list.isNotEmpty,
      loading: () => false,
      error: (_, __) => false,
    );

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
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.bell, color: AppColors.textPrimary, size: 24),
                    onPressed: () {
                      ref.invalidate(recentSettlementsProvider);
                      _showNotificationCenter(context, ref);
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

  void _showNotificationCenter(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border(
              top: BorderSide(color: AppColors.border, width: 1.5),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Top drag indicator
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Notification Centre',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: AppColors.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: AppColors.border, height: 1),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final settlementsAsync = ref.watch(recentSettlementsProvider);

                    return settlementsAsync.when(
                      data: (settlements) {
                        if (settlements.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.accentCyan.withOpacity(0.06),
                                  ),
                                  child: const Icon(
                                    LucideIcons.bellOff,
                                    color: AppColors.accentCyan,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'All Caught Up!',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'No recent group settlements or updates.',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          itemCount: settlements.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final s = settlements[index];
                            final amount = (s['amount'] as num).toDouble();
                            final payer = s['payer_name'] ?? 'Someone';
                            final receiver = s['receiver_name'] ?? 'Someone';
                            final groupName = s['group_name'] ?? 'Group';
                            final note = s['note'] as String?;
                            final rawDate = s['settled_at'] as String?;
                            
                            String formattedTime = 'Just now';
                            if (rawDate != null) {
                              try {
                                final dt = DateTime.parse(rawDate).toLocal();
                                final diff = DateTime.now().difference(dt);
                                if (diff.inMinutes < 1) {
                                  formattedTime = 'Just now';
                                } else if (diff.inMinutes < 60) {
                                  formattedTime = '${diff.inMinutes}m ago';
                                } else if (diff.inHours < 24) {
                                  formattedTime = '${diff.inHours}h ago';
                                } else {
                                  formattedTime = '${diff.inDays}d ago';
                                }
                              } catch (_) {}
                            }

                            return Container(
                              decoration: BoxDecoration(
                                color: AppColors.bgTertiary.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      context.push('/group-detail', extra: s['group_id']);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.accentEmerald.withOpacity(0.12),
                                              border: Border.all(color: AppColors.accentEmerald.withOpacity(0.2), width: 1),
                                            ),
                                            child: const Icon(
                                              LucideIcons.check,
                                              color: AppColors.accentEmerald,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                RichText(
                                                  text: TextSpan(
                                                    style: const TextStyle(
                                                      color: AppColors.textPrimary,
                                                      fontSize: 13,
                                                      height: 1.4,
                                                    ),
                                                    children: [
                                                      TextSpan(
                                                        text: payer,
                                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                                      ),
                                                      const TextSpan(text: ' settled '),
                                                      TextSpan(
                                                        text: '₹${amount.toStringAsFixed(0)}',
                                                        style: const TextStyle(
                                                          color: AppColors.accentEmerald,
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                      const TextSpan(text: ' with '),
                                                      TextSpan(
                                                        text: receiver,
                                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Icon(LucideIcons.users, color: AppColors.accentPurple.withOpacity(0.8), size: 12),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      groupName,
                                                      style: const TextStyle(
                                                        color: AppColors.textTertiary,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    const Text('•', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      formattedTime,
                                                      style: const TextStyle(
                                                        color: AppColors.textTertiary,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (note != null && note.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.bgPrimary.withOpacity(0.4),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: AppColors.border.withOpacity(0.5)),
                                                    ),
                                                    child: Text(
                                                      '"$note"',
                                                      style: const TextStyle(
                                                        color: AppColors.textSecondary,
                                                        fontSize: 11,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.accentCyan),
                      ),
                      error: (err, _) => Center(
                        child: Text(
                          'Error loading: $err',
                          style: const TextStyle(color: AppColors.accentRose, fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
