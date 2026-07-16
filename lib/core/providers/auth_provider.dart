import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/supabase_service.dart';
import '../database/local_cache_service.dart';
import '../database/schema_constants.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  try {
    return Supabase.instance.client.auth.onAuthStateChange;
  } catch (_) {
    return const Stream.empty();
  }
});

final currentUserProvider = Provider<User?>((ref) {
  try {
    final authState = ref.watch(authStateProvider).value;
    return authState?.session?.user ?? Supabase.instance.client.auth.currentUser;
  } catch (_) {
    return null;
  }
});

final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(authServiceProvider).getProfileData(user.id);
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  Future<AuthResponse> signUp(String email, String password, {String? displayName}) async {
    debugPrint('[AUTH] signUp start email=$email');
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: displayName != null && displayName.trim().isNotEmpty
          ? {'full_name': displayName.trim()}
          : null,
      emailRedirectTo: 'com.example.kanakku_flutter://login',
    );
    debugPrint(
      '[AUTH] signUp done user=${response.user?.id} session=${response.session != null}',
    );

    // If we already have a session, make sure a profile row exists.
    // The DB trigger normally creates it; this is a safe recovery path only.
    final user = response.user;
    final session = response.session;
    if (user != null && session != null) {
      await ensureProfileExists(
        userId: user.id,
        displayName: displayName ?? user.userMetadata?['full_name']?.toString(),
      );
    }

    return response;
  }

  Future<AuthResponse> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user != null) {
      await ensureProfileExists(
        userId: user.id,
        displayName: user.userMetadata?['full_name']?.toString(),
      );
    }
    return response;
  }

  Future<void> signOut() async {
    await LocalCacheService.cacheData('is_logged_in', false);
    await _client.auth.signOut();
  }
  
  User? get currentUser => _client.auth.currentUser;

  Future<Map<String, dynamic>?> getProfileData(String userId) async {
    try {
      return await _client.from('profiles').select().eq('user_id', userId).maybeSingle();
    } catch (e) {
      debugPrint('[AUTH] getProfileData error: $e');
      return null;
    }
  }

  /// Ensures a profiles row exists for [userId].
  ///
  /// Normal path: `handle_new_user()` trigger creates the row.
  /// Recovery path: if the trigger timed out / was blocked, insert once via RLS
  /// ("Users can insert own profile"). Never races during signup when the trigger
  /// already succeeded — ON CONFLICT / existence check keeps it idempotent.
  Future<void> ensureProfileExists({
    required String userId,
    String? displayName,
  }) async {
    try {
      final existing = await getProfileData(userId);
      if (existing != null) return;

      // Brief wait for the trigger (it may still be committing).
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final again = await getProfileData(userId);
        if (again != null) return;
      }

      debugPrint('[AUTH] Profile missing after trigger wait — inserting recovery row');
      await _client.from('profiles').insert({
        'user_id': userId,
        'display_name': (displayName != null && displayName.trim().isNotEmpty)
            ? displayName.trim()
            : 'User',
        'language': 'en',
        'currency': 'INR',
      });
    } catch (e) {
      // Unique violation = trigger won the race — fine.
      debugPrint('[AUTH] ensureProfileExists: $e');
    }
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await ensureProfileExists(userId: userId);

    final profileExists = await _client
        .from('profiles')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (profileExists == null) {
      throw Exception('Unable to prepare your profile. Please try again.');
    }

    final clean = filterPayload(data, SchemaColumns.profilesWritable);
    await _client.from('profiles').update({
      ...clean,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId);
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'com.example.kanakku_flutter://reset-password',
    );
  }
}
