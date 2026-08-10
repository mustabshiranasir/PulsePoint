class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String role; // 'requester' or 'donor'
  final String? bloodGroup; // Only for 'donor'
  final bool? isAvailable; // Only for 'donor'

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.role,
    this.bloodGroup,
    this.isAvailable,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'requester',
      bloodGroup: map['bloodGroup'],
      isAvailable: map['isAvailable'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'uid': uid,
      'name': name,
      'phone': phone,
      'role': role,
    };
    if (role == 'donor') {
      data['bloodGroup'] = bloodGroup;
      data['isAvailable'] = isAvailable;
    }
    return data;
  }
}
