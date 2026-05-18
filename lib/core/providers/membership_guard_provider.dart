import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/supabase_service.dart';
import '../providers/auth_provider.dart';
import '../database/local_cache_service.dart';

// ─── Membership Status ───────────────────────────────────────────────────────

enum MembershipStatus {
  loading,
  active,       // user is a confirmed member
  removed,      // user was kicked by admin
  notMember,    // user was never a member (invalid deep-link)
  groupDeleted, // group was deleted
}

// ─── Membership Guard Provider ───────────────────────────────────────────────

/// Watches the current user's membership in a specific group in real-time.
/// If the user is removed, emits [MembershipStatus.removed] INSTANTLY.
///
/// Uses a Supabase realtime channel subscribed to the group_members table
/// so it can detect DELETE events even when no stream is actively reading.
final membershipGuardProvider =
    StreamProvider.family<MembershipStatus, String>((ref, groupId) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  final userId = user?.id;

  if (userId == null) {
    return Stream.value(MembershipStatus.notMember);
  }

  final controller = StreamController<MembershipStatus>();

  // 1. Emit immediately from cache — prevents blank screen flicker
  final cachedMembers = LocalCacheService.getCachedList('group_members_$groupId');
  if (cachedMembers.isNotEmpty) {
    final isCachedMember = cachedMembers.any((m) => m['user_id'] == userId);
    controller.add(isCachedMember ? MembershipStatus.active : MembershipStatus.removed);
  } else {
    controller.add(MembershipStatus.loading);
  }

  // 2. Also do an immediate DB check to confirm current state
  client
      .from('group_members')
      .select('user_id')
      .eq('group_id', groupId)
      .eq('user_id', userId)
      .maybeSingle()
      .then((row) {
        if (controller.isClosed) return;
        if (row == null) {
          _clearGroupCaches(groupId, userId);
          controller.add(MembershipStatus.removed);
        } else {
          controller.add(MembershipStatus.active);
        }
      })
      .catchError((_) {
        // fail-open: don't kick on network error
      });

  // 3. Subscribe to realtime changes on group_members for this group
  //    supabase_flutter 2.x uses the string-based filter API
  final channel = client.channel('membership_${groupId}_$userId');

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'group_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'group_id',
          value: groupId,
        ),
        callback: (payload) {
          if (controller.isClosed) return;
          // Any change to group_members — re-verify this user's membership
          client
              .from('group_members')
              .select('user_id')
              .eq('group_id', groupId)
              .eq('user_id', userId)
              .maybeSingle()
              .then((row) {
                if (controller.isClosed) return;
                if (row == null) {
                  _clearGroupCaches(groupId, userId);
                  controller.add(MembershipStatus.removed);
                } else {
                  controller.add(MembershipStatus.active);
                }
              })
              .catchError((_) {
                // fail-open on network error
              });
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'groups',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: groupId,
        ),
        callback: (payload) {
          if (!controller.isClosed) {
            _clearGroupCaches(groupId, userId);
            controller.add(MembershipStatus.groupDeleted);
          }
        },
      )
      .subscribe();

  controller.onCancel = () {
    client.removeChannel(channel);
    controller.close();
  };

  return controller.stream;
});

/// Clears all caches related to a group for a given user.
/// Called immediately on removal — before any network round-trip completes.
Future<void> _clearGroupCaches(String groupId, String userId) async {
  await Future.wait([
    LocalCacheService.invalidate('group_detail_$groupId'),
    LocalCacheService.invalidate('group_members_$groupId'),
    LocalCacheService.invalidate('group_expenses_$groupId'),
    LocalCacheService.invalidate('group_chats_$groupId'),
    LocalCacheService.invalidate('chat_v2_$groupId'),
    LocalCacheService.invalidate('settlements_$groupId'),
    LocalCacheService.invalidate('groups_$userId'),
  ]);
}
