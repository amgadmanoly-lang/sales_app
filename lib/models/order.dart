enum OrderType { sale, returnOrder }

class Order {
  final int? id;
  final String orderNumber;      // رقم الفاتورة
  final OrderType type;          // بيع أو مرتجع
  final int? originalOrderId;    // للفواتير المرتجعة
  final double total;            // الإجمالي
  final double discount;         // الخصم
  final double paid;             // المدفوع
  final String? notes;           // ملاحظات
  final DateTime createdAt;      // تاريخ الفاتورة
  final int? userId;             // الموظف اللي عملها

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

  // نوع الفاتورة بالعربي
  String get typeNameAr {
    return type == OrderType.sale ? 'بيع' : 'مرتجع';
  }

  // المتبقي
  double get remaining => total - paid;

  // من Map
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

  // إلى Map
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
  final int? orderId;          // الفاتورة الأم
  final int productId;         // المنتج
  final String productName;    // اسم المنتج (للعرض حتى لو اتحذف)
  final String barcode;        // الباركود
  final double price;          // سعر الوحدة
  final int quantity;          // الكمية

  OrderItem({
    this.id,
    this.orderId,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.price,
    required this.quantity,
  });

  // الإجمالي الفرعي
  double get subtotal => price * quantity;

  // من Map
  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      barcode: map['barcode'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
    );
  }

  // إلى Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'barcode': barcode,
      'price': price,
      'quantity': quantity,
    };
  }
}