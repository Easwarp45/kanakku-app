import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/local_cache_service.dart';

class NotificationRepository {
  final SupabaseClient _client;

  NotificationRepository(this._client);

  /// Fetch notifications with pagination, filters, search query, and offline fallback.
  Future<List<Map<String, dynamic>>> getNotifications({
    required String userId,
    int limit = 50,
    int offset = 0,
    bool? isRead,
    String? type,
    String? searchQuery,
  }) async {
    try {
      var query = _client
          .from('notifications')
          .select()
          .eq('user_id', userId);

      if (isRead != null) {
        query = query.eq('is_read', isRead);
      }
      if (type != null && type != 'All') {
        query = query.eq('type', type);
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('title.ilike.%$searchQuery%,body.ilike.%$searchQuery%');
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      // Cache data locally on first page load
      if (offset == 0) {
        await LocalCacheService.cacheData('cached_notifications_$userId', data);
      }
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      // Offline fallback: load cached data if offset is 0
      if (offset == 0) {
        final cached = LocalCacheService.getCachedList('cached_notifications_$userId');
        if (cached.isNotEmpty) {
          var filtered = cached;
          if (isRead != null) {
            filtered = filtered.where((n) => n['is_read'] == isRead).toList();
          }
          if (type != null && type != 'All') {
            filtered = filtered.where((n) => n['type'] == type).toList();
          }
          if (searchQuery != null && searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            filtered = filtered.where((n) {
              final t = (n['title'] ?? '').toString().toLowerCase();
              final b = (n['body'] ?? '').toString().toLowerCase();
              return t.contains(q) || b.contains(q);
            }).toList();
          }
          return filtered;
        }
      }
      rethrow;
    }
  }

  /// Mark notification as read (with offline queueing support).
  Future<void> markAsRead(String id) async {
    final now = DateTime.now().toIso8601String();
    try {
      await _client.from('notifications').update({
        'is_read': true,
        'read_at': now,
      }).eq('id', id);
    } catch (_) {
      // Offline fallback: queue update
      await LocalCacheService.queueAction(
        actionType: 'update',
        path: 'notifications',
        payload: {
          'id': id,
          'is_read': true,
          'read_at': now,
        },
      );
    }
  }

  /// Delete notification (with offline queueing support).
  Future<void> deleteNotification(String id) async {
    try {
      await _client.from('notifications').delete().eq('id', id);
    } catch (_) {
      // Offline fallback: queue delete
      await LocalCacheService.queueAction(
        actionType: 'delete',
        path: 'notifications',
        payload: {'id': id},
      );
    }
  }

  /// Insert notification locally and remotely.
  Future<void> insertNotification(Map<String, dynamic> notification) async {
    try {
      await _client.from('notifications').insert(notification);
    } catch (_) {
      // Offline fallback: queue insert
      await LocalCacheService.queueAction(
        actionType: 'insert',
        path: 'notifications',
        payload: notification,
      );
    }
  }
}
