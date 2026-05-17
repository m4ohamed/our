// lib/data/mappers/event_mapper.dart
import '../../../../domain/entities/timeline_event_entity.dart';
import '../models/timeline_event_hive_model.dart';

extension TimelineEventMapper on TimelineEventHiveModel {
  TimelineEventEntity toEntity() {
    return TimelineEventEntity(
      id: id,
      date: date,
      title: title,
      description: description,
      icon: icon,
      imageUrl: imageUrl,
      localImagePath: localImagePath,
      isActive: isActive,
      orderIndex: orderIndex,
      location: location,
      tags: tags,
      isDemo: isDemo,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension TimelineEntityMapper on TimelineEventEntity {
  TimelineEventHiveModel toHiveModel() {
    return TimelineEventHiveModel(
      id: id,
      date: date,
      title: title,
      description: description,
      icon: icon,
      imageUrl: imageUrl,
      localImagePath: localImagePath,
      isActive: isActive,
      orderIndex: orderIndex,
      location: location,
      tags: tags,
      isDemo: isDemo,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
