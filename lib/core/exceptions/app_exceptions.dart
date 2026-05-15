/// Base exception class for the application
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final Exception? originalException;
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    this.code,
    this.originalException,
    this.stackTrace,
  });

  @override
  String toString() => message;
}

/// Authentication related exceptions
class AuthException extends AppException {
  AuthException({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
  });

  factory AuthException.invalidCredentials({
    Exception? originalException,
    StackTrace? stackTrace,
  }) =>
      AuthException(
        message: 'Invalid email or password',
        code: 'INVALID_CREDENTIALS',
        originalException: originalException,
        stackTrace: stackTrace,
      );

  factory AuthException.userNotFound({
    Exception? originalException,
    StackTrace? stackTrace,
  }) =>
      AuthException(
        message: 'User not found',
        code: 'USER_NOT_FOUND',
        originalException: originalException,
        stackTrace: stackTrace,
      );

  factory AuthException.emailAlreadyExists({
    Exception? originalException,
    StackTrace? stackTrace,
  }) =>
      AuthException(
        message: 'Email already registered',
        code: 'EMAIL_EXISTS',
        originalException: originalException,
        stackTrace: stackTrace,
      );

  factory AuthException.sessionExpired({
    Exception? originalException,
    StackTrace? stackTrace,
  }) =>
      AuthException(
        message: 'Session expired. Please login again.',
        code: 'SESSION_EXPIRED',
        originalException: originalException,
        stackTrace: stackTrace,
      );
}

/// Network related exceptions
class NetworkException extends AppException {
  NetworkException({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
  });

  factory NetworkException.noInternet({
    Exception? originalException,
    StackTrace? stackTrace,
  }) =>
      NetworkException(
        message: 'No internet connection',
        code: 'NO_INTERNET',
        originalException: originalException,
        stackTrace: stackTrace,
      );

  factory NetworkException.timeout({
    Exception? originalException,
    StackTrace? stackTrace,
  }) =>
      NetworkException(
        message: 'Request timeout',
        code: 'TIMEOUT',
        originalException: originalException,
        stackTrace: stackTrace,
      );

  factory NetworkException.serverError({
    required int statusCode,
    Exception? originalException,
    StackTrace? stackTrace,
  }) =>
      NetworkException(
        message: 'Server error: $statusCode',
        code: 'SERVER_ERROR_$statusCode',
        originalException: originalException,
        stackTrace: stackTrace,
      );
}

/// Validation related exceptions
class ValidationException extends AppException {
  ValidationException({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
  });

  factory ValidationException.invalidInput({
    required String fieldName,
    Exception? originalException,
    StackTrace? stackTrace,
  }) =>
      ValidationException(
        message: '$fieldName is invalid',
        code: 'INVALID_INPUT',
        originalException: originalException,
        stackTrace: stackTrace,
      );

  factory ValidationException.requiredField({
    required String fieldName,
    Exception? originalException,
    StackTrace? stackTrace,
  }) =>
      ValidationException(
        message: '$fieldName is required',
        code: 'REQUIRED_FIELD',
        originalException: originalException,
        stackTrace: stackTrace,
      );
}

/// Database related exceptions
class DatabaseException extends AppException {
  DatabaseException({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
  });

  factory DatabaseException.notFound({
    Exception? originalException,
    StackTrace? stackTrace,
  }) =>
      DatabaseException(
        message: 'Data not found',
        code: 'NOT_FOUND',
        originalException: originalException,
        stackTrace: stackTrace,
      );

  factory DatabaseException.operationFailed({
    Exception? originalException,
    StackTrace? stackTrace,
  }) =>
      DatabaseException(
        message: 'Database operation failed',
        code: 'OPERATION_FAILED',
        originalException: originalException,
        stackTrace: stackTrace,
      );
}

/// Generic application error
class AppError extends AppException {
  AppError({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
  });
}
