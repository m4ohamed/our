// lib/data/models/timeline_event_hive_model.dart
import 'package:hive/hive.dart';

part 'timeline_event_hive_model.g.dart';

@HiveType(typeId: 0)
class TimelineEventHiveModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late DateTime date;

  @HiveField(2)
  late String title;

  @HiveField(3)
  late String description;

  @HiveField(4)
  late String icon;

  @HiveField(5)
  String? imageUrl;

  @HiveField(6)
  String? localImagePath;

  @HiveField(7)
  late bool isActive;

  @HiveField(8)
  late int orderIndex;

  @HiveField(9)
  String? location;

  @HiveField(10)
  late List<String> tags;

  @HiveField(11)
  late bool isDemo;

  @HiveField(12)
  late DateTime createdAt;

  @HiveField(13)
  late DateTime updatedAt;

  TimelineEventHiveModel({
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
}
