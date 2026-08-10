// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_request.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedRequestAdapter extends TypeAdapter<CachedRequest> {
  @override
  final int typeId = 0;

  @override
  CachedRequest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedRequest(
      id: fields[0] as String,
      patientName: fields[1] as String,
      bloodGroupNeeded: fields[2] as String,
      hospitalName: fields[3] as String,
      urgencyLevel: fields[4] as String,
      status: fields[5] as String,
      createdAt: fields[6] as DateTime,
      cachedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedRequest obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientName)
      ..writeByte(2)
      ..write(obj.bloodGroupNeeded)
      ..writeByte(3)
      ..write(obj.hospitalName)
      ..writeByte(4)
      ..write(obj.urgencyLevel)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.cachedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedRequestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
