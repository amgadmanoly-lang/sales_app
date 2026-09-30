import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/database_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseService();

  bool _loading = true;
  String _period = 'today'; // today / week / month / all

  // إحصائيات
  double _totalSales = 0;
  double _totalReturns = 0;
  double _totalProfit = 0;
  int _salesCount = 0;
  int _returnsCount = 0;
  List<_ProductSale> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);

    final now = DateTime.now();
    DateTime fromDate;

    switch (_period) {
      case 'today':
        fromDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        fromDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        fromDate = DateTime(now.year, now.month, 1);
        break;
      default:
        fromDate = DateTime(2000);
    }

    final allOrders = await _db.getAllOrders();
    final filtered =
        allOrders.where((o) => o.createdAt.isAfter(fromDate)).toList();

    final products = await _db.getAllProducts();
    final productMap = {for (var p in products) p.id!: p};

    double sales = 0;
    double returns = 0;
    double profit = 0;
    int salesCount = 0;
    int returnsCount = 0;

    // لتجميع المنتجات
    final Map<int, int> productQuantities = {};
    final Map<int, double> productRevenues = {};

    for (final order in filtered) {
      if (order.type == OrderType.sale) {
        sales += order.total;
        salesCount++;

        final items = await _db.getOrderItems(order.id!);
        for (final item in items) {
          productQuantities[item.productId] =
              (productQuantities[item.productId] ?? 0) + item.quantity;
          productRevenues[item.productId] =
              (productRevenues[item.productId] ?? 0) + item.subtotal;

          // الربح = (سعر البيع - التكلفة) × الكمية
          final product = productMap[item.productId];
          if (product != null) {
            profit += (product.price - product.cost) * item.quantity;
          }
        }
      } else {
        returns += order.total;
        returnsCount++;
      }
    }

    // ترتيب المنتجات
    final topList = productQuantities.entries.map((e) {
      return _ProductSale(
        productName: productMap[e.key]?.name ?? 'محذوف',
        quantity: e.value,
        revenue: productRevenues[e.key] ?? 0,
      );
    }).toList();

    topList.sort((a, b) => b.quantity.compareTo(a.quantity));

    setState(() {
      _totalSales = sales;
      _totalReturns = returns;
      _totalProfit = profit;
      _salesCount = salesCount;
      _returnsCount = returnsCount;
      _topProducts = topList.take(10).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // فلاتر الفترة
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                _buildPeriodChip('اليوم', 'today'),
                const SizedBox(width: 6),
                _buildPeriodChip('الأسبوع', 'week'),
                const SizedBox(width: 6),
                _buildPeriodChip('الشهر', 'month'),
                const SizedBox(width: 6),
                _buildPeriodChip('الكل', 'all'),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadReports,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // الإحصائيات الرئيسية
                          _buildMainStatCard(),
                          const SizedBox(height: 12),

                          // شبكة إحصائيات
                          Row(
                            children: [
                              Expanded(
                                child: _buildSmallCard(
                                  'فواتير البيع',
                                  '$_salesCount',
                                  Icons.shopping_cart,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSmallCard(
                                  'المرتجعات',
                                  '$_returnsCount',
                                  Icons.assignment_return,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSmallCard(
                                  'إجمالي المبيعات',
                                  '${_totalSales.toStringAsFixed(0)} ج.م',
                                  Icons.attach_money,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSmallCard(
                                  'إجمالي المرتجعات',
                                  '${_totalReturns.toStringAsFixed(0)} ج.م',
                                  Icons.money_off,
                                  Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // المنتجات الأكثر مبيعاً
                          if (_topProducts.isNotEmpty) ...[
                            const Text(
                              'المنتجات الأكثر مبيعاً',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ..._topProducts.asMap().entries.map((entry) {
                              final i = entry.key + 1;
                              final p = entry.value;
                              return _buildTopProductCard(i, p);
                            }),
                          ] else
                            _buildNoData(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final selected = _period == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _period = value);
          _loadReports();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainStatCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.trending_up, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'صافي الربح',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_totalProfit.toStringAsFixed(0)} ج.م',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'من إجمالي مبيعات ${_totalSales.toStringAsFixed(0)} ج.م',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductCard(int rank, _ProductSale p) {
    final color = rank == 1
        ? Colors.amber
        : rank == 2
            ? Colors.grey
            : rank == 3
                ? Colors.brown
                : Colors.blueGrey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'الكمية: ${p.quantity} | الإيراد: ${p.revenue.toStringAsFixed(0)} ج.م',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoData() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 70, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'لا توجد مبيعات في هذه الفترة',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSale {
  final String productName;
  final int quantity;
  final double revenue;

  _ProductSale({
    required this.productName,
    required this.quantity,
    required this.revenue,
  });
}