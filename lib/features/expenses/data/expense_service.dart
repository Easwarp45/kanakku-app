import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/supabase_service.dart';
import '../../../core/providers/auth_provider.dart';

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
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
            // Use expense_date (the actual DB column) for monthly filtering
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
    
    return _client
        .from('expenses')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('expense_date', ascending: false);
  }

  /// Insert expense with columns matching the exact DB schema:
  /// id, user_id, amount, category (expense_category enum), description,
  /// payment_method (payment_method enum), expense_date, receipt_url, created_at, updated_at
  Future<void> addExpense(Map<String, dynamic> expense) async {
    if (_userId == null) throw Exception('User not authenticated');
    
    final data = {
      'user_id': _userId,
      'amount': expense['amount'],
      'category': expense['category'] ?? 'other',
      'description': expense['description'],
      'payment_method': expense['payment_method'] ?? 'upi',
      'expense_date': expense['expense_date'] ?? DateTime.now().toIso8601String().split('T')[0],
    };
    // Remove null values so DB defaults take effect
    data.removeWhere((key, value) => value == null);
    
    await _client.from('expenses').insert(data);
  }

  Future<void> updateExpense(String id, Map<String, dynamic> expense) async {
    if (_userId == null) throw Exception('User not authenticated');
    // Only allow updating valid DB columns
    final validKeys = {'amount', 'category', 'description', 'payment_method', 'expense_date', 'receipt_url'};
    final cleanData = Map<String, dynamic>.fromEntries(
      expense.entries.where((e) => validKeys.contains(e.key)),
    );
    await _client.from('expenses').update(cleanData).eq('id', id).eq('user_id', _userId);
  }

  Future<void> deleteExpense(String expenseId) async {
    if (_userId == null) return;
    await _client.from('expenses').delete().eq('id', expenseId).eq('user_id', _userId);
  }
}
