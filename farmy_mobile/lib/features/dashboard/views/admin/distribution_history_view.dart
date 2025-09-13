import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/distribution_api_service.dart';

class DistributionHistoryView extends StatefulWidget {
  const DistributionHistoryView({super.key});

  @override
  State<DistributionHistoryView> createState() =>
      _DistributionHistoryViewState();
}

class _DistributionHistoryViewState extends State<DistributionHistoryView> {
  late final DistributionApiService _distributionService;
  List<Map<String, dynamic>> _distributions = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _distributionService = serviceLocator<DistributionApiService>();
    _loadDistributionsForDate(_selectedDate);
  }

  Future<void> _loadDistributionsForDate(DateTime date) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allDistributions = await _distributionService.getAllDistributions();

      // Filter distributions by selected date
      final filteredDistributions = allDistributions.where((distribution) {
        final distributionDate = DateTime.parse(
          distribution['createdAt'] ?? distribution['distributionDate'] ?? '',
        );
        return distributionDate.year == date.year &&
            distributionDate.month == date.month &&
            distributionDate.day == date.day;
      }).toList();

      setState(() {
        _distributions = filteredDistributions;
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
      final employeeName =
          distribution['employee']?['username']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return customerName.contains(query) || employeeName.contains(query);
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
            ],
          ),
          body: Column(
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
                        const Icon(Icons.calendar_today, color: Colors.green),
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
                        hintText: 'البحث في العملاء أو الموظفين...',
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

              // Summary cards
              if (!_isLoading && _filteredDistributions.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'عدد الطلبات',
                          _filteredDistributions.length.toString(),
                          Icons.list_alt,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'إجمالي الوزن',
                          '${_calculateTotalWeight().toStringAsFixed(1)} كجم',
                          Icons.scale,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'إجمالي القيمة',
                          '${_calculateTotalValue().toStringAsFixed(0)} ج.م',
                          Icons.attach_money,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _loadDistributionsForDate(_selectedDate),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredDistributions.length,
      itemBuilder: (context, index) {
        final distribution = _filteredDistributions[index];
        return _buildDistributionCard(distribution);
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
    final employeeName = distribution['employee']?['username'] ?? 'غير معروف';

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
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.1),
              child: const Icon(Icons.person, color: Colors.orange, size: 20),
            ),
            title: const Text('العميل'),
            subtitle: Text(customerName),
            dense: true,
          ),
          const Divider(height: 1),

          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(Icons.work, color: Colors.blue, size: 20),
            ),
            title: const Text('الموظف'),
            subtitle: Text(employeeName),
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
