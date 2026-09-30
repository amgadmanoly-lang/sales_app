import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'barcode_scanner_screen.dart';

class ReturnScreen extends StatefulWidget {
  const ReturnScreen({super.key});

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  final _db = DatabaseService();
  final _auth = AuthService();
  final _notesController = TextEditingController();

  final List<OrderItem> _cart = [];
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _total => _cart.fold(0.0, (sum, item) => sum + item.subtotal);

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

    _addToCart(product);
  }

  void _addToCart(Product product) {
    final index = _cart.indexWhere((item) => item.productId == product.id);
    if (index != -1) {
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

  Future<void> _completeReturn() async {
    if (_cart.isEmpty) {
      _showMessage('لا توجد منتجات للمرتجع');
      return;
    }

    setState(() => _saving = true);

    try {
      final orderNumber = await _db.generateOrderNumber(OrderType.returnOrder);

      final order = Order(
        orderNumber: orderNumber,
        type: OrderType.returnOrder,
        total: _total,
        paid: _total,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        userId: _auth.currentUser?.id,
      );

      await _db.createOrder(order, _cart);

      _showMessage('تم إتمام المرتجع ✅ فاتورة: $orderNumber');

      if (mounted) {
        setState(() {
          _cart.clear();
          _notesController.clear();
        });
      }
    } catch (e) {
      _showMessage('خطأ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        title: const Text('مرتجع جديد'),
      ),
      body: Column(
        children: [
          // زر مسح الباركود
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _scanBarcode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: const Text(
                  'مسح الباركود للمرتجع',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          // قائمة المنتجات
          Expanded(
            child: _cart.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _cart.length,
                    itemBuilder: (ctx, i) => _buildCartItem(i),
                  ),
          ),

          // ملخص
          if (_cart.isNotEmpty) _buildSummary(),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_return_outlined,
              size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد منتجات للمرتجع',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'امسح باركود المنتج المُرتجع',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(int index) {
    final item = _cart[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        title: Text(
          item.productName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${item.price} ج.م × ${item.quantity} = ${item.subtotal.toStringAsFixed(2)} ج.م',
          style: const TextStyle(fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: () => _decrementItem(index),
            ),
            Text(
              '${item.quantity}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: () => _incrementItem(index),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.grey),
              onPressed: () => _removeItem(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // الإجمالي
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text(
                  'إجمالي المرتجع',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_total.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ملاحظات
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'ملاحظات (اختياري)',
              hintText: 'سبب المرتجع...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // زر إتمام المرتجع
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _completeReturn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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
                  : const Icon(Icons.assignment_return),
              label: const Text(
                'إتمام المرتجع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}