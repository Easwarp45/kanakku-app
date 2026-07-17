import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/providers/auth_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../services/notification_scheduler.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final user = ref.watch(currentUserProvider);

    // Helper to re-trigger schedules on changes
    Future<void> syncSchedules() async {
      if (user == null) return;
      final scheduler = NotificationScheduler();
      if (settings.morningBriefEnabled) {
        await scheduler.scheduleMorningBrief(
          userId: user.id,
          time: settings.morningBriefTime,
          sound: settings.soundEnabled,
          vibrate: settings.vibrationEnabled,
          dnd: settings.doNotDisturb,
        );
      } else {
        // Scheduler will automatically clean up when scheduled with cancel or similar
      }

      if (settings.eveningSummaryEnabled) {
        await scheduler.scheduleEveningSummary(
          userId: user.id,
          time: settings.eveningSummaryTime,
          sound: settings.soundEnabled,
          vibrate: settings.vibrationEnabled,
          dnd: settings.doNotDisturb,
        );
      }

      if (settings.weeklyReportEnabled) {
        await scheduler.scheduleWeeklyReport(
          userId: user.id,
          sound: settings.soundEnabled,
          vibrate: settings.vibrationEnabled,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NOTIFICATION SETTINGS',
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
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Daily Digests
            _buildSectionHeader('DAILY DIGESTS'),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Morning Financial Brief', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Summary of balance, budget, and targets at start of day', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    value: settings.morningBriefEnabled,
                    activeColor: AppColors.accentPurple,
                    onChanged: (val) async {
                      await ref.read(notificationSettingsProvider.notifier).updateMorningBriefEnabled(val);
                      await syncSchedules();
                    },
                  ),
                  if (settings.morningBriefEnabled) ...[
                    Divider(color: AppColors.borderSubtle),
                    ListTile(
                      title: const Text('Brief Delivery Time', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(settings.morningBriefTime, style: const TextStyle(color: AppColors.accentPurple, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Icon(LucideIcons.calendar, size: 16, color: AppColors.textTertiary),
                        ],
                      ),
                      onTap: () async {
                        final parts = settings.morningBriefTime.split(':');
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.tryParse(parts[0]) ?? 8,
                            minute: int.tryParse(parts[1]) ?? 0,
                          ),
                        );
                        if (time != null) {
                          final formatted = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                          await ref.read(notificationSettingsProvider.notifier).updateMorningBriefTime(formatted);
                          await syncSchedules();
                        }
                      },
                    ),
                  ],
                  Divider(color: AppColors.borderSubtle),
                  SwitchListTile(
                    title: const Text('Evening Financial Summary', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Analysis of today\'s spending, earnings, and trends', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    value: settings.eveningSummaryEnabled,
                    activeColor: AppColors.accentPurple,
                    onChanged: (val) async {
                      await ref.read(notificationSettingsProvider.notifier).updateEveningSummaryEnabled(val);
                      await syncSchedules();
                    },
                  ),
                  if (settings.eveningSummaryEnabled) ...[
                    Divider(color: AppColors.borderSubtle),
                    ListTile(
                      title: const Text('Summary Delivery Time', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(settings.eveningSummaryTime, style: const TextStyle(color: AppColors.accentPurple, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Icon(LucideIcons.calendar, size: 16, color: AppColors.textTertiary),
                        ],
                      ),
                      onTap: () async {
                        final parts = settings.eveningSummaryTime.split(':');
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.tryParse(parts[0]) ?? 20,
                            minute: int.tryParse(parts[1]) ?? 30,
                          ),
                        );
                        if (time != null) {
                          final formatted = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                          await ref.read(notificationSettingsProvider.notifier).updateEveningSummaryTime(formatted);
                          await syncSchedules();
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Alerts
            _buildSectionHeader('FINANCIAL ALERTS'),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Budget Limits', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Notify when category spending reaches 80%, 90%, 100%', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    value: settings.budgetAlertsEnabled,
                    activeColor: AppColors.accentPurple,
                    onChanged: (val) => ref.read(notificationSettingsProvider.notifier).updateBudgetAlertsEnabled(val),
                  ),
                  Divider(color: AppColors.borderSubtle),
                  SwitchListTile(
                    title: const Text('Goal Progress', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Milestones, deadlines, and contribution reminders', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    value: settings.goalAlertsEnabled,
                    activeColor: AppColors.accentPurple,
                    onChanged: (val) => ref.read(notificationSettingsProvider.notifier).updateGoalAlertsEnabled(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Groups
            _buildSectionHeader('SOCIAL & GROUPS'),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Group Activity', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('New group expenses, chat updates, and members joined', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    value: settings.groupAlertsEnabled,
                    activeColor: AppColors.accentPurple,
                    onChanged: (val) => ref.read(notificationSettingsProvider.notifier).updateGroupAlertsEnabled(val),
                  ),
                  Divider(color: AppColors.borderSubtle),
                  SwitchListTile(
                    title: const Text('Settlement Notifications', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Notify when group payments are recorded or received', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    value: settings.settlementAlertsEnabled,
                    activeColor: AppColors.accentPurple,
                    onChanged: (val) => ref.read(notificationSettingsProvider.notifier).updateSettlementAlertsEnabled(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Reports
            _buildSectionHeader('PERIODIC REPORTS'),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Weekly Summaries', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Weekly performance analysis delivered on Sundays', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    value: settings.weeklyReportEnabled,
                    activeColor: AppColors.accentPurple,
                    onChanged: (val) async {
                      await ref.read(notificationSettingsProvider.notifier).updateWeeklyReportEnabled(val);
                      await syncSchedules();
                    },
                  ),
                  Divider(color: AppColors.borderSubtle),
                  SwitchListTile(
                    title: const Text('Monthly Wrap Up', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Complete budget, savings, and trends analysis at month end', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    value: settings.monthlyReportEnabled,
                    activeColor: AppColors.accentPurple,
                    onChanged: (val) => ref.read(notificationSettingsProvider.notifier).updateMonthlyReportEnabled(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // System
            _buildSectionHeader('SYSTEM & UTILITIES'),
            GlassCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Offline Ledger Sync', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Banners on sync started, completed, or failed offline queues', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    value: settings.offlineSyncAlertsEnabled,
                    activeColor: AppColors.accentPurple,
                    onChanged: (val) => ref.read(notificationSettingsProvider.notifier).updateOfflineSyncAlertsEnabled(val),
                  ),
                  Divider(color: AppColors.borderSubtle),
                  SwitchListTile(
                    title: const Text('Notification Sound', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                    value: settings.soundEnabled,
                    activeColor: AppColors.accentPurple,
                    onChanged: (val) => ref.read(notificationSettingsProvider.notifier).updateSoundEnabled(val),
                  ),
                  Divider(color: AppColors.borderSubtle),
                  SwitchListTile(
                    title: const Text('Notification Vibration', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                    value: settings.vibrationEnabled,
                    activeColor: AppColors.accentPurple,
                    onChanged: (val) => ref.read(notificationSettingsProvider.notifier).updateVibrationEnabled(val),
                  ),
                  Divider(color: AppColors.borderSubtle),
                  SwitchListTile(
                    title: const Text('Do Not Disturb', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Silence all incoming local notifications and briefs', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    value: settings.doNotDisturb,
                    activeColor: AppColors.accentRose,
                    onChanged: (val) => ref.read(notificationSettingsProvider.notifier).updateDoNotDisturb(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
