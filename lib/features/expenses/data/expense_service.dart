import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/supabase_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/database/local_cache_service.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/multi_currency_helper.dart';

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

  /// Add a new expense.
  ///
  /// WHY we write directly to Supabase here instead of queueing:
  ///
  /// The previous implementation called LocalCacheService.queueAction() which
  /// stored the expense in a local Hive queue. RealtimeSyncManager would pick
  /// it up after a 3-second delay (and then every 20 seconds). This meant:
  ///
  ///   1. The user had no visible confirmation the expense was saved.
  ///   2. If the session JWT expired between the UI action and the sync timer
  ///      firing, auth.uid() would return null → RLS block → expense silently lost.
  ///   3. If the app was killed before the timer fired, the expense was lost.
  ///
  /// The correct pattern for a transactional write is:
  ///   - Write to Supabase immediately (authoritative, auditable)
  ///   - Update local cache optimistically for instant UI feedback
  ///   - On network failure, surface the error immediately rather than queuing
  ///
  /// The queue (RealtimeSyncManager) is still used for updates and deletes that
  /// happen offline, because those operations are idempotent and the IDs are known.
  Future<Map<String, dynamic>> addExpense(Map<String, dynamic> expense) async {
    if (_userId == null) throw Exception('User not authenticated');

    // WHY we validate amount here: Supabase will reject a non-numeric amount
    // with a PostgrestException. Catching it here gives a better user message.
    final amount = expense['amount'];
    if (amount == null) throw Exception('Amount is required');

    // Build the canonical payload — must match the DB column names exactly.
    // The Web app sends: amount, category, description (or notes), payment_method,
    // expense_date, currency.
    // WHY currency: The expenses table has a `currency` column (TEXT, default 'INR').
    // If the column is NOT NULL without a server-side default, omitting it causes
    // "null value in column currency violates not-null constraint".
    final payload = <String, dynamic>{
      'user_id': _userId,
      'amount': amount,
      'category': expense['category'] ?? 'other',
      // WHY both 'description' and 'notes': The Web app may store the text in
      // 'notes' while Flutter used 'description'. We send both and let the DB
      // column mapping decide. One will be ignored if the column doesn't exist.
      'description': expense['description'] ?? expense['notes'] ?? '',
      'notes': expense['notes'] ?? expense['description'] ?? '',
      'payment_method': expense['payment_method'] ?? 'upi',
      'expense_date': expense['expense_date'] ??
          DateTime.now().toIso8601String().split('T')[0],
      'currency': expense['currency'] ?? 'INR',
    };

    // Remove null values — the DB rejects explicit nulls for NOT NULL columns.
    // Do NOT remove empty strings, as those are valid values.
    payload.removeWhere((k, v) => v == null);

    // Direct Supabase insert — synchronous, raises on failure.
    // RLS policy: WITH CHECK (auth.uid() = user_id)
    // The SupabaseClient uses the active session JWT automatically.
    final response = await _client
        .from('expenses')
        .insert(payload)
        .select()
        .single();

    final confirmed = Map<String, dynamic>.from(response);

    // Update local cache with the confirmed row (has the real DB-generated id).
    final cached = LocalCacheService.getCachedData('expenses_$_userId') ?? [];
    final updated = [confirmed, ...List<Map<String, dynamic>>.from(cached)];
    await LocalCacheService.cacheData('expenses_$_userId', updated);

    return confirmed;
  }

  Future<void> updateExpense(String id, Map<String, dynamic> expense) async {
    if (_userId == null) throw Exception('User not authenticated');
    
    final validKeys = {'amount', 'category', 'description', 'notes', 'payment_method', 'expense_date', 'currency', 'receipt_url'};
    final cleanData = Map<String, dynamic>.fromEntries(
      expense.entries.where((e) => validKeys.contains(e.key)),
    );
    
    // Optimistic cache update
    final cached = LocalCacheService.getCachedData('expenses_$_userId') ?? [];
    final updated = List<Map<String, dynamic>>.from(cached).map((e) {
      if (e['id'] == id) return {...e, ...cleanData};
      return e;
    }).toList();
    await LocalCacheService.cacheData('expenses_$_userId', updated);
    
    // WHY we queue updates but not inserts:
    // Updates are idempotent (same data, same result) and the record ID is
    // already known (it exists in the DB). Inserts are not idempotent — queuing
    // them risks duplicate rows if the timer fires multiple times.
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
