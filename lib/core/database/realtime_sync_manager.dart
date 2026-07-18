import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_cache_service.dart';
import 'schema_constants.dart';
import '../../features/notifications/services/notification_service.dart';

/// Priority-ordered offline sync queue manager.
/// Messages sync first, then settlements, then expenses/income/goals, then groups.
class RealtimeSyncManager {
  final SupabaseClient _client;
  bool _isSyncing = false;
  Timer? _syncTimer;

  // Priority order for table sync (lower = higher priority)
  static const Map<String, int> _tablePriority = {
    'group_chats': 0,
    'settlements': 1,
    'expenses': 2,
    'income': 3,
    'financial_goals': 4,
    'budgets': 5,
    'group_expenses': 6,
    'groups': 7,
    'group_members': 8,
  };

  static const Map<String, Set<String>> _writableByTable = {
    'expenses': SchemaColumns.expensesWritable,
    'income': SchemaColumns.incomeWritable,
    'budgets': SchemaColumns.budgetsWritable,
    'financial_goals': SchemaColumns.financialGoalsWritable,
    'groups': SchemaColumns.groupsWritable,
    'group_members': SchemaColumns.groupMembersWritable,
    'group_expenses': SchemaColumns.groupExpensesWritable,
    'expense_splits': SchemaColumns.expenseSplitsWritable,
    'settlements': SchemaColumns.settlementsWritable,
    'group_chats': SchemaColumns.groupChatsWritable,
    'profiles': SchemaColumns.profilesWritable,
    'notifications': SchemaColumns.notificationsWritable,
  };

  RealtimeSyncManager(this._client) {
    // Initial sync attempt
    Future.delayed(const Duration(seconds: 3), triggerSync);
    // Periodic sync every 20 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) => triggerSync());
  }

