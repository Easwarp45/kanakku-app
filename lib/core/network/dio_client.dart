import 'package:dio/dio.dart';
import '../database/hive_service.dart';

class DioClient {
  static Dio? _instance;

  static Dio getInstance({String? baseUrl}) {
    _instance ??= Dio(
      BaseOptions(
        baseUrl: baseUrl ?? 'https://api.example.com',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    _instance!.interceptors.clear();

    // Attach interceptors
    _instance!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = HiveService.getSetting('auth_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));

    return _instance!;
  }
}
