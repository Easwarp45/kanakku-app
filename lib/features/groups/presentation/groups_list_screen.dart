import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/group_service.dart';
import '../../../core/providers/auth_provider.dart';

class GroupsListScreen extends ConsumerStatefulWidget {
  const GroupsListScreen({super.key});

  @override
  ConsumerState<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends ConsumerState<GroupsListScreen> {
  bool _showSearch = false;

  void _showJoinGroupDialog() {
    final controller = TextEditingController();
    bool isJoining = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Enter Invite Code', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Join your team and start tracking shared expenses.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'CODE123',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.bgSecondary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(LucideIcons.ticket, color: AppColors.accentCyan, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
            ),
            ElevatedButton(
              onPressed: isJoining ? null : () async {
                final code = controller.text.trim();
                if (code.isEmpty) return;
                
                setDialogState(() => isJoining = true);
                try {
                  await ref.read(groupServiceProvider).joinGroup(code);
                  ref.invalidate(groupsStreamProvider);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Welcome to the group!')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.accentRose));
                  }
                } finally {
                  if (mounted) setDialogState(() => isJoining = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: AppColors.bgPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isJoining ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgPrimary)) : const Text('Join Group', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsStreamProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

    Future<void> handleRefresh() async {
      ref.invalidate(groupsStreamProvider);
      
      // Also invalidate nested card data for all loaded groups
      final groups = groupsAsync.value ?? [];
      for (final group in groups) {
        final groupId = group['id']?.toString();
        if (groupId != null) {
          ref.invalidate(groupExpensesStreamProvider(groupId));
          ref.invalidate(groupSettlementsStreamProvider(groupId));
          ref.invalidate(groupMembersStreamProvider(groupId));
        }
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentPurple,
          backgroundColor: AppColors.bgElevated,
          onRefresh: handleRefresh,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildSummaryCard(ref, groupsAsync, currentUserId)),
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildQuickActions(context)),
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildActiveSettlements()),
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Groups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const Icon(LucideIcons.slidersHorizontal, color: AppColors.textTertiary, size: 20),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 8)),
              groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                        child: Center(
                          child: Text(
                            "You aren't in any groups yet. Create one!",
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = groups[index];
                        return GroupCard(group: group, currentUserId: currentUserId);
                      },
                      childCount: groups.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: AppColors.accentPurple))),
                error: (err, stack) => SliverToBoxAdapter(child: Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.accentRose)))),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 32)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-group'),
        backgroundColor: AppColors.accentPurple,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: const Text('New Group', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('COLLABORATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentPurple, letterSpacing: 2)),
              SizedBox(height: 2),
              Text('Groups', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          IconButton(
            icon: Icon(_showSearch ? LucideIcons.x : LucideIcons.search, color: AppColors.textPrimary),
            onPressed: () => setState(() => _showSearch = !_showSearch),
          ),
        ],
      ),
    );
  }


  Widget _buildSummaryCard(WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> groupsAsync, String currentUserId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [AppColors.accentPurple, AppColors.accentCyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: AppColors.accentPurple.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.arrowUpRight, color: Colors.white.withValues(alpha: 0.8), size: 16),
                      const SizedBox(width: 6),
                      Text('Net Balance', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Active Tracking', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.users, color: Colors.white.withValues(alpha: 0.8), size: 16),
                      const SizedBox(width: 6),
                      Text('Groups', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  groupsAsync.when(
                    data: (g) => Text('${g.length}', style: AppTheme.moneyStyle.copyWith(color: Colors.white, fontSize: 24)),
                    loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    error: (_, __) => const Text('0', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: AppColors.accentEmerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.2))),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.checkCircle, color: AppColors.accentEmerald, size: 18),
                    SizedBox(width: 8),
                    Text('Settle Up', style: TextStyle(color: AppColors.accentEmerald, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: _showJoinGroupDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: AppColors.accentCyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.2))),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.users, color: AppColors.accentCyan, size: 18),
                    SizedBox(width: 8),
                    Text('Join Group', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSettlements() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(
        margin: EdgeInsets.zero,
        borderColor: AppColors.accentAmber.withValues(alpha: 0.3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.accentAmber.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(LucideIcons.clock, color: AppColors.accentAmber, size: 20),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Production Mode Active', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(height: 4),
                  Text('Real-time data synchronization enabled', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(LucideIcons.shieldCheck, color: AppColors.accentCyan, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: !_showSearch
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.search, color: AppColors.textTertiary, size: 18),
                  SizedBox(width: 12),
                  Expanded(child: Text('Search groups...', style: TextStyle(color: AppColors.textTertiary, fontSize: 14))),
                ],
              ),
            ),
    );
  }
}

