import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/supabase_service.dart';
import '../database/local_cache_service.dart';

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
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'full_name': displayName} : null,
    );
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await LocalCacheService.cacheData('is_logged_in', false);
    await _client.auth.signOut();
  }
  
  User? get currentUser => _client.auth.currentUser;

  Future<Map<String, dynamic>?> getProfileData(String userId) async {
    try {
      // Schema table is 'profiles', link is 'user_id'
      return await _client.from('profiles').select().eq('user_id', userId).maybeSingle();
    } catch (e) {
      return null;
    }
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await _client.from('profiles').upsert({
      'user_id': userId,
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  /// Sends a password-reset email via Supabase Auth.
  /// The user receives a link to reset their password; Supabase handles
  /// token generation and expiry (default 1 hour).
  ///
  /// Why redirectTo uses a custom URL scheme: Supabase embeds the recovery
  /// token in the redirect URL as a fragment (#access_token=...). Without
  /// a redirectTo, the link points to Supabase's site-URL (often localhost
  /// in dev projects), giving a "DNS not found" error on mobile.
  /// Using the app's package-name scheme (com.example.kanakku_flutter://)
  /// tells Android to route the link back into the app so supabase_flutter
  /// can parse the token and establish a PASSWORD_RECOVERY auth session.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'com.example.kanakku_flutter://reset-password',
    );
  }
}
