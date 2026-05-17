// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_event_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TimelineEventHiveModelAdapter
    extends TypeAdapter<TimelineEventHiveModel> {
  @override
  final int typeId = 0;

  @override
  TimelineEventHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimelineEventHiveModel(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      title: fields[2] as String,
      description: fields[3] as String,
      icon: fields[4] as String,
      imageUrl: fields[5] as String?,
      localImagePath: fields[6] as String?,
      isActive: fields[7] as bool,
      orderIndex: fields[8] as int,
      location: fields[9] as String?,
      tags: (fields[10] as List).cast<String>(),
      isDemo: fields[11] as bool,
      createdAt: fields[12] as DateTime,
      updatedAt: fields[13] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TimelineEventHiveModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.icon)
      ..writeByte(5)
      ..write(obj.imageUrl)
      ..writeByte(6)
      ..write(obj.localImagePath)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.orderIndex)
      ..writeByte(9)
      ..write(obj.location)
      ..writeByte(10)
      ..write(obj.tags)
      ..writeByte(11)
      ..write(obj.isDemo)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineEventHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
