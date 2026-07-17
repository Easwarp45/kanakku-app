class NotificationSettingsState {
  final bool morningBriefEnabled;
  final String morningBriefTime; // e.g. '08:00'
  final bool eveningSummaryEnabled;
  final String eveningSummaryTime; // e.g. '20:30'
  final bool budgetAlertsEnabled;
  final bool goalAlertsEnabled;
  final bool groupAlertsEnabled;
  final bool settlementAlertsEnabled;
  final bool monthlyReportEnabled;
  final bool weeklyReportEnabled;
  final bool offlineSyncAlertsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool doNotDisturb;

  NotificationSettingsState({
    this.morningBriefEnabled = true,
    this.morningBriefTime = '08:00',
    this.eveningSummaryEnabled = true,
    this.eveningSummaryTime = '20:30',
    this.budgetAlertsEnabled = true,
    this.goalAlertsEnabled = true,
    this.groupAlertsEnabled = true,
    this.settlementAlertsEnabled = true,
    this.monthlyReportEnabled = true,
    this.weeklyReportEnabled = true,
    this.offlineSyncAlertsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.doNotDisturb = false,
  });

  NotificationSettingsState copyWith({
    bool? morningBriefEnabled,
    String? morningBriefTime,
    bool? eveningSummaryEnabled,
    String? eveningSummaryTime,
    bool? budgetAlertsEnabled,
    bool? goalAlertsEnabled,
    bool? groupAlertsEnabled,
    bool? settlementAlertsEnabled,
    bool? monthlyReportEnabled,
    bool? weeklyReportEnabled,
    bool? offlineSyncAlertsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? doNotDisturb,
  }) {
    return NotificationSettingsState(
      morningBriefEnabled: morningBriefEnabled ?? this.morningBriefEnabled,
      morningBriefTime: morningBriefTime ?? this.morningBriefTime,
      eveningSummaryEnabled: eveningSummaryEnabled ?? this.eveningSummaryEnabled,
      eveningSummaryTime: eveningSummaryTime ?? this.eveningSummaryTime,
      budgetAlertsEnabled: budgetAlertsEnabled ?? this.budgetAlertsEnabled,
      goalAlertsEnabled: goalAlertsEnabled ?? this.goalAlertsEnabled,
      groupAlertsEnabled: groupAlertsEnabled ?? this.groupAlertsEnabled,
      settlementAlertsEnabled: settlementAlertsEnabled ?? this.settlementAlertsEnabled,
      monthlyReportEnabled: monthlyReportEnabled ?? this.monthlyReportEnabled,
      weeklyReportEnabled: weeklyReportEnabled ?? this.weeklyReportEnabled,
      offlineSyncAlertsEnabled: offlineSyncAlertsEnabled ?? this.offlineSyncAlertsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      doNotDisturb: doNotDisturb ?? this.doNotDisturb,
    );
  }
}
