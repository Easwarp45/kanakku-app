import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Cryptographic helper for securing application data.
class SecurityHelper {
  /// Hashes a plain-text passcode (e.g. '1234') using SHA-256.
  /// Returns a 64-character hex string representing the digest.
  static String hashPasscode(String passcode) {
    if (passcode.isEmpty) return '';
    final bytes = utf8.encode(passcode);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies an entered passcode against a stored SHA-256 hash.
  static bool verifyPasscode(String entered, String hashed) {
    if (entered.isEmpty || hashed.isEmpty) return false;
    final enteredHash = hashPasscode(entered);
    return enteredHash == hashed;
  }
}
