import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final String locale;
  final IconData icon;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.locale,
    required this.icon,
  });

  String get displayName => '$code ($symbol)';
}

const List<CurrencyInfo> supportedCurrencies = [
  CurrencyInfo(code: 'INR', symbol: '₹', name: 'Indian Rupee', locale: 'en_IN', icon: LucideIcons.indianRupee),
  CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar', locale: 'en_US', icon: LucideIcons.dollarSign),
  CurrencyInfo(code: 'EUR', symbol: '€', name: 'Euro', locale: 'de_DE', icon: LucideIcons.euro),
  CurrencyInfo(code: 'GBP', symbol: '£', name: 'British Pound', locale: 'en_GB', icon: LucideIcons.poundSterling),
  CurrencyInfo(code: 'JPY', symbol: '¥', name: 'Japanese Yen', locale: 'ja_JP', icon: LucideIcons.japaneseYen),
  CurrencyInfo(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham', locale: 'ar_AE', icon: LucideIcons.coins),
];

class MultiCurrencyData {
  final double amount;
  final String currency;
  final double rate; // rate relative to INR (e.g. 1 INR = rate units of currency)
  final double baseAmount;
  final String baseCurrency;

  MultiCurrencyData({
    required this.amount,
    required this.currency,
    required this.rate,
    required this.baseAmount,
    required this.baseCurrency,
  });

  /// Serialize this data into a description token.
  String toToken() {
    return '[MultiCurrency: amount=$amount&currency=$currency&rate=$rate&base_amount=$baseAmount&base_currency=$baseCurrency]';
  }

  /// Parse the multi-currency token from a description string.
  static MultiCurrencyData? parse(String description) {
    final regExp = RegExp(r'\[MultiCurrency:\s*(.*?)\]');
    final match = regExp.firstMatch(description);
    if (match == null) return null;
    
    final queryStr = match.group(1) ?? '';
    final parts = queryStr.split('&');
    final map = <String, String>{};
    for (final part in parts) {
      final kv = part.split('=');
      if (kv.length == 2) {
        map[kv[0]] = kv[1];
      }
    }
    
    try {
      return MultiCurrencyData(
        amount: double.parse(map['amount'] ?? '0'),
        currency: map['currency'] ?? 'INR',
        rate: double.parse(map['rate'] ?? '1'),
        baseAmount: double.parse(map['base_amount'] ?? '0'),
        baseCurrency: map['base_currency'] ?? 'INR',
      );
    } catch (_) {
      return null;
    }
  }

  /// Clean the description by stripping the multi-currency token.
  static String cleanDescription(String description) {
    final regExp = RegExp(r'\[MultiCurrency:\s*(.*?)\]\s*');
    return description.replaceAll(regExp, '').trim();
  }
}

class CurrencyFormatter {
  /// Format money amount according to currency code and locale formatting preferences.
  static String format(double amount, String currencyCode, {bool showSymbol = true}) {
    final info = supportedCurrencies.firstWhere(
      (c) => c.code == currencyCode,
      orElse: () => supportedCurrencies[0],
    );
    
    final isJpy = currencyCode == 'JPY';
    final formatter = NumberFormat.currency(
      locale: info.locale,
      symbol: showSymbol ? info.symbol : '',
      decimalDigits: isJpy ? 0 : 2,
    );
    
    return formatter.format(amount);
  }
}
