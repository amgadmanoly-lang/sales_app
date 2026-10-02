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
  final String? deviceId;
  final int? boundAt;

  // ⭐ الأدوار المركبة (للمدير)
  // لما المدير يكون عنده دور إضافي (مندوب أو كاشير)
  final bool agentRoleActive;    // دور المندوب مفعّل؟
  final bool cashierRoleActive;  // دور الكاشير مفعّل؟

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
    this.agentRoleActive = false,
    this.cashierRoleActive = false,
  }) : createdAt = createdAt ?? DateTime.now();

  // هل المستخدم مربوط بجهاز؟
  bool get isBound => deviceId != null && deviceId!.isNotEmpty;

  // ⭐ هل هو مدير؟
  bool get isAdmin => role == UserRole.admin;

  // ⭐ هل يقدر يعدّل المخزن والعرض؟
  // - مدير + دور المندوب مفعّل ✅
  // - مندوب (أساسي) ✅
  bool get canManageInventory {
    if (role == UserRole.agent) return true;
    if (role == UserRole.admin && agentRoleActive) return true;
    return false;
  }

  // ⭐ هل يقدر يبيع ويرجّع؟
  // - مدير + دور الكاشير مفعّل ✅
  // - كاشير (أساسي) ✅
  bool get canSell {
    if (role == UserRole.cashier) return true;
    if (role == UserRole.admin && cashierRoleActive) return true;
    return false;
  }

  // ⭐ هل هو مدير بدون أي دور إضافي؟
  bool get isPureAdmin {
    return role == UserRole.admin &&
        !agentRoleActive &&
        !cashierRoleActive;
  }

  // ⭐ وصف الأدوار النشطة
  String get activeRolesText {
    if (role == UserRole.admin) {
      final roles = <String>['مدير'];
      if (agentRoleActive) roles.add('مندوب');
      if (cashierRoleActive) roles.add('كاشير');
      return roles.join(' + ');
    }
    return roleNameAr;
  }

  // من Map
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
      // ⭐ الأدوار المركبة
      agentRoleActive: (map['agent_role_active'] as int?) == 1,
      cashierRoleActive: (map['cashier_role_active'] as int?) == 1,
    );
  }

  // إلى Map
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
      // ⭐ الأدوار المركبة
      'agent_role_active': agentRoleActive ? 1 : 0,
      'cashier_role_active': cashierRoleActive ? 1 : 0,
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
    bool? agentRoleActive,
    bool? cashierRoleActive,
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
      agentRoleActive: agentRoleActive ?? this.agentRoleActive,
      cashierRoleActive: cashierRoleActive ?? this.cashierRoleActive,
    );
  }
}