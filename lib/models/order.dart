enum OrderType { sale, returnOrder }

class Order {
  final int? id;
  final String orderNumber;
  final OrderType type;
  final int? originalOrderId;
  final double total;
  final double discount;
  final double paid;
  final String? notes;
  final DateTime createdAt;
  final int? userId;

  Order({
    this.id,
    required this.orderNumber,
    required this.type,
    this.originalOrderId,
    required this.total,
    this.discount = 0,
    required this.paid,
    this.notes,
    DateTime? createdAt,
    this.userId,
  }) : createdAt = createdAt ?? DateTime.now();

  String get typeNameAr {
    return type == OrderType.sale ? 'بيع' : 'مرتجع';
  }

  double get remaining => total - paid;

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int?,
      orderNumber: map['order_number'] as String,
      type: map['type'] == 'sale' ? OrderType.sale : OrderType.returnOrder,
      originalOrderId: map['original_order_id'] as int?,
      total: (map['total'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      paid: (map['paid'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      userId: map['user_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_number': orderNumber,
      'type': type == OrderType.sale ? 'sale' : 'return',
      'original_order_id': originalOrderId,
      'total': total,
      'discount': discount,
      'paid': paid,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'user_id': userId,
    };
  }
}

class OrderItem {
  final int? id;
  final int? orderId;
  final int productId;
  final String productName;
  final String barcode;
  final double price;
  final int quantity;

  // ⭐ أقصى كمية متاحة على العرض (مش بتتحفظ في قاعدة البيانات)
  final int maxQuantity;

  OrderItem({
    this.id,
    this.orderId,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.price,
    required this.quantity,
    this.maxQuantity = 0,
  });

  double get subtotal => price * quantity;

  // ⭐ هل وصلنا للحد الأقصى؟
  bool get isMaxedOut => maxQuantity > 0 && quantity >= maxQuantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      barcode: map['barcode'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      // maxQuantity مش بيتخزن في DB — يبقى 0 عند التحميل
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'barcode': barcode,
      'price': price,
      'quantity': quantity,
      // ⚠️ maxQuantity مش بيتبعت للـ DB
    };
  }

  // ⭐ نسخة معدّلة
  OrderItem copyWith({
    int? id,
    int? orderId,
    int? productId,
    String? productName,
    String? barcode,
    double? price,
    int? quantity,
    int? maxQuantity,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      maxQuantity: maxQuantity ?? this.maxQuantity,
    );
  }
}