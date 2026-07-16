import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logging/app_logger.dart';

/// Maps technical Supabase / network errors to user-facing messages.
///
/// Development: logs the full technical error via [AppLogger].
/// Production / UI: only the friendly message should be shown.
class ErrorMapper {
  ErrorMapper._();

  static String userMessage(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    logger.e('Mapped error', error);

    if (error is AuthException) {
      return _authMessage(error);
    }
    if (error is PostgrestException) {
      return _postgrestMessage(error, fallback);
    }

    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('connection')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (text.contains('timeout')) {
      return 'The request timed out. Please try again.';
    }

    // Never surface raw exception strings to users.
    return fallback;
  }

  static String _authMessage(AuthException error) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login') ||
        msg.contains('invalid credentials') ||
        msg.contains('email not confirmed')) {
      return error.message; // Supabase auth messages are already user-safe
    }
    if (msg.contains('user already registered') || msg.contains('already been registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('password')) {
      return error.message;
    }
    if (msg.contains('database error') || msg.contains('unexpected_failure')) {
      return 'Unable to create your account. Please try again in a moment.';
    }
    return error.message.isNotEmpty
        ? error.message
        : 'Unable to authenticate. Please try again.';
  }

  static String _postgrestMessage(PostgrestException error, String fallback) {
    if (kDebugMode) {
      logger.e('PostgrestException code=${error.code} details=${error.details} hint=${error.hint}');
    }

    final msg = (error.message).toLowerCase();
    final code = error.code ?? '';

    if (code == '22P02' || msg.contains('invalid input value for enum')) {
      return 'One of the selected values is not supported. Please choose a different option.';
    }
    if (code == '23505' || msg.contains('duplicate')) {
      return 'This record already exists.';
    }
    if (code == '23503' || msg.contains('foreign key')) {
      return 'Related data is missing. Please refresh and try again.';
    }
    if (code == '42501' || msg.contains('row-level security')) {
      return 'You do not have permission to perform this action.';
    }
    if (msg.contains('jwt') || msg.contains('not authenticated')) {
      return 'Your session has expired. Please sign in again.';
    }

    return fallback;
  }
}
