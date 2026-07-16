import 'package:flutter_test/flutter_test.dart';
import 'package:kanakku_flutter/core/utils/security_helper.dart';

void main() {
  group('SecurityHelper Tests', () {
    test('hashPasscode converts passcode to standard 64-character SHA-256 hex string', () {
      final pin = '1234';
      final hash = SecurityHelper.hashPasscode(pin);
      
      expect(hash.length, 64);
      expect(hash, isNot(pin));
      // Verify hashing consistency
      expect(SecurityHelper.hashPasscode(pin), hash);
    });

    test('hashPasscode returns empty string for empty input', () {
      expect(SecurityHelper.hashPasscode(''), '');
    });

    test('verifyPasscode correctly matches entered PIN with its stored hash', () {
      final pin = '5678';
      final hash = SecurityHelper.hashPasscode(pin);

      expect(SecurityHelper.verifyPasscode(pin, hash), isTrue);
      expect(SecurityHelper.verifyPasscode('1234', hash), isFalse);
      expect(SecurityHelper.verifyPasscode('', hash), isFalse);
      expect(SecurityHelper.verifyPasscode(pin, ''), isFalse);
    });
  });
}
