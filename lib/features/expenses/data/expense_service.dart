import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/supabase_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/database/local_cache_service.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/multi_currency_helper.dart';
import '../../../core/database/schema_constants.dart';

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  // Warm up RealtimeSyncManager
  ref.read(realtimeSyncManagerProvider);
  return ExpenseService(client, user?.id);
});

final expensesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(expenseServiceProvider);
  return service.getExpensesStream();
});

final monthlyExpensesProvider = Provider<double>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  final now = DateTime.now();
  final rawAmount = expensesAsync.maybeWhen(
    data: (expenses) {
      return expenses
          .where((e) {
            final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
            final date = DateTime.tryParse(dateStr);
            return date != null && 
                   date.year == now.year && 
                   date.month == now.month;
          })
          .fold<double>(0.0, (sum, e) => sum + _parseAmount(e['amount']));
    },
    orElse: () => 0.0,
  );
  final pref = ref.watch(preferencesProvider);
  final code = supportedCurrencies[pref.currencyIndex].code;
  final rate = pref.rates[code] ?? 1.0;
  return rawAmount * rate;
});

final totalExpensesProvider = Provider<double>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  final rawAmount = expensesAsync.maybeWhen(
    data: (expenses) {
      return expenses.fold<double>(0.0, (sum, e) => sum + _parseAmount(e['amount']));
    },
    orElse: () => 0.0,
  );
  final pref = ref.watch(preferencesProvider);
  final code = supportedCurrencies[pref.currencyIndex].code;
  final rate = pref.rates[code] ?? 1.0;
  return rawAmount * rate;
});

double _parseAmount(dynamic amount) {
  if (amount is num) return amount.toDouble();
  return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
}

class ExpenseService {
  final SupabaseClient _client;
  final String? _userId;

  ExpenseService(this._client, this._userId);

