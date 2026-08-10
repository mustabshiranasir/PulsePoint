import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String role; // 'requester' or 'donor'
  final String? bloodGroup; // Only for 'donor'
  final bool? isAvailable; // Only for 'donor'
  final String? fcmToken;
  final GeoPoint? location;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.role,
    this.bloodGroup,
    this.isAvailable,
    this.fcmToken,
    this.location,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'requester',
      bloodGroup: map['bloodGroup'],
      isAvailable: map['isAvailable'] ?? false,
      fcmToken: map['fcmToken'],
      location: map['location'] as GeoPoint?,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'uid': uid,
      'name': name,
      'phone': phone,
      'role': role,
      'fcmToken': fcmToken,
    };
    if (role == 'donor') {
      data['bloodGroup'] = bloodGroup;
      data['isAvailable'] = isAvailable;
      data['location'] = location;
    }
    return data;
  }
}
