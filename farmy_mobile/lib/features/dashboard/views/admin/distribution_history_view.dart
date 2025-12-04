import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/customer_api_service.dart';
import '../../../../core/services/distribution_api_service.dart';
import '../../../../core/services/inventory_api_service.dart';
import '../../../../core/utils/pdf_arabic_utils.dart';

class DistributionHistoryView extends StatefulWidget {
  const DistributionHistoryView({super.key});

  @override
  State<DistributionHistoryView> createState() =>
      _DistributionHistoryViewState();
}

class _DistributionHistoryViewState extends State<DistributionHistoryView> {
  late final DistributionApiService _distributionService;
  late final InventoryApiService _inventoryService;
  late final CustomerApiService _customerService;
  List<Map<String, dynamic>> _distributions = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String? _error;
  String _searchQuery = '';
  Map<String, dynamic>? _dailyStock;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _chickenTypes = [];
  bool _isReferenceLoading = false;
  String? _referenceError;

  @override
  void initState() {
    super.initState();
    _distributionService = serviceLocator<DistributionApiService>();
    _inventoryService = serviceLocator<InventoryApiService>();
    _customerService = serviceLocator<CustomerApiService>();
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
          dt = DateTime.parse(raw).toLocal();
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

  Future<bool> _ensureReferenceData() async {
    if (_customers.isNotEmpty && _chickenTypes.isNotEmpty) {
      return true;
    }

    if (_isReferenceLoading) {
      while (_isReferenceLoading && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _referenceError == null &&
          _customers.isNotEmpty &&
          _chickenTypes.isNotEmpty;
    }

    if (!mounted) return false;
    setState(() {
      _isReferenceLoading = true;
      _referenceError = null;
    });

    try {
      final customers = await _customerService.getAllCustomers();
      final chickenTypes = await _inventoryService.getAllChickenTypes();
      if (!mounted) return false;
      setState(() {
        _customers = customers;
        _chickenTypes = chickenTypes;
        _isReferenceLoading = false;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _referenceError = e.toString();
        _isReferenceLoading = false;
      });
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAvailableLoadings(
    DateTime date,
    String chickenTypeId,
  ) async {
    try {
      final loadings = await _distributionService.getAvailableLoadings(
        date,
        chickenTypeId,
      );
      return loadings;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل التحميلات المتاحة: $e')),
        );
      }
      return [];
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
      // Use the exact value without rounding
      return sum + netWeight.toDouble();
    });
  }

  double _calculateTotalValue() {
    return _filteredDistributions.fold<double>(0.0, (sum, distribution) {
      final totalAmount = (distribution['totalAmount'] ?? 0) as num;
      return sum + totalAmount.toDouble();
    });
  }

  Future<void> _editDistribution(Map<String, dynamic> d) async {
    final loaded = await _ensureReferenceData();
    if (!loaded) {
      if (!mounted) return;
      final message =
          _referenceError ?? 'فشل تحميل بيانات العملاء أو أنواع الفراخ';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    String? stringifyId(dynamic value) {
      if (value == null) return null;
      final str = value.toString();
      return str.isEmpty ? null : str;
    }

    final existingCustomerId = stringifyId(
      d['customer'] is Map<String, dynamic>
          ? (d['customer']['_id'] ?? d['customer']['id'])
          : d['customer'],
    );
    final existingChickenTypeId = stringifyId(
      d['chickenType'] is Map<String, dynamic>
          ? (d['chickenType']['_id'] ?? d['chickenType']['id'])
          : d['chickenType'],
    );
    final existingSourceLoadingId = stringifyId(
      d['sourceLoading'] is Map<String, dynamic>
          ? (d['sourceLoading']['_id'] ?? d['sourceLoading']['id'])
          : d['sourceLoading'],
    );

    DateTime selectedDate;
    try {
      final raw = (d['distributionDate'] ?? d['createdAt'])?.toString();
      selectedDate = raw != null
          ? DateTime.parse(raw).toLocal()
          : DateTime.now();
    } catch (_) {
      selectedDate = DateTime.now();
    }

    List<Map<String, dynamic>> customerOptions =
        List<Map<String, dynamic>>.from(_customers);
    if (existingCustomerId != null &&
        customerOptions.every(
          (c) => stringifyId(c['_id']) != existingCustomerId,
        )) {
      final customerMap = d['customer'];
      if (customerMap is Map<String, dynamic>) {
        customerOptions = [
          ...customerOptions,
          {'_id': existingCustomerId, 'name': customerMap['name'] ?? 'عميل'},
        ];
      }
    }

    List<Map<String, dynamic>> chickenOptions = List<Map<String, dynamic>>.from(
      _chickenTypes,
    );
    if (existingChickenTypeId != null &&
        chickenOptions.every(
          (c) => stringifyId(c['_id']) != existingChickenTypeId,
        )) {
      final chickenMap = d['chickenType'];
      if (chickenMap is Map<String, dynamic>) {
        chickenOptions = [
          ...chickenOptions,
          {
            '_id': existingChickenTypeId,
            'name': chickenMap['name'] ?? 'نوع غير معروف',
          },
        ];
      }
    }

    List<Map<String, dynamic>> loadingOptions = [];
    final currentLoading = d['sourceLoading'] as Map<String, dynamic>?;
    if (currentLoading != null && existingSourceLoadingId != null) {
      loadingOptions.add({
        '_id': existingSourceLoadingId,
        'supplier': currentLoading['supplier']?['name'] ?? 'غير معروف',
        'remainingQuantity': currentLoading['remainingQuantity'],
        'remainingNetWeight': currentLoading['remainingNetWeight'],
        'loadingDate':
            currentLoading['loadingDate'] ?? currentLoading['createdAt'],
      });
    }

    if (existingChickenTypeId != null) {
      final fetched = await _fetchAvailableLoadings(
        selectedDate,
        existingChickenTypeId,
      );
      for (final loading in fetched) {
        final loadingId = stringifyId(loading['_id']);
        if (loadingId == null) continue;
        if (loadingOptions.every((l) => stringifyId(l['_id']) != loadingId)) {
          loadingOptions.add(loading);
        }
      }
    }

    final formResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditDistributionDialog(
        customers: customerOptions,
        chickenTypes: chickenOptions,
        initialCustomerId: existingCustomerId,
        initialChickenTypeId: existingChickenTypeId,
        initialLoadingId: existingSourceLoadingId,
        initialQuantity: (d['quantity'] ?? 0).toString(),
        initialGrossWeight: (d['grossWeight'] ?? 0).toString(),
        initialPrice: (d['price'] ?? 0).toString(),
        initialDate: selectedDate,
        initialLoadingOptions: loadingOptions,
        loadLoadings: _fetchAvailableLoadings,
      ),
    );

    if (formResult == null) return;

    final String id = (d['_id'] ?? '').toString();
    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('معرّف التوزيع غير صالح')));
      return;
    }

    try {
      await _distributionService.updateDistribution(id, formResult);
      if (!mounted) return;
      await _loadDistributionsForDate(_selectedDate);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث سجل التوزيع')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'غير معروف';
    try {
      final dt = DateTime.parse(dateTime).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header with date selector and search
                SliverToBoxAdapter(
                  child: Container(
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
                ),

                // Summary list (more compact & readable)
                if (!_isLoading && _filteredDistributions.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
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
                  ),
                ],

                // Content
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 16),
                  sliver: SliverToBoxAdapter(child: _buildContent()),
                ),
              ],
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

    return Column(
      children: List.generate(_filteredDistributions.length, (index) {
        final d = _filteredDistributions[index];
        final String title = d['customer']?['name'] ?? 'عميل غير معروف';
        final String subtitle = _formatDateTime(
          d['distributionDate'] ?? d['createdAt'],
        );
        final num totalAmount = (d['totalAmount'] ?? 0) as num;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.1),
              child: const Icon(Icons.outbound, color: Colors.green),
            ),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(subtitle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'تعديل هذا السجل',
                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                  onPressed: () => _editDistribution(d),
                ),
                Text(
                  '${totalAmount.toDouble().toStringAsFixed(0)} ج.م',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'حذف هذا السجل',
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _confirmAndDeleteDistribution(d),
                ),
              ],
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
          ),
        );
      }),
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

  Future<void> _confirmAndDeleteDistribution(Map<String, dynamic> d) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('هل تريد حذف سجل التوزيع هذا؟'),
            const SizedBox(height: 8),
            Text(
              'العميل: ${d['customer']?['name'] ?? 'غير معروف'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'المبلغ: ${(d['totalAmount'] ?? 0).toStringAsFixed(0)} ج.م',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'تحذير: لا يمكن التراجع عن هذا الإجراء',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('جاري الحذف...'),
          ],
        ),
      ),
    );

    try {
      final String id = (d['_id'] ?? '').toString();
      if (id.isEmpty) throw Exception('معرّف غير صالح');

      debugPrint('[DistributionHistory] Deleting distribution with ID: $id');
      await _distributionService.deleteDistribution(id);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (!mounted) return;
      setState(() {
        _distributions.removeWhere((x) => x['_id'] == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم حذف سجل التوزيع بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (!mounted) return;

      String errorMessage = 'فشل الحذف';
      if (e.toString().contains('404')) {
        errorMessage = 'سجل التوزيع غير موجود';
      } else if (e.toString().contains('400')) {
        errorMessage = 'معرّف غير صالح';
      } else if (e.toString().contains('500')) {
        errorMessage = 'خطأ في الخادم، حاول مرة أخرى';
      } else {
        errorMessage = 'فشل الحذف: $e';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
      distribution['distributionDate'] ?? distribution['createdAt'],
    );
    final customerName = distribution['customer']?['name'] ?? 'غير معروف';
    final userName = distribution['user']?['username'] ?? 'غير معروف';
    final chickenTypeName = distribution['chickenType']?['name'] ?? 'غير محدد';

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
              backgroundColor: Colors.amber.withOpacity(0.1),
              child: const Icon(Icons.pets, color: Colors.amber, size: 20),
            ),
            title: const Text('نوع الفراخ'),
            subtitle: Text(chickenTypeName),
            dense: true,
          ),
          const Divider(height: 1),

          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(Icons.person, color: Colors.blue, size: 20),
            ),
            title: const Text('المستخدم'),
            subtitle: Text(
              '$userName${distribution['user']?['role'] == 'employee' ? ' (موظف)' : ''}',
            ),
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
            subtitle: Text('${price.toDouble()} ج.م/كجم'),
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

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'غير معروف';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'تاريخ غير صحيح';
    }
  }

  String _buildDistributionHtml() {
    final netWeight = (distribution['netWeight'] ?? 0) as num;
    final totalAmount = (distribution['totalAmount'] ?? 0) as num;
    final grossWeight = (distribution['grossWeight'] ?? 0) as num;
    final quantity = (distribution['quantity'] ?? 0) as num;
    final price = (distribution['price'] ?? 0) as num;
    final orderId =
        distribution['_id']?.toString().substring(0, 8) ?? 'غير معروف';
    final createdAt = _formatDateTime(
      distribution['distributionDate'] ?? distribution['createdAt'],
    );
    final customerName = distribution['customer']?['name'] ?? 'غير معروف';
    final userName = distribution['user']?['username'] ?? 'غير معروف';

    return '''
      <div style="padding: 20px; max-width: 800px; margin: 0 auto;">
        <h1 style="text-align: center; color: #2e7d32;">تفاصيل طلب التوزيع</h1>
        <hr style="border: 1px solid #2e7d32; margin: 20px 0;">
        
        <div style="background: #e8f5e9; padding: 15px; border-radius: 8px; margin-bottom: 20px;">
          <h2 style="margin: 0 0 10px 0;">معلومات الطلب</h2>
          <p><strong>رقم الطلب:</strong> #$orderId</p>
          <p><strong>التاريخ:</strong> $createdAt</p>
          <p style="font-size: 18px; color: #2e7d32;"><strong>إجمالي المبلغ:</strong> ${totalAmount.toDouble().toStringAsFixed(0)} ج.م</p>
        </div>

        <div style="margin-bottom: 20px;">
          <h3 style="background: #f5f5f5; padding: 10px; border-radius: 5px;">معلومات العميل والموظف</h3>
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>العميل:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">$customerName</td>
            </tr>
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>نوع الفراخ:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">${distribution['chickenType']?['name'] ?? 'غير محدد'}</td>
            </tr>
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>المستخدم:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">$userName${distribution['user']?['role'] == 'employee' ? ' (موظف)' : ''}</td>
            </tr>
          </table>
        </div>

        <div style="margin-bottom: 20px;">
          <h3 style="background: #f5f5f5; padding: 10px; border-radius: 5px;">تفاصيل التوزيع</h3>
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>الكمية:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">${quantity.toInt()} وحدة</td>
            </tr>
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>الوزن القائم:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">${grossWeight.toDouble().toStringAsFixed(1)} كجم</td>
            </tr>
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>الوزن الصافي:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">${netWeight.toDouble().toStringAsFixed(1)} كجم</td>
            </tr>
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>سعر الكيلو:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">${price.toDouble()} ج.م/كجم</td>
            </tr>
          </table>
        </div>

        <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 2px solid #2e7d32;">
          <p style="color: #666; font-size: 12px;">تم إنشاء هذا التقرير من نظام إدارة المزرعة</p>
        </div>
      </div>
    ''';
  }

  Future<void> _printPdf(BuildContext context) async {
    try {
      final html = _buildDistributionHtml();
      await PdfArabicUtils.printArabicHtml(htmlBody: html);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل الطباعة: $e')));
      }
    }
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final html = _buildDistributionHtml();
      final pdfBytes = await PdfArabicUtils.generateArabicHtmlPdf(
        htmlBody: html,
      );

      final tempDir = await getTemporaryDirectory();
      final orderId =
          distribution['_id']?.toString().substring(0, 8) ?? 'unknown';
      final customerName =
          distribution['customer']?['name'] ?? 'عميل غير معروف';
      final createdAt = _formatDateTime(
        distribution['createdAt'] ?? distribution['distributionDate'],
      );
      final dateStr = createdAt
          .replaceAll('/', '-')
          .replaceAll(' ', '_')
          .replaceAll(':', '-');
      final fileName = 'توزيع_${customerName}_$dateStr.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      if (!context.mounted) return;

      // Show share options dialog
      await showModalBottomSheet(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'مشاركة PDF عبر',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF25D366),
                    child: Image.asset(
                      'assets/whatsapp_icon.png',
                      width: 24,
                      height: 24,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.chat, color: Colors.white),
                    ),
                  ),
                  title: const Text('واتساب'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _shareViaWhatsApp(context, file, orderId);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF0088CC),
                    child: Icon(Icons.telegram, color: Colors.white),
                  ),
                  title: const Text('تيليجرام'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _shareViaTelegram(context, file, orderId);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.share, color: Colors.white),
                  ),
                  title: const Text('تطبيقات أخرى'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Share.shareXFiles([
                      XFile(file.path),
                    ], text: 'تفاصيل طلب التوزيع #$orderId');
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل المشاركة: $e')));
      }
    }
  }

  Future<void> _shareViaWhatsApp(
    BuildContext context,
    File file,
    String orderId,
  ) async {
    try {
      // Try to share directly via WhatsApp using share_plus with result
      final customerName =
          distribution['customer']?['name'] ?? 'عميل غير معروف';
      final result = await Share.shareXFiles([
        XFile(file.path),
      ], text: 'تفاصيل طلب التوزيع - $customerName');

      // If sharing was successful, try to open WhatsApp explicitly
      if (result.status == ShareResultStatus.success) {
        // Try WhatsApp scheme
        final whatsappUrl = Uri.parse('whatsapp://send');
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl);
        }
      } else {
        // Fallback: try to open WhatsApp directly
        final whatsappUrl = Uri.parse('whatsapp://send');
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('قم بإرفاق الملف من معرض الصور')),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('واتساب غير مثبت على هذا الجهاز')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل المشاركة عبر واتساب: $e')));
      }
    }
  }

  Future<void> _shareViaTelegram(
    BuildContext context,
    File file,
    String orderId,
  ) async {
    try {
      // Share the file first
      final customerName =
          distribution['customer']?['name'] ?? 'عميل غير معروف';
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'تفاصيل طلب التوزيع - $customerName');

      // Try to open Telegram
      final telegramUrl = Uri.parse('tg://');
      if (await canLaunchUrl(telegramUrl)) {
        await launchUrl(telegramUrl);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تيليجرام غير مثبت على هذا الجهاز')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل المشاركة عبر تيليجرام: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل طلب التوزيع'),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'طباعة',
              onPressed: () => _printPdf(context),
            ),
          ],
        ),
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

