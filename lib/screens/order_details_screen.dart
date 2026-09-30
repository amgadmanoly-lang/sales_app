import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/shop_settings.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final _db = DatabaseService();

  List<OrderItem> _items = [];
  bool _loading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    final items = await _db.getOrderItems(widget.order.id!);
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _shareInvoice() async {
    setState(() => _sharing = true);

    try {
      final settings = await _db.getShopSettings();
      if (settings == null) {
        _showMessage('لا توجد إعدادات للمحل');
        setState(() => _sharing = false);
        return;
      }

      await PdfService.shareInvoice(
        order: widget.order,
        items: _items,
        settings: settings,
      );
    } catch (e) {
      _showMessage('خطأ في المشاركة: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _deleteOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الفاتورة'),
        content: const Text(
            'سيتم حذف الفاتورة، لكن لن يتم تعديل المخزون تلقائياً. متأكد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteOrder(widget.order.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isSale = order.type == OrderType.sale;
    final color = isSale ? Colors.green : Colors.orange;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: Text('تفاصيل الفاتورة ${order.orderNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'حذف',
            onPressed: _deleteOrder,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildInfoRow('رقم الفاتورة', order.orderNumber),
                          const Divider(),
                          _buildInfoRow(
                            'النوع',
                            order.typeNameAr,
                            valueColor: color,
                          ),
                          const Divider(),
                          _buildInfoRow('التاريخ', _formatFullDate(order.createdAt)),
                          if (order.notes != null && order.notes!.isNotEmpty) ...[
                            const Divider(),
                            _buildInfoRow('ملاحظات', order.notes!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'المنتجات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._items.map((item) => _buildItemCard(item, color)),
                  const SizedBox(height: 16),

                  Card(
                    color: color.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildTotalRow('الإجمالي الفرعي',
                              '${(_items.fold(0.0, (s, i) => s + i.subtotal)).toStringAsFixed(2)} ج.م'),
                          if (order.discount > 0)
                            _buildTotalRow('الخصم',
                                '- ${order.discount.toStringAsFixed(2)} ج.م'),
                          const Divider(),
                          _buildTotalRow(
                            'الإجمالي',
                            '${order.total.toStringAsFixed(2)} ج.م',
                            isBold: true,
                            valueColor: color,
                          ),
                          if (isSale) ...[
                            const Divider(),
                            _buildTotalRow('المدفوع',
                                '${order.paid.toStringAsFixed(2)} ج.م'),
                            _buildTotalRow(
                              'المتبقي',
                              '${order.remaining.toStringAsFixed(2)} ج.م',
                              valueColor: order.remaining > 0
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // زر المشاركة
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _sharing ? null : _shareInvoice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), // واتساب
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _sharing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.share, size: 22),
                      label: const Text(
                        'مشاركة الفاتورة',
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

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(OrderItem item, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.inventory_2, color: color, size: 20),
        ),
        title: Text(
          item.productName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${item.price} ج.م × ${item.quantity}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '${item.subtotal.toStringAsFixed(2)} ج.م',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 17 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} - '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}