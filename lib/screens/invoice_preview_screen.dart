import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/order.dart';
import '../models/shop_settings.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final Order order;
  final List<OrderItem> items;
  final ShopSettings settings;
  final String? customerName;
  final String? customerPhone;

  const InvoicePreviewScreen({
    super.key,
    required this.order,
    required this.items,
    required this.settings,
    this.customerName,
    this.customerPhone,
  });

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _sharing = false;

  double get _subtotal =>
      widget.items.fold(0.0, (sum, item) => sum + item.subtotal);

  Future<void> _shareAsImage() async {
    setState(() => _sharing = true);

    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 2.0,
      );

      if (imageBytes == null) {
        _showMessage('فشل إنشاء الصورة');
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/invoice_${widget.order.orderNumber}.png');
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'فاتورة ${widget.order.orderNumber}',
        text: 'فاتورة رقم ${widget.order.orderNumber}\n'
            'الإجمالي: ${widget.order.total.toStringAsFixed(2)} ج.م',
      );
    } catch (e) {
      _showMessage('خطأ: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
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
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Text('معاينة الفاتورة'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Screenshot(
                controller: _screenshotController,
                child: _buildInvoiceWidget(),
              ),
            ),
          ),
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildInvoiceWidget() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ===== الهيدر =====
          Row(
            children: [
              // الشعار
              if (widget.settings.logoPath != null &&
                  File(widget.settings.logoPath!).existsSync())
                Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: FileImage(File(widget.settings.logoPath!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.settings.shopName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    if (widget.settings.phone?.isNotEmpty == true)
                      Text(
                        'ت: ${widget.settings.phone}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    if (widget.settings.address?.isNotEmpty == true)
                      Text(
                        widget.settings.address!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.order.type == OrderType.sale
                      ? const Color(0xFF2E7D32)
                      : Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.order.type == OrderType.sale ? 'فاتورة بيع' : 'فاتورة مرتجع',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ===== معلومات الفاتورة =====
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رقم الفاتورة',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      widget.order.orderNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'التاريخ',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      _formatDate(widget.order.createdAt),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ===== بيانات العميل =====
          if ((widget.customerName?.isNotEmpty == true) ||
              (widget.customerPhone?.isNotEmpty == true)) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'بيانات العميل',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.customerName?.isNotEmpty == true)
                    Text('الاسم: ${widget.customerName}',
                        style: const TextStyle(fontSize: 12)),
                  if (widget.customerPhone?.isNotEmpty == true)
                    Text('الهاتف: ${widget.customerPhone}',
                        style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ===== جدول المنتجات =====
          _buildItemsTable(),

          const SizedBox(height: 16),

          // ===== الإجماليات =====
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  _buildTotalRow('الإجمالي الفرعي',
                      '${_subtotal.toStringAsFixed(2)} ج.م'),
                  if (widget.order.discount > 0)
                    _buildTotalRow('الخصم',
                        '- ${widget.order.discount.toStringAsFixed(2)} ج.م'),
                  const Divider(),
                  _buildTotalRow(
                    'الإجمالي',
                    '${widget.order.total.toStringAsFixed(2)} ج.م',
                    isBold: true,
                    valueColor: widget.order.type == OrderType.sale
                        ? const Color(0xFF2E7D32)
                        : Colors.orange,
                  ),
                  if (widget.order.type == OrderType.sale) ...[
                    const SizedBox(height: 6),
                    _buildTotalRow('المدفوع',
                        '${widget.order.paid.toStringAsFixed(2)} ج.م'),
                    _buildTotalRow(
                      'المتبقي',
                      '${widget.order.remaining.toStringAsFixed(2)} ج.م',
                      valueColor: widget.order.remaining > 0
                          ? Colors.red
                          : const Color(0xFF2E7D32),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ===== الفوتر =====
          if (widget.settings.footerText?.isNotEmpty == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.settings.footerText!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),

          const SizedBox(height: 10),
          Center(
            child: Text(
              'شكراً لتعاملكم معنا',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    return Table(
      border: TableBorder.all(
        color: Colors.grey[400]!,
        width: 0.5,
        borderRadius: BorderRadius.circular(8),
      ),
      columnWidths: const {
        0: FlexColumnWidth(0.6),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1.3),
      },
      children: [
        // رأس الجدول
        TableRow(
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(0.1),
          ),
          children: [
            _headerCell('#'),
            _headerCell('المنتج'),
            _headerCell('السعر'),
            _headerCell('الكمية'),
            _headerCell('الإجمالي'),
          ],
        ),
        // صفوف المنتجات
        ...widget.items.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final item = entry.value;
          return TableRow(
            children: [
              _cell('$i'),
              _cell(item.productName),
              _cell('${item.price.toStringAsFixed(2)} ج.م'),
              _cell('${item.quantity}'),
              _cell('${item.subtotal.toStringAsFixed(2)} ج.م'),
            ],
          );
        }),
      ],
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1565C0),
        ),
      ),
    );
  }

  Widget _cell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _sharing ? null : _shareAsImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
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
                    : const Icon(Icons.share),
                label: const Text(
                  'مشاركة كصورة',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}