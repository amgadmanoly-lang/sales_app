class Product {
  final int? id;
  final String barcode;        // الباركود (فريد)
  final String name;            // اسم المنتج
  final String? description;    // وصف
  final double price;           // سعر البيع
  final double cost;            // سعر التكلفة

  // ⭐ الرصيدين الجديدين
  final int stockQuantity;      // الكمية في المخزن
  final int displayQuantity;    // الكمية على العرض

  final String? category;       // الفئة
  final String? imageUrl;       // صورة
  final bool isActive;          // مفعل/متوقف
  final DateTime createdAt;     // تاريخ الإضافة

  Product({
    this.id,
    required this.barcode,
    required this.name,
    this.description,
    required this.price,
    required this.cost,
    this.stockQuantity = 0,
    this.displayQuantity = 0,
    this.category,
    this.imageUrl,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // الربح
  double get profit => price - cost;

  // ⭐ إجمالي الكمية (مخزن + عرض)
  int get totalQuantity => stockQuantity + displayQuantity;

  // ⭐ للتوافق مع الكود القديم
  int get quantity => totalQuantity;

  // ⭐ حالة العرض
  bool get isDisplayLowStock => displayQuantity <= 5 && displayQuantity > 0;
  bool get isDisplayOutOfStock => displayQuantity == 0;

  // ⭐ حالة المخزن
  bool get isStockLowStock => stockQuantity <= 5 && stockQuantity > 0;
  bool get isStockOutOfStock => stockQuantity == 0;

  // ⭐ هل مخزون إجمالي منخفض؟
  bool get isLowStock => totalQuantity <= 5 && totalQuantity > 0;
  bool get isOutOfStock => totalQuantity == 0;

  // ⭐ هل يحتاج تعبئة العرض؟
  bool get needsRestock => displayQuantity <= 3 && stockQuantity > 0;

  // من Map
  factory Product.fromMap(Map<String, dynamic> map) {
    final oldQuantity = map['quantity'] as int?;
    final stock = map['stock_quantity'] as int?;
    final display = map['display_quantity'] as int?;

    return Product(
      id: map['id'] as int?,
      barcode: map['barcode'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      price: (map['price'] as num).toDouble(),
      cost: (map['cost'] as num).toDouble(),
      stockQuantity: stock ?? 0,
      displayQuantity: display ?? (oldQuantity ?? 0),
      category: map['category'] as String?,
      imageUrl: map['image_url'] as String?,
      isActive: (map['is_active'] as int) == 1,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  // إلى Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'barcode': barcode,
      'name': name,
      'description': description,
      'price': price,
      'cost': cost,
      'stock_quantity': stockQuantity,
      'display_quantity': displayQuantity,
      'quantity': totalQuantity,
      'category': category,
      'image_url': imageUrl,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  // نسخة معدّلة
  Product copyWith({
    int? id,
    String? barcode,
    String? name,
    String? description,
    double? price,
    double? cost,
    int? stockQuantity,
    int? displayQuantity,
    String? category,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      displayQuantity: displayQuantity ?? this.displayQuantity,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ⭐ نسخة بعد نقل من المخزن للعرض
  Product moveToDisplay(int amount) {
    final actualMove = amount > stockQuantity ? stockQuantity : amount;
    return copyWith(
      stockQuantity: stockQuantity - actualMove,
      displayQuantity: displayQuantity + actualMove,
    );
  }

  // ⭐ نسخة بعد بيع (نقصان من العرض)
  Product sellFromDisplay(int amount) {
    final newDisplay = displayQuantity - amount;
    return copyWith(
      displayQuantity: newDisplay < 0 ? 0 : newDisplay,
    );
  }

  // ⭐ نسخة بعد استلام من مورد (زيادة في المخزن)
  Product addToStock(int amount) {
    return copyWith(stockQuantity: stockQuantity + amount);
  }
}