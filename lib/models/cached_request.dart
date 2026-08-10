import 'package:hive/hive.dart';

part 'cached_request.g.dart';

@HiveType(typeId: 0)
class CachedRequest extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String patientName;

  @HiveField(2)
  final String bloodGroupNeeded;

  @HiveField(3)
  final String hospitalName;

  @HiveField(4)
  final String urgencyLevel;

  @HiveField(5)
  final String status;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime cachedAt;

  CachedRequest({
    required this.id,
    required this.patientName,
    required this.bloodGroupNeeded,
    required this.hospitalName,
    required this.urgencyLevel,
    required this.status,
    required this.createdAt,
    required this.cachedAt,
  });
}