class _EditDistributionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> chickenTypes;
  final List<Map<String, dynamic>> initialLoadingOptions;
  final String? initialCustomerId;
  final String? initialChickenTypeId;
  final String? initialLoadingId;
  final String initialQuantity;
  final String initialGrossWeight;
  final String initialPrice;
  final DateTime initialDate;
  final Future<List<Map<String, dynamic>>> Function(DateTime, String)
  loadLoadings;

  const _EditDistributionDialog({
    required this.customers,
    required this.chickenTypes,
    required this.initialLoadingOptions,
    required this.initialCustomerId,
    required this.initialChickenTypeId,
    required this.initialLoadingId,
    required this.initialQuantity,
    required this.initialGrossWeight,
    required this.initialPrice,
    required this.initialDate,
    required this.loadLoadings,
  });

  @override
  State<_EditDistributionDialog> createState() =>
      _EditDistributionDialogState();
}

class _EditDistributionDialogState extends State<_EditDistributionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _grossCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _emptyWeightCtrl;
  late final TextEditingController _netWeightCtrl;
  late DateTime _selectedDate;
  String? _selectedCustomerId;
  String? _selectedChickenTypeId;
  String? _selectedLoadingId;
  List<Map<String, dynamic>> _loadingOptions = [];
  bool _loadingLoadings = false;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _quantityCtrl = TextEditingController(text: widget.initialQuantity);
    _grossCtrl = TextEditingController(text: widget.initialGrossWeight);
    _priceCtrl = TextEditingController(text: widget.initialPrice);
    _emptyWeightCtrl = TextEditingController();
    _netWeightCtrl = TextEditingController();
    _selectedDate = widget.initialDate;
    _selectedCustomerId = widget.initialCustomerId;
    _selectedChickenTypeId = widget.initialChickenTypeId;
    _selectedLoadingId = widget.initialLoadingId;
    _loadingOptions = List<Map<String, dynamic>>.from(
      widget.initialLoadingOptions,
    );
    if (_loadingOptions.isEmpty &&
        _selectedChickenTypeId != null &&
        _selectedChickenTypeId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshLoadings();
      });
    }
    // Calculate initial values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculate();
    });
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _grossCtrl.dispose();
    _priceCtrl.dispose();
    _emptyWeightCtrl.dispose();
    _netWeightCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    final quantity = int.tryParse(_quantityCtrl.text) ?? 0;
    final gross = double.tryParse(_grossCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;

    final emptyWeight = quantity * 8;
    final net = (gross - emptyWeight).clamp(0, double.infinity);
    final totalAmount = price * net;

    setState(() {
      _emptyWeightCtrl.text = emptyWeight.toStringAsFixed(2);
      _netWeightCtrl.text = net.toStringAsFixed(2);
      _totalAmount = totalAmount;
    });
  }

  String _labelForLoading(Map<String, dynamic> loading) {
    final supplier = loading['supplier'] ?? loading['supplierName'];
    final remainingQty = loading['remainingQuantity'];
    final remainingNet = loading['remainingNetWeight'];
    return '${supplier ?? 'تحميل'} - متبقي: ${remainingQty ?? '-'} وحدة / ${(remainingNet ?? '-')} كجم';
  }

  Future<void> _refreshLoadings() async {
    final chickenId = _selectedChickenTypeId;
    if (chickenId == null || chickenId.isEmpty) {
      setState(() {
        _loadingOptions = [];
        _selectedLoadingId = null;
      });
      return;
    }
    setState(() {
      _loadingLoadings = true;
    });
    final items = await widget.loadLoadings(_selectedDate, chickenId);
    setState(() {
      _loadingOptions = items;
      if (_loadingOptions.every(
        (element) => (element['_id'] ?? '').toString() != _selectedLoadingId,
      )) {
        _selectedLoadingId = null;
      }
      _loadingLoadings = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تعديل سجل التوزيع'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCustomerId,
                  decoration: const InputDecoration(
                    labelText: 'العميل',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.customers
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: (c['_id'] ?? '').toString(),
                          child: Text((c['name'] ?? 'عميل').toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedCustomerId = value;
                  }),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'اختر العميل' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedChickenTypeId,
                  decoration: const InputDecoration(
                    labelText: 'نوع الفراخ',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.chickenTypes
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: (c['_id'] ?? '').toString(),
                          child: Text((c['name'] ?? 'نوع').toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedChickenTypeId = value;
                      _selectedLoadingId = null;
                    });
                    _refreshLoadings();
                  },
                  validator: (value) =>
                      value == null || value.isEmpty ? 'اختر نوع الفراخ' : null,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2024, 1, 1),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _refreshLoadings();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _quantityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الكمية (عدد)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _recalculate(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الكمية مطلوبة';
                    }
                    final qty = int.tryParse(value);
                    if (qty == null || qty <= 0) {
                      return 'أدخل كمية صحيحة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _grossCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'الوزن القائم (كجم)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _recalculate(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'القيمة مطلوبة';
                    }
                    final gross = double.tryParse(value);
                    if (gross == null || gross < 0) {
                      return 'أدخل وزن صحيح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emptyWeightCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'الوزن الفارغ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _netWeightCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'الوزن الصافي',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'السعر (ج.م/كجم)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _recalculate(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'القيمة مطلوبة';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price < 0) {
                      return 'أدخل سعر صحيح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Text(
                    'إجمالي المبلغ: ${_totalAmount.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              if (_selectedCustomerId == null ||
                  _selectedChickenTypeId == null ||
                  _selectedLoadingId == null) {
                return;
              }

              // Recalculate to ensure values are up to date
              _recalculate();

              Navigator.pop(context, {
                'customer': _selectedCustomerId!,
                'chickenType': _selectedChickenTypeId!,
                'sourceLoading': _selectedLoadingId!,
                'quantity': int.parse(_quantityCtrl.text),
                'grossWeight': double.parse(_grossCtrl.text),
                'price': double.parse(_priceCtrl.text),
                'distributionDate': _selectedDate.toIso8601String(),
              });
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
