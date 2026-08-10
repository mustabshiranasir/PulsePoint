import 'package:cloud_firestore/cloud_firestore.dart';

class BloodRequestModel {
  final String id;
  final String requesterId;
  final String requesterPhone; // Phone of requester
  final String patientName;
  final String bloodGroupNeeded;
  final int unitsNeeded;
  final String hospitalName;
  final Map<String, dynamic> hospitalLocation; // contains 'geopoint' and 'geohash'
  final String urgencyLevel; // 'critical' / 'high' / 'normal'
  final String status; // 'pending' / 'accepted' / 'completed' / 'cancelled'
  final DateTime createdAt;
  final String? acceptedByDonorId;
  final String? acceptedByDonorPhone; // Phone of accepted donor
  final GeoPoint? donorLiveLocation; // Live tracking coordinates of donor

  BloodRequestModel({
    required this.id,
    required this.requesterId,
    required this.requesterPhone,
    required this.patientName,
    required this.bloodGroupNeeded,
    required this.unitsNeeded,
    required this.hospitalName,
    required this.hospitalLocation,
    required this.urgencyLevel,
    required this.status,
    required this.createdAt,
    this.acceptedByDonorId,
    this.acceptedByDonorPhone,
    this.donorLiveLocation,
  });

  factory BloodRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return BloodRequestModel(
      id: id,
      requesterId: map['requesterId'] ?? '',
      requesterPhone: map['requesterPhone'] ?? '',
      patientName: map['patientName'] ?? '',
      bloodGroupNeeded: map['bloodGroupNeeded'] ?? '',
      unitsNeeded: (map['unitsNeeded'] as num?)?.toInt() ?? 1,
      hospitalName: map['hospitalName'] ?? '',
      hospitalLocation: Map<String, dynamic>.from(map['hospitalLocation'] ?? {}),
      urgencyLevel: map['urgencyLevel'] ?? 'normal',
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      acceptedByDonorId: map['acceptedByDonorId'],
      acceptedByDonorPhone: map['acceptedByDonorPhone'],
      donorLiveLocation: map['donorLiveLocation'] as GeoPoint?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterPhone': requesterPhone,
      'patientName': patientName,
      'bloodGroupNeeded': bloodGroupNeeded,
      'unitsNeeded': unitsNeeded,
      'hospitalName': hospitalName,
      'hospitalLocation': hospitalLocation,
      'urgencyLevel': urgencyLevel,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedByDonorId': acceptedByDonorId,
      'acceptedByDonorPhone': acceptedByDonorPhone,
      'donorLiveLocation': donorLiveLocation,
    };
  }

  // Get raw GeoPoint directly from the geoflutterfire map
  GeoPoint get geoPoint {
    return hospitalLocation['geopoint'] as GeoPoint;
  }
}
