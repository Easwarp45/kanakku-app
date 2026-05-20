import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'local_cache_service.dart';

// ─── Message State ──────────────────────────────────────────────────────────

/// Delivery state for every chat message in the system.
/// Never discarded — only promoted upward: pending → synced | failed.
enum MessageState {
  pending,  // optimistic — not yet confirmed by server
  synced,   // server confirmed
  failed,   // send failed, user can retry
}

// ─── Chat Message Model ─────────────────────────────────────────────────────

class ChatMessage {
  final String clientId;     // stable UUID assigned on creation — never changes
  final String? serverId;    // assigned by Supabase after insert
  final String groupId;
  final String userId;
  final String message;
  final DateTime createdAt;
  final MessageState state;

  const ChatMessage({
    required this.clientId,
    this.serverId,
    required this.groupId,
    required this.userId,
    required this.message,
    required this.createdAt,
    this.state = MessageState.synced,
  });

  bool get isPending => state == MessageState.pending;
  bool get isFailed => state == MessageState.failed;
  bool get isSynced => state == MessageState.synced;

  ChatMessage copyWith({
    String? serverId,
    MessageState? state,
  }) {
    return ChatMessage(
      clientId: clientId,
      serverId: serverId ?? this.serverId,
      groupId: groupId,
      userId: userId,
      message: message,
      createdAt: createdAt,
      state: state ?? this.state,
    );
  }

  /// Serialize to JSON for cache storage
  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'server_id': serverId,
    'group_id': groupId,
    'user_id': userId,
    'message': message,
    'created_at': createdAt.toIso8601String(),
    'state': state.name,
  };

  /// Deserialize from cached JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      clientId: json['client_id'] as String,
      serverId: json['server_id'] as String?,
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      state: MessageState.values.firstWhere(
        (s) => s.name == json['state'],
        orElse: () => MessageState.synced,
      ),
    );
  }

  /// Build from a Supabase realtime row.
  /// client_id may be present (from our own send) or absent (from others).
  factory ChatMessage.fromRealtime(Map<String, dynamic> row) {
    return ChatMessage(
      clientId: row['client_id'] as String? ??
          row['id']?.toString() ?? // fallback: use server id as stable key
          const Uuid().v4(),
      serverId: row['id']?.toString(),
      groupId: row['group_id'] as String,
      userId: row['user_id'] as String,
      message: row['message'] as String? ?? '',
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      state: MessageState.synced,
    );
  }
}

// ─── Chat Reconciliation Engine ─────────────────────────────────────────────

/// Singleton reconciliation engine per group.
/// Merges optimistic (pending) messages with confirmed realtime messages
/// using client_id as the stable identity key.
///
/// Guarantees:
/// - No disappearing messages: pending messages survive until confirmed or failed
/// - No duplicates: client_id deduplification
/// - No flickers: merge-only, never replace entire list
/// - Stable sort: newest first, pending on top within same timestamp bucket
class ChatReconciliationEngine {
  final String groupId;

  // The canonical message map — keyed by client_id
  final Map<String, ChatMessage> _messages = {};

  // Stream controller for UI updates
  final _controller = StreamController<List<ChatMessage>>.broadcast();

  Stream<List<ChatMessage>> get stream async* {
    yield _sortedMessages();
    yield* _controller.stream;
  }

  ChatReconciliationEngine(this.groupId) {
    _loadFromCache();
  }

  // ── Cache Bootstrap ────────────────────────────────────────────────────────

  void _loadFromCache() {
    try {
      final cached = LocalCacheService.getCachedList('chat_v2_$groupId');
      for (final json in cached) {
        final msg = ChatMessage.fromJson(json);
        _messages[msg.clientId] = msg;
      }
      if (_messages.isNotEmpty) _emit();
    } catch (_) {}
  }

  void _saveToCache() {
    final list = _sortedMessages();
    LocalCacheService.cacheData(
      'chat_v2_$groupId',
      list.map((m) => m.toJson()).toList(),
    );
  }

  // ── Optimistic Insert ──────────────────────────────────────────────────────

