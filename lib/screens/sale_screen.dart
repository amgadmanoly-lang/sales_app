import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import 'barcode_scanner_screen.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen>
    with WidgetsBindingObserver {
  final _db = DatabaseService();
  final _auth = AuthService();
  final _discountController = TextEditingController(text: '0');
  final _paidController = TextEditingController();

  final List<OrderItem> _cart = [];
  bool _saving = false;

  // للفاتورة المعلقة بعد العودة من واتساب
  Order? _pendingOrder;
  List<OrderItem>? _pendingItems;
  String? _pendingCustomerName;
  String? _pendingCustomerPhone;
  bool _waitingForWhatsApp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _discountController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // لما المستخدم يرجع من واتساب
    if (state == AppLifecycleState.resumed && _waitingForWhatsApp) {
      _waitingForWhatsApp = false;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showPdfShareDialog();
      });
    }
  }

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + item.subtotal);
  double get _discount => double.tryParse(_discountController.text) ?? 0;
  double get _total => _subtotal - _discount;

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (barcode == null || barcode.isEmpty) return;

    final product = await _db.getProductByBarcode(barcode);

    if (product == null) {
      _showMessage('المنتج غير موجود ❌');
      return;
    }

    if (product.quantity <= 0) {
      _showMessage('المنتج غير متوفر في المخزون ❌');
      return;
    }

    _addToCart(product);
  }

  void _addToCart(Product product) {
    final index = _cart.indexWhere((item) => item.productId == product.id);
    if (index != -1) {
      final currentQty = _cart[index].quantity;
      if (currentQty >= product.quantity) {
        _showMessage('الكمية المتاحة: ${product.quantity} فقط ❌');
        return;
      }
      setState(() {
        _cart[index] = OrderItem(
          productId: _cart[index].productId,
          productName: _cart[index].productName,
          barcode: _cart[index].barcode,
          price: _cart[index].price,
          quantity: _cart[index].quantity + 1,
        );
      });
    } else {
      setState(() {
        _cart.add(OrderItem(
          productId: product.id!,
          productName: product.name,
          barcode: product.barcode,
          price: product.price,
          quantity: 1,
        ));
      });
    }
  }

  void _incrementItem(int index) {
    setState(() {
      final item = _cart[index];
      _cart[index] = OrderItem(
        productId: item.productId,
        productName: item.productName,
        barcode: item.barcode,
        price: item.price,
        quantity: item.quantity + 1,
      );
    });
  }

  void _decrementItem(int index) {
    setState(() {
      final item = _cart[index];
      if (item.quantity <= 1) {
        _cart.removeAt(index);
      } else {
        _cart[index] = OrderItem(
          productId: item.productId,
          productName: item.productName,
          barcode: item.barcode,
          price: item.price,
          quantity: item.quantity - 1,
        );
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _cart.removeAt(index));
  }

  Future<void> _completeSale() async {
    if (_cart.isEmpty) {
      _showMessage('السلة فاضية');
      return;
    }

    final paid = double.tryParse(_paidController.text) ?? _total;

    if (paid < _total) {
      _showMessage('المبلغ المدفوع أقل من الإجمالي');
      return;
    }

    final customer = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _CustomerDialog(),
    );

    if (customer == null) return;

    setState(() => _saving = true);

    final itemsCopy = List<OrderItem>.from(_cart);

    try {
      final orderNumber = await _db.generateOrderNumber(OrderType.sale);

      final order = Order(
        orderNumber: orderNumber,
        type: OrderType.sale,
        total: _total,
        discount: _discount,
        paid: paid,
        userId: _auth.currentUser?.id,
        notes: customer['name']!.isNotEmpty
            ? 'العميل: ${customer['name']} - ${customer['phone']}'
            : null,
      );

      await _db.createOrder(order, _cart);

      final orders = await _db.getSalesOrders();
      final savedOrder = orders.firstWhere(
        (o) => o.orderNumber == orderNumber,
        orElse: () => order,
      );

      _showMessage('تم إتمام البيع ✅');

      if (mounted) {
        setState(() {
          _cart.clear();
          _discountController.text = '0';
          _paidController.clear();
        });
      }

      final settings = await _db.getShopSettings();
      if (settings != null && mounted) {
        await _showSendOptions(
          order: savedOrder,
          items: itemsCopy,
          settings: settings,
          customerName: customer['name']!,
          customerPhone: customer['phone']!,
        );
      }
    } catch (e) {
      _showMessage('خطأ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSendOptions({
    required Order order,
    required List<OrderItem> items,
    required dynamic settings,
    required String customerName,
    required String customerPhone,
  }) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إرسال الفاتورة'),
        content: const Text('اختر طريقة إرسال الفاتورة:'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, 'skip'),
            icon: const Icon(Icons.close, color: Colors.grey),
            label: const Text('تخطي', style: TextStyle(color: Colors.grey)),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, 'whatsapp'),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF25D366).withOpacity(0.1),
            ),
            icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
            label: const Text(
              'واتساب',
              style: TextStyle(
                color: Color(0xFF25D366),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, 'share'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.1),
            ),
            icon: const Icon(Icons.share, color: Colors.blue),
            label: const Text(
              'مشاركة PDF',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (action == 'whatsapp') {
      if (customerPhone.isEmpty) {
        _showMessage('مفيش رقم للعميل — استخدم مشاركة PDF');
        return;
      }

      // نحفظ الفاتورة عشان نفتحها لما نرجع
      _pendingOrder = order;
      _pendingItems = items;
      _pendingCustomerName = customerName;
      _pendingCustomerPhone = customerPhone;

      final success = await PdfService.sendWhatsApp(
        phone: customerPhone,
        orderNumber: order.orderNumber,
        total: order.total,
        shopName: settings.shopName ?? '',
      );

      if (success) {
        _waitingForWhatsApp = true;
      } else {
        _showMessage('فشل فتح واتساب');
        _pendingOrder = null;
        _pendingItems = null;
        _pendingCustomerName = null;
        _pendingCustomerPhone = null;
      }
    } else if (action == 'share') {
      try {
        await PdfService.shareInvoice(
          order: order,
          items: items,
          settings: settings,
          customerName: customerName,
          customerPhone: customerPhone,
        );
      } catch (e) {
        _showMessage('فشل المشاركة: $e');
      }
    }
  }

  // نافذة مشاركة PDF بعد العودة من واتساب
  Future<void> _showPdfShareDialog() async {
    if (_pendingOrder == null ||
        _pendingItems == null ||
        _pendingCustomerName == null ||
        _pendingCustomerPhone == null) {
      return;
    }

    final settings = await _db.getShopSettings();
    if (settings == null || !mounted) return;

    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Text('الخطوة التالية'),
          ],
        ),
        content: const Text('اضغط "مشاركة PDF" لإرسال الفاتورة على واتساب'),
        actions: [
          TextButton(
            onPressed: () {
              _pendingOrder = null;
              _pendingItems = null;
              _pendingCustomerName = null;
              _pendingCustomerPhone = null;
              Navigator.pop(ctx);
            },
            child: const Text('تخطي', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await PdfService.shareInvoice(
                  order: _pendingOrder!,
                  items: _pendingItems!,
                  settings: settings,
                  customerName: _pendingCustomerName,
                  customerPhone: _pendingCustomerPhone,
                );
              } catch (e) {
                _showMessage('فشل المشاركة: $e');
              } finally {
                _pendingOrder = null;
                _pendingItems = null;
                _pendingCustomerName = null;
                _pendingCustomerPhone = null;
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.share),
            label: const Text('مشاركة PDF'),
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
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        title: const Text('بيع جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _scanBarcode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner, size: 22),
                label: const Text(
                  'مسح الباركود',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _cart.length,
                    itemBuilder: (ctx, i) => _buildCartItem(i),
                  ),
          ),
          if (_cart.isNotEmpty) _buildCompactSummary(),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 70, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'السلة فاضية',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 6),
          Text(
            'اضغط "مسح الباركود" لبدء البيع',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(int index) {
    final item = _cart[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${item.price} ج.م × ${item.quantity} = ${item.subtotal.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              icon: const Icon(Icons.remove_circle,
                  color: Colors.red, size: 24),
              onPressed: () => _decrementItem(index),
            ),
            Text(
              '${item.quantity}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              icon: const Icon(Icons.add_circle,
                  color: Colors.green, size: 24),
              onPressed: () => _incrementItem(index),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              icon: const Icon(Icons.delete, color: Colors.grey, size: 22),
              onPressed: () => _removeItem(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSummary() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 70),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('الإجمالي:',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(
                        '${_total.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'خصم',
                    suffixText: 'ج.م',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _paidController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'مدفوع',
                    suffixText: 'ج.م',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _completeSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_circle, size: 20),
                    label: const Text(
                      'إتمام البيع',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== نافذة بيانات العميل ====================

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog();

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('بيانات العميل'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'اسم العميل (اختياري)',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'رقم الهاتف (اختياري)',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context, {
              'name': _nameController.text.trim(),
              'phone': _phoneController.text.trim(),
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('التالي'),
        ),
      ],
    );
  }
}