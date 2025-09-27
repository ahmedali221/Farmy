import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/distribution_api_service.dart';
import '../../../../core/services/inventory_api_service.dart';

class DistributionHistoryView extends StatefulWidget {
  const DistributionHistoryView({super.key});

  @override
  State<DistributionHistoryView> createState() =>
      _DistributionHistoryViewState();
}

class _DistributionHistoryViewState extends State<DistributionHistoryView> {
  late final DistributionApiService _distributionService;
  late final InventoryApiService _inventoryService;
  List<Map<String, dynamic>> _distributions = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String? _error;
  String _searchQuery = '';
  Map<String, dynamic>? _dailyStock;

  @override
  void initState() {
    super.initState();
    _distributionService = serviceLocator<DistributionApiService>();
    _inventoryService = serviceLocator<InventoryApiService>();
    _loadDistributionsForDate(_selectedDate);
  }

  Future<void> _loadDistributionsForDate(DateTime date) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allDistributions = await _distributionService.getAllDistributions();

      // Filter distributions strictly by operational date (distributionDate preferred)
      final filteredDistributions = allDistributions.where((distribution) {
        final String? raw =
            (distribution['distributionDate'] ?? distribution['createdAt'])
                ?.toString();
        if (raw == null || raw.isEmpty) return false;
        DateTime dt;
        try {
          dt = DateTime.parse(raw);
        } catch (_) {
          return false;
        }
        return dt.year == date.year &&
            dt.month == date.month &&
            dt.day == date.day;
      }).toList();

      // Debug totals for the selected day
      final totalNetWeight = filteredDistributions.fold<num>(0, (sum, d) {
        final net = (d['netWeight'] ?? 0) as num;
        return sum + net;
      });

      // Fetch daily stock totals from backend for the selected date
      final day = DateTime(date.year, date.month, date.day);
      final daily = await _inventoryService.getDailyInventoryByDate(
        day.toIso8601String(),
      );
      final sysNet = (daily['netDistributionWeight'] ?? 0) as num;
      debugPrint('[DistributionHistory] system.netDistributionWeight=$sysNet');
      debugPrint('[DistributionHistory] list.totalNetWeight=$totalNetWeight');

      setState(() {
        _distributions = filteredDistributions;
        _dailyStock = daily;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadDistributionsForDate(picked);
    }
  }

  List<Map<String, dynamic>> get _filteredDistributions {
    if (_searchQuery.isEmpty) return _distributions;

    return _distributions.where((distribution) {
      final customerName =
          distribution['customer']?['name']?.toString().toLowerCase() ?? '';
      final userName =
          distribution['user']?['username']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return customerName.contains(query) || userName.contains(query);
    }).toList();
  }

  double _calculateTotalWeight() {
    return _filteredDistributions.fold<double>(0.0, (sum, distribution) {
      final netWeight = (distribution['netWeight'] ?? 0) as num;
      return sum + netWeight.toDouble();
    });
  }

