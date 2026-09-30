import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  final _db = DatabaseService();

  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;

    if (remember) {
      setState(() {
        _usernameController.text = prefs.getString('saved_username') ?? '';
        _passwordController.text = prefs.getString('saved_password') ?? '';
        _rememberMe = true;
      });
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMessage('من فضلك أدخل اسم المستخدم وكلمة السر');
      return;
    }

    setState(() => _loading = true);

    final result = await _auth.loginWithDeviceCheck(username, password);

    setState(() => _loading = false);

    switch (result.status) {
      case LoginStatus.invalidCredentials:
        _showMessage('اسم المستخدم أو كلمة السر غير صحيحة ❌');
        // ⭐ نعرض نافذة الاستعادة
        _showRecoveryDialog();
        return;

      case LoginStatus.deviceMismatch:
        _showDeviceMismatchDialog(result.user!.fullName);
        return;

      case LoginStatus.success:
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('saved_username', username);
          await prefs.setString('saved_password', password);
        } else {
          await prefs.setBool('remember_me', false);
          await prefs.remove('saved_username');
          await prefs.remove('saved_password');
        }

        _showMessage('مرحباً ${result.user!.fullName} ✅');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
    }
  }

  // ⭐ نافذة استعادة بيانات الدخول
  void _showRecoveryDialog() {
    showDialog(
      context: context,
      builder: (_) => const _RecoveryDialog(),
    );
  }

  // نافذة خطأ الجهاز
  void _showDeviceMismatchDialog(String fullName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phonelink_lock, color: Colors.red),
            SizedBox(width: 8),
            Text('جهاز غير مصرّح'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المستخدم "$fullName" مرتبط بجهاز آخر.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'للدخول من هذا الجهاز:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              '• اطلب من المدير فصل الجهاز من "إدارة المستخدمين"',
              style: TextStyle(fontSize: 13),
            ),
            const Text(
              '• أو سجّل دخول من الجهاز الأصلي',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.store,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 20),
                const Text(
                  'تسجيل الدخول',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'أدخل بياناتك للدخول',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'اسم المستخدم',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'كلمة السر',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                CheckboxListTile(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  title: const Text('تذكرني'),
                  subtitle: const Text(
                    'حفظ اسم المستخدم وكلمة السر',
                    style: TextStyle(fontSize: 11),
                  ),
                  activeColor: Colors.blue,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'دخول',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // ⭐ زر "نسيت بيانات الدخول؟"
                TextButton.icon(
                  onPressed: _loading ? null : _showRecoveryDialog,
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text(
                    'نسيت بيانات الدخول؟',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'مبرمج  م/أمجد مانولي ',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== Recovery Dialog ====================

class _RecoveryDialog extends StatefulWidget {
  const _RecoveryDialog();

  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  final _phoneController = TextEditingController();
  final _auth = AuthService();
  final _db = DatabaseService();

  bool _loading = false;
  bool _showData = false;
  List<User> _users = [];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _recover() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showError('أدخل رقم التليفون');
      return;
    }

    setState(() => _loading = true);

    final result = await _auth.recoverByPhone(phone);

    setState(() => _loading = false);

    switch (result.status) {
      case RecoveryStatus.success:
        // نجيب كل المستخدمين
        final users = await _db.getAllUsers();
        setState(() {
          _users = users;
          _showData = true;
        });
        break;

      case RecoveryStatus.wrongPhone:
        _showError('الرقم غير مطابق للرقم المسجل عند المطور');
        break;

      case RecoveryStatus.noPhoneRegistered:
        _showError('مفيش رقم مسجل عند المطور لهذا السيريال');
        break;

      case RecoveryStatus.serialNotFound:
        _showError('السيريال مش موجود — تواصل مع المطور');
        break;

      case RecoveryStatus.noSerial:
        _showError('التطبيق غير مفعّل — أدخل السيريال أولاً');
        break;

      case RecoveryStatus.emptyPhone:
        _showError('أدخل رقم صحيح');
        break;

      case RecoveryStatus.networkError:
        _showError('فشل الاتصال بالإنترنت — حاول تاني');
        break;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showData) {
      return _buildRecoveredData();
    }
    return _buildPhoneInput();
  }

  Widget _buildPhoneInput() {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.help_outline, color: Colors.blue),
          SizedBox(width: 8),
          Text('نسيت بيانات الدخول؟'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل رقم التليفون المسجل عند المطور:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              enabled: !_loading,
              decoration: InputDecoration(
                labelText: 'رقم التليفون',
                hintText: '01xxxxxxxxx',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'لازم الإنترنت شغّال',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _recover,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.search, size: 18),
          label: const Text('بحث'),
        ),
      ],
    );
  }

  Widget _buildRecoveredData() {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('تم التحقق'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'بيانات الدخول المتاحة:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'اختر أحد المستخدمين للدخول ببياناته:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),

              ..._users.map((user) => _buildUserCard(user)),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Colors.blue, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ينصح بتغيير كلمة السر من "تغيير بياناتي" بعد الدخول',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  Widget _buildUserCard(User user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 14, color: Colors.blue),
              const SizedBox(width: 4),
              Text(
                user.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.account_circle, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              const Text('اسم المستخدم: ', style: TextStyle(fontSize: 11)),
              Text(
                user.username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.lock, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              const Text('كلمة السر: ', style: TextStyle(fontSize: 11)),
              Text(
                user.password,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}