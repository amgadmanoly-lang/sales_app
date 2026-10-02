import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'sale_screen.dart';
import 'return_screen.dart';
import 'order_details_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _db = DatabaseService();
  final _auth = AuthService();
  final _searchController = TextEditingController();

  List<Order> _allOrders = [];
  List<Order> _orders = [];
  bool _loading = true;
  String _filter = 'all';

  // ⭐ هل المستخدم يقدر يبيع؟
  bool get _canSell => _auth.canSell;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);

    List<Order> orders;
    if (_filter == 'sale') {
      orders = await _db.getSalesOrders();
    } else if (_filter == 'return') {
      orders = await _db.getReturnOrders();
    } else {
      orders = await _db.getAllOrders();
    }

    setState(() {
      _allOrders = orders;
      _applySearch(_searchController.text);
      _loading = false;
    });
  }

  void _applySearch(String query) {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      setState(() => _orders = _allOrders);
      return;
    }

    final filtered = _allOrders.where((o) {
      if (o.orderNumber.toLowerCase().contains(q)) return true;
      if (o.notes != null && o.notes!.toLowerCase().contains(q)) return true;
      if (o.total.toString().contains(q)) return true;
      return false;
    }).toList();

    setState(() => _orders = filtered);
  }

  String? _extractCustomerName(Order order) {
    if (order.notes == null || order.notes!.isEmpty) return null;
    final notes = order.notes!;
    if (!notes.startsWith('العميل: ')) return null;
    final parts = notes.substring(8).split(' - ');
    if (parts.isEmpty) return null;
    final name = parts[0].trim();
    return name.isEmpty ? null : name;
  }

  String? _extractCustomerPhone(Order order) {
    if (order.notes == null || order.notes!.isEmpty) return null;
    final notes = order.notes!;
    if (!notes.startsWith('العميل: ')) return null;
    final parts = notes.substring(8).split(' - ');
    if (parts.length < 2) return null;
    final phone = parts[1].trim();
    return phone.isEmpty ? null : phone;
  }

  // ⭐ فحص الصلاحية قبل البيع
  void _onSalePressed() {
    if (!_canSell) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'ليس لديك صلاحية البيع. فعّل "دور الكاشير" من إعدادات المستخدم.'),
          backgroundColor: Colors.orange[700],
        ),
      );
      return;
    }
    _openSale();
  }

  // ⭐ فحص الصلاحية قبل المرتجع
  void _onReturnPressed() {
    if (!_canSell) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'ليس لديك صلاحية المرتجع. فعّل "دور الكاشير" من إعدادات المستخدم.'),
          backgroundColor: Colors.orange[700],
        ),
      );
      return;
    }
    _openReturn();
  }

  Future<void> _openSale() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SaleScreen()),
    );
    _loadOrders();
  }

  Future<void> _openReturn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReturnScreen()),
    );
    _loadOrders();
  }

  Future<void> _openDetails(Order order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(order: order),
      ),
    );
    _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _applySearch,
              decoration: InputDecoration(
                hintText: 'ابحث برقم الفاتورة / اسم العميل / رقم الهاتف',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _applySearch('');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // فلاتر
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildFilterChip('الكل', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('بيع', 'sale'),
                const SizedBox(width: 8),
                _buildFilterChip('مرتجع', 'return'),
              ],
            ),
          ),

          // قائمة الفواتير
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 160),
                          itemCount: _orders.length,
                          itemBuilder: (ctx, i) =>
                              _buildOrderCard(_orders[i]),
                        ),
                      ),
          ),
        ],
      ),
      // ⭐ الأزرار تظهر فقط لو عنده صلاحية البيع
      floatingActionButton: _canSell
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'return',
                  onPressed: _onReturnPressed,
                  backgroundColor: Colors.orange,
                  icon: const Icon(Icons.assignment_return,
                      color: Colors.white),
                  label: const Text('مرتجع',
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'sale',
                  onPressed: _onSalePressed,
                  backgroundColor: Colors.green,
                  icon: const Icon(Icons.add_shopping_cart,
                      color: Colors.white),
                  label: const Text('بيع جديد',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _filter = value);
          _loadOrders();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.blue : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchController.text.isNotEmpty
                ? Icons.search_off
                : Icons.receipt_long,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'لا توجد نتائج'
                : 'لا توجد فواتير',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty
                ? 'جرّب كلمة بحث أخرى'
                : (_canSell
                    ? 'اضغط "بيع جديد" أو "مرتجع"'
                    : 'أنت في وضع العرض فقط'),
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final isSale = order.type == OrderType.sale;
    final color = isSale ? Colors.green : Colors.orange;

    final customerName = _extractCustomerName(order);
    final customerPhone = _extractCustomerPhone(order);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isSale ? Icons.sell : Icons.assignment_return,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                order.orderNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                order.typeNameAr,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(order.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${order.total.toStringAsFixed(2)} ج.م',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),

              if (customerName != null || customerPhone != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (customerName != null) ...[
                      const Icon(Icons.person,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          customerName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (customerName != null && customerPhone != null)
                      const SizedBox(width: 12),
                    if (customerPhone != null) ...[
                      const Icon(Icons.phone,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        customerPhone,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';

    return '${date.day}/${date.month}/${date.year}';
  }
}