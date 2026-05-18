import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/supabase_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/database/local_cache_service.dart';
import '../../../core/database/chat_reconciliation_engine.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final groupServiceProvider = Provider<GroupService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  ref.read(realtimeSyncManagerProvider); // warm up sync manager
  return GroupService(client, user?.id);
});

final groupsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(groupServiceProvider);
  return service.getGroupsStream();
});

final groupDetailStreamProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, groupId) {
  final service = ref.watch(groupServiceProvider);
  return service.getGroupByIdStream(groupId);
});

final groupMembersStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
  final service = ref.watch(groupServiceProvider);
  return service.getGroupMembersStream(groupId);
});

final groupExpensesStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
  final service = ref.watch(groupServiceProvider);
  return service.getGroupExpensesStream(groupId);
});

final groupChatStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
  final service = ref.watch(groupServiceProvider);
  return service.getGroupChatStream(groupId);
});

final groupSettlementsStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
  final service = ref.watch(groupServiceProvider);
  return service.getSettlementsStream(groupId);
});

final recentSettlementsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  final userId = user?.id;
  if (userId == null) return [];

  final cached = LocalCacheService.getCachedList('all_recent_settlements_$userId');

  try {
    final memberships = await client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);

    if (memberships.isEmpty) {
      LocalCacheService.cacheData('all_recent_settlements_$userId', []);
      return [];
    }

    final groupIds = memberships.map((m) => m['group_id'] as String).toList();

    final settlements = await client
        .from('settlements')
        .select()
        .filter('group_id', 'in', groupIds)
        .order('settled_at', ascending: false)
        .limit(30);

    if (settlements.isEmpty) {
      LocalCacheService.cacheData('all_recent_settlements_$userId', []);
      return [];
    }

    final payerIds = settlements.map((s) => s['paid_by']).toList();
    final receiverIds = settlements.map((s) => s['paid_to']).toList();
    final uniqueUserIds = <String>{
      ...payerIds.map((id) => id.toString()),
      ...receiverIds.map((id) => id.toString()),
    }.toList();

    final profilesFuture = client
        .from('profiles')
        .select('user_id, display_name')
        .filter('user_id', 'in', uniqueUserIds);

    final groupsFuture = client
        .from('groups')
        .select('id, name')
        .filter('id', 'in', groupIds);

    final results = await Future.wait([profilesFuture, groupsFuture]);
    final profiles = List<Map<String, dynamic>>.from(results[0]);
    final groups = List<Map<String, dynamic>>.from(results[1]);

    final parsed = settlements.map((s) {
      final group = groups.firstWhere(
        (g) => g['id'].toString() == s['group_id']?.toString(),
        orElse: () => {},
      );
      final payer = profiles.firstWhere(
        (p) => p['user_id'] == s['paid_by'],
        orElse: () => {},
      );
      final receiver = profiles.firstWhere(
        (p) => p['user_id'] == s['paid_to'],
        orElse: () => {},
      );
      return {
        ...s,
        'group_name': group['name'] ?? 'Unknown Group',
        'payer_name': payer['display_name'] ?? 'Someone',
        'receiver_name': receiver['display_name'] ?? 'Someone',
      };
    }).toList();

    LocalCacheService.cacheData('all_recent_settlements_$userId', parsed);
    return parsed;
  } catch (e) {
    if (cached.isNotEmpty) {
      return cached;
    }
    rethrow;
  }
});

// ─── Service ──────────────────────────────────────────────────────────────────

class GroupService {
  final SupabaseClient _client;
  final String? _userId;
  static const _uuid = Uuid();

  GroupService(this._client, this._userId);

  // ── Groups List ─────────────────────────────────────────────────────────────
  // Stream watches group_members for the current user.
  // On any change (join/leave/removal), fetches full group objects.
  // Uses merge-write cache: only writes if data is newer.

