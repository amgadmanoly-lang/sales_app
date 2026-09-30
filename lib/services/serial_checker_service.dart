import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class SerialCheckerService {
  static final SerialCheckerService _instance =
      SerialCheckerService._internal();
  factory SerialCheckerService() => _instance;
  SerialCheckerService._internal();

  Timer? _timer;

  // كل ساعة
  static const Duration _checkInterval = Duration(hours: 1);

  // الحد الأقصى للأيام بدون نت
  static const int _maxDaysOffline = 7;

  void startPeriodicCheck({
    required VoidCallback onInvalid,
  }) {
    _timer?.cancel();

    _timer = Timer.periodic(_checkInterval, (_) async {
      final result = await checkSerial();
      if (result == SerialCheckResult.invalid ||
          result == SerialCheckResult.expired) {
        onInvalid();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<SerialCheckResult> checkSerial() async {
    final prefs = await SharedPreferences.getInstance();
    final serial = prefs.getString('serial');

    if (serial == null || serial.isEmpty) {
      return SerialCheckResult.invalid;
    }

    // 1) نتحقق من الإنترنت
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasInternet = !connectivityResult.contains(ConnectivityResult.none);

    if (!hasInternet) {
      // مفيش نت → نتحقق من عدد الأيام بدون نت
      final lastOnline = prefs.getInt('last_online_check') ?? 0;
      final daysOffline = lastOnline == 0
          ? 0
          : DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(lastOnline))
              .inDays;

      if (daysOffline >= _maxDaysOffline) {
        return SerialCheckResult.offlineExpired;
      }

      // نتحقق من المدة المحفوظة محلياً
      final localExpiry = prefs.getInt('expiry_date') ?? 0;
      if (localExpiry > 0) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now > localExpiry) {
          return SerialCheckResult.expired;
        }
      }

      return SerialCheckResult.offline;
    }

    // 2) فيه نت → نتحقق من Firebase
    try {
      final deviceId = await _getDeviceId();
      final ref = FirebaseDatabase.instance.ref('serials/$serial');
      final snapshot = await ref.get().timeout(
        const Duration(seconds: 10),
      );

      if (!snapshot.exists) {
        return SerialCheckResult.invalid;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final isActive = data['active'] == true;
      final savedDeviceId = (data['deviceId'] ?? '').toString();
      final durationDays = _parseInt(data['durationDays']);
      final activatedAt = _parseInt(data['activatedAt']);

      // السيريال موقوف
      if (!isActive) {
        return SerialCheckResult.invalid;
      }

      // مربوط بجهاز تاني
      if (savedDeviceId.isNotEmpty && savedDeviceId != deviceId) {
        return SerialCheckResult.invalid;
      }

      // ⭐ فحص المدة
      if (durationDays > 0 && activatedAt > 0) {
        final activated = DateTime.fromMillisecondsSinceEpoch(activatedAt);
        final expiry = activated.add(Duration(days: durationDays));
        final now = DateTime.now();

        // نحفظ المدة محلياً للفحص الأوفلاين
        await prefs.setInt(
          'expiry_date',
          expiry.millisecondsSinceEpoch,
        );

        // منتهي؟
        if (now.isAfter(expiry)) {
          return SerialCheckResult.expired;
        }
      }

      // نحدّث آخر فحص أونلاين
      await prefs.setInt(
        'last_online_check',
        DateTime.now().millisecondsSinceEpoch,
      );

      return SerialCheckResult.valid;
    } catch (e) {
      // فشل الاتصال → نعتبره offline
      final lastOnline = prefs.getInt('last_online_check') ?? 0;
      final daysOffline = lastOnline == 0
          ? 0
          : DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(lastOnline))
              .inDays;

      if (daysOffline >= _maxDaysOffline) {
        return SerialCheckResult.offlineExpired;
      }

      // فحص المدة المحفوظة
      final localExpiry = prefs.getInt('expiry_date') ?? 0;
      if (localExpiry > 0) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now > localExpiry) {
          return SerialCheckResult.expired;
        }
      }

      return SerialCheckResult.offline;
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  Future<String> _getDeviceId() async {
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
}

// ==================== النتائج ====================

enum SerialCheckResult {
  valid,
  invalid,
  offline,
  offlineExpired,
  expired,        // ⭐ المدة انتهت
}

typedef VoidCallback = void Function();