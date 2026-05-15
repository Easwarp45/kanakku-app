import 'package:flutter_test/flutter_test.dart';
import 'package:kanakku_flutter/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('validateEmail returns null for valid email', () {
      expect(Validators.validateEmail('test@example.com'), isNull);
    });

    test('validateEmail returns message for invalid email', () {
      expect(Validators.validateEmail('invalid-email'), isNotNull);
    });

    test('validatePassword enforces length and characters', () {
      expect(Validators.validatePassword('a1b2c3'), isNull);
      expect(Validators.validatePassword('short'), isNotNull);
      expect(Validators.validatePassword('123456'), isNotNull);
    });

    test('validateAmount enforces numeric and positive', () {
      expect(Validators.validateAmount('10'), isNull);
      expect(Validators.validateAmount('-5'), isNotNull);
      expect(Validators.validateAmount('not-a-number'), isNotNull);
    });
  });
}
