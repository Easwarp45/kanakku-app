import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/supabase_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/database/local_cache_service.dart';

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
  return expensesAsync.maybeWhen(
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
});

final totalExpensesProvider = Provider<double>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  return expensesAsync.maybeWhen(
    data: (expenses) {
      return expenses.fold<double>(0.0, (sum, e) => sum + _parseAmount(e['amount']));
    },
    orElse: () => 0.0,
  );
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

  Future<void> addExpense(Map<String, dynamic> expense) async {
    if (_userId == null) throw Exception('User not authenticated');
    
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final data = {
      'id': tempId,
      'user_id': _userId,
      'amount': expense['amount'],
      'category': expense['category'] ?? 'other',
      'description': expense['description'],
      'payment_method': expense['payment_method'] ?? 'upi',
      'expense_date': expense['expense_date'] ?? DateTime.now().toIso8601String().split('T')[0],
      'created_at': DateTime.now().toIso8601String(),
    };
    
    // Optimistic cache update
    final cached = LocalCacheService.getCachedData('expenses_$_userId') ?? [];
    final updated = [data, ...List<Map<String, dynamic>>.from(cached)];
    await LocalCacheService.cacheData('expenses_$_userId', updated);
    
    // Queue background upload
    final syncData = Map<String, dynamic>.from(data)..remove('id')..remove('created_at');
    await LocalCacheService.queueAction(
      actionType: 'insert',
      path: 'expenses',
      payload: syncData,
    );
  }

  Future<void> updateExpense(String id, Map<String, dynamic> expense) async {
    if (_userId == null) throw Exception('User not authenticated');
    
    final validKeys = {'amount', 'category', 'description', 'payment_method', 'expense_date', 'receipt_url'};
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
    
    // Queue background edit
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
    
    // Queue background deletion
    await LocalCacheService.queueAction(
      actionType: 'delete',
      path: 'expenses',
      payload: {'id': expenseId},
    );
  }
}
