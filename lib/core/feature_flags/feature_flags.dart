import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/hive_service.dart';

class FeatureFlags {
  static const _boxKey = 'feature_flags';

  final Map<String, bool> _flags;

  FeatureFlags._(this._flags);

  static Future<FeatureFlags> load() async {
    final raw = HiveService.getSetting(_boxKey);
    if (raw == null || raw.isEmpty) return FeatureFlags._(<String, bool>{});
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return FeatureFlags._(decoded.map((k, v) => MapEntry(k, v == true)));
    } catch (_) {
      return FeatureFlags._(<String, bool>{});
    }
  }

  bool isEnabled(String key) => _flags[key] ?? false;

  Future<void> set(String key, bool value) async {
    _flags[key] = value;
    await HiveService.setSetting(_boxKey, json.encode(_flags));
  }

  Map<String, bool> asMap() => Map.unmodifiable(_flags);
}

final featureFlagsProvider = FutureProvider<FeatureFlags>((ref) async {
  return FeatureFlags.load();
});