class GroupCard extends ConsumerWidget {
  final Map<String, dynamic> group;
  final String currentUserId;

  const GroupCard({super.key, required this.group, required this.currentUserId});

  String _buildGroupMonogram(String name) {
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}';
    }
    return name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupId = group['id'];
    final name = group['name'] ?? 'Unknown Group';
    final desc = group['description'] ?? 'No description';
    
    final expensesAsync = ref.watch(groupExpensesStreamProvider(groupId));
    final settlementsAsync = ref.watch(groupSettlementsStreamProvider(groupId));
    final membersAsync = ref.watch(groupMembersStreamProvider(groupId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: GlassCard(
        margin: EdgeInsets.zero,
        borderRadius: 20,
        onTap: () => context.push('/group-detail', extra: groupId),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.accentCyan.withOpacity(0.2), AppColors.accentPurple.withOpacity(0.2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Text(
                        _buildGroupMonogram(name),
                        style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.2)),
                        const SizedBox(height: 3),
                        Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight, color: AppColors.textTertiary, size: 20),
                ],
              ),
              const SizedBox(height: 20),
              expensesAsync.when(
                data: (expenses) => membersAsync.when(
                  data: (members) => settlementsAsync.when(
                    data: (settlements) {
                      double myBalance = 0;
                      if (members.isNotEmpty) {
                        for (var e in expenses) {
                          final paidBy = e['paid_by'];
                          final amount = (e['amount'] as num).toDouble();
                          final share = amount / members.length;
                          if (paidBy == currentUserId) {
                            myBalance += (amount - share);
                          } else {
                            myBalance -= share;
                          }
                        }
                        for (var s in settlements) {
                          final amount = (s['amount'] as num).toDouble();
                          if (s['paid_by'] == currentUserId) {
                            myBalance += amount;
                          } else if (s['paid_to'] == currentUserId) {
                            myBalance -= amount;
                          }
                        }
                      }

                      final isOwed = myBalance >= 0;
                      final statusColor = isOwed ? AppColors.accentCyan : AppColors.accentRose;

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Overlapping Avatar Stack of members
                              if (members.isNotEmpty)
                                SizedBox(
                                  height: 28,
                                  width: 80,
                                  child: Stack(
                                    children: List.generate(
                                      members.length > 3 ? 3 : members.length,
                                      (idx) {
                                        final m = members[idx];
                                        final initial = (m['nickname'] ?? m['display_name'] ?? 'U').substring(0, 1).toUpperCase();
                                        return Positioned(
                                          left: idx * 16.0,
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.bgSecondary,
                                              border: Border.all(color: AppColors.bgPrimary, width: 1.5),
                                            ),
                                            child: Center(
                                              child: Text(
                                                initial,
                                                style: TextStyle(
                                                  color: idx == 0 ? AppColors.accentCyan : (idx == 1 ? AppColors.accentPurple : AppColors.accentEmerald),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                              // Small visual stats indicator
                              Row(
                                children: [
                                  Icon(LucideIcons.receipt, size: 12, color: AppColors.textTertiary),
                                  const SizedBox(width: 4),
                                  Text('${expenses.length} bills', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withOpacity(0.15)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isOwed ? 'YOU ARE OWED' : 'YOU OWE',
                                  style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w800, letterSpacing: 1),
                                ),
                                Text(
                                  '₹${myBalance.abs().toStringAsFixed(2)}',
                                  style: AppTheme.moneyStyle.copyWith(fontSize: 15, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(color: AppColors.accentPurple))),
                    error: (_, __) => const Text('Error loading balances', style: TextStyle(color: AppColors.accentRose, fontSize: 12)),
                  ),
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(color: AppColors.accentPurple))),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(color: AppColors.accentPurple))),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

