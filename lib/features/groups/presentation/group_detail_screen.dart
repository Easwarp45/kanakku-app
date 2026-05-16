import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/group_service.dart';
import 'group_expense_entry_screen.dart';
import '../../../core/providers/auth_provider.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String? groupId;
  const GroupDetailScreen({super.key, this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  Map<String, double> _calculateBalances(String currentUserId, List<Map<String, dynamic>> expenses, List<Map<String, dynamic>> settlements, List<Map<String, dynamic>> members) {
    if (members.isEmpty) return {};
    Map<String, double> balances = {};
    for (var m in members) {
      balances[m['user_id']] = 0.0;
    }

    for (var e in expenses) {
      final paidBy = e['paid_by'];
      final amount = (e['amount'] as num).toDouble();
      final splitAmount = amount / members.length;
      
      balances[paidBy] = (balances[paidBy] ?? 0) + (amount - splitAmount);
      
      for (var m in members) {
        if (m['user_id'] != paidBy) {
          balances[m['user_id']] = (balances[m['user_id']] ?? 0) - splitAmount;
        }
      }
    }

    for (var s in settlements) {
      final paidBy = s['paid_by'];
      final paidTo = s['paid_to'];
      final amount = (s['amount'] as num).toDouble();
      
      balances[paidBy] = (balances[paidBy] ?? 0) + amount;
      balances[paidTo] = (balances[paidTo] ?? 0) - amount;
    }

    return balances;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('No group ID provided')),
      );
    }

    final groupAsync = ref.watch(groupDetailStreamProvider(widget.groupId!));
    final expensesAsync = ref.watch(groupExpensesStreamProvider(widget.groupId!));
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId!));
    final settlementsAsync = ref.watch(groupSettlementsStreamProvider(widget.groupId!));
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

    return Scaffold(
      body: SafeArea(
        child: groupAsync.when(
          data: (group) {
            if (group == null) {
              return const Center(child: Text('Group not found'));
            }
            return expensesAsync.when(
              data: (expenses) => membersAsync.when(
                data: (members) => settlementsAsync.when(
                  data: (settlements) {
                    final balances = _calculateBalances(currentUserId, expenses, settlements, members);
                    final myBalance = balances[currentUserId] ?? 0.0;
                    
                    return Column(
                      children: [
                        _buildHeader(context, group),
                        _buildBalanceSummary(myBalance, members, currentUserId),
                        _buildTabBar(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildExpensesTab(expenses),
                              _buildBalancesTab(balances, members, currentUserId),
                              _buildChatTab(ref, widget.groupId!),
                              _buildMembersTab(members),
                              _buildAnalyticsTab(),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/group-expense-entry', extra: widget.groupId!),
        backgroundColor: AppColors.accentCyan,
        foregroundColor: AppColors.bgPrimary,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> group) {
    final name = group['name'] ?? 'Unknown Group';
    final desc = group['description'] ?? 'No description';
    String initials = 'G';
    if (name.isNotEmpty) {
      initials = name.substring(0, 1).toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary), onPressed: () => context.pop()),
          CircleAvatar(
            radius: 18, 
            backgroundColor: AppColors.accentPurple.withValues(alpha: 0.2), 
            child: Text(initials, style: const TextStyle(color: AppColors.accentPurple, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(icon: const Icon(LucideIcons.settings, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildBalanceSummary(double myBalance, List<Map<String, dynamic>> members, String currentUserId) {
    final isOwed = myBalance >= 0;
    final absBalance = myBalance.abs();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isOwed ? 'You are Owed' : 'You Owe', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('₹${absBalance.toStringAsFixed(2)}', style: AppTheme.moneyStyle.copyWith(color: isOwed ? AppColors.accentCyan : AppColors.accentRose, fontSize: 24)),
              ],
            ),
            if (!isOwed)
              ElevatedButton(
                onPressed: () {
                  // Find someone you owe (this is a simple version)
                  // In a real app, you'd pick a specific person to settle with
                  context.push('/settle-up', extra: {
                    'groupId': widget.groupId,
                    'amount': absBalance,
                    'paidTo': members.firstWhere((m) => m['user_id'] != currentUserId, orElse: () => {})['user_id'],
                    'name': members.firstWhere((m) => m['user_id'] != currentUserId, orElse: () => {})['nickname'] ?? 
                            members.firstWhere((m) => m['user_id'] != currentUserId, orElse: () => {})['display_name'] ?? 'Member'
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentRose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Settle Up', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppColors.accentCyan,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.accentCyan,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: const [
          Tab(text: 'EXPENSES'),
          Tab(text: 'BALANCES'),
          Tab(text: 'CHAT'),
          Tab(text: 'MEMBERS'),
          Tab(text: 'ANALYTICS'),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(List<Map<String, dynamic>> expenses) {
    if (expenses.isEmpty) {
      return const Center(child: Text('No expenses yet. Add one!', style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: expenses.length,
      separatorBuilder: (_, __) => Divider(color: AppColors.borderSubtle, height: 1),
      itemBuilder: (context, index) {
        final e = expenses[index];
        final amount = e['amount'] is num ? (e['amount'] as num).toDouble() : 0.0;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.accentPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(LucideIcons.receipt, color: AppColors.accentPurple),
          ),
          title: Text(e['description'] ?? 'Expense', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: Text('Split ${e['split_type'] ?? 'equal'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Total', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
              Text('₹${amount.toStringAsFixed(2)}', style: AppTheme.moneyStyle.copyWith(color: AppColors.textPrimary, fontSize: 15)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalancesTab(Map<String, double> balances, List<Map<String, dynamic>> members, String currentUserId) {
    final otherMembers = members.where((m) => m['user_id'] != currentUserId).toList();
    
    if (otherMembers.isEmpty) {
      return const Center(child: Text('Add more members to see balances', style: TextStyle(color: AppColors.textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: otherMembers.length,
      itemBuilder: (context, index) {
        final m = otherMembers[index];
        final balance = balances[m['user_id']] ?? 0.0;
        final isOwedByThem = balance < 0; // If their balance is negative, they owe money to the group (effectively some to you)
        // Note: This is a simplified view. In a real app, you'd show individual debts.
        
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16, 
                backgroundColor: (isOwedByThem ? AppColors.accentCyan : AppColors.accentRose).withValues(alpha: 0.1),
                child: Text((m['nickname'] ?? m['display_name'] ?? 'U').substring(0, 1).toUpperCase(), style: TextStyle(color: isOwedByThem ? AppColors.accentCyan : AppColors.accentRose, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(m['nickname'] ?? m['display_name'] ?? 'Group Member', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
              Text(
                balance == 0 ? 'Settled' : '₹${balance.abs().toStringAsFixed(2)}', 
                style: AppTheme.moneyStyle.copyWith(color: balance == 0 ? AppColors.textSecondary : (isOwedByThem ? AppColors.accentCyan : AppColors.accentRose), fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  final _chatController = TextEditingController();

  Widget _buildChatTab(WidgetRef ref, String groupId) {
    final chatAsync = ref.watch(groupChatStreamProvider(groupId));
    return Column(
      children: [
        Expanded(
          child: chatAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return const Center(child: Text('Say hello to the group!', style: TextStyle(color: AppColors.textSecondary)));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(24),
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(radius: 12, child: Icon(LucideIcons.user, size: 12)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(msg['message'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.bgSecondary,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.send, color: AppColors.accentCyan),
                onPressed: () {
                  final text = _chatController.text.trim();
                  if (text.isNotEmpty) {
                    ref.read(groupServiceProvider).sendChatMessage(groupId, text);
                    _chatController.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembersTab(List<Map<String, dynamic>> members) {
    if (members.isEmpty) {
      return const Center(child: Text('No members found', style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: members.length,
      separatorBuilder: (_, __) => Divider(color: AppColors.borderSubtle, height: 1),
      itemBuilder: (context, index) {
        final m = members[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.accentCyan.withValues(alpha: 0.2),
            child: const Icon(LucideIcons.user, color: AppColors.accentCyan, size: 16),
          ),
          title: Text(m['nickname'] ?? m['display_name'] ?? 'Member', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Text(m['is_admin'] == true ? 'Admin' : 'Member', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          trailing: const Text('Joined', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return const Center(child: Text('Group Analytics Dashboard', style: TextStyle(color: AppColors.textTertiary)));
  }
}
