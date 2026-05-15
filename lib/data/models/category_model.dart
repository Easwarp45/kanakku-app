import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String icon;
  final int colorValue;
  final String description;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
    this.description = '',
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      colorValue: json['colorValue'] as int,
      description: json['description'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'colorValue': colorValue,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
      };

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    int? colorValue,
    String? description,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Category(id: $id, name: $name, icon: $icon, colorValue: $colorValue, description: $description, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          icon == other.icon &&
          colorValue == other.colorValue &&
          description == other.description &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      icon.hashCode ^
      colorValue.hashCode ^
      description.hashCode ^
      createdAt.hashCode;
}

/// Predefined categories for the app
abstract class PredefinedCategories {
  static final List<Category> defaults = [
    Category(
      id: 'food',
      name: 'Food',
      icon: '🍔',
      colorValue: Colors.orange.toARGB32(),
      createdAt: DateTime.now(),
    ),
    Category(
      id: 'transport',
      name: 'Transport',
      icon: '🚗',
      colorValue: Colors.blue.toARGB32(),
      createdAt: DateTime.now(),
    ),
    Category(
      id: 'entertainment',
      name: 'Entertainment',
      icon: '🎬',
      colorValue: Colors.purple.toARGB32(),
      createdAt: DateTime.now(),
    ),
    Category(
      id: 'utilities',
      name: 'Utilities',
      icon: '💡',
      colorValue: Colors.yellow.toARGB32(),
      createdAt: DateTime.now(),
    ),
    Category(
      id: 'shopping',
      name: 'Shopping',
      icon: '🛍️',
      colorValue: Colors.pink.toARGB32(),
      createdAt: DateTime.now(),
    ),
    Category(
      id: 'healthcare',
      name: 'Healthcare',
      icon: '⚕️',
      colorValue: Colors.red.toARGB32(),
      createdAt: DateTime.now(),
    ),
    Category(
      id: 'other',
      name: 'Other',
      icon: '📌',
      colorValue: Colors.grey.toARGB32(),
      createdAt: DateTime.now(),
    ),
  ];
}
