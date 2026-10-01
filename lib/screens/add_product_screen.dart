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
  final _quantityController = TextEditingController();
  final _categoryController = TextEditingController();

  bool _saving = false;
  bool _checkingBarcode = false;

  // ⭐ لما نفتح منتج موجود، نتتبعه هنا
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
    _quantityController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  // ⭐ نملأ البيانات من المنتج
  void _fillData(Product p) {
    _barcodeController.text = p.barcode;
    _nameController.text = p.name;
    _descriptionController.text = p.description ?? '';
    _priceController.text = p.price.toString();
    _costController.text = p.cost.toString();
    _quantityController.text = p.quantity.toString();
    _categoryController.text = p.category ?? '';
  }

  // ⭐ فحص الباركود
  Future<void> _checkBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return;

    // لو إحنا بالفعل في وضع تعديل → مش محتاجين فحص
    if (widget.product != null) return;

    setState(() => _checkingBarcode = true);

    final existing = await _db.getProductByBarcode(barcode.trim());

    setState(() => _checkingBarcode = false);

    if (existing != null) {
      // الباركود موجود → نفتحه للتعديل
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
                    Text('📊 الكمية: ${existing.quantity}'),
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
        // نفتح المنتج في نفس الشاشة
        setState(() {
          _loadedProduct = existing;
          _fillData(existing);
        });
        _showMessage('يمكنك تعديل المنتج الآن');
      } else if (mounted) {
        // إلغاء → امسح الباركود
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
      // ⭐ نفحص الباركود مباشرة
      await _checkBarcode(result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final barcode = _barcodeController.text.trim();

      // لو إضافة جديدة، نتأكد إن الباركود مش موجود
      if (!_isEditing) {
        final exists = await _db.barcodeExists(barcode);
        if (exists) {
          _showMessage('الباركود مسجل بالفعل ❌');
          setState(() => _saving = false);
          return;
        }
      }

      final product = Product(
        id: _currentProduct?.id,
        barcode: barcode,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        cost: double.parse(_costController.text.trim()),
        quantity: int.parse(_quantityController.text.trim()),
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
              // ⭐ شارة "وضع التعديل"
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

              // اسم المنتج
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

              // الوصف
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

              // السعر + التكلفة
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

              // الكمية + الفئة
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'الكمية',
                        prefixIcon: const Icon(Icons.numbers),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        if (int.tryParse(v) == null) return 'رقم صحيح فقط';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _categoryController,
                      decoration: InputDecoration(
                        labelText: 'الفئة (اختياري)',
                        prefixIcon: const Icon(Icons.category),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // زر الحفظ
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