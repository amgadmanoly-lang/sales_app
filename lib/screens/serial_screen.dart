import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class SerialScreen extends StatefulWidget {
  const SerialScreen({super.key});

  @override
  State<SerialScreen> createState() => _SerialScreenState();
}

class _SerialScreenState extends State<SerialScreen> {
  final TextEditingController _serialController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
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

  Future<void> _verifySerial() async {
    final serial = _serialController.text.trim().toUpperCase();

    if (serial.isEmpty) {
      _showMessage('من فضلك أدخل السيريال');
      return;
    }

    setState(() => _loading = true);

    try {
      final deviceId = await _getDeviceId();
      final ref = FirebaseDatabase.instance.ref('serials/$serial');
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        _showMessage('السيريال غير صحيح ❌');
        setState(() => _loading = false);
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final isActive = data['active'] == true;
      final savedDeviceId = (data['deviceId'] ?? '').toString();
      final durationDays = _parseInt(data['durationDays']);
      final activatedAt = _parseInt(data['activatedAt']);

      if (!isActive) {
        _showMessage('السيريال غير مفعّل ❌');
        setState(() => _loading = false);
        return;
      }

      // فحص المدة (لو السيريال مُفعّل على جهاز قبل كده)
      if (durationDays > 0 && activatedAt > 0) {
        final activated = DateTime.fromMillisecondsSinceEpoch(activatedAt);
        final expiry = activated.add(Duration(days: durationDays));
        if (DateTime.now().isAfter(expiry)) {
          _showMessage('انتهت صلاحية السيريال ❌ — تواصل مع المطور');
          setState(() => _loading = false);
          return;
        }
      }

      if (savedDeviceId.isNotEmpty && savedDeviceId != deviceId) {
        _showMessage('السيريال مستخدم على جهاز آخر ❌');
        setState(() => _loading = false);
        return;
      }

      if (savedDeviceId.isEmpty) {
        await ref.update({
          'deviceId': deviceId,
          'activatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('activated', true);
      await prefs.setString('serial', serial);

      _showMessage('تم التفعيل بنجاح ✅');

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      _showMessage('خطأ في الاتصال: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  void _showRecoveryDialog() {
    showDialog(
      context: context,
      builder: (_) => _SerialRecoveryDialog(
        onSerialSelected: (serial) {
          _serialController.text = serial;
        },
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
                  Icons.verified_user,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 30),
                const Text(
                  'تفعيل التطبيق',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'أدخل رقم السيريال الخاص بك',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _serialController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 16,
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XXXX-XXXX-XXXX',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifySerial,
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
                            'تحقق',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // ⭐ زر استعادة السيريال
                TextButton.icon(
                  onPressed: _loading ? null : _showRecoveryDialog,
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text(
                    'نسيت السيريال؟',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== Serial Recovery Dialog ====================

class _SerialRecoveryDialog extends StatefulWidget {
  final Function(String serial) onSerialSelected;

  const _SerialRecoveryDialog({required this.onSerialSelected});

  @override
  State<_SerialRecoveryDialog> createState() => _SerialRecoveryDialogState();
}

class _SerialRecoveryDialogState extends State<_SerialRecoveryDialog> {
  final _phoneController = TextEditingController();
  bool _loading = false;
  bool _showResults = false;
  List<_RecoveredSerial> _serials = [];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final phone = _phoneController.text.trim();
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanPhone.isEmpty) {
      _showError('أدخل رقم التليفون');
      return;
    }

    setState(() => _loading = true);

    try {
      final ref = FirebaseDatabase.instance.ref('serials');
      final snapshot = await ref.get().timeout(
        const Duration(seconds: 10),
      );

      if (!snapshot.exists) {
        _showError('مفيش بيانات');
        setState(() => _loading = false);
        return;
      }

      final Map<dynamic, dynamic> data =
          snapshot.value as Map<dynamic, dynamic>;

      final list = <_RecoveredSerial>[];
      data.forEach((key, value) {
        final map = value as Map<dynamic, dynamic>;
        final savedPhone = (map['customerPhone'] ?? '').toString();
        final cleanSaved = savedPhone.replaceAll(RegExp(r'[^0-9]'), '');

        if (cleanSaved.isEmpty) return;

        // مطابقة الجزء الأخير من الرقم (عشان اختلاف +20 / 0)
        final match = cleanSaved == cleanPhone ||
            cleanSaved.endsWith(cleanPhone) ||
            cleanPhone.endsWith(cleanSaved);

        if (match) {
          list.add(_RecoveredSerial(
            serial: key.toString(),
            customerName: (map['customerName'] ?? '').toString(),
            customerPhone: savedPhone,
            active: map['active'] == true,
            durationDays: _parseInt(map['durationDays']),
            activatedAt: _parseInt(map['activatedAt']),
          ));
        }
      });

      setState(() {
        _serials = list;
        _showResults = true;
        _loading = false;
      });
    } catch (e) {
      _showError('خطأ في الاتصال: $e');
      setState(() => _loading = false);
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showResults) {
      return _buildResults();
    }
    return _buildPhoneInput();
  }

  Widget _buildPhoneInput() {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.help_outline, color: Colors.blue),
          SizedBox(width: 8),
          Text('استعادة السيريال'),
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
          onPressed: _loading ? null : _search,
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

  Widget _buildResults() {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _serials.isEmpty ? Icons.error_outline : Icons.list_alt,
            color: _serials.isEmpty ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(_serials.isEmpty ? 'لا توجد نتائج' : 'السيريالات'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _serials.isEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text(
                    'مفيش سيريال مسجل بهذا الرقم',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'تأكد من الرقم، أو تواصل مع المطور',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _serials
                      .map((s) => _buildSerialCard(s))
                      .toList(),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _showResults = false;
              _serials = [];
            });
          },
          child: const Text('رجوع'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  Widget _buildSerialCard(_RecoveredSerial serial) {
    final color = serial.isExpired
        ? Colors.red
        : serial.isExpiringSoon
            ? Colors.orange
            : (serial.active ? Colors.green : Colors.grey);

    final canUse = serial.active && !serial.isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // السيريال
          Row(
            children: [
              Expanded(
                child: Text(
                  serial.serial,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  serial.statusText,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (serial.customerName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              serial.customerName,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],

          // المدة المتبقية
          if (serial.durationDays > 0 && serial.activatedAt > 0) ...[
            const SizedBox(height: 4),
            Text(
              serial.isExpired
                  ? 'انتهت الصلاحية'
                  : 'متبقي ${serial.remainingDays} يوم',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else if (serial.durationDays > 0) ...[
            const SizedBox(height: 4),
            Text(
              'لم يُفعّل بعد',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],

          // زر "استخدام"
          if (canUse) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onSerialSelected(serial.serial);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text(
                  'استخدام هذا السيريال',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block, color: Colors.red, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      serial.isExpired
                          ? 'السيريال منتهي — تواصل مع المطور للتجديد'
                          : 'السيريال موقوف — تواصل مع المطور',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==================== Recovered Serial Model ====================

class _RecoveredSerial {
  final String serial;
  final String customerName;
  final String customerPhone;
  final bool active;
  final int durationDays;
  final int activatedAt;

  _RecoveredSerial({
    required this.serial,
    required this.customerName,
    required this.customerPhone,
    required this.active,
    required this.durationDays,
    required this.activatedAt,
  });

  int get remainingDays {
    if (durationDays <= 0) return 0;
    if (activatedAt == 0) return durationDays;
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(activatedAt)
        .add(Duration(days: durationDays));
    final diff = expiryDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get isExpired {
    if (durationDays <= 0) return false;
    if (activatedAt == 0) return false;
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(activatedAt)
        .add(Duration(days: durationDays));
    return DateTime.now().isAfter(expiryDate);
  }

  bool get isExpiringSoon {
    if (durationDays <= 0) return false;
    if (isExpired) return false;
    return remainingDays <= 5 && remainingDays > 0;
  }

  String get statusText {
    if (!active) return 'موقوف';
    if (isExpired) return 'منتهي';
    return 'مفعّل';
  }
}