  double _calculateTotalValue() {
    return _filteredDistributions.fold<double>(0.0, (sum, distribution) {
      final totalAmount = (distribution['totalAmount'] ?? 0) as num;
      return sum + totalAmount.toDouble();
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'غير معروف';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'تاريخ غير صحيح';
    }
  }

  void _navigateToCustomerHistory(
    BuildContext context,
    Map<String, dynamic> distribution,
  ) {
    final customer = distribution['customer'];
    if (customer != null) {
      context.push('/customer-history', extra: {'customer': customer});
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!didPop) {
          context.go('/admin-dashboard');
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('سجل طلبات التوزيع'),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/admin-dashboard');
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _loadDistributionsForDate(_selectedDate),
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever),
                tooltip: 'حذف كل سجلات التوزيع',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('تأكيد الحذف'),
                      content: const Text(
                        'هل أنت متأكد من حذف جميع سجلات التوزيع؟ لا يمكن التراجع.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('إلغاء'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    // Ask for password before deletion
                    final pwd = await showDialog<String?>(
                      context: context,
                      builder: (ctx) {
                        final ctrl = TextEditingController();
                        return AlertDialog(
                          title: const Text('إدخال كلمة المرور'),
                          content: TextField(
                            controller: ctrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'كلمة المرور',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(null),
                              child: const Text('إلغاء'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(ctx).pop(ctrl.text.trim()),
                              child: const Text('تأكيد'),
                            ),
                          ],
                        );
                      },
                    );
                    if (pwd == null || pwd.isEmpty) return;
                    if (pwd != 'delete') {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'كلمة المرور غير صحيحة. استخدم "delete"',
                          ),
                        ),
                      );
                      return;
                    }
                    try {
                      await _distributionService.deleteAllDistributions();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم حذف كل سجلات التوزيع'),
                        ),
                      );
                      await _loadDistributionsForDate(_selectedDate);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
                    }
                  }
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _loadDistributionsForDate(_selectedDate),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Header with date selector and search
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[50],
                    child: Column(
                      children: [
                        // Date selector
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'تاريخ التوزيع:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(_formatDate(_selectedDate)),
                              onPressed: _selectDate,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Search bar
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'البحث في العملاء أو المستخدمين...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // Summary list (more compact & readable)
                  if (!_isLoading && _filteredDistributions.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        elevation: 1,
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.info_outline),
                              title: const Text('ملخص اليوم'),
                              subtitle: Text(_formatDate(_selectedDate)),
                            ),
                            const Divider(height: 1),
                            _buildSummaryTile(
                              'عدد الطلبات',
                              _filteredDistributions.length.toString(),
                              Icons.list_alt,
                              Colors.green,
                            ),
                            const Divider(height: 1),
                            _buildSummaryTile(
                              'إجمالي الوزن (حسب القائمة)',
                              '${_calculateTotalWeight().toStringAsFixed(1)} كجم',
                              Icons.scale,
                              Colors.blue,
                            ),
                            const Divider(height: 1),
                            _buildSummaryTile(
                              'وزن اليوم (من النظام)',
                              '${((_dailyStock?['netDistributionWeight'] ?? 0) as num).toDouble().toStringAsFixed(1)} كجم',
                              Icons.calendar_today,
                              Colors.purple,
                            ),
                            const Divider(height: 1),
                            _buildSummaryTile(
                              'إجمالي القيمة',
                              '${_calculateTotalValue().toStringAsFixed(0)} ج.م',
                              Icons.attach_money,
                              Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Content
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'خطأ في تحميل البيانات',
              style: TextStyle(fontSize: 18, color: Colors.red[700]),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.red[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadDistributionsForDate(_selectedDate),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    if (_filteredDistributions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.outbound_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'لا توجد نتائج للبحث'
                  : 'لا توجد طلبات توزيع',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'جرب البحث بكلمات مختلفة'
                  : 'لم يتم تسجيل أي طلبات توزيع في هذا التاريخ',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredDistributions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final d = _filteredDistributions[index];
        final String title = d['customer']?['name'] ?? 'عميل غير معروف';
        final String subtitle = _formatDateTime(
          d['createdAt'] ?? d['distributionDate'],
        );
        final num totalAmount = (d['totalAmount'] ?? 0) as num;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.green.withOpacity(0.1),
            child: const Icon(Icons.outbound, color: Colors.green),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle),
          trailing: Text(
            '${totalAmount.toDouble().toStringAsFixed(0)} ج.م',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: Colors.white,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _DistributionDetailsPage(distribution: d),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryTile(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: Text(
        value,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      dense: true,
    );
  }

  Widget _buildDistributionCard(Map<String, dynamic> distribution) {
    // Pre-calculate values to avoid repeated calculations
    final netWeight = (distribution['netWeight'] ?? 0) as num;
    final totalAmount = (distribution['totalAmount'] ?? 0) as num;
    final grossWeight = (distribution['grossWeight'] ?? 0) as num;
    final quantity = (distribution['quantity'] ?? 0) as num;
    final price = (distribution['price'] ?? 0) as num;

    final orderId =
        distribution['_id']?.toString().substring(0, 8) ?? 'غير معروف';
    final createdAt = _formatDateTime(
      distribution['createdAt'] ?? distribution['distributionDate'],
    );
    final customerName = distribution['customer']?['name'] ?? 'غير معروف';
    final userName = distribution['user']?['username'] ?? 'غير معروف';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Column(
        children: [
          // Header with order info and total amount
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.1),
                  child: const Icon(Icons.outbound, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب توزيع #$orderId',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        createdAt,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${totalAmount.toDouble().toStringAsFixed(0)} ج.م',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details as ListTiles
          GestureDetector(
            onTap: () => _navigateToCustomerHistory(context, distribution),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.withOpacity(0.1),
                child: const Icon(Icons.person, color: Colors.orange, size: 20),
              ),
              title: const Text('العميل'),
              subtitle: Text(
                customerName,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
              dense: true,
            ),
          ),
          const Divider(height: 1),

          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(Icons.person, color: Colors.blue, size: 20),
            ),
            title: const Text('المستخدم'),
            subtitle: Text(userName),
            dense: true,
          ),
          const Divider(height: 1),

          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.withOpacity(0.1),
              child: const Icon(
                Icons.inventory,
                color: Colors.purple,
                size: 20,
              ),
            ),
            title: const Text('الكمية'),
            subtitle: Text('${quantity.toInt()} وحدة'),
            dense: true,
          ),
          const Divider(height: 1),

          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.withOpacity(0.1),
              child: const Icon(Icons.scale, color: Colors.red, size: 20),
            ),
            title: const Text('الوزن القائم'),
            subtitle: Text('${grossWeight.toDouble().toStringAsFixed(1)} كجم'),
            dense: true,
          ),
          const Divider(height: 1),

          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.1),
              child: const Icon(
                Icons.scale_outlined,
                color: Colors.green,
                size: 20,
              ),
            ),
            title: const Text('الوزن الصافي'),
            subtitle: Text('${netWeight.toDouble().toStringAsFixed(1)} كجم'),
            dense: true,
          ),
          const Divider(height: 1),

          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(
                Icons.attach_money,
                color: Colors.blue,
                size: 20,
              ),
            ),
            title: const Text('سعر الكيلو'),
            subtitle: Text('${price.toDouble().toStringAsFixed(0)} ج.م/كجم'),
            dense: true,
          ),
        ],
      ),
    );
  }
}

class _DistributionDetailsPage extends StatelessWidget {
  final Map<String, dynamic> distribution;
  const _DistributionDetailsPage({required this.distribution});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل طلب التوزيع')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _DistributionHistoryViewState()._buildDistributionCard(
            distribution,
          ),
        ),
      ),
    );
  }
}
