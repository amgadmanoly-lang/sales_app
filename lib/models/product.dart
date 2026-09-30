class Product {
  final int? id;
  final String barcode;      // الباركود (فريد)
  final String name;          // اسم المنتج
  final String? description;  // وصف
  final double price;         // سعر البيع
  final double cost;          // سعر التكلفة
  final int quantity;         // الكمية في المخزون
  final String? category;     // الفئة
  final String? imageUrl;     // صورة
  final bool isActive;        // مفعل/متوقف
  final DateTime createdAt;   // تاريخ الإضافة

  Product({
    this.id,
    required this.barcode,
    required this.name,
    this.description,
    required this.price,
    required this.cost,
    required this.quantity,
    this.category,
    this.imageUrl,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // الربح
  double get profit => price - cost;

  // حالة المخزون
  bool get isLowStock => quantity <= 5 && quantity > 0;
  bool get isOutOfStock => quantity == 0;

  // من Map
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      barcode: map['barcode'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      price: (map['price'] as num).toDouble(),
      cost: (map['cost'] as num).toDouble(),
      quantity: map['quantity'] as int,
      category: map['category'] as String?,
      imageUrl: map['image_url'] as String?,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
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
      'quantity': quantity,
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
    int? quantity,
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
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}