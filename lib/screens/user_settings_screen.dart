import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  final _auth = AuthService();

  bool _agentRole = false;
  bool _cashierRole = false;
  bool _saving = false;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentRoles();
  }

  void _loadCurrentRoles() {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _agentRole = user.agentRoleActive;
        _cashierRole = user.cashierRoleActive;
        _initialLoading = false;
      });
    } else {
      setState(() => _initialLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final result = await _auth.updateMyRoles(
      agentRoleActive: _agentRole,
      cashierRoleActive: _cashierRole,
    );

    setState(() => _saving = false);

    switch (result) {
      case RoleUpdateResult.success:
        _showMessage('تم حفظ الإعدادات ✅');
        if (mounted) Navigator.pop(context, true);
        return;

      case RoleUpdateResult.notAdmin:
        _showMessage('هذه الصفحة للمدير فقط ❌');
        return;

      case RoleUpdateResult.notLoggedIn:
        _showMessage('يجب تسجيل الدخول');
        return;
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (_initialLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // لو مش مدير → ما يقدرش يعدّل
    if (user == null || user.role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          title: const Text('إعدادات المستخدم'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'هذه الصفحة للمدير فقط',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('إعدادات المستخدم'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== بطاقة معلومات المستخدم =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'الأدوار النشطة: ${user.activeRolesText}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ===== العنوان =====
            const Text(
              'اختر الأدوار الإضافية',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'المدير يمكنه تفعيل أدوار إضافية للقيام بمهام أخرى.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // ===== دور المندوب =====
            _buildRoleCard(
              icon: Icons.local_shipping,
              color: Colors.orange,
              title: 'دور المندوب',
              description:
                  'يسمح بتعديل المخزن والعرض، وإدارة البضاعة.',
              value: _agentRole,
              onChanged: (v) => setState(() => _agentRole = v),
            ),
            const SizedBox(height: 12),

            // ===== دور الكاشير =====
            _buildRoleCard(
              icon: Icons.point_of_sale,
              color: Colors.green,
              title: 'دور الكاشير',
              description:
                  'يسمح بالبيع والمرتجع من شاشة "بيع جديد".',
              value: _cashierRole,
              onChanged: (v) => setState(() => _cashierRole = v),
            ),
            const SizedBox(height: 24),

            // ===== ملخص الأدوار =====
            _buildRolesSummary(),
            const SizedBox(height: 24),

            // ===== زر الحفظ =====
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: const Text(
                  'حفظ الإعدادات',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: value ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: value
            ? BorderSide(color: color.withOpacity(0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolesSummary() {
    final activeRoles = <String>['مدير'];
    if (_agentRole) activeRoles.add('مندوب');
    if (_cashierRole) activeRoles.add('كاشير');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'الصلاحيات الحالية:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildPermissionRow(
            'إدارة المستخدمين والتقارير',
            true,
          ),
          _buildPermissionRow(
            'تعديل المخزن والعرض',
            _agentRole,
          ),
          _buildPermissionRow(
            'البيع والمرتجع',
            _cashierRole,
          ),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'الأدوار النشطة: ${activeRoles.join(' + ')}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String label, bool enabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.cancel,
            color: enabled ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: enabled ? Colors.black87 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}