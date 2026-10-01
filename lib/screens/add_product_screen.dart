import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import 'barcode_scanner_screen.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();

  // ⭐ بدل _quantityController
  final _stockController = TextEditingController(text: '0');
  final _displayController = TextEditingController(text: '0');

  final _categoryController = TextEditingController();

  bool _saving = false;
  bool _checkingBarcode = false;
  Product? _loadedProduct;

  bool get _isEditing => widget.product != null || _loadedProduct != null;
  Product? get _currentProduct => widget.product ?? _loadedProduct;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _fillData(widget.product!);
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _displayController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _fillData(Product p) {
    _barcodeController.text = p.barcode;
    _nameController.text = p.name;
    _descriptionController.text = p.description ?? '';
    _priceController.text = p.price.toString();
    _costController.text = p.cost.toString();
    _stockController.text = p.stockQuantity.toString();
    _displayController.text = p.displayQuantity.toString();
    _categoryController.text = p.category ?? '';
  }

  Future<void> _checkBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return;
    if (widget.product != null) return;

    setState(() => _checkingBarcode = true);

    final existing = await _db.getProductByBarcode(barcode.trim());

    setState(() => _checkingBarcode = false);

    if (existing != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('المنتج موجود'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'المنتج موجود بالفعل في قاعدة البيانات:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📦 ${existing.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('💰 السعر: ${existing.price} ج.م'),
                    Text('🏪 المخزن: ${existing.stockQuantity}'),
                    Text('🛒 العرض: ${existing.displayQuantity}'),
                    Text('🔢 الباركود: ${existing.barcode}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'هل تريد فتحه للتعديل؟',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('تعديل'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        setState(() {
          _loadedProduct = existing;
          _fillData(existing);
        });
        _showMessage('يمكنك تعديل المنتج الآن');
      } else if (mounted) {
        _barcodeController.clear();
      }
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _barcodeController.text = result;
      });
      await _checkBarcode(result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final barcode = _barcodeController.text.trim();

      if (!_isEditing) {
        final exists = await _db.barcodeExists(barcode);
        if (exists) {
          _showMessage('الباركود مسجل بالفعل ❌');
          setState(() => _saving = false);
          return;
        }
      }

      final stock = int.parse(_stockController.text.trim());
      final display = int.parse(_displayController.text.trim());

      final product = Product(
        id: _currentProduct?.id,
        barcode: barcode,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        cost: double.parse(_costController.text.trim()),
        stockQuantity: stock,
        displayQuantity: display,
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
      );

      if (_isEditing) {
        await _db.updateProduct(product);
        _showMessage('تم تعديل المنتج ✅');
      } else {
        await _db.insertProduct(product);
        _showMessage('تم إضافة المنتج ✅');
      }

      if (mounted) Navigator.pop(context, true);
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
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text(_isEditing ? 'تعديل منتج' : 'إضافة منتج'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_isEditing && widget.product == null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'أنت في وضع التعديل',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),

              // الباركود + زر المسح
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      enabled: !_isEditing,
                      decoration: InputDecoration(
                        labelText: 'الباركود',
                        prefixIcon: const Icon(Icons.qr_code),
                        suffixIcon: _checkingBarcode
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                        filled: _isEditing,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'أدخل الباركود' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 56,
                    width: 56,
                    child: ElevatedButton(
                      onPressed: _isEditing ? null : _scanBarcode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Icon(Icons.camera_alt),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'اسم المنتج',
                  prefixIcon: const Icon(Icons.inventory_2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'أدخل اسم المنتج' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'الوصف (اختياري)',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'سعر البيع',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        if (double.tryParse(v) == null) return 'رقم غلط';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'سعر التكلفة',
                        prefixIcon: const Icon(Icons.money_off),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        if (double.tryParse(v) == null) return 'رقم غلط';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ⭐ حقل المخزن + حقل العرض
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'كمية المخزن',
                        prefixIcon: const Icon(Icons.warehouse),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        if (int.tryParse(v) == null) return 'رقم صحيح';
                        if (int.parse(v) < 0) return 'رقم موجب';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _displayController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'كمية العرض',
                        prefixIcon: const Icon(Icons.storefront),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        if (int.tryParse(v) == null) return 'رقم صحيح';
                        if (int.parse(v) < 0) return 'رقم موجب';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'المخزن = الكمية الاحتياطية\nالعرض = الكمية المعروضة للبيع',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'الفئة (اختياري)',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
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
                      : const Icon(Icons.save),
                  label: Text(
                    _isEditing ? 'حفظ التعديلات' : 'إضافة المنتج',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}