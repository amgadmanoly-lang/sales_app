import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'database_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final DatabaseService _db = DatabaseService();
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isCashier => _currentUser?.role == UserRole.cashier;
  bool get isAgent => _currentUser?.role == UserRole.agent;

  // ==================== Device ID ====================

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      deviceId = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString('device_id', deviceId);
    }

    return deviceId;
  }

  // ==================== Login ====================

  Future<LoginResult> loginWithDeviceCheck(
      String username, String password) async {
    final user = await _db.getUserByUsername(username);

    if (user == null || user.password != password || !user.isActive) {
      return LoginResult(
        status: LoginStatus.invalidCredentials,
        user: null,
      );
    }

    final deviceId = await getDeviceId();

    if (!user.isBound) {
      await _db.bindUserToDevice(user.id!, deviceId);
      final updatedUser = user.copyWith(deviceId: deviceId);
      _currentUser = updatedUser;
      await _saveSession(updatedUser);
      return LoginResult(
        status: LoginStatus.success,
        user: updatedUser,
      );
    }

    if (user.deviceId != deviceId) {
      return LoginResult(
        status: LoginStatus.deviceMismatch,
        user: user,
      );
    }

    _currentUser = user;
    await _saveSession(user);
    return LoginResult(
      status: LoginStatus.success,
      user: user,
    );
  }

  Future<User?> login(String username, String password) async {
    final user = await _db.login(username, password);
    if (user != null) {
      _currentUser = user;
      await _saveSession(user);
    }
    return user;
  }

  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_user_id', user.id!);
    await prefs.setString('current_user_role', user.role.name);
  }

  // ==================== Recovery by Phone ====================

  /// استعادة بيانات الدخول عن طريق رقم التليفون
  /// (يرجع true لو الرقم مطابق لرقم السيريال في Firebase)
  Future<RecoveryResult> recoverByPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final serial = prefs.getString('serial');

    if (serial == null || serial.isEmpty) {
      return RecoveryResult(
        status: RecoveryStatus.noSerial,
        phoneFromServer: null,
      );
    }

    // تنظيف الرقم
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanPhone.isEmpty) {
      return RecoveryResult(
        status: RecoveryStatus.emptyPhone,
        phoneFromServer: null,
      );
    }

    try {
      final ref = FirebaseDatabase.instance.ref('serials/$serial');
      final snapshot = await ref.get().timeout(
        const Duration(seconds: 10),
      );

      if (!snapshot.exists) {
        return RecoveryResult(
          status: RecoveryStatus.serialNotFound,
          phoneFromServer: null,
        );
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final savedPhone = (data['customerPhone'] ?? '').toString();
      final cleanSaved = savedPhone.replaceAll(RegExp(r'[^0-9]'), '');

      if (cleanSaved.isEmpty) {
        return RecoveryResult(
          status: RecoveryStatus.noPhoneRegistered,
          phoneFromServer: null,
        );
      }

      // المقارنة
      if (cleanSaved == cleanPhone ||
          cleanSaved.endsWith(cleanPhone) ||
          cleanPhone.endsWith(cleanSaved)) {
        return RecoveryResult(
          status: RecoveryStatus.success,
          phoneFromServer: savedPhone,
        );
      } else {
        return RecoveryResult(
          status: RecoveryStatus.wrongPhone,
          phoneFromServer: null,
        );
      }
    } catch (e) {
      return RecoveryResult(
        status: RecoveryStatus.networkError,
        phoneFromServer: null,
      );
    }
  }

  // ==================== Logout ====================

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    await prefs.remove('current_user_role');
  }

  // ==================== Restore Session ====================

  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('current_user_id');
    if (userId == null) return false;

    final users = await _db.getAllUsers();
    try {
      final user = users.firstWhere((u) => u.id == userId);

      final deviceId = await getDeviceId();
      if (user.isBound && user.deviceId != deviceId) {
        await logout();
        return false;
      }

      _currentUser = user;
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  // ==================== User Management ====================

  Future<bool> addUser(User user) async {
    if (!isAdmin) return false;
    if (await _db.usernameExists(user.username)) return false;
    await _db.insertUser(user);
    return true;
  }

  Future<bool> deleteUser(int userId) async {
    if (!isAdmin) return false;
    if (_currentUser?.id == userId) return false;
    await _db.deleteUser(userId);
    return true;
  }

  Future<bool> updateUser(User user) async {
    if (!isAdmin) return false;
    await _db.updateUser(user);
    return true;
  }

  Future<List<User>> getAllUsers() async {
    return await _db.getAllUsers();
  }

  Future<bool> unbindUserDevice(int userId) async {
    if (!isAdmin) return false;
    await _db.unbindUserDevice(userId);
    return true;
  }

  // ⭐ تغيير بيانات المستخدم الحالي
  Future<ProfileUpdateResult> updateMyProfile({
    required String oldPassword,
    required String newFullName,
    required String newPassword,
  }) async {
    if (_currentUser == null) {
      return ProfileUpdateResult.notLoggedIn;
    }

    if (_currentUser!.password != oldPassword) {
      return ProfileUpdateResult.wrongPassword;
    }

    if (newFullName.trim().isEmpty) {
      return ProfileUpdateResult.emptyFullName;
    }

    if (newPassword.trim().length < 4) {
      return ProfileUpdateResult.weakPassword;
    }

    final updatedUser = _currentUser!.copyWith(
      fullName: newFullName.trim(),
      password: newPassword.trim(),
    );

    await _db.updateUser(updatedUser);
    _currentUser = updatedUser;

    return ProfileUpdateResult.success;
  }
}

// ==================== Login Result ====================

enum LoginStatus {
  success,
  invalidCredentials,
  deviceMismatch,
}

class LoginResult {
  final LoginStatus status;
  final User? user;

  LoginResult({
    required this.status,
    required this.user,
  });
}

// ==================== Profile Update Result ====================

enum ProfileUpdateResult {
  success,
  wrongPassword,
  emptyFullName,
  weakPassword,
  notLoggedIn,
}

// ==================== Recovery Result ====================

enum RecoveryStatus {
  success,
  wrongPhone,
  noPhoneRegistered,
  serialNotFound,
  noSerial,
  emptyPhone,
  networkError,
}

class RecoveryResult {
  final RecoveryStatus status;
  final String? phoneFromServer;

  RecoveryResult({
    required this.status,
    required this.phoneFromServer,
  });
}