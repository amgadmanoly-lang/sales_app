import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/database_service.dart';

class MoveToDisplayScreen extends StatefulWidget {
  final Product product;

  const MoveToDisplayScreen({super.key, required this.product});

  @override
  State<MoveToDisplayScreen> createState() => _MoveToDisplayScreenState();
}

class _MoveToDisplayScreenState extends State<MoveToDisplayScreen> {
  final _db = DatabaseService();
  final _quantityController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _moveAll() async {
    setState(() => _quantityController.text = widget.product.stockQuantity.toString());
  }

  Future<void> _save() async {
    final amountText = _quantityController.text.trim();

    if (amountText.isEmpty) {
      _showMessage('أدخل الكمية');
      return;
    }

    final amount = int.tryParse(amountText);

    if (amount == null || amount <= 0) {
      _showMessage('الكمية لازم تكون أكبر من 0');
      return;
    }

    if (amount > widget.product.stockQuantity) {
      _showMessage('المخزن فيه ${widget.product.stockQuantity} فقط');
      return;
    }

    setState(() => _saving = true);

    final success = await _db.moveToDisplay(widget.product.id!, amount);

    setState(() => _saving = false);

    if (success) {
      _showMessage('تم نقل $amount للمخزن ✅');
      if (mounted) Navigator.pop(context, true);
    } else {
      _showMessage('فشل النقل ❌');
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
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        title: const Text('نقل للمخزن'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== معلومات المنتج =====
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_2,
                              color: Colors.blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.product.barcode,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQtyBox(
                            icon: Icons.warehouse,
                            label: 'المخزن حالياً',
                            value: '${widget.product.stockQuantity}',
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQtyBox(
                            icon: Icons.storefront,
                            label: 'العرض حالياً',
                            value: '${widget.product.displayQuantity}',
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ===== حقل الكمية =====
            const Text(
              'الكمية المراد نقلها:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 24,
                  color: Colors.grey[400],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
            const SizedBox(height: 12),

            // زر "نقل الكل"
            if (widget.product.stockQuantity > 0)
              TextButton.icon(
                onPressed: _moveAll,
                icon: const Icon(Icons.done_all, size: 18),
                label: Text(
                    'نقل كل المتاح (${widget.product.stockQuantity})'),
              ),

            const SizedBox(height: 24),

            // ===== ملاحظة =====
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'النقل يحوّل كمية من المخزن إلى العرض.\nالباقي في المخزن يفضل كما هو.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ===== زر الحفظ =====
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                    : const Icon(Icons.swap_horiz),
                label: const Text(
                  'نقل للعرض',
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

  Widget _buildQtyBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}