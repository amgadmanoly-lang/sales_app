enum UserRole { admin, cashier, agent }

class User {
  final int? id;
  final String username;
  final String password;
  final String fullName;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  // ربط الجهاز
  final String? deviceId;   // رقم الجهاز المرتبط
  final int? boundAt;       // وقت الربط

  User({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.role,
    this.isActive = true,
    DateTime? createdAt,
    this.deviceId,
    this.boundAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // هل المستخدم مربوط بجهاز؟
  bool get isBound => deviceId != null && deviceId!.isNotEmpty;

  // تحويل من Map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      username: map['username'] as String,
      password: map['password'] as String,
      fullName: map['full_name'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.agent,
      ),
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      deviceId: map['device_id'] as String?,
      boundAt: map['bound_at'] as int?,
    );
  }

  // تحويل إلى Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'password': password,
      'full_name': fullName,
      'role': role.name,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'device_id': deviceId,
      'bound_at': boundAt,
    };
  }

  // اسم الدور بالعربي
  String get roleNameAr {
    switch (role) {
      case UserRole.admin:
        return 'مدير';
      case UserRole.cashier:
        return 'كاشير';
      case UserRole.agent:
        return 'مندوب';
    }
  }

  // نسخة معدّلة
  User copyWith({
    int? id,
    String? username,
    String? password,
    String? fullName,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
    String? deviceId,
    int? boundAt,
    bool clearDevice = false,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      deviceId: clearDevice ? null : (deviceId ?? this.deviceId),
      boundAt: clearDevice ? null : (boundAt ?? this.boundAt),
    );
  }
}