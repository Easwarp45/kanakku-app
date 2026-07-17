import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../../core/database/local_cache_service.dart';

/// Service to schedule repeating time-zone aware briefs and reports.
class NotificationScheduler {
  static final NotificationScheduler _instance = NotificationScheduler._internal();
  factory NotificationScheduler() => _instance;
  NotificationScheduler._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initialize time zones and configure Android/iOS background settings.
  Future<void> initialize() async {
    tz.initializeTimeZones();
  }

  /// Schedule the Morning Brief repeating daily at [time] (HH:MM format).
  Future<void> scheduleMorningBrief({
    required String userId,
    required String time,
    bool sound = true,
    bool vibrate = true,
    bool dnd = false,
  }) async {
    await _localNotifications.cancel(1001); // Cancel existing first to avoid duplication
    
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;

    final scheduleTime = _nextInstanceOfTime(hour, minute);
    final text = _generateMorningBriefText(userId);

    await _localNotifications.zonedSchedule(
      1001,
      'Morning Financial Brief ☀️',
      text,
      scheduleTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'kanakku_morning_brief',
          'Morning Brief',
          channelDescription: 'Daily morning financial briefing',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: sound,
          enableVibration: vibrate,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: sound,
          presentAlert: true,
          presentBadge: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedule the Evening Summary repeating daily at [time] (HH:MM format).
  Future<void> scheduleEveningSummary({
    required String userId,
    required String time,
    bool sound = true,
    bool vibrate = true,
    bool dnd = false,
  }) async {
    await _localNotifications.cancel(1002);
    
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 20;
    final minute = int.tryParse(parts[1]) ?? 30;

    final scheduleTime = _nextInstanceOfTime(hour, minute);
    final text = _generateEveningSummaryText(userId);

    await _localNotifications.zonedSchedule(
      1002,
      'Evening Summary 🌙',
      text,
      scheduleTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'kanakku_evening_summary',
          'Evening Summary',
          channelDescription: 'Daily evening financial digest',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: sound,
          enableVibration: vibrate,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: sound,
          presentAlert: true,
          presentBadge: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedule the Weekly Report repeating every Sunday at 6:00 PM.
  Future<void> scheduleWeeklyReport({
    required String userId,
    bool sound = true,
    bool vibrate = true,
  }) async {
    await _localNotifications.cancel(1003);
    final scheduleTime = _nextInstanceOfDayAndTime(DateTime.sunday, 18, 0);
    final text = _generateWeeklySummaryText(userId);

    await _localNotifications.zonedSchedule(
      1003,
      'Weekly Financial Report 📊',
      text,
      scheduleTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'kanakku_weekly_report',
          'Weekly Report',
          channelDescription: 'Weekly financial performance summary',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: sound,
          enableVibration: vibrate,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: sound,
          presentAlert: true,
          presentBadge: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Cancels all scheduled background updates.
  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int dayOfWeek, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  String _generateMorningBriefText(String userId) {
    final expenses = LocalCacheService.getCachedList('cached_expenses_$userId');
    final incomes = LocalCacheService.getCachedList('cached_income_$userId');
    final budgets = LocalCacheService.getCachedList('cached_budgets_$userId');

    double totalIncome = incomes.fold(0.0, (sum, i) => sum + (double.tryParse(i['amount']?.toString() ?? '0') ?? 0.0));
    double totalExpense = expenses.fold(0.0, (sum, e) => sum + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0));
    double balance = totalIncome - totalExpense;

    final now = DateTime.now();
    double monthlySpent = expenses.where((e) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.year == now.year && d.month == now.month;
    }).fold(0.0, (sum, e) => sum + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0));

    double totalBudget = budgets.fold(0.0, (sum, b) => sum + (double.tryParse(b['amount']?.toString() ?? '0') ?? 0.0));
    double remainingBudget = totalBudget > 0 ? (totalBudget - monthlySpent).clamp(0, double.infinity) : 0.0;

    String brief = 'Good Morning! Current Balance: ₹${balance.toStringAsFixed(0)}.';
    if (totalBudget > 0) {
      brief += ' Monthly Budget remaining: ₹${remainingBudget.toStringAsFixed(0)}.';
    }
    brief += ' Have a disciplined financial day!';
    return brief;
  }

  String _generateEveningSummaryText(String userId) {
    final expenses = LocalCacheService.getCachedList('cached_expenses_$userId');
    final now = DateTime.now();

    final todayExpenses = expenses.where((e) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();

    double spentToday = todayExpenses.fold(0.0, (sum, e) => sum + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0));

    if (spentToday == 0) {
      return "Good evening! You spent ₹0 today. Excellent discipline in saving!";
    }

    double biggestAmt = 0.0;
    String biggestCategory = 'Others';
    for (final e in todayExpenses) {
      final amt = double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0;
      if (amt > biggestAmt) {
        biggestAmt = amt;
        biggestCategory = e['category']?.toString() ?? 'Others';
      }
    }

    return 'Spent ₹${spentToday.toStringAsFixed(0)} today across ${todayExpenses.length} transactions. Biggest transaction was ₹${biggestAmt.toStringAsFixed(0)} on $biggestCategory.';
  }

  String _generateWeeklySummaryText(String userId) {
    final expenses = LocalCacheService.getCachedList('cached_expenses_$userId');
    final incomes = LocalCacheService.getCachedList('cached_income_$userId');

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    double weeklySpent = expenses.where((e) {
      final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.isAfter(sevenDaysAgo);
    }).fold(0.0, (sum, e) => sum + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0));

    double weeklyEarned = incomes.where((i) {
      final dateStr = i['income_date']?.toString() ?? i['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.isAfter(sevenDaysAgo);
    }).fold(0.0, (sum, i) => sum + (double.tryParse(i['amount']?.toString() ?? '0') ?? 0.0));

    return 'Weekly Review: Earned ₹${weeklyEarned.toStringAsFixed(0)}, spent ₹${weeklySpent.toStringAsFixed(0)}. Keep tracking to reach your targets!';
  }
}
