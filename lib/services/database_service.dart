import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/shop_settings.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sales_app.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        device_id TEXT,
        bound_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        cost REAL NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        category TEXT,
        image_url TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT UNIQUE NOT NULL,
        type TEXT NOT NULL,
        original_order_id INTEGER,
        total REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        paid REAL NOT NULL,
        notes TEXT,
        created_at INTEGER NOT NULL,
        user_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        barcode TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE shop_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shop_name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        logo_path TEXT,
        footer_text TEXT,
        tax_enabled INTEGER NOT NULL DEFAULT 0,
        tax_percent REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.insert('shop_settings', {
      'shop_name': 'اسم المحل',
      'phone': '',
      'address': '',
      'logo_path': null,
      'footer_text': 'شكراً لتعاملكم معنا',
      'tax_enabled': 0,
      'tax_percent': 0,
    });

    await db.insert('users', {
      'username': 'admin',
      'password': 'admin',
      'full_name': 'المدير',
      'role': 'admin',
      'is_active': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          barcode TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          description TEXT,
          price REAL NOT NULL,
          cost REAL NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 0,
          category TEXT,
          image_url TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_number TEXT UNIQUE NOT NULL,
          type TEXT NOT NULL,
          original_order_id INTEGER,
          total REAL NOT NULL,
          discount REAL NOT NULL DEFAULT 0,
          paid REAL NOT NULL,
          notes TEXT,
          created_at INTEGER NOT NULL,
          user_id INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE order_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          product_name TEXT NOT NULL,
          barcode TEXT NOT NULL,
          price REAL NOT NULL,
          quantity INTEGER NOT NULL,
          FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE shop_settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          shop_name TEXT NOT NULL,
          phone TEXT,
          address TEXT,
          logo_path TEXT,
          footer_text TEXT,
          tax_enabled INTEGER NOT NULL DEFAULT 0,
          tax_percent REAL NOT NULL DEFAULT 0
        )
      ''');

      await db.insert('shop_settings', {
        'shop_name': 'اسم المحل',
        'phone': '',
        'address': '',
        'logo_path': null,
        'footer_text': 'شكراً لتعاملكم معنا',
        'tax_enabled': 0,
        'tax_percent': 0,
      });
    }

    if (oldVersion < 5) {
      // إضافة حقول ربط الجهاز للمستخدمين
      try {
        await db.execute('ALTER TABLE users ADD COLUMN device_id TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE users ADD COLUMN bound_at INTEGER');
      } catch (_) {}
    }
  }

  // ==================== Shop Settings ====================

  Future<ShopSettings?> getShopSettings() async {
    final db = await database;
    final result = await db.query('shop_settings', limit: 1);
    if (result.isEmpty) return null;
    return ShopSettings.fromMap(result.first);
  }

  Future<int> updateShopSettings(ShopSettings settings) async {
    final db = await database;
    return await db.update(
      'shop_settings',
      settings.toMap(),
      where: 'id = ?',
      whereArgs: [settings.id],
    );
  }

  // ==================== Users ====================

  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final result = await db.query('users', orderBy: 'created_at DESC');
    return result.map((map) => User.fromMap(map)).toList();
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  Future<User?> login(String username, String password) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'username = ? AND password = ? AND is_active = 1',
      whereArgs: [username, password],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  // ربط المستخدم بجهاز
  Future<void> bindUserToDevice(int userId, String deviceId) async {
    final db = await database;
    await db.update(
      'users',
      {
        'device_id': deviceId,
        'bound_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // فصل المستخدم عن الجهاز
  Future<void> unbindUserDevice(int userId) async {
    final db = await database;
    await db.update(
      'users',
      {'device_id': null, 'bound_at': null},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> usernameExists(String username) async {
    final user = await getUserByUsername(username);
    return user != null;
  }

  // ==================== Products ====================

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final result = await db.query('products', orderBy: 'created_at DESC');
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  Future<List<Product>> searchProducts(String keyword) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> barcodeExists(String barcode) async {
    final product = await getProductByBarcode(barcode);
    return product != null;
  }

  // ==================== Orders ====================

  Future<String> generateOrderNumber(OrderType type) async {
    final db = await database;
    final prefix = type == OrderType.sale ? 'S' : 'R';
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM orders WHERE type = ?',
      [type == OrderType.sale ? 'sale' : 'return'],
    );
    final count = (result.first['count'] as int) + 1;
    return '$prefix-$dateStr-${count.toString().padLeft(4, '0')}';
  }

  Future<int> createOrder(Order order, List<OrderItem> items) async {
    final db = await database;
    return await db.transaction((txn) async {
      final orderId = await txn.insert('orders', order.toMap());

      for (final item in items) {
        await txn.insert('order_items', {
          ...item.toMap(),
          'order_id': orderId,
        });

        final result = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item.productId],
          limit: 1,
        );

        if (result.isNotEmpty) {
          final currentQty = result.first['quantity'] as int;
          int newQty;
          if (order.type == OrderType.sale) {
            newQty = currentQty - item.quantity;
          } else {
            newQty = currentQty + item.quantity;
          }
          await txn.update(
            'products',
            {'quantity': newQty},
            where: 'id = ?',
            whereArgs: [item.productId],
          );
        }
      }

      return orderId;
    });
  }

  Future<List<Order>> getAllOrders() async {
    final db = await database;
    final result = await db.query('orders', orderBy: 'created_at DESC');
    return result.map((map) => Order.fromMap(map)).toList();
  }

  Future<List<Order>> getSalesOrders() async {
    final db = await database;
    final result = await db.query(
      'orders',
      where: 'type = ?',
      whereArgs: ['sale'],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Order.fromMap(map)).toList();
  }

  Future<List<Order>> getReturnOrders() async {
    final db = await database;
    final result = await db.query(
      'orders',
      where: 'type = ?',
      whereArgs: ['return'],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Order.fromMap(map)).toList();
  }

  Future<Order?> getOrderById(int id) async {
    final db = await database;
    final result = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Order.fromMap(result.first);
  }

  Future<List<OrderItem>> getOrderItems(int orderId) async {
    final db = await database;
    final result = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
    return result.map((map) => OrderItem.fromMap(map)).toList();
  }

  Future<int> deleteOrder(int id) async {
    final db = await database;
    await db.delete('order_items', where: 'order_id = ?', whereArgs: [id]);
    return await db.delete('orders', where: 'id = ?', whereArgs: [id]);
  }
}