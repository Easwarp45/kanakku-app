import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/supabase_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/database/local_cache_service.dart';

// ─── Providers ───────────────────────────────────────────────────────

final incomeServiceProvider = Provider<IncomeService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  // Warm up RealtimeSyncManager
  ref.read(realtimeSyncManagerProvider);
  return IncomeService(client, user?.id);
});

final incomeStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(incomeServiceProvider);
  return service.getIncomeStream();
});

final totalIncomeAmountProvider = Provider<double>((ref) {
  final incomeAsync = ref.watch(incomeStreamProvider);
  return incomeAsync.maybeWhen(
    data: (list) => list.fold<double>(0.0, (sum, e) => sum + _parseAmount(e['amount'])),
    orElse: () => 0.0,
  );
});

final monthlyIncomeProvider = Provider<double>((ref) {
  final incomeAsync = ref.watch(incomeStreamProvider);
  final now = DateTime.now();
  return incomeAsync.maybeWhen(
    data: (list) => list.where((e) {
      // Use income_date (the actual DB column) for monthly filtering
      final dateStr = e['income_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.year == now.year && d.month == now.month;
    }).fold<double>(0.0, (sum, e) => sum + _parseAmount(e['amount'])),
    orElse: () => 0.0,
  );
});

final weeklyIncomeProvider = Provider<double>((ref) {
  final incomeAsync = ref.watch(incomeStreamProvider);
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  return incomeAsync.maybeWhen(
    data: (list) => list.where((e) {
      final dateStr = e['income_date']?.toString() ?? e['created_at']?.toString() ?? '';
      final d = DateTime.tryParse(dateStr);
      return d != null && d.isAfter(weekStart.subtract(const Duration(days: 1)));
    }).fold<double>(0.0, (sum, e) => sum + _parseAmount(e['amount'])),
    orElse: () => 0.0,
  );
});

double _parseAmount(dynamic amount) {
  if (amount is num) return amount.toDouble();
  return double.tryParse(amount?.toString() ?? '0') ?? 0.0;
}

// ─── Source Metadata (maps DB enum values → display info) ───────────
// DB column is `source` with enum type `income_source`
// Keys here MUST match the DB enum values exactly

class IncomeSourceMeta {
  final String displayName;
  final String emoji;

  const IncomeSourceMeta(this.displayName, this.emoji);
}

const incomeSources = <String, IncomeSourceMeta>{
  'salary':       IncomeSourceMeta('Salary', '💼'),
  'freelance':    IncomeSourceMeta('Freelance', '💻'),
  'business':     IncomeSourceMeta('Business', '🏢'),
  'investment':   IncomeSourceMeta('Investments', '📈'),
  'gift':         IncomeSourceMeta('Gifts', '🎁'),
  'rental':       IncomeSourceMeta('Rental Income', '🏠'),
  'bonus':        IncomeSourceMeta('Bonuses', '🎯'),
  'cashback':     IncomeSourceMeta('Cashback', '💸'),
  'passive':      IncomeSourceMeta('Passive Income', '🔄'),
  'refund':       IncomeSourceMeta('Refunds', '↩️'),
  'other':        IncomeSourceMeta('Others', '📦'),
};

// Keep backward-compatible aliases for any UI code that still references these
// (these will be removed once all UI is migrated)
typedef IncomeCategoryMeta = IncomeSourceMeta;
final incomeCategories = incomeSources;

// ─── Service ────────────────────────────────────────────────────────

class IncomeService {
  final SupabaseClient _client;
  final String? _userId;

  IncomeService(this._client, this._userId);

  Stream<List<Map<String, dynamic>>> getIncomeStream() {
    if (_userId == null) return Stream.value([]);
    
    final controller = StreamController<List<Map<String, dynamic>>>();
    
    // 1. Immediate cache payload emission
    final cached = LocalCacheService.getCachedData('income_$_userId');
    if (cached != null) {
      controller.add(List<Map<String, dynamic>>.from(cached));
    }
    
    // 2. Dynamic realtime socket synchronizer
    final subscription = _client
        .from('income')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('income_date', ascending: false)
        .listen((data) {
          LocalCacheService.cacheData('income_$_userId', data);
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

  Future<void> addIncome(Map<String, dynamic> income) async {
    if (_userId == null) throw Exception('User not authenticated');
    
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final data = {
      'id': tempId,
      'user_id': _userId,
      'amount': income['amount'],
      'source': income['source'] ?? 'salary',
      'description': income['description'],
      'income_date': income['income_date'] ?? DateTime.now().toIso8601String().split('T')[0],
      'is_recurring': income['is_recurring'] ?? false,
      'created_at': DateTime.now().toIso8601String(),
    };
    
    // Optimistic cache update
    final cached = LocalCacheService.getCachedData('income_$_userId') ?? [];
    final updated = [data, ...List<Map<String, dynamic>>.from(cached)];
    await LocalCacheService.cacheData('income_$_userId', updated);
    
    // Queue background upload
    final syncData = Map<String, dynamic>.from(data)..remove('id')..remove('created_at');
    await LocalCacheService.queueAction(
      actionType: 'insert',
      path: 'income',
      payload: syncData,
    );
  }

  Future<void> updateIncome(String id, Map<String, dynamic> data) async {
    if (_userId == null) throw Exception('User not authenticated');
    
    final validKeys = {'amount', 'source', 'description', 'income_date', 'is_recurring'};
    final cleanData = Map<String, dynamic>.fromEntries(
      data.entries.where((e) => validKeys.contains(e.key)),
    );
    
    // Optimistic cache update
    final cached = LocalCacheService.getCachedData('income_$_userId') ?? [];
    final updated = List<Map<String, dynamic>>.from(cached).map((e) {
      if (e['id'] == id) return {...e, ...cleanData};
      return e;
    }).toList();
    await LocalCacheService.cacheData('income_$_userId', updated);
    
    // Queue background edit
    await LocalCacheService.queueAction(
      actionType: 'update',
      path: 'income',
      payload: {'id': id, ...cleanData},
    );
  }

  Future<void> deleteIncome(String id) async {
    if (_userId == null) return;
    
    // Optimistic cache update
    final cached = LocalCacheService.getCachedData('income_$_userId') ?? [];
    final updated = List<Map<String, dynamic>>.from(cached).where((e) => e['id'] != id).toList();
    await LocalCacheService.cacheData('income_$_userId', updated);
    
    // Queue background deletion
    await LocalCacheService.queueAction(
      actionType: 'delete',
      path: 'income',
      payload: {'id': id},
    );
  }
}
