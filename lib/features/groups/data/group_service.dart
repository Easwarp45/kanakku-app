import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/supabase_service.dart';
import '../../../core/providers/auth_provider.dart';

final groupServiceProvider = Provider<GroupService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  return GroupService(client, user?.id);
});

final groupsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(groupServiceProvider);
  return service.getGroupsStream();
});

final groupDetailStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, groupId) {
  final service = ref.watch(groupServiceProvider);
  return service.getGroupByIdStream(groupId);
});

final groupMembersStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
  final service = ref.watch(groupServiceProvider);
  return service.getGroupMembersStream(groupId);
});

final groupExpensesStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
  final service = ref.watch(groupServiceProvider);
  return service.getGroupExpensesStream(groupId);
});

final groupChatStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
  final service = ref.watch(groupServiceProvider);
  return service.getGroupChatStream(groupId);
});

final groupSettlementsStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
  final service = ref.watch(groupServiceProvider);
  return service.getSettlementsStream(groupId);
});

class GroupService {
  final SupabaseClient _client;
  final String? _userId;

  GroupService(this._client, this._userId);

  Stream<List<Map<String, dynamic>>> getGroupsStream() {
    if (_userId == null) return Stream.value([]);
    
    // First, stream the memberships for the current user
    return _client
        .from('group_members')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId!)
        .asyncMap((memberships) async {
          if (memberships.isEmpty) return [];
          
          final groupIds = memberships.map((m) => m['group_id']).toList();
          
          // Fetch the group details for these memberships
          final groups = await _client
              .from('groups')
              .select()
              .filter('id', 'in', groupIds)
              .order('created_at', ascending: false);
              
          return List<Map<String, dynamic>>.from(groups);
        });
  }

  Stream<Map<String, dynamic>?> getGroupByIdStream(String groupId) {
    if (_userId == null) return Stream.value(null);
    return _client
        .from('groups')
        .stream(primaryKey: ['id'])
        .eq('id', groupId)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  Stream<List<Map<String, dynamic>>> getGroupMembersStream(String groupId) {
    if (_userId == null) return Stream.value([]);
    // Joining with profiles table to get real names
    return _client
        .from('group_members')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .asyncMap((members) async {
          if (members.isEmpty) return [];
          
          final userIds = members.map((m) => m['user_id']).toList();
          final profiles = await _client
              .from('profiles')
              .select('user_id, display_name')
              .filter('user_id', 'in', userIds);
          
          // Merge profile data into members list
          return members.map((m) {
            final profile = profiles.firstWhere(
              (p) => p['user_id'] == m['user_id'],
              orElse: () => {},
            );
            return {
              ...m,
              'display_name': profile['display_name'],
            };
          }).toList();
        });
  }

  Stream<List<Map<String, dynamic>>> getGroupExpensesStream(String groupId) {
    if (_userId == null) return Stream.value([]);
    return _client
        .from('group_expenses')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('expense_date', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> getGroupChatStream(String groupId) {
    if (_userId == null) return Stream.value([]);
    return _client
        .from('group_chats')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> getSettlementsStream(String groupId) {
    if (_userId == null) return Stream.value([]);
    return _client
        .from('settlements')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('settled_at', ascending: false);
  }

  Future<void> createGroup(String name, String description, {String? imageUrl}) async {
    if (_userId == null) throw Exception('User not authenticated');
    
    final response = await _client.from('groups').insert({
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'created_by': _userId,
    }).select().single();
    
    if (response['id'] != null) {
      await _client.from('group_members').insert({
        'group_id': response['id'],
        'user_id': _userId,
        'is_admin': true,
      });
    }
  }

  Future<void> joinGroup(String inviteCode) async {
    if (_userId == null) throw Exception('User not authenticated');

    final group = await _client
        .from('groups')
        .select()
        .eq('invite_code', inviteCode)
        .maybeSingle();

    if (group == null) throw Exception('Invalid invite code');

    await _client.from('group_members').insert({
      'group_id': group['id'],
      'user_id': _userId,
      'is_admin': false,
    });
  }

  Future<void> addGroupExpense({
    required String groupId,
    required String description,
    required double amount,
    required String category,
    String splitType = 'equal',
  }) async {
    if (_userId == null) throw Exception('User not authenticated');
    
    // 1. Create the expense
    final expense = await _client.from('group_expenses').insert({
      'group_id': groupId,
      'paid_by': _userId,
      'amount': amount,
      'description': description,
      'category': category,
      'split_type': splitType,
    }).select().single();

    // 2. Create splits (Equal split by default)
    if (splitType == 'equal') {
      final members = await _client.from('group_members').select('user_id').eq('group_id', groupId);
      if (members.isNotEmpty) {
        final splitAmount = amount / members.length;
        final splits = members.map((m) => {
          'group_expense_id': expense['id'],
          'user_id': m['user_id'],
          'amount': splitAmount,
        }).toList();
        
        await _client.from('expense_splits').insert(splits);
      }
    }
  }

  Future<void> createSettlement({
    required String groupId,
    required String paidTo,
    required double amount,
    String? note,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    await _client.from('settlements').insert({
      'group_id': groupId,
      'paid_by': _userId,
      'paid_to': paidTo,
      'amount': amount,
      'note': note,
    });
  }

  Future<void> sendChatMessage(String groupId, String message) async {
    if (_userId == null) throw Exception('User not authenticated');
    
    await _client.from('group_chats').insert({
      'group_id': groupId,
      'user_id': _userId,
      'message': message,
    });
  }

  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
  }
}
