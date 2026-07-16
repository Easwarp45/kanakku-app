import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/group_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/membership_guard_provider.dart';
import '../../expenses/data/expense_service.dart';
import '../../../core/database/local_cache_service.dart';
import '../../../core/database/chat_reconciliation_engine.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/multi_currency_helper.dart';


class GroupDetailScreen extends ConsumerStatefulWidget {
  final String? groupId;
  const GroupDetailScreen({super.key, this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    // Do NOT call setState here — use ValueListenableBuilder in build() instead.
    // This was previously causing a full rebuild of the entire 1351-line widget
    // on every tab swipe.
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleGroupRefresh() async {
    if (mounted) {
      setState(() => _isRefreshing = true);
    }
    if (widget.groupId != null) {
      ref.invalidate(groupDetailStreamProvider(widget.groupId!));
      ref.invalidate(groupExpensesStreamProvider(widget.groupId!));
      ref.invalidate(groupMembersStreamProvider(widget.groupId!));
      ref.invalidate(groupSettlementsStreamProvider(widget.groupId!));
      ref.invalidate(membershipGuardProvider(widget.groupId!));
      ref.invalidate(groupChatStreamProvider(widget.groupId!));
      ref.invalidate(reconciledChatStreamProvider(widget.groupId!));
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Map<String, double> _calculateBalances(String currentUserId, List<Map<String, dynamic>> expenses, List<Map<String, dynamic>> settlements, List<Map<String, dynamic>> members) {
    if (members.isEmpty) return {};
    Map<String, double> balances = {};
    for (var m in members) {
      final uId = m['user_id'] as String?;
      if (uId != null) {
        balances[uId] = 0.0;
      }
    }

    for (var e in expenses) {
      final paidBy = e['paid_by'] as String?;
      final amountVal = e['amount'];
      if (paidBy == null || amountVal == null) continue;
      final amount = (amountVal as num).toDouble();
      final splitAmount = amount / members.length;
      
      balances[paidBy] = (balances[paidBy] ?? 0) + (amount - splitAmount);
      
      for (var m in members) {
        final uId = m['user_id'] as String?;
        if (uId != null && uId != paidBy) {
          balances[uId] = (balances[uId] ?? 0) - splitAmount;
        }
      }
    }

    for (var s in settlements) {
      final paidBy = s['paid_by'] as String?;
      final paidTo = s['paid_to'] as String?;
      final amountVal = s['amount'];
      if (paidBy == null || paidTo == null || amountVal == null) continue;
      final amount = (amountVal as num).toDouble();
      
      balances[paidBy] = (balances[paidBy] ?? 0) + amount;
      balances[paidTo] = (balances[paidTo] ?? 0) - amount;
    }

    return balances;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'food':
        return LucideIcons.utensils;
      case 'transport':
        return LucideIcons.car;
      case 'entertainment':
        return LucideIcons.tv;
      case 'housing':
        return LucideIcons.home;
      case 'shopping':
        return LucideIcons.shoppingBag;
      case 'health':
        return LucideIcons.heart;
      default:
        return LucideIcons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('No group ID provided')),
      );
    }

    // ── Membership Guard ──────────────────────────────────────────────────────
    // Independently watches for removal/group-deletion via a dedicated
    // realtime channel. Fires BEFORE the main streams update.
    final membershipStatus = ref.watch(membershipGuardProvider(widget.groupId!));
    final status = membershipStatus.when(
      data: (s) => s,
      loading: () => MembershipStatus.loading,
      error: (_, _) => MembershipStatus.active, // fail-open
    );
    if (status == MembershipStatus.removed ||
        status == MembershipStatus.groupDeleted) {
      // Use addPostFrameCallback so we don't navigate during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/groups');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status == MembershipStatus.groupDeleted
                  ? 'This group has been deleted'
                  : 'You have been removed from this group'),
              backgroundColor: AppColors.accentRose,
            ),
          );
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
      );
    }

    // Watch only what the root scaffold needs — group info, members, expenses, settlements.
    // The chat stream is watched ONLY inside _IsolatedChatTab to prevent chat
    // updates from triggering a full GroupDetailScreen rebuild.
    final groupAsync = ref.watch(groupDetailStreamProvider(widget.groupId!));
    final expensesAsync = ref.watch(groupExpensesStreamProvider(widget.groupId!));
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId!));
    final settlementsAsync = ref.watch(groupSettlementsStreamProvider(widget.groupId!));
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // Derive data safely — prefer cached data while loading (cache-first pattern)
    final group = groupAsync.when(
      data: (d) => d,
      loading: () => LocalCacheService.getCachedMap('group_detail_${widget.groupId}'),
      error: (_, _) => LocalCacheService.getCachedMap('group_detail_${widget.groupId}'),
    );
    final expenses = expensesAsync.when<List<Map<String, dynamic>>>(
      data: (d) => d,
      loading: () => LocalCacheService.getCachedList('group_expenses_${widget.groupId}'),
      error: (_, _) => LocalCacheService.getCachedList('group_expenses_${widget.groupId}'),
    );
    final members = membersAsync.when<List<Map<String, dynamic>>>(
      data: (d) => d,
      loading: () => LocalCacheService.getCachedList('group_members_${widget.groupId}'),
      error: (_, _) => LocalCacheService.getCachedList('group_members_${widget.groupId}'),
    );
    final settlements = settlementsAsync.when<List<Map<String, dynamic>>>(
      data: (d) => d,
      loading: () => LocalCacheService.getCachedList('settlements_${widget.groupId}'),
      error: (_, _) => LocalCacheService.getCachedList('settlements_${widget.groupId}'),
    );

    // Show full-screen spinner only on first cold load (no cache)
    final isFirstLoad = group == null &&
        groupAsync.isLoading &&
        !LocalCacheService.hasCachedData('group_detail_${widget.groupId}');

    if (isFirstLoad) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
      );
    }

    if (group == null && !groupAsync.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(backgroundColor: AppColors.bgPrimary),
        body: const Center(child: Text('Group not found', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final safeGroup = group ?? {};
    final balances = _calculateBalances(currentUserId, expenses, settlements, members);
    final myBalance = balances[currentUserId] ?? 0.0;

    final prefs = ref.watch(preferencesProvider);
    final preferredCurrencyCode = supportedCurrencies[prefs.currencyIndex].code;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            RepaintBoundary(child: _buildHeader(context, safeGroup, members, currentUserId)),
            if (!isKeyboardOpen)
              RepaintBoundary(
                child: _buildGlassHeroCard(
                    safeGroup, myBalance, members, currentUserId, expenses.length, prefs, preferredCurrencyCode),
              ),
            _buildModernTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Why RepaintBoundary: Each tab (expenses, balances, chat, members, analytics) 
                  // performs distinct, high-activity painting tasks (e.g. chat messages streams, 
                  // analytics graphs, long list scrolling). Wrapping each tab in a RepaintBoundary 
                  // isolates their paint cycles completely, avoiding full screen repaints on tab updates.
                  // Each tab is isolated — rebuilds independently
                  RepaintBoundary(
                    child: _buildExpensesTab(expenses, members, currentUserId, prefs, preferredCurrencyCode),
                  ),
                  RepaintBoundary(
                    child: _buildBalancesTab(balances, members, currentUserId, prefs, preferredCurrencyCode),
                  ),
                  // Chat tab is fully isolated — has its own stream watch
                  RepaintBoundary(
                    child: _IsolatedChatTab(
                      groupId: widget.groupId!,
                      members: members,
                      currentUserId: currentUserId,
                      inviteCode: safeGroup['invite_code'] ?? '',
                      onRefresh: _handleGroupRefresh,
                    ),
                  ),
                  RepaintBoundary(
                    child: _buildMembersTab(ref, members, safeGroup['invite_code'], currentUserId),
                  ),
                  RepaintBoundary(
                    child: _buildAnalyticsTab(expenses, members),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // AnimatedBuilder listens to the tab animation — FAB only rebuilds on tab changes
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final isChatTab = _tabController.index == 2;
          if (isChatTab || _tabController.indexIsChanging) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () =>
                context.push('/group-expense-entry', extra: widget.groupId!),
            backgroundColor: AppColors.accentCyan,
            foregroundColor: AppColors.bgPrimary,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Icon(LucideIcons.plus, size: 24),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> group, List<Map<String, dynamic>> members, String currentUserId) {
    final name = group['name'] ?? 'Unknown Group';
    final desc = group['description'] ?? 'No description';
    String initials = 'G';
    if (name.isNotEmpty) {
      initials = name.substring(0, 1).toUpperCase();
    }

    final amIAdmin = members.any((m) => m['user_id'] == currentUserId && m['is_admin'] == true);
    final myMemberInfo = members.firstWhere((m) => m['user_id'] == currentUserId, orElse: () => <String, dynamic>{});

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary, size: 28),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20, 
            backgroundColor: AppColors.accentPurple.withValues(alpha: 0.15), 
            child: Text(initials, style: const TextStyle(color: AppColors.accentPurple, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          _isRefreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                  ),
                )
              : IconButton(
                  icon: const Icon(LucideIcons.refreshCw, color: AppColors.textSecondary, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Refresh Group',
                  onPressed: () async {
                    await _handleGroupRefresh();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Group details refreshed'),
                          duration: Duration(seconds: 1),
                          backgroundColor: AppColors.bgSecondary,
                        ),
                      );
                    }
                  },
                ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(LucideIcons.settings, color: AppColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              // Quick action to show invite code
              final inviteCode = group['invite_code'] ?? 'N/A';
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.bgSecondary,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (context) => Container(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 24),
                      const Text('GROUP DETAILS', style: TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                      const SizedBox(height: 20),
                      Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      ],
                      const SizedBox(height: 24),
                      const Text('Invite Code', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied!')));
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(color: AppColors.bgTertiary, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(inviteCode, style: const TextStyle(color: AppColors.accentPurple, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 3)),
                              const SizedBox(width: 12),
                              const Icon(LucideIcons.copy, color: AppColors.accentPurple, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 12),
                      if (myMemberInfo.isNotEmpty)
                        ListTile(
                          leading: const Icon(LucideIcons.logOut, color: AppColors.accentRose),
                          title: const Text('Leave Group', style: TextStyle(color: AppColors.accentRose, fontWeight: FontWeight.w700)),
                          subtitle: const Text('You will no longer be part of this group', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                          onTap: () {
                            Navigator.pop(context); // Close bottom sheet
                            _showLeaveGroupDialog(context, ref, widget.groupId!, myMemberInfo);
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      if (amIAdmin) ...[
                        const SizedBox(height: 8),
                        ListTile(
                          leading: const Icon(LucideIcons.trash2, color: AppColors.accentRose),
                          title: const Text('Delete Group', style: TextStyle(color: AppColors.accentRose, fontWeight: FontWeight.w700)),
                          subtitle: const Text('Permanently delete the group and all its data', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                          onTap: () {
                            Navigator.pop(context); // Close bottom sheet
                            _showDeleteGroupDialog(context, ref, widget.groupId!);
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
     Widget _buildGlassHeroCard(Map<String, dynamic> group, double myBalance, List<Map<String, dynamic>> members, String currentUserId, int expenseCount, PreferencesState prefs, String preferredCurrencyCode) {
    final isOwed = myBalance >= 0;
    final absBalance = myBalance.abs();
    final preferredBalance = prefs.convertFromBaseline(absBalance);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GlassCard(
        margin: EdgeInsets.zero,
        borderRadius: 24,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.bgTertiary.withValues(alpha: 0.4),
                AppColors.bgSecondary.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isOwed ? 'YOU ARE OWED' : 'YOU OWE', style: TextStyle(color: isOwed ? AppColors.accentCyan : AppColors.accentRose, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            CurrencyFormatter.format(preferredBalance, preferredCurrencyCode),
                            style: AppTheme.moneyStyle.copyWith(color: isOwed ? AppColors.accentCyan : AppColors.accentRose, fontSize: 32),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isOwed) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final paidToUser = members.firstWhere((m) => m['user_id'] != currentUserId, orElse: () => {});
                        context.push('/settle-up', extra: {
                          'groupId': widget.groupId,
                          'amount': absBalance,
                          'paidTo': paidToUser['user_id'],
                          'name': paidToUser['nickname'] ?? paidToUser['display_name'] ?? 'Member'
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentRose.withValues(alpha: 0.15),
                        foregroundColor: AppColors.accentRose,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        side: BorderSide(color: AppColors.accentRose.withValues(alpha: 0.3)),
                      ),
                      icon: const Icon(LucideIcons.checkSquare, size: 16),
                      label: const Text('Settle Up', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildStatBadge(LucideIcons.users, '${members.length} Members', () => _tabController.animateTo(3))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatBadge(LucideIcons.receipt, '$expenseCount Bills', () => _tabController.animateTo(0))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatBadge(LucideIcons.messageSquare, 'Chats', () => _tabController.animateTo(2))),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.borderSubtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text, 
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        labelColor: AppColors.accentCyan,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.accentCyan,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: const [
          Tab(text: 'EXPENSES'),
          Tab(text: 'BALANCES'),
          Tab(text: 'CHATS'),
          Tab(text: 'MEMBERS'),
          Tab(text: 'ANALYTICS'),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(List<Map<String, dynamic>> expenses, List<Map<String, dynamic>> members, String currentUserId, PreferencesState prefs, String preferredCurrencyCode) {
    final Widget content;
    if (expenses.isEmpty) {
      content = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              minWidth: constraints.maxWidth,
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(LucideIcons.receipt, color: AppColors.textTertiary, size: 40),
                  SizedBox(height: 16),
                  Text('No expenses recorded yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('Tap "+" below to add your first bill', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      content = ListView.separated(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: expenses.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final e = expenses[index];
          final amount = e['amount'] is num ? (e['amount'] as num).toDouble() : 0.0;
          final payerId = e['paid_by'];
          final isMe = payerId == currentUserId;
          
          final payer = members.firstWhere((m) => m['user_id'] == payerId, orElse: () => {});
          final payerName = isMe ? 'You' : (payer['nickname'] ?? payer['display_name'] ?? 'Member');
          
          final splitShare = members.isNotEmpty ? amount / members.length : 0.0;

          // Double token check and MultiCurrencyData parsing
          final cleanGroupDesc = e['description']?.toString().replaceFirst(RegExp(r'^\[GroupExpense:[^\]]+\]\s*'), '').trim() ?? '';
          final mcData = MultiCurrencyData.parse(cleanGroupDesc);
          final cleanTitle = MultiCurrencyData.cleanDescription(cleanGroupDesc);
          final displayTitle = cleanTitle.isNotEmpty ? cleanTitle : 'Expense';

          String formattedAmount = '';
          String subAmountText = '';

          if (mcData != null) {
            formattedAmount = CurrencyFormatter.format(mcData.amount, mcData.currency);
            final origOwed = mcData.amount - (mcData.amount / members.length);
            final origOwe = mcData.amount / members.length;
            final displayOrigSub = isMe
                ? 'Owed ${CurrencyFormatter.format(origOwed, mcData.currency)}'
                : 'You owe ${CurrencyFormatter.format(origOwe, mcData.currency)}';
            
            if (preferredCurrencyCode != mcData.currency) {
              final prefVal = prefs.convertFromBaseline(amount);
              final prefShare = prefs.convertFromBaseline(splitShare);
              final displayShare = isMe ? (prefVal - prefShare) : prefShare;
              subAmountText = '$displayOrigSub (≈ ${CurrencyFormatter.format(displayShare, preferredCurrencyCode)})';
            } else {
              subAmountText = displayOrigSub;
            }
          } else {
            final convertedAmount = prefs.convertFromBaseline(amount);
            final convertedSplit = prefs.convertFromBaseline(splitShare);
            formattedAmount = CurrencyFormatter.format(convertedAmount, preferredCurrencyCode);
            subAmountText = isMe
                ? 'Owed ${CurrencyFormatter.format(convertedAmount - convertedSplit, preferredCurrencyCode)}'
                : 'You owe ${CurrencyFormatter.format(convertedSplit, preferredCurrencyCode)}';
          }
          
          return RepaintBoundary(
            child: GlassCard(
              margin: EdgeInsets.zero,
              borderRadius: 16,
              onTap: () {
                if (e['id']?.toString().startsWith('temp_') == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Expense is syncing with the server. Please wait...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
                context.push('/edit-group-expense', extra: {
                  'groupId': widget.groupId,
                  'expense': e,
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_getCategoryIcon(e['category']), color: AppColors.accentPurple, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayTitle, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: 'Paid by $payerName', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                                const TextSpan(text: '  •  ', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                                TextSpan(text: _formatDate(e['expense_date'] ?? e['created_at']), style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formattedAmount, style: AppTheme.moneyStyle.copyWith(fontSize: 16, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                          subAmountText,
                          style: TextStyle(color: isMe ? AppColors.accentCyan : AppColors.accentRose, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
 
    return RefreshIndicator(
      color: AppColors.accentCyan,
      backgroundColor: AppColors.bgElevated,
      onRefresh: _handleGroupRefresh,
      child: content,
    );
  }

  Widget _buildBalancesTab(Map<String, double> balances, List<Map<String, dynamic>> members, String currentUserId, PreferencesState prefs, String preferredCurrencyCode) {
    final otherMembers = members.where((m) => m['user_id'] != currentUserId).toList();
    
    final Widget content;
    if (otherMembers.isEmpty) {
      content = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              minWidth: constraints.maxWidth,
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(LucideIcons.users, color: AppColors.textTertiary, size: 40),
                  SizedBox(height: 16),
                  Text('No members in group yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('Share invite code to add group members', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      content = ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: otherMembers.length,
        itemBuilder: (context, index) {
          final m = otherMembers[index];
          final balance = balances[m['user_id']] ?? 0.0;
          final isOwedByThem = balance < 0; 
          
          final preferredAbsBalance = prefs.convertFromBaseline(balance.abs());

          return RepaintBoundary(
            child: GlassCard(
              margin: const EdgeInsets.only(bottom: 12),
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20, 
                      backgroundColor: (isOwedByThem ? AppColors.accentCyan : AppColors.accentRose).withValues(alpha: 0.1),
                      child: Builder(
                        builder: (context) {
                          final displayName = m['nickname']?.toString() ?? m['display_name']?.toString() ?? 'U';
                          final displayInitials = displayName.trim().isEmpty ? 'U' : displayName.trim().substring(0, 1).toUpperCase();
                          return Text(
                            displayInitials,
                            style: TextStyle(color: isOwedByThem ? AppColors.accentCyan : AppColors.accentRose, fontSize: 14, fontWeight: FontWeight.w800),
                          );
                        }
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['nickname'] ?? m['display_name'] ?? 'Group Member', 
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            balance == 0 
                                ? 'All settled up' 
                                : (isOwedByThem ? 'Owes you money' : 'You owe them money'), 
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          balance == 0 
                              ? 'Settled' 
                              : CurrencyFormatter.format(preferredAbsBalance, preferredCurrencyCode), 
                          style: AppTheme.moneyStyle.copyWith(color: balance == 0 ? AppColors.textSecondary : (isOwedByThem ? AppColors.accentCyan : AppColors.accentRose), fontSize: 16),
                        ),
                        if (!isOwedByThem && balance != 0) ...[
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              context.push('/settle-up', extra: {
                                'groupId': widget.groupId,
                                'amount': balance.abs(),
                                'paidTo': m['user_id'],
                                'name': m['nickname'] ?? m['display_name'] ?? 'Member'
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentRose.withValues(alpha: 0.15),
                              foregroundColor: AppColors.accentRose,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Pay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      color: AppColors.accentCyan,
      backgroundColor: AppColors.bgElevated,
      onRefresh: _handleGroupRefresh,
      child: content,
    );
  }


  Widget _buildMembersTab(WidgetRef ref, List<Map<String, dynamic>> members, String? inviteCode, String currentUserId) {
    final amIAdmin = members.any((m) => m['user_id'] == currentUserId && m['is_admin'] == true);

    return RefreshIndicator(
      color: AppColors.accentCyan,
      backgroundColor: AppColors.bgElevated,
      onRefresh: _handleGroupRefresh,
      // Why CustomScrollView & SliverList: Previously, this list was nested with 
      // shrinkWrap: true and NeverScrollableScrollPhysics(), forcing Flutter to immediately 
      // instantiate and build all group members, bypassing lazy viewport loading. 
      // Flat slivers enable virtualization so that cards are lazily instantiated as they 
      // scroll into the viewport, which scales efficiently on large groups.
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (inviteCode != null) ...[
                    GlassCard(
                      margin: const EdgeInsets.only(bottom: 24),
                      borderRadius: 18,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.accentPurple.withValues(alpha: 0.05), Colors.transparent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(LucideIcons.userPlus, color: AppColors.accentPurple, size: 28),
                            const SizedBox(height: 12),
                            const Text('Invite Friends', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 6),
                            const Text('Share this code with roommates or friends to join', style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgTertiary,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(inviteCode, style: const TextStyle(color: AppColors.accentCyan, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2)),
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.accentCyan.withValues(alpha: 0.15),
                                  child: IconButton(
                                    icon: const Icon(LucideIcons.copy, color: AppColors.accentCyan, size: 18),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: inviteCode));
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied to clipboard!')));
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 12),
                    child: Text('MEMBERS LIST', style: TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final m = members[index];
                  final isAdmin = m['is_admin'] == true;
                  final isSelf = m['user_id'] == currentUserId;

                  return RepaintBoundary(
                    child: Container(
                      margin: EdgeInsets.only(bottom: index == members.length - 1 ? 0 : 10),
                      child: GlassCard(
                        margin: EdgeInsets.zero,
                        borderRadius: 16,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: (isAdmin ? AppColors.accentPurple : AppColors.accentCyan).withValues(alpha: 0.15),
                                child: Icon(isAdmin ? LucideIcons.shield : LucideIcons.user, color: isAdmin ? AppColors.accentPurple : AppColors.accentCyan, size: 18),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m['nickname'] ?? m['display_name'] ?? 'Member', 
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isAdmin ? 'Group Admin' : 'Collaborator', 
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (amIAdmin && !isSelf)
                                IconButton(
                                  icon: const Icon(LucideIcons.userMinus, color: AppColors.accentRose, size: 20),
                                  onPressed: () => _showRemoveMemberDialog(context, ref, widget.groupId!, m),
                                  tooltip: 'Remove Member',
                                )
                              else if (isSelf)
                                IconButton(
                                  icon: const Icon(LucideIcons.logOut, color: AppColors.accentRose, size: 20),
                                  onPressed: () => _showLeaveGroupDialog(context, ref, widget.groupId!, m),
                                  tooltip: 'Leave Group',
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.borderSubtle,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Active', 
                                    style: TextStyle(
                                      color: AppColors.textTertiary, 
                                      fontSize: 11, 
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: members.length,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (amIAdmin) ...[
                    const SizedBox(height: 32),
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 12),
                      child: Text('ADMIN CONTROLS', style: TextStyle(color: AppColors.accentRose, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    ),
                    GlassCard(
                      margin: EdgeInsets.zero,
                      borderRadius: 18,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.accentRose.withValues(alpha: 0.05), Colors.transparent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.shieldAlert, color: AppColors.accentRose, size: 20),
                                const SizedBox(width: 8),
                                const Text('Danger Zone', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text('As an admin, you can permanently delete this group and clear all related bills, chats, and settlements. This cannot be undone.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _showDeleteGroupDialog(context, ref, widget.groupId!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentRose.withValues(alpha: 0.15),
                                foregroundColor: AppColors.accentRose,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: AppColors.accentRose.withValues(alpha: 0.3)),
                              ),
                              icon: const Icon(LucideIcons.trash2, size: 16),
                              label: const Text('Delete Group Permanently', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupDialog(BuildContext context, WidgetRef ref, String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.accentRose, size: 22),
            SizedBox(width: 10),
            Text('Delete Group', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you absolutely sure you want to delete this group? This action is irreversible and will erase all expense records, chats, and balances permanently.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(groupServiceProvider).deleteGroup(groupId);
                ref.invalidate(groupsStreamProvider);
                ref.invalidate(expensesStreamProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group deleted successfully')),
                  );
                  context.go('/dashboard');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting group: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: AppColors.bgPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberDialog(BuildContext context, WidgetRef ref, String groupId, Map<String, dynamic> member) {
    final name = member['nickname'] ?? member['display_name'] ?? 'Member';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.userMinus, color: AppColors.accentRose, size: 22),
            SizedBox(width: 10),
            Text('Remove Member', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove $name from this group?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(groupServiceProvider).removeGroupMember(groupId, member['user_id']);
                ref.invalidate(groupMembersStreamProvider(groupId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$name removed successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error removing member: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: AppColors.bgPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showLeaveGroupDialog(BuildContext context, WidgetRef ref, String groupId, Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.logOut, color: AppColors.accentRose, size: 22),
            SizedBox(width: 10),
            Text('Leave Group', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to leave this group? You will no longer be able to view its expenses or balances.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(groupServiceProvider).removeGroupMember(groupId, member['user_id']);
                ref.invalidate(groupMembersStreamProvider(groupId));
                ref.invalidate(groupsStreamProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully left the group')),
                  );
                  context.go('/groups');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error leaving group: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: AppColors.bgPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Leave', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
  Widget _buildAnalyticsTab(List<Map<String, dynamic>> expenses, List<Map<String, dynamic>> members) {
    final Widget child;
    if (expenses.isEmpty) {
      child = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              minWidth: constraints.maxWidth,
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(LucideIcons.pieChart, color: AppColors.textTertiary, size: 40),
                  SizedBox(height: 16),
                  Text('Not enough data for analytics', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('Add some bills to generate spending graphs', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      );
    } else {

    // 1. Calculate stats
    double totalSpend = 0.0;
    Map<String, double> categorySpend = {};
    Map<String, double> individualPayments = {};

    for (var e in expenses) {
      final amt = e['amount'] is num ? (e['amount'] as num).toDouble() : 0.0;
      totalSpend += amt;
      
      final cat = e['category'] ?? 'Other';
      categorySpend[cat] = (categorySpend[cat] ?? 0) + amt;

      final paidBy = e['paid_by'];
      individualPayments[paidBy] = (individualPayments[paidBy] ?? 0) + amt;
    }

    // Sort categories
    final sortedCategories = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Sort spenders
    final sortedSpenders = individualPayments.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    child = ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Total Spend Hero
        GlassCard(
          margin: const EdgeInsets.only(bottom: 20),
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text('TOTAL GROUP SPEND', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Text('₹${totalSpend.toStringAsFixed(2)}', style: AppTheme.moneyStyle.copyWith(fontSize: 36, color: AppColors.accentCyan)),
                const SizedBox(height: 8),
                Text('Average bill size: ₹${(totalSpend / expenses.length).toStringAsFixed(1)}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),

        // Leaderboard Spenders
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 12),
          child: Text('CONTRIBUTION LEADERBOARD', style: TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        ),
        GlassCard(
          margin: const EdgeInsets.only(bottom: 24),
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: List.generate(sortedSpenders.length, (index) {
                final item = sortedSpenders[index];
                final spender = members.firstWhere((m) => m['user_id'] == item.key, orElse: () => {});
                final name = spender['nickname'] ?? spender['display_name'] ?? 'User';
                final amount = item.value;
                final percentage = totalSpend > 0 ? (amount / totalSpend) : 0.0;

                String medal = '🥉';
                if (index == 0) medal = '🥇';
                if (index == 1) medal = '🥈';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Text(medal, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage,
                                minHeight: 6,
                                backgroundColor: AppColors.border,
                                color: index == 0 ? AppColors.accentCyan : AppColors.accentPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text('₹${amount.toStringAsFixed(0)}', style: AppTheme.moneyStyle.copyWith(fontSize: 14, color: AppColors.textPrimary)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),

        // Category Breakdown
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 12),
          child: Text('SPENDING BY CATEGORY', style: TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        ),
        GlassCard(
          margin: EdgeInsets.zero,
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: List.generate(sortedCategories.length, (index) {
                final item = sortedCategories[index];
                final category = item.key;
                final amount = item.value;
                final percentage = totalSpend > 0 ? (amount / totalSpend) : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.borderSubtle, borderRadius: BorderRadius.circular(10)),
                        child: Icon(_getCategoryIcon(category), color: AppColors.accentPurple, size: 16),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(category.toUpperCase(), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                                Text('${(percentage * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage,
                                minHeight: 4,
                                backgroundColor: AppColors.border,
                                color: AppColors.accentPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text('₹${amount.toStringAsFixed(0)}', style: AppTheme.moneyStyle.copyWith(fontSize: 14)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
    }

    return RefreshIndicator(
      color: AppColors.accentCyan,
      backgroundColor: AppColors.bgElevated,
      onRefresh: _handleGroupRefresh,
      child: child,
    );
  }
}

// ─── Isolated Chat Tab ────────────────────────────────────────────────────────
// Uses ChatReconciliationEngine for stable client_id-based merge.
// Chat realtime updates ONLY rebuild this widget — never GroupDetailScreen.

class _IsolatedChatTab extends ConsumerStatefulWidget {
  final String groupId;
  final List<Map<String, dynamic>> members;
  final String currentUserId;
  final String inviteCode;
  final RefreshCallback onRefresh;

  const _IsolatedChatTab({
    required this.groupId,
    required this.members,
    required this.currentUserId,
    required this.inviteCode,
    required this.onRefresh,
  });

  @override
  ConsumerState<_IsolatedChatTab> createState() => _IsolatedChatTabState();
}

class _IsolatedChatTabState extends ConsumerState<_IsolatedChatTab> {
  final _chatController = TextEditingController();

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;
    _chatController.clear();
    final engine = ref.read(chatEngineProvider(widget.groupId));
    try {
      await ref.read(groupServiceProvider).sendChatMessage(
        groupId: widget.groupId,
        message: text,
        engine: engine,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: AppColors.accentRose),
        );
      }
    }
  }

  Future<void> _retryMessage(ChatMessage msg) async {
    final engine = ref.read(chatEngineProvider(widget.groupId));
    try {
      await ref.read(groupServiceProvider).retryChatMessage(
        groupId: widget.groupId,
        clientId: msg.clientId,
        message: msg.message,
        engine: engine,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // reconciledChatStreamProvider only rebuilds _IsolatedChatTab
    final engine = ref.watch(chatEngineProvider(widget.groupId));
    final rawAsync = ref.watch(groupChatStreamProvider(widget.groupId));
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // Feed raw realtime rows into the engine for merge (no-op if already merged)
    rawAsync.whenData((rows) => engine.mergeFromRealtime(rows));

    final messagesAsync = ref.watch(reconciledChatStreamProvider(widget.groupId));
    final allMessages = messagesAsync.when<List<ChatMessage>>(
      data: (msgs) => msgs,
      loading: () => [],
      error: (_, _) => [],
    );

    return Column(
      children: [
        if (widget.inviteCode.isNotEmpty && !isKeyboardOpen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: AppColors.accentPurple.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accentPurple.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.userPlus, color: AppColors.accentPurple, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Invite friends to join this group',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied!')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(widget.inviteCode,
                            style: const TextStyle(
                                color: AppColors.accentPurple, fontSize: 11,
                                fontWeight: FontWeight.w800, letterSpacing: 1)),
                        const SizedBox(width: 6),
                        const Icon(LucideIcons.copy, color: AppColors.accentPurple, size: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            color: AppColors.accentCyan,
            backgroundColor: AppColors.bgSecondary,
            child: allMessages.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                          minWidth: constraints.maxWidth,
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.messageSquare, color: AppColors.textTertiary, size: 40),
                              SizedBox(height: 16),
                              Text('Say hello to the group!',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                              SizedBox(height: 6),
                              Text('Messages sync in real time',
                                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    reverse: true,
                    itemCount: allMessages.length,
                    itemBuilder: (context, index) {
                      final msg = allMessages[index];
                      return RepaintBoundary(
                        child: _ChatMessageTile(
                          message: msg,
                          members: widget.members,
                          currentUserId: widget.currentUserId,
                          onRetry: msg.isFailed ? () => _retryMessage(msg) : null,
                        ),
                      );
                    },
                  ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, isKeyboardOpen ? 10 : 24),
          decoration: const BoxDecoration(
            color: AppColors.bgSecondary,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.bgTertiary,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accentCyan,
                child: IconButton(
                  icon: const Icon(LucideIcons.send, color: AppColors.bgPrimary, size: 18),
                  onPressed: () => _sendMessage(_chatController.text.trim()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Chat Message Tile ────────────────────────────────────────────────────────
// Accepts the typed ChatMessage model. Shows pending spinner and failed retry.

class _ChatMessageTile extends StatelessWidget {
  final ChatMessage message;
  final List<Map<String, dynamic>> members;
  final String currentUserId;
  final VoidCallback? onRetry;

  const _ChatMessageTile({
    required this.message,
    required this.members,
    required this.currentUserId,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final senderId = message.userId;
    final isMe = senderId == currentUserId;
    final isPending = message.isPending;
    final isFailed = message.isFailed;

    final sender = members.firstWhere(
      (m) => m['user_id'] == senderId,
      orElse: () => {},
    );
    final senderName = sender['nickname']?.toString() ??
        sender['display_name']?.toString() ??
        'User';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.accentPurple.withValues(alpha: 0.15),
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                style: const TextStyle(
                    color: AppColors.accentPurple, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(senderName,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                GestureDetector(
                  onTap: isFailed ? onRetry : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isFailed
                          ? AppColors.accentRose.withValues(alpha: 0.10)
                          : isMe
                              ? AppColors.accentCyan.withValues(alpha: isPending ? 0.08 : 0.15)
                              : AppColors.bgSecondary,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      border: Border.all(
                        color: isFailed
                            ? AppColors.accentRose.withValues(alpha: 0.3)
                            : isMe
                                ? AppColors.accentCyan.withValues(alpha: isPending ? 0.15 : 0.25)
                                : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            message.message,
                            style: TextStyle(
                              color: isFailed
                                  ? AppColors.accentRose
                                  : isPending
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isPending) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 10, height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.textTertiary),
                            ),
                          ),
                        ],
                        if (isFailed) ...[
                          const SizedBox(width: 8),
                          const Icon(LucideIcons.refreshCw, color: AppColors.accentRose, size: 12),
                        ],
                      ],
                    ),
                  ),
                ),
                if (isFailed)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, right: 4),
                    child: Text('Tap to retry',
                        style: TextStyle(color: AppColors.accentRose, fontSize: 10)),
                  ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.accentCyan.withValues(alpha: 0.15),
              child: const Text('U',
                  style: TextStyle(
                      color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }
}


