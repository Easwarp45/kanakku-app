import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Cryptographic helper for securing application data.
class SecurityHelper {
  /// Hashes a plain-text passcode (e.g. '1234') using SHA-256 and a cryptographic salt.
  /// Returns a 64-character hex string representing the digest.
  static String hashPasscode(String passcode, {String salt = ''}) {
    if (passcode.isEmpty) return '';
    final bytes = utf8.encode(passcode + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies an entered passcode against a stored SHA-256 hash.
  /// Integrates fallback checking to support migrating unsalted legacy passcodes.
  static bool verifyPasscode(String entered, String hashed, {String salt = ''}) {
    if (entered.isEmpty || hashed.isEmpty) return false;
    
    // 1. Verify with salt
    final enteredHashWithSalt = hashPasscode(entered, salt: salt);
    if (enteredHashWithSalt == hashed) return true;

    // 2. Fallback verify without salt for legacy compatibility
    final enteredHashLegacy = hashPasscode(entered, salt: '');
    return enteredHashLegacy == hashed;
  }
}
