import 'dart:convert';

/// Data model representing a financial notification.
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // 'morning_brief', 'evening_summary', 'budget_alert', 'goal_alert', 'group_alert', 'settlement_alert', 'offline_sync', 'monthly_report', 'weekly_summary'
  final String priority; // 'low', 'medium', 'high'
  final Map<String, dynamic>? payload;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? scheduledAt;
  final DateTime? deliveredAt;
  final String source; // 'local' or 'push'

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.priority,
    this.payload,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.scheduledAt,
    this.deliveredAt,
    required this.source,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? payloadMap;
    if (json['payload'] != null) {
      if (json['payload'] is String) {
        try {
          payloadMap = jsonDecode(json['payload'] as String) as Map<String, dynamic>?;
        } catch (_) {}
      } else if (json['payload'] is Map) {
        payloadMap = Map<String, dynamic>.from(json['payload'] as Map);
      }
    }
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      priority: json['priority'] as String? ?? 'medium',
      payload: payloadMap,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      scheduledAt: json['scheduled_at'] != null ? DateTime.parse(json['scheduled_at'] as String) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at'] as String) : null,
      source: json['source'] as String? ?? 'local',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'priority': priority,
      'payload': payload != null ? jsonEncode(payload) : null,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'scheduled_at': scheduledAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'source': source,
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    String? priority,
    Map<String, dynamic>? payload,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
    DateTime? scheduledAt,
    DateTime? deliveredAt,
    String? source,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      payload: payload ?? this.payload,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      source: source ?? this.source,
    );
  }
}
