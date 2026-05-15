import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';
import '../../data/repositories/auth_repository.dart';
import '../network/dio_client.dart';

final dioProvider = Provider((ref) => DioClient.getInstance());

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.read(dioProvider)));

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? token;

  AuthState({this.isLoading = false, this.isAuthenticated = false, this.token});

  AuthState copyWith({bool? isLoading, bool? isAuthenticated, String? token}) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        token: token ?? this.token,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(AuthState(isAuthenticated: _repo.isAuthenticated(), token: _repo.getToken()));

  AuthState get current => state;

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _repo.login(email, password);
      state = state.copyWith(isLoading: false, isAuthenticated: true, token: token);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = AuthState(isAuthenticated: false);
  }
}

final authNotifierProvider = Provider<AuthNotifier>((ref) {
  final repo = ref.read(authRepositoryProvider);
  final notifier = AuthNotifier(repo);
  ref.onDispose(() {
    try {
      notifier.dispose();
    } catch (_) {}
  });
  return notifier;
});

final authStateProvider = Provider<AuthState>((ref) {
  final notifier = ref.watch(authNotifierProvider);
  return notifier.current;
});
