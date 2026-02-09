// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SongModelAdapter extends TypeAdapter<SongModel> {
  @override
  final int typeId = 0;

  @override
  SongModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SongModel(
      path: fields[0] as String,
      title: fields[1] as String,
      artist: fields[2] as String,
      album: fields[3] as String,
      durationMs: fields[4] as int,
      isFavorite: fields[5] as bool,
      format: fields[6] as String,
      artUri: fields[7] as String?,
      year: fields[8] as int?,
      genre: fields[9] == null ? 'Unknown' : fields[9] as String,
      trackNumber: fields[10] as int?,
      playHistory:
          fields[11] == null ? [] : (fields[11] as List?)?.cast<DateTime>(),
    );
  }

  @override
  void write(BinaryWriter writer, SongModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.path)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.artist)
      ..writeByte(3)
      ..write(obj.album)
      ..writeByte(4)
      ..write(obj.durationMs)
      ..writeByte(5)
      ..write(obj.isFavorite)
      ..writeByte(6)
      ..write(obj.format)
      ..writeByte(7)
      ..write(obj.artUri)
      ..writeByte(8)
      ..write(obj.year)
      ..writeByte(9)
      ..write(obj.genre)
      ..writeByte(10)
      ..write(obj.trackNumber)
      ..writeByte(11)
      ..write(obj.playHistory);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