  Future<void> _insertSyncNotification(String title, String body) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final payload = {
        'user_id': user.id,
        'title': title,
        'body': body,
        'type': 'offline_sync',
        'priority': 'low',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'source': 'local',
      };
      await _client.from('notifications').insert(payload);
    } catch (_) {}
  }

  /// Drain the pending queue with priority ordering and exponential backoff
  Future<void> triggerSync() async {
    if (_isSyncing) return;
    
    final actions = LocalCacheService.getPendingActionsWithIndices();
    if (actions.isEmpty) return;

    _isSyncing = true;

    // Trigger Sync Started notification
    NotificationService().showNotification(
      id: 9001,
      title: 'Sync Started 🔄',
      body: 'Synchronizing ${actions.length} pending actions with the server...',
      type: 'offline_sync',
    );
    _insertSyncNotification(
      'Sync Started 🔄',
      'Synchronizing ${actions.length} pending actions with the server...',
    );
    
    // Sort by priority then timestamp (stable sort)
    final sorted = List<Map<String, dynamic>>.from(actions);
    sorted.sort((a, b) {
      final pa = _tablePriority[a['path']] ?? 99;
      final pb = _tablePriority[b['path']] ?? 99;
      if (pa != pb) return pa.compareTo(pb);
      return (a['timestamp'] as String).compareTo(b['timestamp'] as String);
    });

    // Track which hive keys to delete (by their unique keys)
    final Set<String> processedHashes = {};
    final List<dynamic> keysToDelete = [];

    try {
      final user = _client.auth.currentUser;
      for (int i = 0; i < sorted.length; i++) {
        final action = sorted[i];
        final queueKey = action['_queueKey'];
        if (queueKey == null) {
          continue;
        }
        
        // Deduplication: skip if same action hash already processed this session
        final hash = _actionHash(action);
        if (processedHashes.contains(hash)) {
          keysToDelete.add(queueKey);
          continue;
        }
        
        final type = action['actionType'] as String;
        final path = action['path'] as String;
        final payload = Map<String, dynamic>.from(action['payload']);
        
        // Skip temp IDs — let the realtime stream resolve them
        if (path == 'group_chats') {
          // For chat messages, do a direct insert (no queue replay needed 
          // since sendChatMessage already calls Supabase directly)
          keysToDelete.add(queueKey);
          processedHashes.add(hash);
          continue;
        }

        bool success = false;
        try {
          if (type == 'insert') {
            final cleanPayload = _sanitizePayload(path, payload)
              ..remove('id');
            final response = await _client.from(path).insert(cleanPayload).select().single();
            final confirmed = Map<String, dynamic>.from(response);

            // Reconcile ID in local cache
            final tempId = payload['id']?.toString();
            if (tempId != null && tempId.startsWith('temp_') && user != null) {
              final cacheKey = '${path}_${user.id}';
              final cached = LocalCacheService.getCachedData(cacheKey) ?? [];
              final updated = List<Map<String, dynamic>>.from(cached).map((e) {
                if (e['id']?.toString() == tempId) {
                  return confirmed;
                }
                return e;
              }).toList();
              await LocalCacheService.cacheData(cacheKey, updated);
            }

            success = true;
          } else if (type == 'update') {
            final id = payload['id']?.toString();
            if (id == null || id.startsWith('temp_')) {
              // Skip — temp ID, real record not created yet
              success = true; 
            } else {
              final cleanPayload = _sanitizePayload(path, payload)..remove('id');
              await _client.from(path).update(cleanPayload).eq('id', id);
              success = true;
            }
          } else if (type == 'delete') {
            final id = payload['id']?.toString();
            if (id != null && !id.startsWith('temp_')) {
              await _client.from(path).delete().eq('id', id);
            }
            success = true;
          }
        } on PostgrestException catch (e) {
          // A permanent database logic/constraint/RLS error: mark as success to clear from queue
          success = true;
          // Log standard print for audit trail
          debugPrint('[SYNC ERROR] Permanent PostgrestException on $path: $e');
        } catch (_) {
          // Network error — stop processing, retry on next cycle
          break;
        }

        if (success) {
          keysToDelete.add(queueKey);
          processedHashes.add(hash);
        }
      }
    } finally {
      // Delete processed entries by key
      for (final key in keysToDelete) {
        try {
          await LocalCacheService.clearPendingActionByKey(key);
        } catch (_) {}
      }
      _isSyncing = false;

      // Determine sync outcome and notify
      final currentQueue = LocalCacheService.getPendingActions();
      if (currentQueue.isEmpty) {
        NotificationService().showNotification(
          id: 9002,
          title: 'Sync Successful ✅',
          body: 'All offline actions successfully synchronized!',
          type: 'offline_sync',
        );
        _insertSyncNotification(
          'Sync Successful ✅',
          'All offline actions successfully synchronized!',
        );
      } else if (keysToDelete.isEmpty) {
        NotificationService().showNotification(
          id: 9003,
          title: 'Sync Failed ❌',
          body: 'Network synchronization failed. Will retry automatically.',
          type: 'offline_sync',
        );
        _insertSyncNotification(
          'Sync Failed ❌',
          'Network synchronization failed. Will retry automatically.',
        );
      } else {
        NotificationService().showNotification(
          id: 9004,
          title: 'Sync Warning ⚠️',
          body: 'Synchronized ${keysToDelete.length} actions, ${currentQueue.length} remaining.',
          type: 'offline_sync',
        );
        _insertSyncNotification(
          'Sync Warning ⚠️',
          'Synchronized ${keysToDelete.length} actions, ${currentQueue.length} remaining.',
        );
      }
    }
  }

  Map<String, dynamic> _sanitizePayload(String path, Map<String, dynamic> payload) {
    final allowed = _writableByTable[path];
    var clean = allowed == null
        ? Map<String, dynamic>.from(payload)
        : filterPayload(payload, allowed);

    if (clean.containsKey('expense_date')) {
      clean['expense_date'] = toDateOnly(clean['expense_date']);
    }
    if (clean.containsKey('income_date')) {
      clean['income_date'] = toDateOnly(clean['income_date']);
    }
    if (clean.containsKey('deadline')) {
      clean['deadline'] = toDateOnly(clean['deadline']);
    }
    if (clean.containsKey('category') &&
        (path == 'expenses' || path == 'group_expenses')) {
      clean['category'] = sanitizeExpenseCategory(clean['category']);
    }
    if (clean.containsKey('source') && path == 'income') {
      clean['source'] = sanitizeIncomeSource(clean['source']);
    }
    if (clean.containsKey('payment_method') && path == 'expenses') {
      clean['payment_method'] = sanitizePaymentMethod(clean['payment_method']);
    }

    clean.removeWhere((k, v) => v == null);
    return clean;
  }

  String _actionHash(Map<String, dynamic> action) {
    return '${action['actionType']}_${action['path']}_${jsonEncode(action['payload'])}';
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}