  Stream<List<Map<String, dynamic>>> getGroupsStream() {
    if (_userId == null) return Stream.value([]);

    final controller = StreamController<List<Map<String, dynamic>>>();

    // Instant cache render
    final cached = LocalCacheService.getCachedList('groups_$_userId');
    if (cached.isNotEmpty) controller.add(cached);

    final subscription = _client
        .from('group_members')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .asyncMap((memberships) async {
          if (memberships.isEmpty) return <Map<String, dynamic>>[];
          final groupIds = memberships.map((m) => m['group_id']).toList();
          final groups = await _client
              .from('groups')
              .select('id, name, description, invite_code, created_by, created_at')
              .filter('id', 'in', groupIds)
              .order('created_at', ascending: false);
          return List<Map<String, dynamic>>.from(groups);
        })
        .listen((data) {
          // Merge-write: always write (server is authoritative for groups list)
          LocalCacheService.cacheData('groups_$_userId', data);
          if (!controller.isClosed) controller.add(data);
        }, onError: (_) {});

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // ── Group Detail ────────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>?> getGroupByIdStream(String groupId) {
    if (_userId == null) return Stream.value(null);

    final controller = StreamController<Map<String, dynamic>?>();

    final cached = LocalCacheService.getCachedMap('group_detail_$groupId');
    if (cached != null) controller.add(cached);

    final subscription = _client
        .from('groups')
        .stream(primaryKey: ['id'])
        .eq('id', groupId)
        .asyncMap((list) async {
          if (list.isEmpty) return null;
          final group = Map<String, dynamic>.from(list.first);
          final code = group['invite_code']?.toString().trim();
          if (code == null || code.length != 6) {
            final newCode = _generateInviteCode();
            try {
              await _client
                  .from('groups')
                  .update({'invite_code': newCode})
                  .eq('id', groupId);
              group['invite_code'] = newCode;
            } catch (_) {
              group['invite_code'] = newCode;
            }
          }
          return group;
        })
        .listen((data) {
          if (data != null) {
            // Merge-write: only update non-stale fields
            final existing = LocalCacheService.getCachedMap('group_detail_$groupId');
            final merged = {...?existing, ...data};
            LocalCacheService.cacheData('group_detail_$groupId', merged);
          }
          if (!controller.isClosed) controller.add(data);
        }, onError: (_) {});

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // ── Group Members ───────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getGroupMembersStream(String groupId) {
    if (_userId == null) return Stream.value([]);

    final controller = StreamController<List<Map<String, dynamic>>>();

    // 1. Load cached members and deduplicate by user_id to prevent duplicates
    final cached = LocalCacheService.getCachedList('group_members_$groupId');
    if (cached.isNotEmpty) {
      final uniqueCached = <String, Map<String, dynamic>>{};
      for (final m in cached) {
        final uId = m['user_id'] as String?;
        if (uId != null) {
          // If already exists, prefer admin one or keep the first one
          if (!uniqueCached.containsKey(uId) || m['is_admin'] == true) {
            uniqueCached[uId] = Map<String, dynamic>.from(m);
          }
        }
      }
      controller.add(uniqueCached.values.toList());
    }

    final subscription = _client
        .from('group_members')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .asyncMap((members) async {
          if (members.isEmpty) return <Map<String, dynamic>>[];

          // 2. Deduplicate incoming realtime members by user_id
          final uniqueMembers = <String, Map<String, dynamic>>{};
          for (final m in members) {
            final uId = m['user_id'] as String?;
            if (uId != null) {
              if (!uniqueMembers.containsKey(uId) || m['is_admin'] == true) {
                uniqueMembers[uId] = m;
              }
            }
          }
          final filteredMembers = uniqueMembers.values.toList();

          final userIds = filteredMembers.map((m) => m['user_id']).toList();
          final profiles = await _client
              .from('profiles')
              .select('user_id, display_name')
              .filter('user_id', 'in', userIds);

          return filteredMembers.map((m) {
            final profile = profiles.firstWhere(
              (p) => p['user_id'] == m['user_id'],
              orElse: () => {},
            );
            return {...m, 'display_name': profile['display_name']};
          }).toList();
        })
        .listen((data) {
          // Server is authoritative for member list
          LocalCacheService.cacheData('group_members_$groupId', data);
          if (!controller.isClosed) controller.add(data);
        }, onError: (_) {});

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // ── Group Expenses ──────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getGroupExpensesStream(String groupId) {
    if (_userId == null) return Stream.value([]);

    final controller = StreamController<List<Map<String, dynamic>>>();

    final cached = LocalCacheService.getCachedList('group_expenses_$groupId');
    if (cached.isNotEmpty) controller.add(cached);

    final subscription = _client
        .from('group_expenses')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('expense_date', ascending: false)
        .listen((data) {
          // Merge with any temp entries (optimistic) that haven't confirmed yet
          final currentCache = LocalCacheService.getCachedList('group_expenses_$groupId');
          final tempEntries = currentCache.where((e) =>
            e['id']?.toString().startsWith('temp_') == true).toList();

          // Combine: temp entries on top, then confirmed server entries
          final serverIds = data.map((e) => e['id']?.toString()).toSet();
          final filteredTemps = tempEntries
              .where((t) => !serverIds.contains(t['id']?.toString()))
              .toList();

          final merged = [...filteredTemps, ...data];
          LocalCacheService.cacheData('group_expenses_$groupId', merged);
          if (!controller.isClosed) controller.add(merged);
        }, onError: (_) {});

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // ── Group Chat Stream ───────────────────────────────────────────────────────
  // This raw stream feeds the ChatReconciliationEngine.
  // The UI should watch reconciledChatStreamProvider, not this directly.
  // This stream is kept for legacy compatibility with any existing watchers.

  Stream<List<Map<String, dynamic>>> getGroupChatStream(String groupId) {
    if (_userId == null) return Stream.value([]);

    final controller = StreamController<List<Map<String, dynamic>>>();

    final cached = LocalCacheService.getCachedList('group_chats_$groupId');
    if (cached.isNotEmpty) controller.add(cached);

    // Track server IDs to avoid double-counting same message
    final seenServerIds = <String>{};

    final subscription = _client
        .from('group_chats')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .listen((rows) {
          seenServerIds.clear();
          final deduped = <Map<String, dynamic>>[];
          for (final row in rows) {
            final id = row['id']?.toString() ?? '';
            if (id.isNotEmpty && !seenServerIds.contains(id)) {
              seenServerIds.add(id);
              deduped.add(row);
            }
          }
          // Only write to legacy cache — reconciliation engine gets its own cache
          LocalCacheService.cacheData('group_chats_$groupId', deduped);
          if (!controller.isClosed) controller.add(deduped);
        }, onError: (_) {});

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // ── Settlements ─────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getSettlementsStream(String groupId) {
    if (_userId == null) return Stream.value([]);

    final controller = StreamController<List<Map<String, dynamic>>>();

    final cached = LocalCacheService.getCachedList('settlements_$groupId');
    if (cached.isNotEmpty) controller.add(cached);

    final subscription = _client
        .from('settlements')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('settled_at', ascending: false)
        .listen((data) {
          // Merge with temp entries
          final currentCache = LocalCacheService.getCachedList('settlements_$groupId');
          final tempEntries = currentCache
              .where((e) => e['id']?.toString().startsWith('temp_') == true)
              .toList();
          final serverIds = data.map((e) => e['id']?.toString()).toSet();
          final filteredTemps = tempEntries
              .where((t) => !serverIds.contains(t['id']?.toString()))
              .toList();

          final merged = [...filteredTemps, ...data];
          LocalCacheService.cacheData('settlements_$groupId', merged);
          if (!controller.isClosed) controller.add(merged);
        }, onError: (_) {});

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // ─── Mutations ──────────────────────────────────────────────────────────────

  String _generateInviteCode() {
    final rand = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (i) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> createGroup(String name, String description, {String? imageUrl}) async {
    if (_userId == null) throw Exception('User not authenticated');

    final response = await _client.from('groups').insert({
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'created_by': _userId,
      'invite_code': _generateInviteCode(),
    }).select().single();

    if (response['id'] != null) {
      await _client.from('group_members').insert({
        'group_id': response['id'],
        'user_id': _userId,
        'is_admin': true,
      });
      // Immediately invalidate groups cache so new group appears
      await LocalCacheService.invalidate('groups_$_userId');
    }
  }

  Future<void> joinGroup(String inviteCode) async {
    if (_userId == null) throw Exception('User not authenticated');

    final group = await _client
        .from('groups')
        .select('id, name, invite_code')
        .eq('invite_code', inviteCode.toUpperCase().trim())
        .maybeSingle();

    if (group == null) throw Exception('Invalid invite code');

    final existing = await _client
        .from('group_members')
        .select('id')
        .eq('group_id', group['id'])
        .eq('user_id', _userId)
        .maybeSingle();

    if (existing != null) throw Exception('Already a member of this group');

    await _client.from('group_members').insert({
      'group_id': group['id'],
      'user_id': _userId,
      'is_admin': false,
    });

    // Bust groups cache so list refreshes immediately
    await LocalCacheService.invalidate('groups_$_userId');
  }

  // ── Send Chat Message ───────────────────────────────────────────────────────
  // Returns the client_id used — callers must pass this to the reconciliation
  // engine for proper pending→synced promotion.

  Future<({String clientId, String serverId})> sendChatMessage({
    required String groupId,
    required String message,
    required ChatReconciliationEngine engine,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    // 1. Generate stable client_id — same UUID goes into optimistic + DB row
    final clientId = engine.addOptimistic(
      userId: _userId,
      message: message,
    );

    try {
      // 2. Insert with client_id so receivers can deduplicate
      final result = await _client.from('group_chats').insert({
        'group_id': groupId,
        'user_id': _userId,
        'message': message,
        'client_id': clientId,
      }).select().single();

      final serverId = result['id']?.toString() ?? '';

      // 3. Promote optimistic → synced in the engine
      engine.confirmMessage(clientId, serverId);

      return (clientId: clientId, serverId: serverId);
    } catch (e) {
      // 4. Mark failed — UI shows retry indicator
      engine.markFailed(clientId);
      rethrow;
    }
  }

  /// Retry a previously failed message.
  Future<void> retryChatMessage({
    required String groupId,
    required String clientId,
    required String message,
    required ChatReconciliationEngine engine,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    engine.markRetry(clientId);

    try {
      final result = await _client.from('group_chats').insert({
        'group_id': groupId,
        'user_id': _userId,
        'message': message,
        'client_id': clientId,
      }).select().single();

      engine.confirmMessage(clientId, result['id']?.toString() ?? '');
    } catch (_) {
      engine.markFailed(clientId);
      rethrow;
    }
  }

  // ── Group Expenses ──────────────────────────────────────────────────────────

  Future<void> addGroupExpense({
    required String groupId,
    required String description,
    required double amount,
    required String category,
    String splitType = 'equal',
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final tempId = 'temp_${_uuid.v4()}';
    final tempData = {
      'id': tempId,
      'group_id': groupId,
      'paid_by': _userId,
      'amount': amount,
      'description': description,
      'category': category,
      'split_type': splitType,
      'expense_date': DateTime.now().toIso8601String(),
    };

    // Optimistic insert at head
    final cached = LocalCacheService.getCachedList('group_expenses_$groupId');
    await LocalCacheService.cacheData('group_expenses_$groupId', [tempData, ...cached]);

    try {
      final expense = await _client.from('group_expenses').insert({
        'group_id': groupId,
        'paid_by': _userId,
        'amount': amount,
        'description': description,
        'category': category,
        'split_type': splitType,
      }).select().single();

      if (splitType == 'equal') {
        final members = await _client
            .from('group_members')
            .select('user_id')
            .eq('group_id', groupId);
        if (members.isNotEmpty) {
          final splitAmount = amount / members.length;
          await _client.from('expense_splits').insert(
            members.map((m) => {
              'group_expense_id': expense['id'],
              'user_id': m['user_id'],
              'amount': splitAmount,
            }).toList(),
          );
        }
      }
      // Realtime stream will replace temp entry with confirmed one
    } catch (_) {
      // Revert optimistic
      final current = LocalCacheService.getCachedList('group_expenses_$groupId');
      await LocalCacheService.cacheData('group_expenses_$groupId',
          current.where((e) => e['id'] != tempId).toList());
      rethrow;
    }
  }

  // ── Settlements ─────────────────────────────────────────────────────────────

  Future<void> createSettlement({
    required String groupId,
    required String paidTo,
    required double amount,
    String? note,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final tempId = 'temp_${_uuid.v4()}';
    final tempData = {
      'id': tempId,
      'group_id': groupId,
      'paid_by': _userId,
      'paid_to': paidTo,
      'amount': amount,
      'note': note,
      'settled_at': DateTime.now().toIso8601String(),
    };

    final cached = LocalCacheService.getCachedList('settlements_$groupId');
    await LocalCacheService.cacheData('settlements_$groupId', [tempData, ...cached]);

    try {
      await _client.from('settlements').insert({
        'group_id': groupId,
        'paid_by': _userId,
        'paid_to': paidTo,
        'amount': amount,
        'note': note,
      });
    } catch (_) {
      final current = LocalCacheService.getCachedList('settlements_$groupId');
      await LocalCacheService.cacheData('settlements_$groupId',
          current.where((e) => e['id'] != tempId).toList());
      rethrow;
    }
  }

  // ── Member Management ───────────────────────────────────────────────────────

  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
    await _clearGroupCaches(groupId);
    await LocalCacheService.invalidate('groups_$_userId');
  }

  /// Remove a member with instant local cache invalidation BEFORE the DB call.
  /// The removed user's membership guard will detect the change and navigate away.
  Future<void> removeGroupMember(String groupId, String targetUserId) async {
    if (_userId == null) throw Exception('User not authenticated');

    // 1. Optimistic local update: remove from cache immediately
    final cached = LocalCacheService.getCachedList('group_members_$groupId');
    await LocalCacheService.cacheData(
      'group_members_$groupId',
      cached.where((m) => m['user_id'] != targetUserId).toList(),
    );

    // 2. DB delete — RLS enforces admin check
    final response = await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', targetUserId)
        .select();

    if ((response as List).isEmpty) {
      // Revert optimistic update
      await LocalCacheService.cacheData('group_members_$groupId', cached);
      throw Exception(
        'Remove failed: RLS policy blocked this operation. '
        'Ensure the admins_can_remove_members policy is configured in Supabase.',
      );
    }

    // 3. Bust the removed user's group cache entries
    // (They'll be kicked when their membership guard fires)
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<void> _clearGroupCaches(String groupId) async {
    await Future.wait([
      LocalCacheService.invalidate('group_detail_$groupId'),
      LocalCacheService.invalidate('group_expenses_$groupId'),
      LocalCacheService.invalidate('group_chats_$groupId'),
      LocalCacheService.invalidate('chat_v2_$groupId'),
      LocalCacheService.invalidate('group_members_$groupId'),
      LocalCacheService.invalidate('settlements_$groupId'),
    ]);
  }
}
