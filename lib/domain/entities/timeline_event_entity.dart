// lib/domain/entities/timeline_event_entity.dart

import 'package:flutter/foundation.dart';

@immutable
class TimelineEventEntity {
  final String id;
  final DateTime date;
  final String title;
  final String description;
  final String icon;
  final String? imageUrl;
  final String? localImagePath; // للصور المحلية
  final bool isActive;
  final int orderIndex;
  final String? location;
  final List<String> tags;
  final bool isDemo; // للتمييز بين البيانات التجريبية والحقيقية
  final DateTime createdAt;
  final DateTime updatedAt;

  const TimelineEventEntity({
    required this.id,
    required this.date,
    required this.title,
    required this.description,
    required this.icon,
    this.imageUrl,
    this.localImagePath,
    this.isActive = true,
    required this.orderIndex,
    this.location,
    this.tags = const [],
    this.isDemo = false,
    required this.createdAt,
    required this.updatedAt,
  });

  TimelineEventEntity copyWith({
    String? id,
    DateTime? date,
    String? title,
    String? description,
    String? icon,
    String? imageUrl,
    String? localImagePath,
    bool? isActive,
    int? orderIndex,
    String? location,
    List<String>? tags,
    bool? isDemo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimelineEventEntity(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      isActive: isActive ?? this.isActive,
      orderIndex: orderIndex ?? this.orderIndex,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      isDemo: isDemo ?? this.isDemo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Computed properties
  int get daysSinceEvent => DateTime.now().difference(date).inDays;

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String get seasonKey => switch (date.month) {
    12 || 1 || 2 => 'winter',
    3 || 4 || 5 => 'spring',
    6 || 7 || 8 => 'summer',
    _ => 'autumn',
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TimelineEventEntity && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TimelineEvent{id: $id, title: $title}';
}
