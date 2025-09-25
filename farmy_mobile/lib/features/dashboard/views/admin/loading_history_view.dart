import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/loading_api_service.dart';
import '../../../../core/services/inventory_api_service.dart';

class LoadingHistoryView extends StatefulWidget {
  const LoadingHistoryView({super.key});

  @override
  State<LoadingHistoryView> createState() => _LoadingHistoryViewState();
}

class _LoadingHistoryViewState extends State<LoadingHistoryView> {
  late final LoadingApiService _loadingService;
  late final InventoryApiService _inventoryService;
  List<Map<String, dynamic>> _loadings = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String? _error;
  String _searchQuery = '';
  Map<String, dynamic>? _dailyStock;

  @override
  void initState() {
    super.initState();
    _loadingService = serviceLocator<LoadingApiService>();
    _inventoryService = serviceLocator<InventoryApiService>();
    _loadLoadingsForDate(_selectedDate);
  }

  Future<void> _loadLoadingsForDate(DateTime date) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allLoadings = await _loadingService.getAllLoadings();

      // Filter loadings strictly by operational date (loadingDate preferred)
      final filteredLoadings = allLoadings.where((loading) {
        final String? raw =
            (loading['loadingDate'] ?? loading['createdAt'] ?? loading['date'])
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
      final totalNetWeight = filteredLoadings.fold<num>(0, (sum, loading) {
        final net = (loading['netWeight'] ?? 0) as num;
        return sum + net;
      });
      debugPrint(
        '[LoadingHistory] date=${_formatDate(date)} entries=${filteredLoadings.length}',
      );
      debugPrint('[LoadingHistory] totalNetWeight=$totalNetWeight');
      for (final loading in filteredLoadings) {
        final id = (loading['_id']?.toString() ?? '')
            .padRight(8)
            .substring(0, 8);
        final net = (loading['netWeight'] ?? 0);
        final createdAt = loading['createdAt'] ?? loading['date'];
        debugPrint(
          '[LoadingHistory] item#$id netWeight=$net createdAt=$createdAt',
        );
      }

      // Fetch daily stock totals from backend for the selected date
      final day = DateTime(date.year, date.month, date.day);
      final daily = await _inventoryService.getDailyInventoryByDate(
        day.toIso8601String(),
      );

      // Debug compare list-sum vs system daily
      final sysNet = (daily['netLoadingWeight'] ?? 0) as num;
      debugPrint('[LoadingHistory] system.netLoadingWeight=$sysNet');
      debugPrint('[LoadingHistory] list.totalNetWeight=$totalNetWeight');

      setState(() {
        _loadings = filteredLoadings;
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
      _loadLoadingsForDate(picked);
    }
  }

  List<Map<String, dynamic>> get _filteredLoadings {
    if (_searchQuery.isEmpty) return _loadings;

    return _loadings.where((loading) {
      final customerName =
          loading['customer']?['name']?.toString().toLowerCase() ?? '';
      final chickenType =
          loading['chickenType']?['name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return customerName.contains(query) || chickenType.contains(query);
    }).toList();
  }

  double _calculateTotalWeight() {
    return _filteredLoadings.fold<double>(0.0, (sum, loading) {
      final netWeight = (loading['netWeight'] ?? 0) as num;
      return sum + netWeight.toDouble();
    });
  }

  double _calculateTotalValue() {
    return _filteredLoadings.fold<double>(0.0, (sum, loading) {
      final totalLoading = (loading['totalLoading'] ?? 0) as num;
      return sum + totalLoading.toDouble();
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
    Map<String, dynamic> loading,
  ) {
    final customer = loading['customer'];
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
            title: const Text('سجل طلبات التحميل'),
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
                onPressed: () => _loadLoadingsForDate(_selectedDate),
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever),
                tooltip: 'حذف كل سجلات التحميل',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('تأكيد الحذف'),
                      content: const Text(
                        'هل أنت متأكد من حذف جميع سجلات التحميل؟ لا يمكن التراجع.',
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
                    try {
                      await _loadingService.deleteAllLoadings();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم حذف كل سجلات التحميل'),
                        ),
                      );
                      await _loadLoadingsForDate(_selectedDate);
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
            onRefresh: () => _loadLoadingsForDate(_selectedDate),
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
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'تاريخ التحميل:',
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
                            hintText: 'البحث في العملاء أو نوع الدجاج...',
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
                  if (!_isLoading && _filteredLoadings.isNotEmpty) ...[
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
                              _filteredLoadings.length.toString(),
                              Icons.list_alt,
                              Colors.blue,
                            ),
                            const Divider(height: 1),
                            _buildSummaryTile(
                              'إجمالي الوزن (حسب القائمة)',
                              '${_calculateTotalWeight().toStringAsFixed(1)} كجم',
                              Icons.scale,
                              Colors.green,
                            ),
                            const Divider(height: 1),
                            _buildSummaryTile(
                              'وزن اليوم (من النظام)',
                              '${((_dailyStock?['netLoadingWeight'] ?? 0) as num).toDouble().toStringAsFixed(1)} كجم',
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
              onPressed: () => _loadLoadingsForDate(_selectedDate),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_filteredLoadings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'لا توجد نتائج للبحث'
                  : 'لا توجد طلبات تحميل',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'جرب البحث بكلمات مختلفة'
                  : 'لم يتم تسجيل أي طلبات تحميل في هذا التاريخ',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredLoadings.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = _filteredLoadings[index];
        final String title = m['customer']?['name'] ?? 'عميل غير معروف';
        final String subtitle = _formatDateTime(m['createdAt']);
        final num totalLoading = (m['totalLoading'] ?? 0) as num;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: const Icon(Icons.local_shipping, color: Colors.blue),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle),
          trailing: Text(
            '${totalLoading.toDouble().toStringAsFixed(0)} ج.م',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: Colors.white,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _LoadingDetailsPage(loading: m),
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

  Widget _buildLoadingCard(Map<String, dynamic> loading) {
    // Pre-calculate values to avoid repeated calculations
    final netWeight = (loading['netWeight'] ?? 0) as num;
    final totalLoading = (loading['totalLoading'] ?? 0) as num;
    final grossWeight = (loading['grossWeight'] ?? 0) as num;
    final quantity = (loading['quantity'] ?? 0) as num;
    final loadingPrice = (loading['loadingPrice'] ?? 0) as num;

    final orderId = loading['_id']?.toString().substring(0, 8) ?? 'غير معروف';
    final createdAt = _formatDateTime(loading['createdAt']);
    final chickenType = loading['chickenType']?['name'] ?? 'غير معروف';
    final customerName = loading['customer']?['name'] ?? 'غير معروف';
    final notes = loading['notes']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Column(
        children: [
          // Header with order info and total amount
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(Icons.local_shipping, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب تحميل #$orderId',
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${totalLoading.toDouble().toStringAsFixed(0)} ج.م',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details as ListTiles
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.1),
              child: const Icon(Icons.category, color: Colors.green, size: 20),
            ),
            title: const Text('نوع الدجاج'),
            subtitle: Text(chickenType),
            dense: true,
          ),
          const Divider(height: 1),

          GestureDetector(
            onTap: () => _navigateToCustomerHistory(context, loading),
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
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(
                Icons.scale_outlined,
                color: Colors.blue,
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
              backgroundColor: Colors.green.withOpacity(0.1),
              child: const Icon(
                Icons.attach_money,
                color: Colors.green,
                size: 20,
              ),
            ),
            title: const Text('سعر التحميل'),
            subtitle: Text(
              '${loadingPrice.toDouble().toStringAsFixed(0)} ج.م/كجم',
            ),
            dense: true,
          ),

          // Notes if available
          if (notes != null && notes.isNotEmpty) ...[
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey.withOpacity(0.1),
                child: const Icon(Icons.note, color: Colors.grey, size: 20),
              ),
              title: const Text('ملاحظات'),
              subtitle: Text(notes),
              dense: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingDetailsPage extends StatelessWidget {
  final Map<String, dynamic> loading;
  const _LoadingDetailsPage({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل طلب التحميل')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _LoadingHistoryViewState()._buildLoadingCard(loading),
        ),
      ),
    );
  }
}