  /// Called immediately when the user taps Send.
  /// Returns the client_id to pass to the Supabase insert.
  String addOptimistic({
    required String userId,
    required String message,
  }) {
    final clientId = const Uuid().v4();
    final msg = ChatMessage(
      clientId: clientId,
      groupId: groupId,
      userId: userId,
      message: message,
      createdAt: DateTime.now(),
      state: MessageState.pending,
    );
    _messages[clientId] = msg;
    _emit();
    _saveToCache();
    return clientId;
  }

  // ── Server Confirmation ────────────────────────────────────────────────────

  /// Called when Supabase returns the inserted row.
  /// Promotes pending → synced and attaches the server id.
  void confirmMessage(String clientId, String serverId) {
    final existing = _messages[clientId];
    if (existing == null) return;
    _messages[clientId] = existing.copyWith(
      serverId: serverId,
      state: MessageState.synced,
    );
    _emit();
    _saveToCache();
  }

  // ── Failure Handling ───────────────────────────────────────────────────────

  /// Mark a message as failed so user can retry.
  void markFailed(String clientId) {
    final existing = _messages[clientId];
    if (existing == null) return;
    _messages[clientId] = existing.copyWith(state: MessageState.failed);
    _emit();
    _saveToCache();
  }

  /// Retry a failed message — re-mark as pending.
  void markRetry(String clientId) {
    final existing = _messages[clientId];
    if (existing == null) return;
    _messages[clientId] = existing.copyWith(state: MessageState.pending);
    _emit();
  }

  // ── Realtime Merge ────────────────────────────────────────────────────────

  /// Merge an incoming batch of server messages.
  /// Uses client_id to reconcile — never destroys pending messages.
  void mergeFromRealtime(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final incoming = ChatMessage.fromRealtime(row);

      // Check if we already have this message by client_id
      final existing = _messages[incoming.clientId];
      if (existing != null) {
        // Already present — just confirm it if it was pending
        if (existing.isPending || existing.isFailed) {
          _messages[incoming.clientId] = existing.copyWith(
            serverId: incoming.serverId,
            state: MessageState.synced,
          );
        }
        // Already synced — no-op (prevents stale overwrite)
        continue;
      }

      // Also check by server_id to prevent duplicates from receivers
      final byServerId = _messages.values.firstWhere(
        (m) => m.serverId == incoming.serverId && incoming.serverId != null,
        orElse: () => ChatMessage(
          clientId: '', groupId: '', userId: '',
          message: '', createdAt: DateTime.now(),
        ),
      );
      if (byServerId.clientId.isNotEmpty) continue;

      // New message from another user — insert it
      _messages[incoming.clientId] = incoming;
    }

    _emit();
    _saveToCache();
  }

  // ── Sorted Output ─────────────────────────────────────────────────────────

  List<ChatMessage> _sortedMessages() {
    final list = _messages.values.toList();
    // Sort: newest first. Pending messages float above same-time messages.
    list.sort((a, b) {
      final timeCmp = b.createdAt.compareTo(a.createdAt);
      if (timeCmp != 0) return timeCmp;
      // Same time: pending first (will appear at top of group)
      if (a.isPending && !b.isPending) return -1;
      if (!a.isPending && b.isPending) return 1;
      return 0;
    });
    return list;
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_sortedMessages());
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void dispose() {
    _controller.close();
  }
}

// ─── Engine Registry Provider ────────────────────────────────────────────────

/// Per-group reconciliation engine — created once, survives rebuilds.
/// Keyed by groupId so each group has its own isolated engine.
final chatEngineProvider =
    Provider.family<ChatReconciliationEngine, String>((ref, groupId) {
  final engine = ChatReconciliationEngine(groupId);
  ref.onDispose(engine.dispose);
  return engine;
});

/// Provides the live, merged, reconciled message stream for a group.
final reconciledChatStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, groupId) {
  final engine = ref.watch(chatEngineProvider(groupId));
  return engine.stream;
});

// ─── Message Delivery Status Serializer ─────────────────────────────────────

extension MessageStateLabel on MessageState {
  String get label {
    switch (this) {
      case MessageState.pending: return 'Sending...';
      case MessageState.synced:  return 'Sent';
      case MessageState.failed:  return 'Failed — tap to retry';
    }
  }
}