  Stream<List<Map<String, dynamic>>> getExpensesStream() {
    if (_userId == null) return Stream.value([]);
    
    final controller = StreamController<List<Map<String, dynamic>>>();
    
    // 1. Immediate cache payload emission
    final cached = LocalCacheService.getCachedData('expenses_$_userId');
    if (cached != null) {
      controller.add(List<Map<String, dynamic>>.from(cached));
    }
    
    // 2. High-speed websocket sync subscription
    final subscription = _client
        .from('expenses')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('expense_date', ascending: false)
        .listen((data) {
          LocalCacheService.cacheData('expenses_$_userId', data);
          if (!controller.isClosed) {
            controller.add(data);
          }
        }, onError: (_) {});

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Inserts directly into Supabase so the write is authoritative and visible
  /// to the React client via Realtime immediately.
  Future<Map<String, dynamic>> addExpense(Map<String, dynamic> expense) async {
    if (_userId == null) throw Exception('User not authenticated');

    final amount = expense['amount'];
    if (amount == null) throw Exception('Amount is required');

    final payload = filterPayload({
      'user_id': _userId,
      'amount': amount,
      'category': sanitizeExpenseCategory(expense['category'] ?? 'other'),
      'description': expense['description'] ?? '',
      'payment_method': sanitizePaymentMethod(expense['payment_method'] ?? 'upi'),
      'expense_date': toDateOnly(expense['expense_date']),
      'receipt_url': expense['receipt_url'],
    }, SchemaColumns.expensesWritable);

    final response = await _client
        .from('expenses')
        .insert(payload)
        .select()
        .single();

    final confirmed = Map<String, dynamic>.from(response);

    final cached = LocalCacheService.getCachedData('expenses_$_userId') ?? [];
    final updated = [confirmed, ...List<Map<String, dynamic>>.from(cached)];
    await LocalCacheService.cacheData('expenses_$_userId', updated);

    // Trigger category budget check async
    _checkCategoryBudget(confirmed['category'] ?? 'other', _parseAmount(confirmed['amount']));

    return confirmed;
  }

  Future<void> _checkCategoryBudget(String category, double newExpenseAmount) async {
    if (_userId == null) return;
    try {
      final budgets = LocalCacheService.getCachedList('cached_budgets_$_userId');
      if (budgets.isEmpty) return;

      final normalizedCategory = sanitizeExpenseCategory(category);
      final budgetMatch = budgets.firstWhere(
        (b) => sanitizeExpenseCategory(b['category']) == normalizedCategory,
        orElse: () => <String, dynamic>{},
      );

      if (budgetMatch.isEmpty) return;

      final budgetAmount = double.tryParse(budgetMatch['amount']?.toString() ?? '0') ?? 0.0;
      if (budgetAmount <= 0) return;

      final expenses = LocalCacheService.getCachedData('expenses_$_userId') ?? [];
      final now = DateTime.now();
      double spentThisMonth = 0.0;
      for (final e in expenses) {
        final dateStr = e['expense_date']?.toString() ?? e['created_at']?.toString() ?? '';
        final d = DateTime.tryParse(dateStr);
        if (d != null && d.year == now.year && d.month == now.month && sanitizeExpenseCategory(e['category']) == normalizedCategory) {
          spentThisMonth += double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0;
        }
      }

      final ratio = spentThisMonth / budgetAmount;
      String? alertTitle;
      String? alertBody;
      String priority = 'medium';

      if (ratio >= 1.0) {
        alertTitle = 'Budget Limit Exceeded! 🚨';
        alertBody = 'You have spent ₹${spentThisMonth.toStringAsFixed(0)} of your ₹${budgetAmount.toStringAsFixed(0)} budget for $category.';
        priority = 'high';
      } else if (ratio >= 0.9) {
        alertTitle = 'Budget Critical Alert ⚠️';
        alertBody = 'You have spent 90% of your ₹${budgetAmount.toStringAsFixed(0)} budget for $category.';
      } else if (ratio >= 0.8) {
        alertTitle = 'Budget Milestone Alert 💡';
        alertBody = 'You have spent 80% of your ₹${budgetAmount.toStringAsFixed(0)} budget for $category.';
      }

      if (alertTitle != null && alertBody != null) {
        await _client.from('notifications').insert({
          'user_id': _userId,
          'title': alertTitle,
          'body': alertBody,
          'type': 'budget_alert',
          'priority': priority,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
          'source': 'local',
        });
      }
    } catch (_) {}
  }

  Future<void> updateExpense(String id, Map<String, dynamic> expense) async {
    if (_userId == null) throw Exception('User not authenticated');
    
    final cleanData = filterPayload({
      ...expense,
      if (expense.containsKey('category'))
        'category': sanitizeExpenseCategory(expense['category']),
      if (expense.containsKey('payment_method'))
        'payment_method': sanitizePaymentMethod(expense['payment_method']),
      if (expense.containsKey('expense_date'))
        'expense_date': toDateOnly(expense['expense_date']),
    }, {
      'amount',
      'category',
      'description',
      'payment_method',
      'expense_date',
      'receipt_url',
    });
    
    // Optimistic cache update
    final cached = LocalCacheService.getCachedData('expenses_$_userId') ?? [];
    final updated = List<Map<String, dynamic>>.from(cached).map((e) {
      if (e['id'] == id) return {...e, ...cleanData};
      return e;
    }).toList();
    await LocalCacheService.cacheData('expenses_$_userId', updated);

    // Trigger budget checking if category or amount changes
    if (cleanData.containsKey('category') || cleanData.containsKey('amount')) {
      final cat = cleanData['category']?.toString() ?? 'other';
      final amt = _parseAmount(cleanData['amount'] ?? 0.0);
      _checkCategoryBudget(cat, amt);
    }
    
    await LocalCacheService.queueAction(
      actionType: 'update',
      path: 'expenses',
      payload: {'id': id, ...cleanData},
    );
  }

  Future<void> deleteExpense(String expenseId) async {
    if (_userId == null) return;
    
    // Optimistic cache update
    final cached = LocalCacheService.getCachedData('expenses_$_userId') ?? [];
    final updated = List<Map<String, dynamic>>.from(cached).where((e) => e['id'] != expenseId).toList();
    await LocalCacheService.cacheData('expenses_$_userId', updated);
    
    // Queue background deletion (idempotent — safe to retry)
    await LocalCacheService.queueAction(
      actionType: 'delete',
      path: 'expenses',
      payload: {'id': expenseId},
    );
  }
}
