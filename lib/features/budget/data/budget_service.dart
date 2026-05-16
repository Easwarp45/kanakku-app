import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/supabase_service.dart';
import '../../../core/providers/auth_provider.dart';

final budgetServiceProvider = Provider<BudgetService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  return BudgetService(client, user?.id);
});

final budgetsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(budgetServiceProvider);
  return service.getBudgetsStream();
});

class BudgetService {
  final SupabaseClient _client;
  final String? _userId;

  BudgetService(this._client, this._userId);

  Stream<List<Map<String, dynamic>>> getBudgetsStream() {
    if (_userId == null) return Stream.value([]);
    return _client
        .from('budgets')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('category');
  }

  Future<void> upsertBudget(Map<String, dynamic> data) async {
    if (_userId == null) return;
    await _client.from('budgets').upsert({
      'user_id': _userId,
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteBudget(String id) async {
    await _client.from('budgets').delete().eq('id', id);
  }
}
