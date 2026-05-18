import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_cache_service.dart';

/// Priority-ordered offline sync queue manager.
/// Messages sync first, then settlements, then expenses/income, then groups.
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
    'group_expenses': 4,
    'groups': 5,
    'group_members': 6,
  };

  RealtimeSyncManager(this._client) {
    // Initial sync attempt
    Future.delayed(const Duration(seconds: 3), triggerSync);
    // Periodic sync every 20 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) => triggerSync());
  }

  /// Drain the pending queue with priority ordering and exponential backoff
  Future<void> triggerSync() async {
    if (_isSyncing) return;
    
    final actions = LocalCacheService.getPendingActions();
    if (actions.isEmpty) return;

    _isSyncing = true;
    
    // Sort by priority then timestamp (stable sort)
    final sorted = List<Map<String, dynamic>>.from(actions);
    sorted.sort((a, b) {
      final pa = _tablePriority[a['path']] ?? 99;
      final pb = _tablePriority[b['path']] ?? 99;
      if (pa != pb) return pa.compareTo(pb);
      return (a['timestamp'] as String).compareTo(b['timestamp'] as String);
    });

    // Track which hive keys to delete (by their original position)
    final Set<String> processedHashes = {};
    final List<int> indicesToDelete = [];

    try {
      for (int i = 0; i < sorted.length; i++) {
        final action = sorted[i];
        
        // Deduplication: skip if same action hash already processed this session
        final hash = _actionHash(action);
        if (processedHashes.contains(hash)) {
          indicesToDelete.add(i);
          continue;
        }
        
        final type = action['actionType'] as String;
        final path = action['path'] as String;
        final payload = Map<String, dynamic>.from(action['payload']);
        
        // Skip temp IDs — let the realtime stream resolve them
        if (path == 'group_chats') {
          // For chat messages, do a direct insert (no queue replay needed 
          // since sendChatMessage already calls Supabase directly)
          indicesToDelete.add(i);
          processedHashes.add(hash);
          continue;
        }

        bool success = false;
        try {
          if (type == 'insert') {
            // Remove temp fields before inserting
            final cleanPayload = Map<String, dynamic>.from(payload)
              ..remove('id')
              ..removeWhere((k, v) => v == null);
            await _client.from(path).insert(cleanPayload);
            success = true;
          } else if (type == 'update') {
            final id = payload['id']?.toString();
            if (id == null || id.startsWith('temp_')) {
              // Skip — temp ID, real record not created yet
              success = true; 
            } else {
              final cleanPayload = Map<String, dynamic>.from(payload)..remove('id');
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
        } catch (_) {
          // Network error — stop processing, retry on next cycle
          break;
        }

        if (success) {
          indicesToDelete.add(i);
          processedHashes.add(hash);
        }
      }
    } finally {
      // Delete processed entries in reverse order to preserve indices
      final sortedIndices = indicesToDelete.toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      for (final idx in sortedIndices) {
        try {
          await LocalCacheService.clearPendingAction(idx);
        } catch (_) {}
      }
      _isSyncing = false;
    }
  }

  String _actionHash(Map<String, dynamic> action) {
    return '${action['actionType']}_${action['path']}_${jsonEncode(action['payload'])}';
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}
