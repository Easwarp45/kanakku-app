import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

/// Service for managing Hive database operations.
///
/// Uses untyped [Box<dynamic>] for all storage because the app's domain
/// model classes (User, Expense, Category, Transaction) do not have
/// registered Hive type adapters. Typed boxes require adapters — without
/// them, Hive throws [HiveError: Cannot write, unknown type] on first use.
///
/// All data is stored / retrieved as plain Maps (JSON-compatible),
/// which is consistent with how [LocalCacheService] works.
class HiveService {
  static const String userBoxKey = 'users_box';
  static const String expenseBoxKey = 'expenses_box';
  static const String categoryBoxKey = 'categories_box';
  static const String transactionBoxKey = 'transactions_box';
  static const String settingsBoxKey = 'settings_box';

  // Untyped boxes — safe without type adapters
  static late Box<dynamic> _userBox;
  static late Box<dynamic> _expenseBox;
  static late Box<dynamic> _categoryBox;
  static late Box<dynamic> _transactionBox;
  static late Box<dynamic> _settingsBox;

  static bool _initialized = false;

  /// Initialize Hive and open all boxes.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();

      // Open all boxes concurrently for faster startup.
      // Use untyped dynamic boxes — no adapters needed.
      final boxes = await Future.wait([
        Hive.openBox<dynamic>(userBoxKey),
        Hive.openBox<dynamic>(expenseBoxKey),
        Hive.openBox<dynamic>(categoryBoxKey),
        Hive.openBox<dynamic>(transactionBoxKey),
        Hive.openBox<dynamic>(settingsBoxKey),
      ]);

      _userBox = boxes[0];
      _expenseBox = boxes[1];
      _categoryBox = boxes[2];
      _transactionBox = boxes[3];
      _settingsBox = boxes[4];
      _initialized = true;
    } catch (e, stack) {
      debugPrint('[HiveService] Initialization failed: $e\n$stack');
      // Try to recover by deleting corrupt boxes and re-initializing
      try {
        await Hive.deleteBoxFromDisk(userBoxKey);
        await Hive.deleteBoxFromDisk(expenseBoxKey);
        await Hive.deleteBoxFromDisk(categoryBoxKey);
        await Hive.deleteBoxFromDisk(transactionBoxKey);
        await Hive.deleteBoxFromDisk(settingsBoxKey);

        final boxes = await Future.wait([
          Hive.openBox<dynamic>(userBoxKey),
          Hive.openBox<dynamic>(expenseBoxKey),
          Hive.openBox<dynamic>(categoryBoxKey),
          Hive.openBox<dynamic>(transactionBoxKey),
          Hive.openBox<dynamic>(settingsBoxKey),
        ]);
        _userBox = boxes[0];
        _expenseBox = boxes[1];
        _categoryBox = boxes[2];
        _transactionBox = boxes[3];
        _settingsBox = boxes[4];
        _initialized = true;
        debugPrint('[HiveService] Recovered after deleting corrupt boxes');
      } catch (e2) {
        debugPrint('[HiveService] Recovery also failed: $e2');
        rethrow;
      }
    }
  }

  static void _assertInitialized() {
    if (!_initialized) {
      throw StateError(
          '[HiveService] Not initialized. Call HiveService.initialize() first.');
    }
  }

  /// Clear all data (use with caution)
  static Future<void> clearAll() async {
    _assertInitialized();
    await Future.wait([
      _userBox.clear(),
      _expenseBox.clear(),
      _categoryBox.clear(),
      _transactionBox.clear(),
      _settingsBox.clear(),
    ]);
  }

  // ── Settings operations ──────────────────────────────────────────────────

  static Future<void> setSetting(String key, String value) async {
    _assertInitialized();
    await _settingsBox.put(key, value);
  }

  static String? getSetting(String key) {
    if (!_initialized) return null;
    final val = _settingsBox.get(key);
    return val as String?;
  }

  static Future<void> deleteSetting(String key) async {
    _assertInitialized();
    await _settingsBox.delete(key);
  }

  // ── User operations ──────────────────────────────────────────────────────

  static Future<void> saveUserMap(Map<String, dynamic> user) async {
    _assertInitialized();
    await _userBox.put('current_user', user);
  }

  static Map<String, dynamic>? getUserMap() {
    if (!_initialized) return null;
    final val = _userBox.get('current_user');
    if (val == null) return null;
    try {
      return Map<String, dynamic>.from(val as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteUser() async {
    _assertInitialized();
    await _userBox.delete('current_user');
  }

  // ── Expense count ────────────────────────────────────────────────────────

  static int getExpenseCount() {
    if (!_initialized) return 0;
    return _expenseBox.length;
  }

  // ── Transaction count ────────────────────────────────────────────────────

  static int getTransactionCount() {
    if (!_initialized) return 0;
    return _transactionBox.length;
  }
}
