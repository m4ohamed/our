// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_file_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MediaFileHiveModelAdapter extends TypeAdapter<MediaFileHiveModel> {
  @override
  final int typeId = 1;

  @override
  MediaFileHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaFileHiveModel(
      id: fields[0] as String,
      cloudinaryUrl: fields[1] as String,
      thumbnailUrl: fields[2] as String,
      localPath: fields[3] as String?,
      mediaType: fields[4] as String,
      uploadDate: fields[5] as DateTime,
      eventId: fields[6] as String?,
      description: fields[7] as String?,
      isFeatured: fields[8] as bool,
      location: fields[9] as String?,
      aspectRatio: fields[10] as double,
      fileSize: fields[11] as int?,
      fileName: fields[12] as String?,
      tags: (fields[13] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, MediaFileHiveModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.cloudinaryUrl)
      ..writeByte(2)
      ..write(obj.thumbnailUrl)
      ..writeByte(3)
      ..write(obj.localPath)
      ..writeByte(4)
      ..write(obj.mediaType)
      ..writeByte(5)
      ..write(obj.uploadDate)
      ..writeByte(6)
      ..write(obj.eventId)
      ..writeByte(7)
      ..write(obj.description)
      ..writeByte(8)
      ..write(obj.isFeatured)
      ..writeByte(9)
      ..write(obj.location)
      ..writeByte(10)
      ..write(obj.aspectRatio)
      ..writeByte(11)
      ..write(obj.fileSize)
      ..writeByte(12)
      ..write(obj.fileName)
      ..writeByte(13)
      ..write(obj.tags);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaFileHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
