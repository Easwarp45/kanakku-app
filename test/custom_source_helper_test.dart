import 'package:flutter_test/flutter_test.dart';
import 'package:kanakku_flutter/core/utils/custom_source_helper.dart';

void main() {
  group('CustomSourceData Tests', () {
    test('serialize to token correctly', () {
      final data = CustomSourceData(name: 'Dividends');
      expect(data.toToken(), '[CustomSource: name=Dividends]');
    });

    test('parse custom source from token string successfully', () {
      const description = '[CustomSource: name=Rent From Shop] Remaining description details';
      final parsed = CustomSourceData.parse(description);
      expect(parsed, isNotNull);
      expect(parsed!.name, 'Rent From Shop');
    });

    test('parse returns null if no token is present', () {
      const description = 'Regular transaction without custom metadata';
      final parsed = CustomSourceData.parse(description);
      expect(parsed, isNull);
    });

    test('cleanDescription removes token metadata cleanly', () {
      const description = '[CustomSource: name=Allowance] Pocket money from parents';
      final cleaned = CustomSourceData.cleanDescription(description);
      expect(cleaned, 'Pocket money from parents');
    });
  });
}
