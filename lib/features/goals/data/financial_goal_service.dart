import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/supabase_service.dart';
import '../../../core/database/local_cache_service.dart';
import '../../../core/database/schema_constants.dart';
import '../../../core/providers/auth_provider.dart';

final financialGoalServiceProvider = Provider<FinancialGoalService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  ref.read(realtimeSyncManagerProvider);
  return FinancialGoalService(client, user?.id);
});

final financialGoalsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(financialGoalServiceProvider);
  return service.getGoalsStream();
});

/// CRUD + realtime for `public.financial_goals`.
///
/// DB columns (source of truth):
///   id, user_id, target_amount, current_saved, deadline, created_at, updated_at
///
/// The Flutter UI still shows a local `name` overlay (not a DB column).
/// Names are cached locally keyed by goal id and never sent to Supabase.
class FinancialGoalService {
  final SupabaseClient _client;
  final String? _userId;

  FinancialGoalService(this._client, this._userId);

  String get _namesKey => 'goal_names_$_userId';
  String get _cacheKey => 'financial_goals_$_userId';

  Map<String, String> _loadNames() {
    final raw = LocalCacheService.getCachedMap(_namesKey) ?? {};
    return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? 'Savings Goal'));
  }

  Future<void> _saveName(String id, String name) async {
    final names = _loadNames();
    names[id] = name;
    await LocalCacheService.cacheData(_namesKey, names);
  }

  Future<void> _removeName(String id) async {
    final names = _loadNames()..remove(id);
    await LocalCacheService.cacheData(_namesKey, names);
  }

  /// Maps a DB row to the UI-shaped map used by Insights.
  Map<String, dynamic> toUiMap(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final names = _loadNames();
    return {
      'id': id,
      'name': names[id] ?? 'Savings Goal',
      'targetAmount': _asDouble(row['target_amount']),
      'currentAmount': _asDouble(row['current_saved']),
      'deadline': row['deadline']?.toString(),
      'target_amount': row['target_amount'],
      'current_saved': row['current_saved'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
    };
  }

  Stream<List<Map<String, dynamic>>> getGoalsStream() {
    if (_userId == null) return Stream.value([]);

    final controller = StreamController<List<Map<String, dynamic>>>();

    final cached = LocalCacheService.getCachedData(_cacheKey);
    if (cached != null) {
      controller.add(
        List<Map<String, dynamic>>.from(cached).map(toUiMap).toList(),
      );
    }

    final subscription = _client
        .from('financial_goals')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('deadline', ascending: true)
        .listen((data) {
          LocalCacheService.cacheData(_cacheKey, data);
          if (!controller.isClosed) {
            controller.add(data.map((e) => toUiMap(Map<String, dynamic>.from(e))).toList());
          }
        }, onError: (_) {});

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Future<Map<String, dynamic>> addGoal({
    required String name,
    required double targetAmount,
    required double currentSaved,
    DateTime? deadline,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final payload = filterPayload({
      'user_id': _userId,
      'target_amount': targetAmount,
      'current_saved': currentSaved,
      'deadline': toDateOnly(
        deadline ?? DateTime.now().add(const Duration(days: 365)),
      ),
    }, SchemaColumns.financialGoalsWritable);

    final response = await _client
        .from('financial_goals')
        .insert(payload)
        .select()
        .single();

    final confirmed = Map<String, dynamic>.from(response);
    await _saveName(confirmed['id'].toString(), name);

    final cached = LocalCacheService.getCachedData(_cacheKey) ?? [];
    await LocalCacheService.cacheData(
      _cacheKey,
      [confirmed, ...List<Map<String, dynamic>>.from(cached)],
    );

    return toUiMap(confirmed);
  }

  Future<void> updateProgress(String id, double currentSaved) async {
    if (_userId == null) throw Exception('User not authenticated');

    final payload = {
      'current_saved': currentSaved,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _client.from('financial_goals').update(payload).eq('id', id).eq('user_id', _userId);

    final cached = LocalCacheService.getCachedData(_cacheKey) ?? [];
    final updated = List<Map<String, dynamic>>.from(cached).map((g) {
      if (g['id']?.toString() == id) {
        return {...g, 'current_saved': currentSaved};
      }
      return g;
    }).toList();
    await LocalCacheService.cacheData(_cacheKey, updated);
  }

  Future<void> deleteGoal(String id) async {
    if (_userId == null) return;

    await _client.from('financial_goals').delete().eq('id', id).eq('user_id', _userId);
    await _removeName(id);

    final cached = LocalCacheService.getCachedData(_cacheKey) ?? [];
    await LocalCacheService.cacheData(
      _cacheKey,
      List<Map<String, dynamic>>.from(cached)
          .where((g) => g['id']?.toString() != id)
          .toList(),
    );
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0.0;
  }
}

/// UI-facing goals notifier — keeps the Insights widgets unchanged while
/// persisting to `financial_goals` via [FinancialGoalService].
class LocalGoalsNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    return ref.watch(financialGoalsStreamProvider).maybeWhen(
          data: (goals) => goals,
          orElse: () => const [],
        );
  }

  void loadGoals() {
    ref.invalidate(financialGoalsStreamProvider);
  }

  Future<void> addGoal(String name, double target, double current) async {
    await ref.read(financialGoalServiceProvider).addGoal(
          name: name,
          targetAmount: target,
          currentSaved: current,
        );
    ref.invalidate(financialGoalsStreamProvider);
  }

  Future<void> updateGoalProgress(String id, double progress) async {
    await ref.read(financialGoalServiceProvider).updateProgress(id, progress);
    ref.invalidate(financialGoalsStreamProvider);
  }

  Future<void> deleteGoal(String id) async {
    await ref.read(financialGoalServiceProvider).deleteGoal(id);
    ref.invalidate(financialGoalsStreamProvider);
  }
}

final localGoalsProvider =
    NotifierProvider<LocalGoalsNotifier, List<Map<String, dynamic>>>(
  LocalGoalsNotifier.new,
);
