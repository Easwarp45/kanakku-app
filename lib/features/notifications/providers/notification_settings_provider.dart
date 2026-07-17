import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_cache_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/notification_settings.dart';

class NotificationSettingsNotifier extends Notifier<NotificationSettingsState> {
  @override
  NotificationSettingsState build() {
    ref.listen(currentUserProvider, (previous, next) {
      state = _getLoadedState();
    });
    return _getLoadedState();
  }

  String get _userPrefix {
    final user = ref.read(currentUserProvider);
    return user != null ? 'notif_pref_${user.id}_' : 'notif_pref_guest_';
  }

  NotificationSettingsState _getLoadedState() {
    final prefix = _userPrefix;
    return NotificationSettingsState(
      morningBriefEnabled: LocalCacheService.getCachedData('${prefix}morningBriefEnabled') ?? true,
      morningBriefTime: LocalCacheService.getCachedData('${prefix}morningBriefTime') ?? '08:00',
      eveningSummaryEnabled: LocalCacheService.getCachedData('${prefix}eveningSummaryEnabled') ?? true,
      eveningSummaryTime: LocalCacheService.getCachedData('${prefix}eveningSummaryTime') ?? '20:30',
      budgetAlertsEnabled: LocalCacheService.getCachedData('${prefix}budgetAlertsEnabled') ?? true,
      goalAlertsEnabled: LocalCacheService.getCachedData('${prefix}goalAlertsEnabled') ?? true,
      groupAlertsEnabled: LocalCacheService.getCachedData('${prefix}groupAlertsEnabled') ?? true,
      settlementAlertsEnabled: LocalCacheService.getCachedData('${prefix}settlementAlertsEnabled') ?? true,
      monthlyReportEnabled: LocalCacheService.getCachedData('${prefix}monthlyReportEnabled') ?? true,
      weeklyReportEnabled: LocalCacheService.getCachedData('${prefix}weeklyReportEnabled') ?? true,
      offlineSyncAlertsEnabled: LocalCacheService.getCachedData('${prefix}offlineSyncAlertsEnabled') ?? true,
      soundEnabled: LocalCacheService.getCachedData('${prefix}soundEnabled') ?? true,
      vibrationEnabled: LocalCacheService.getCachedData('${prefix}vibrationEnabled') ?? true,
      doNotDisturb: LocalCacheService.getCachedData('${prefix}doNotDisturb') ?? false,
    );
  }

  Future<void> updateMorningBriefEnabled(bool value) async {
    state = state.copyWith(morningBriefEnabled: value);
    await LocalCacheService.cacheData('${_userPrefix}morningBriefEnabled', value);
  }

  Future<void> updateMorningBriefTime(String value) async {
    state = state.copyWith(morningBriefTime: value);
    await LocalCacheService.cacheData('${_userPrefix}morningBriefTime', value);
  }

  Future<void> updateEveningSummaryEnabled(bool value) async {
    state = state.copyWith(eveningSummaryEnabled: value);
    await LocalCacheService.cacheData('${_userPrefix}eveningSummaryEnabled', value);
  }

  Future<void> updateEveningSummaryTime(String value) async {
    state = state.copyWith(eveningSummaryTime: value);
    await LocalCacheService.cacheData('${_userPrefix}eveningSummaryTime', value);
  }

  Future<void> updateBudgetAlertsEnabled(bool value) async {
    state = state.copyWith(budgetAlertsEnabled: value);
    await LocalCacheService.cacheData('${_userPrefix}budgetAlertsEnabled', value);
  }

  Future<void> updateGoalAlertsEnabled(bool value) async {
    state = state.copyWith(goalAlertsEnabled: value);
    await LocalCacheService.cacheData('${_userPrefix}goalAlertsEnabled', value);
  }

  Future<void> updateGroupAlertsEnabled(bool value) async {
    state = state.copyWith(groupAlertsEnabled: value);
    await LocalCacheService.cacheData('${_userPrefix}groupAlertsEnabled', value);
  }

  Future<void> updateSettlementAlertsEnabled(bool value) async {
    state = state.copyWith(settlementAlertsEnabled: value);
    await LocalCacheService.cacheData('${_userPrefix}settlementAlertsEnabled', value);
  }

  Future<void> updateMonthlyReportEnabled(bool value) async {
    state = state.copyWith(monthlyReportEnabled: value);
    await LocalCacheService.cacheData('${_userPrefix}monthlyReportEnabled', value);
  }

  Future<void> updateWeeklyReportEnabled(bool value) async {
    state = state.copyWith(weeklyReportEnabled: value);
    await LocalCacheService.cacheData('${_userPrefix}weeklyReportEnabled', value);
  }

  Future<void> updateOfflineSyncAlertsEnabled(bool value) async {
    state = state.copyWith(offlineSyncAlertsEnabled: value);
    await LocalCacheService.cacheData('${_userPrefix}offlineSyncAlertsEnabled', value);
  }

  Future<void> updateSoundEnabled(bool value) async {
    state = state.copyWith(soundEnabled: value);
    await LocalCacheService.cacheData('${_userPrefix}soundEnabled', value);
  }

  Future<void> updateVibrationEnabled(bool value) async {
    state = state.copyWith(vibrationEnabled: value);
    await LocalCacheService.cacheData('${_userPrefix}vibrationEnabled', value);
  }

  Future<void> updateDoNotDisturb(bool value) async {
    state = state.copyWith(doNotDisturb: value);
    await LocalCacheService.cacheData('${_userPrefix}doNotDisturb', value);
  }
}

final notificationSettingsProvider = NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(() {
  return NotificationSettingsNotifier();
});
