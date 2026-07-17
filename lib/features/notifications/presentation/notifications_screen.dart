import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'All';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.accentPurple,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          notificationsAsync.maybeWhen(
            data: (list) {
              final unread = list.where((n) => !n.isRead).toList();
              if (unread.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(LucideIcons.checkSquare, color: AppColors.textSecondary),
                tooltip: 'Mark all read',
                onPressed: () async {
                  final repo = ref.read(notificationRepositoryProvider);
                  for (final n in unread) {
                    await repo.markAsRead(n.id);
                  }
                  ref.invalidate(notificationsStreamProvider);
                },
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: Icon(LucideIcons.settings, color: AppColors.textPrimary),
            onPressed: () => context.push('/notification-settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Search notifications...',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    prefixIcon: Icon(LucideIcons.search, color: AppColors.textTertiary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            
            // Filter categories
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['All', 'Briefs', 'Alerts', 'Groups', 'Offline Sync'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedFilter = filter);
                        }
                      },
                      selectedColor: AppColors.accentPurple.withValues(alpha: 0.2),
                      backgroundColor: AppColors.bgSecondary,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.accentPurple : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? AppColors.accentPurple : AppColors.border,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Notification list
            Expanded(
              child: notificationsAsync.when(
                data: (list) {
                  var filteredList = list.where((n) {
                    if (_selectedFilter == 'Briefs') {
                      return n.type == 'morning_brief' ||
                          n.type == 'evening_summary' ||
                          n.type == 'weekly_summary' ||
                          n.type == 'monthly_report';
                    }
                    if (_selectedFilter == 'Alerts') {
                      return n.type == 'budget_alert' || n.type == 'goal_alert';
                    }
                    if (_selectedFilter == 'Groups') {
                      return n.type == 'group_alert' || n.type == 'settlement_alert';
                    }
                    if (_selectedFilter == 'Offline Sync') {
                      return n.type == 'offline_sync';
                    }
                    return true;
                  }).toList();

                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    filteredList = filteredList.where((n) {
                      return n.title.toLowerCase().contains(q) ||
                          n.body.toLowerCase().contains(q);
                    }).toList();
                  }

                  if (filteredList.isEmpty) {
                    return _buildEmptyState();
                  }

                  final grouped = _groupNotifications(filteredList);

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(notificationsStreamProvider);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final group = grouped[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                group.title,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textTertiary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            ...group.items.map((notif) => _buildNotificationCard(notif)),
                          ],
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accentPurple),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'Error: $err',
                    style: const TextStyle(color: AppColors.accentRose),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.bgSecondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.bellOff,
              size: 48,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No notifications to show here.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notif) {
    Color iconBg = AppColors.bgSecondary;
    Color iconColor = AppColors.textSecondary;
    IconData icon = LucideIcons.bell;

    switch (notif.type) {
      case 'morning_brief':
        iconBg = Colors.amber.withValues(alpha: 0.15);
        iconColor = Colors.amber;
        icon = LucideIcons.sparkles;
        break;
      case 'evening_summary':
        iconBg = AppColors.accentPurple.withValues(alpha: 0.15);
        iconColor = AppColors.accentPurple;
        icon = LucideIcons.piggyBank;
        break;
      case 'budget_alert':
        iconBg = AppColors.accentRose.withValues(alpha: 0.15);
        iconColor = AppColors.accentRose;
        icon = LucideIcons.alertTriangle;
        break;
      case 'goal_alert':
        iconBg = AppColors.accentEmerald.withValues(alpha: 0.15);
        iconColor = AppColors.accentEmerald;
        icon = LucideIcons.target;
        break;
      case 'group_alert':
        iconBg = AppColors.accentCyan.withValues(alpha: 0.15);
        iconColor = AppColors.accentCyan;
        icon = LucideIcons.users;
        break;
      case 'settlement_alert':
        iconBg = AppColors.accentEmerald.withValues(alpha: 0.15);
        iconColor = AppColors.accentEmerald;
        icon = LucideIcons.checkCircle;
        break;
      case 'offline_sync':
        iconBg = AppColors.textSecondary.withValues(alpha: 0.15);
        iconColor = AppColors.textPrimary;
        icon = LucideIcons.refreshCw;
        break;
      case 'weekly_summary':
      case 'monthly_report':
        iconBg = AppColors.accentPurple.withValues(alpha: 0.15);
        iconColor = AppColors.accentPurple;
        icon = LucideIcons.pieChart;
        break;
    }

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.accentRose.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash2, color: AppColors.accentRose),
      ),
      onDismissed: (_) async {
        await ref.read(notificationRepositoryProvider).deleteNotification(notif.id);
        ref.invalidate(notificationsStreamProvider);
      },
      child: GestureDetector(
        onTap: () async {
          if (!notif.isRead) {
            await ref.read(notificationRepositoryProvider).markAsRead(notif.id);
            ref.invalidate(notificationsStreamProvider);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                                color: notif.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (!notif.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.accentPurple,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.body,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: notif.isRead ? FontWeight.w400 : FontWeight.w500,
                          color: notif.isRead ? AppColors.textTertiary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('hh:mm a').format(notif.createdAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_NotificationGroup> _groupNotifications(List<AppNotification> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    final List<AppNotification> todayItems = [];
    final List<AppNotification> yesterdayItems = [];
    final List<AppNotification> lastWeekItems = [];
    final List<AppNotification> olderItems = [];

    for (final n in list) {
      final createdDate = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      if (createdDate == today) {
        todayItems.add(n);
      } else if (createdDate == yesterday) {
        yesterdayItems.add(n);
      } else if (createdDate.isAfter(lastWeek)) {
        lastWeekItems.add(n);
      } else {
        olderItems.add(n);
      }
    }

    final List<_NotificationGroup> groups = [];
    if (todayItems.isNotEmpty) {
      groups.add(_NotificationGroup('TODAY', todayItems));
    }
    if (yesterdayItems.isNotEmpty) {
      groups.add(_NotificationGroup('YESTERDAY', yesterdayItems));
    }
    if (lastWeekItems.isNotEmpty) {
      groups.add(_NotificationGroup('THIS WEEK', lastWeekItems));
    }
    if (olderItems.isNotEmpty) {
      groups.add(_NotificationGroup('OLDER', olderItems));
    }
    return groups;
  }
}

class _NotificationGroup {
  final String title;
  final List<AppNotification> items;
  _NotificationGroup(this.title, this.items);
}
