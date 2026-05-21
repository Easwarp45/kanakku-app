import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'realtime_sync_manager.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final realtimeSyncManagerProvider = Provider<RealtimeSyncManager>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final manager = RealtimeSyncManager(client);
  ref.onDispose(manager.dispose);
  return manager;
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(ref.watch(supabaseClientProvider));
});

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  // Example: Fetch user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  // Example: Fetch expenses
  Future<List<Map<String, dynamic>>> getExpenses() async {
    try {
      final response = await _client
          .from('expenses')
          .select()
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      return [];
    }
  }
}
