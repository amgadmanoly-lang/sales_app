import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/serial_checker_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _auth = AuthService();
  final _checker = SerialCheckerService();
  String _status = 'جاري التحميل...';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _checker.stop();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final prefs = await SharedPreferences.getInstance();
    final serial = prefs.getString('serial');
    final activated = prefs.getBool('activated') ?? false;

    // 1) مفيش سيريال محفوظ → شاشة التفعيل
    if (serial == null || !activated) {
      _goTo('/');
      return;
    }

    // 2) فحص السيريال
    setState(() => _status = 'جاري التحقق من السيريال...');

    final result = await _checker.checkSerial();

    switch (result) {
      case SerialCheckResult.valid:
        // تمام → نكمل
        break;

      case SerialCheckResult.invalid:
        await _clearAll();
        _showErrorAndGo('السيريال غير صالح أو تم إيقافه');
        return;

      case SerialCheckResult.expired:
        // ⭐ المدة انتهت
        await _clearAll();
        _showExpiredAndGo();
        return;

      case SerialCheckResult.offlineExpired:
        _showErrorAndGo(
            'يجب الاتصال بالإنترنت لتفعيل التطبيق (منذ أكثر من 7 أيام)');
        return;

      case SerialCheckResult.offline:
        // مفيش نت بس لسه في الفترة المسموحة
        setState(() => _status = 'لا يوجد اتصال - جاري الفتح...');
        await Future.delayed(const Duration(milliseconds: 500));
        break;
    }

    // 3) نبدأ التحقق الدوري (كل ساعة)
    _checker.startPeriodicCheck(onInvalid: _onSerialInvalid);

    // 4) نتحقق من الجلسة
    setState(() => _status = 'جاري تسجيل الدخول...');
    final restored = await _auth.restoreSession();

    if (restored) {
      _goTo('/home');
    } else {
      _goTo('/login');
    }
  }

  // لو السيريال اتغير أثناء التشغيل
  void _onSerialInvalid() async {
    await _clearAll();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('تنبيه'),
          content: const Text(
            'تم إيقاف السيريال أو تغييره.\n'
            'سيتم إغلاق التطبيق.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _goTo('/');
              },
              child: const Text('موافق'),
            ),
          ],
        ),
      );
    }
  }

  // المدة انتهت
  void _showExpiredAndGo() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.timer_off, color: Colors.red),
            SizedBox(width: 8),
            Text('انتهت الصلاحية'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'انتهت مدة صلاحية التطبيق.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'لتجديد الاشتراك، تواصل مع المطور:',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              '📱 أمجد مانولي',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goTo('/');
            },
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('serial');
    await prefs.remove('expiry_date');
    await prefs.setBool('activated', false);
    await _auth.logout();
  }

  void _showErrorAndGo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () => _goTo('/'));
  }

  void _goTo(String route) {
    if (mounted) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.store,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sales App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'إدارة المبيعات',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 60),
                const CircularProgressIndicator(
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                Text(
                  _status,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}