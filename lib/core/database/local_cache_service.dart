import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Production-grade offline-first local cache with versioning,
/// typed reads, and sync-safe accessors.
class LocalCacheService {
  // Bump version suffix to bust stale cache on schema changes
  static const String _cacheVersion = 'v4';
  static const String cacheBoxKey = 'kanakku_cache_$_cacheVersion';
  static const String queueBoxKey = 'kanakku_pending_queue_$_cacheVersion';

  static late Box _cacheBox;
  static late Box _queueBox;

  static bool _initialized = false;

  /// Initialize both boxes concurrently.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      final boxes = await Future.wait([
        Hive.openBox(cacheBoxKey),
        Hive.openBox(queueBoxKey),
      ]);
      _cacheBox = boxes[0];
      _queueBox = boxes[1];
      _initialized = true;
    } catch (e) {
      // Corrupt box — delete and recreate fresh
      try {
        await Hive.deleteBoxFromDisk(cacheBoxKey);
        await Hive.deleteBoxFromDisk(queueBoxKey);
        final boxes = await Future.wait([
          Hive.openBox(cacheBoxKey),
          Hive.openBox(queueBoxKey),
        ]);
        _cacheBox = boxes[0];
        _queueBox = boxes[1];
        _initialized = true;
      } catch (e2) {
        rethrow;
      }
    }
  }

  // ─── Write ──────────────────────────────────────────────────────────

  /// Write JSON data to cache (async, for background persistence)
  static Future<void> cacheData(String key, dynamic data) async {
    if (!_initialized) return;
    final jsonStr = jsonEncode(data);
    await _cacheBox.put(key, jsonStr);
  }

  // ─── Read ───────────────────────────────────────────────────────────

  /// Read raw dynamic data (returns null if missing or corrupt)
  static dynamic getCachedData(String key) {
    if (!_initialized) return null;
    final raw = _cacheBox.get(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw as String);
    } catch (_) {
      return null;
    }
  }

  /// Read a typed list — avoids repeated casting at call sites
  static List<Map<String, dynamic>> getCachedList(String key) {
    final raw = getCachedData(key);
    if (raw == null) return [];
    try {
      return (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Read a typed map (single object) — safe cast
  static Map<String, dynamic>? getCachedMap(String key) {
    final raw = getCachedData(key);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }

  /// Check if a cache key exists and is non-empty
  static bool hasCachedData(String key) {
    if (!_initialized) return false;
    return _cacheBox.containsKey(key) && _cacheBox.get(key) != null;
  }

  /// Delete a specific cache entry (selective invalidation)
  static Future<void> invalidate(String key) async {
    if (!_initialized) return;
    await _cacheBox.delete(key);
  }

  // ─── Offline Action Queue ────────────────────────────────────────────

  /// Enqueue an offline mutation — stored with timestamp for ordering
  static Future<void> queueAction({
    required String actionType,
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    if (!_initialized) return;
    final action = jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'actionType': actionType,
      'path': path,
      'payload': payload,
    });
    await _queueBox.add(action);
  }

  /// Get all pending actions as typed maps
  static List<Map<String, dynamic>> getPendingActions() {
    if (!_initialized) return [];
    return _queueBox.values.map((item) {
      try {
        return Map<String, dynamic>.from(jsonDecode(item as String) as Map);
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((a) => a.isNotEmpty).toList();
  }

  /// Delete a pending action by Hive box index
  static Future<void> clearPendingAction(int index) async {
    if (!_initialized) return;
    if (index < _queueBox.length) {
      final key = _queueBox.keyAt(index);
      await _queueBox.delete(key);
    }
  }

  /// Clear entire pending queue
  static Future<void> clearPendingQueue() async {
    if (!_initialized) return;
    await _queueBox.clear();
  }

  // ─── Lifecycle ───────────────────────────────────────────────────────

  /// Clear all cached data on logout
  static Future<void> clearAll() async {
    if (!_initialized) return;
    await Future.wait([
      _cacheBox.clear(),
      _queueBox.clear(),
    ]);
  }
}
