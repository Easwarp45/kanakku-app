import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/supabase_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/database/local_cache_service.dart';
import '../models/notification_model.dart';
import '../repository/notification_repository.dart';
import '../services/notification_service.dart';
import 'notification_settings_provider.dart';
import '../services/notification_scheduler.dart';

/// Provider for the notification repository.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NotificationRepository(client);
});

/// StreamProvider providing real-time notification data with offline cache fallbacks.
final notificationsStreamProvider = StreamProvider<List<AppNotification>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final controller = StreamController<List<AppNotification>>();

  // Load from local Hive cache first to ensure immediate display
  final cached = LocalCacheService.getCachedData('notifications_${user.id}');
  if (cached != null) {
    try {
      final list = (cached as List)
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      controller.add(list);
    } catch (_) {}
  }

  // Subscribe to real-time changes
  final subscription = client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .listen((data) {
        final list = data.map((e) => AppNotification.fromJson(e)).toList();
        
        // Cache data locally
        final jsonList = list.map((e) => e.toJson()).toList();
        LocalCacheService.cacheData('notifications_${user.id}', jsonList);

        // Check if there are newly received, unread notifications to dispatch to the OS tray
        final settings = ref.read(notificationSettingsProvider);
        if (!settings.doNotDisturb) {
          for (final notif in list) {
            final ageInSeconds = DateTime.now().difference(notif.createdAt).inSeconds;
            // If the notification is unread and created within the last 15 seconds, show banner
            if (!notif.isRead && ageInSeconds.abs() < 15) {
              // Apply toggle check
              bool enabled = true;
              switch (notif.type) {
                case 'morning_brief':
                  enabled = settings.morningBriefEnabled;
                  break;
                case 'evening_summary':
                  enabled = settings.eveningSummaryEnabled;
                  break;
                case 'budget_alert':
                  enabled = settings.budgetAlertsEnabled;
                  break;
                case 'goal_alert':
                  enabled = settings.goalAlertsEnabled;
                  break;
                case 'group_alert':
                  enabled = settings.groupAlertsEnabled;
                  break;
                case 'settlement_alert':
                  enabled = settings.settlementAlertsEnabled;
                  break;
                case 'offline_sync':
                  enabled = settings.offlineSyncAlertsEnabled;
                  break;
                case 'weekly_summary':
                  enabled = settings.weeklyReportEnabled;
                  break;
                case 'monthly_report':
                  enabled = settings.monthlyReportEnabled;
                  break;
              }

              if (enabled) {
                NotificationService().showNotification(
                  id: notif.id.hashCode,
                  title: notif.title,
                  body: notif.body,
                  type: notif.type,
                  sound: settings.soundEnabled,
                  vibrate: settings.vibrationEnabled,
                  dnd: settings.doNotDisturb,
                );
              }
            }
          }
        }

        if (!controller.isClosed) {
          controller.add(list);
        }
      }, onError: (err) async {
        debugPrint('[NOTIFICATIONS STREAM ERROR] $err');
        try {
          final repo = ref.read(notificationRepositoryProvider);
          final raw = await repo.getNotifications(userId: user.id);
          final list = raw.map((e) => AppNotification.fromJson(e)).toList();
          if (!controller.isClosed) {
            controller.add(list);
          }
        } catch (fetchErr) {
          if (!controller.isClosed) {
            controller.addError(err);
          }
        }
      });

  controller.onCancel = () {
    subscription.cancel();
    controller.close();
  };

  return controller.stream;
});

/// Computes the count of unread notifications reactively.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifsAsync = ref.watch(notificationsStreamProvider);
  return notifsAsync.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

/// Warm-up provider to orchestrate background notification scheduling based on settings.
final notificationScheduleOrchestratorProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final settings = ref.watch(notificationSettingsProvider);

  if (user == null) {
    NotificationScheduler().cancelAll();
    return;
  }

  // Schedule Morning Brief
  if (settings.morningBriefEnabled) {
    NotificationScheduler().scheduleMorningBrief(
      userId: user.id,
      time: settings.morningBriefTime,
      sound: settings.soundEnabled,
      vibrate: settings.vibrationEnabled,
      dnd: settings.doNotDisturb,
    );
  } else {
    // Delivery turned off
  }

  // Schedule Evening Summary
  if (settings.eveningSummaryEnabled) {
    NotificationScheduler().scheduleEveningSummary(
      userId: user.id,
      time: settings.eveningSummaryTime,
      sound: settings.soundEnabled,
      vibrate: settings.vibrationEnabled,
      dnd: settings.doNotDisturb,
    );
  }

  // Schedule Weekly Report
  if (settings.weeklyReportEnabled) {
    NotificationScheduler().scheduleWeeklyReport(
      userId: user.id,
      sound: settings.soundEnabled,
      vibrate: settings.vibrationEnabled,
    );
  }
});
