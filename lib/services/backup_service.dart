import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'database_service.dart';

class BackupService {
  final DatabaseService _db = DatabaseService();

  // جداول النسخة الاحتياطية
  static const List<String> _tables = [
    'users',
    'products',
    'orders',
    'order_items',
    'shop_settings',
  ];

  // إنشاء نسخة احتياطية
  Future<File> createBackup() async {
    final db = await _db.database;
    final Map<String, dynamic> backup = {
      'app': 'sales_app',
      'version': 1,
      'created_at': DateTime.now().toIso8601String(),
      'data': {},
    };

    for (final table in _tables) {
      final rows = await db.query(table);
      backup['data'][table] = rows;
    }

    // حفظ الملف
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('${dir.path}/backup_$timestamp.json');
    await file.writeAsString(jsonEncode(backup));

    return file;
  }

  // مشاركة النسخة الاحتياطية
  Future<void> shareBackup() async {
    final file = await createBackup();
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'نسخة احتياطية - Sales App',
      text: 'نسخة احتياطية من بيانات التطبيق',
    );
  }

  // استعادة من ملف
  Future<bool> restoreBackup(File file) async {
    try {
      final content = await file.readAsString();
      final Map<String, dynamic> backup = jsonDecode(content);

      if (backup['app'] != 'sales_app') {
        throw Exception('ملف النسخة الاحتياطية غير صحيح');
      }

      final data = backup['data'] as Map<String, dynamic>;
      final db = await _db.database;

      await db.transaction((txn) async {
        // مسح كل البيانات القديمة
        for (final table in _tables.reversed) {
          await txn.delete(table);
        }

        // إدخال البيانات الجديدة
        for (final table in _tables) {
          final rows = data[table] as List?;
          if (rows == null) continue;

          for (final row in rows) {
            await txn.insert(
              table,
              Map<String, dynamic>.from(row),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // حذف كل البيانات
  Future<void> clearAllData() async {
    final db = await _db.database;
    await db.transaction((txn) async {
      for (final table in _tables.reversed) {
        await txn.delete(table);
      }
    });
  }
}