import 'package:dio/dio.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/database/hive_service.dart';

class AuthRepository {
  final Dio dio;

  AuthRepository(this.dio);

  /// Attempts to login using an API. Falls back to local mock if no backend.
  Future<String> login(String email, String password) async {
    try {
      // Example API path - change to real endpoint when available
      final response = await dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final token = response.data['token'] as String?;
      final userJson = response.data['user'] as Map<String, dynamic>?;

      if (token == null) {
        throw AuthException.invalidCredentials();
      }

      // Persist token and optionally user
      await HiveService.setSetting('auth_token', token);
      if (userJson != null) {
        await HiveService.setSetting('auth_user', userJson.toString());
      }

      return token;
    } on DioError catch (e) {
      if (e.type == DioErrorType.connectionTimeout || e.type == DioErrorType.receiveTimeout) {
        throw NetworkException.timeout(originalException: e);
      }

      if (e.response != null && e.response?.statusCode == 401) {
        throw AuthException.invalidCredentials(originalException: e);
      }

      throw NetworkException.serverError(statusCode: e.response?.statusCode ?? -1, originalException: e);
    } catch (e, st) {
      throw AppError(message: 'Login failed', originalException: e as Exception?, stackTrace: st);
    }
  }

  Future<void> logout() async {
    await HiveService.deleteSetting('auth_token');
    await HiveService.deleteSetting('auth_user');
  }

  String? getToken() => HiveService.getSetting('auth_token');

  bool isAuthenticated() => getToken() != null;
}
