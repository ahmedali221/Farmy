import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/loading_api_service.dart';
import '../../../../core/services/inventory_api_service.dart';
import '../../../../core/services/supplier_api_service.dart';
import '../../../../core/utils/pdf_arabic_utils.dart';

class LoadingHistoryView extends StatefulWidget {
  const LoadingHistoryView({super.key});

  @override
  State<LoadingHistoryView> createState() => _LoadingHistoryViewState();
}

class _LoadingHistoryViewState extends State<LoadingHistoryView> {
  late final LoadingApiService _loadingService;
  late final InventoryApiService _inventoryService;
  late final SupplierApiService _supplierService;
  List<Map<String, dynamic>> _loadings = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String? _error;
  String _searchQuery = '';
  Map<String, dynamic>? _dailyStock;
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _chickenTypes = [];
  bool _isReferenceLoading = false;
  String? _referenceError;

  @override
  void initState() {
    super.initState();
    _loadingService = serviceLocator<LoadingApiService>();
    _inventoryService = serviceLocator<InventoryApiService>();
    _supplierService = serviceLocator<SupplierApiService>();
    Future.microtask(_ensureReferenceData);
    _loadLoadingsForDate(_selectedDate);
  }

  Future<bool> _ensureReferenceData() async {
    if (_suppliers.isNotEmpty && _chickenTypes.isNotEmpty) {
      return true;
    }

    if (_isReferenceLoading) {
      while (_isReferenceLoading && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _referenceError == null &&
          _suppliers.isNotEmpty &&
          _chickenTypes.isNotEmpty;
    }

    if (!mounted) return false;
    setState(() {
      _isReferenceLoading = true;
      _referenceError = null;
    });

    try {
      final suppliers = await _supplierService.getAllSuppliers();
      final chickenTypes = await _inventoryService.getAllChickenTypes();
      if (!mounted) return false;
      setState(() {
        _suppliers = suppliers;
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
      final supplierName =
          loading['supplier']?['name']?.toString().toLowerCase() ?? '';
      final chickenType =
          loading['chickenType']?['name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return supplierName.contains(query) || chickenType.contains(query);
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

  Future<void> _editLoading(Map<String, dynamic> m) async {
    final bool loaded = await _ensureReferenceData();
    if (!loaded) {
      if (!mounted) return;
      final message =
          _referenceError ?? 'فشل تحميل بيانات الموردين أو أنواع الدجاج';
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

    final String? existingSupplierId = stringifyId(
      m['supplier'] is Map<String, dynamic>
          ? (m['supplier']['_id'] ?? m['supplier']['id'])
          : m['supplier'],
    );
    final String? existingChickenTypeId = stringifyId(
      m['chickenType'] is Map<String, dynamic>
          ? (m['chickenType']['_id'] ?? m['chickenType']['id'])
          : m['chickenType'],
    );

    DateTime selectedDate;
    try {
      final raw = (m['loadingDate'] ?? m['createdAt'] ?? m['date'])?.toString();
      selectedDate = raw != null ? DateTime.parse(raw) : DateTime.now();
    } catch (_) {
      selectedDate = DateTime.now();
    }

    String? selectedSupplierId =
        (existingSupplierId != null && existingSupplierId.isNotEmpty)
        ? existingSupplierId
        : null;
    String? selectedChickenTypeId =
        (existingChickenTypeId != null && existingChickenTypeId.isNotEmpty)
        ? existingChickenTypeId
        : null;

    List<Map<String, dynamic>> supplierOptions =
        List<Map<String, dynamic>>.from(_suppliers);
    List<Map<String, dynamic>> chickenOptions = List<Map<String, dynamic>>.from(
      _chickenTypes,
    );

    String extractId(Map<String, dynamic> item) =>
        (item['_id'] ?? item['id'] ?? item['value'] ?? '').toString();

    if (selectedSupplierId != null &&
        selectedSupplierId.isNotEmpty &&
        !supplierOptions.any((s) => extractId(s) == selectedSupplierId)) {
      supplierOptions = [
        ...supplierOptions,
        {
          '_id': selectedSupplierId,
          'name': (m['supplier']?['name'] ?? 'مورد غير معروف').toString(),
        },
      ];
    }

    if (selectedChickenTypeId != null &&
        selectedChickenTypeId.isNotEmpty &&
        !chickenOptions.any((c) => extractId(c) == selectedChickenTypeId)) {
      chickenOptions = [
        ...chickenOptions,
        {
          '_id': selectedChickenTypeId,
          'name': (m['chickenType']?['name'] ?? 'نوع غير معروف').toString(),
        },
      ];
    }

    if (!supplierOptions.any((s) => extractId(s) == selectedSupplierId)) {
      selectedSupplierId = null;
    }
    if (!chickenOptions.any((c) => extractId(c) == selectedChickenTypeId)) {
      selectedChickenTypeId = null;
    }

    if (supplierOptions.isEmpty || chickenOptions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا توجد بيانات كافية لتعديل السجل. برجاء إضافة الموردين والأنواع أولاً.',
          ),
        ),
      );
      return;
    }

    final formResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditLoadingDialog(
        suppliers: supplierOptions,
        chickenTypes: chickenOptions,
        initialSupplierId: selectedSupplierId,
        initialChickenTypeId: selectedChickenTypeId,
        initialQuantity: (m['quantity'] ?? 0).toString(),
        initialNetWeight: (m['netWeight'] ?? 0).toString(),
        initialLoadingPrice: (m['loadingPrice'] ?? 0).toString(),
        initialNotes: (m['notes'] ?? '').toString(),
        initialDate: selectedDate,
      ),
    );

    if (formResult == null) return;

    final String id = (m['_id'] ?? '').toString();
    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('معرّف السجل غير صالح')));
      return;
    }

    try {
      await _loadingService.updateLoading(id, formResult);
      if (!mounted) return;
      await _loadLoadingsForDate(_selectedDate);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث سجل التحميل')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
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
                    // Simple check: require 'delete' password for safety
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
                            hintText: 'البحث في الموردين أو نوع الدجاج...',
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
        final String title = m['supplier']?['name'] ?? 'مورد غير معروف';
        final String subtitle = _formatDateTime(
          m['loadingDate'] ?? m['createdAt'],
        );
        final num totalLoading = (m['totalLoading'] ?? 0) as num;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: const Icon(Icons.local_shipping, color: Colors.blue),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'تعديل هذا السجل',
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                onPressed: () => _editLoading(m),
              ),
              Text(
                '${totalLoading.toDouble().toStringAsFixed(0)} ج.م',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'حذف هذا السجل',
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => _confirmAndDeleteLoading(m),
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
                builder: (_) => _LoadingDetailsPage(loading: m),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndDeleteLoading(Map<String, dynamic> m) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف سجل التحميل هذا؟'),
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
    if (confirmed != true) return;
    try {
      final String id = (m['_id'] ?? '').toString();
      if (id.isEmpty) throw Exception('معرّف غير صالح');
      await _loadingService.deleteLoading(id);
      if (!mounted) return;
      setState(() {
        _loadings.removeWhere((x) => x['_id'] == id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف سجل التحميل')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
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
    final quantity = (loading['quantity'] ?? 0) as num;
    final loadingPrice = (loading['loadingPrice'] ?? 0) as num;

    final orderId = loading['_id']?.toString().substring(0, 8) ?? 'غير معروف';
    final createdAt = _formatDateTime(
      loading['loadingDate'] ?? loading['createdAt'],
    );
    final chickenType = loading['chickenType']?['name'] ?? 'غير معروف';
    final supplierName = loading['supplier']?['name'] ?? 'غير معروف';
    final userName = loading['user']?['username'] ?? 'غير معروف';
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

          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.1),
              child: const Icon(Icons.business, color: Colors.orange, size: 20),
            ),
            title: const Text('المورد'),
            subtitle: Text(
              supplierName,
              style: const TextStyle(color: Colors.blue),
            ),
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
              '$userName${loading['user']?['role'] == 'employee' ? ' (موظف)' : ''}',
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

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'غير معروف';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'تاريخ غير صحيح';
    }
  }

  String _buildLoadingHtml() {
    final netWeight = (loading['netWeight'] ?? 0) as num;
    final totalLoading = (loading['totalLoading'] ?? 0) as num;
    final quantity = (loading['quantity'] ?? 0) as num;
    final loadingPrice = (loading['loadingPrice'] ?? 0) as num;
    final orderId = loading['_id']?.toString().substring(0, 8) ?? 'غير معروف';
    final createdAt = _formatDateTime(
      loading['loadingDate'] ?? loading['createdAt'],
    );
    final chickenType = loading['chickenType']?['name'] ?? 'غير معروف';
    final supplierName = loading['supplier']?['name'] ?? 'غير معروف';
    final userName = loading['user']?['username'] ?? 'غير معروف';
    final notes = loading['notes']?.toString() ?? '';

    return '''
      <div style="padding: 20px; max-width: 800px; margin: 0 auto;">
        <h1 style="text-align: center; color: #1976d2;">تفاصيل طلب التحميل</h1>
        <hr style="border: 1px solid #1976d2; margin: 20px 0;">
        
        <div style="background: #e3f2fd; padding: 15px; border-radius: 8px; margin-bottom: 20px;">
          <h2 style="margin: 0 0 10px 0;">معلومات الطلب</h2>
          <p><strong>رقم الطلب:</strong> #$orderId</p>
          <p><strong>التاريخ:</strong> $createdAt</p>
          <p style="font-size: 18px; color: #1976d2;"><strong>إجمالي المبلغ:</strong> ${totalLoading.toDouble().toStringAsFixed(0)} ج.م</p>
        </div>

        <div style="margin-bottom: 20px;">
          <h3 style="background: #f5f5f5; padding: 10px; border-radius: 5px;">معلومات المورد والنوع</h3>
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>المورد:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">$supplierName</td>
            </tr>
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>نوع الدجاج:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">$chickenType</td>
            </tr>
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>المستخدم:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">$userName${loading['user']?['role'] == 'employee' ? ' (موظف)' : ''}</td>
            </tr>
          </table>
        </div>

        <div style="margin-bottom: 20px;">
          <h3 style="background: #f5f5f5; padding: 10px; border-radius: 5px;">تفاصيل التحميل</h3>
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>الكمية:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">${quantity.toInt()} وحدة</td>
            </tr>
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>الوزن الصافي:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">${netWeight.toDouble().toStringAsFixed(1)} كجم</td>
            </tr>
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>سعر التحميل:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">${loadingPrice.toDouble().toStringAsFixed(0)} ج.م/كجم</td>
            </tr>
          </table>
        </div>

        ${notes.isNotEmpty ? '''
        <div style="margin-bottom: 20px;">
          <h3 style="background: #f5f5f5; padding: 10px; border-radius: 5px;">ملاحظات</h3>
          <p style="padding: 10px; background: #fff3e0; border-radius: 5px;">$notes</p>
        </div>
        ''' : ''}

        <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 2px solid #1976d2;">
          <p style="color: #666; font-size: 12px;">تم إنشاء هذا التقرير من نظام إدارة المزرعة</p>
        </div>
      </div>
    ''';
  }

  Future<void> _printPdf(BuildContext context) async {
    try {
      final html = _buildLoadingHtml();
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
      print('Starting PDF share process...');

      // First test: Simple share without PDF generation
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('بدء عملية المشاركة...')));

      final html = _buildLoadingHtml();
      print('HTML generated, creating PDF...');
      final pdfBytes = await PdfArabicUtils.generateArabicHtmlPdf(
        htmlBody: html,
      );
      print('PDF created, saving to file...');

      final tempDir = await getTemporaryDirectory();
      final orderId = loading['_id']?.toString().substring(0, 8) ?? 'unknown';
      final supplierName = loading['supplier']?['name'] ?? 'مورد غير معروف';
      final createdAt = _formatDateTime(
        loading['loadingDate'] ?? loading['createdAt'],
      );
      final dateStr = createdAt
          .replaceAll('/', '-')
          .replaceAll(' ', '_')
          .replaceAll(':', '-');
      final fileName = 'تحميل_${supplierName}_$dateStr.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      print('PDF saved to: ${file.path}');

      if (!context.mounted) return;

      print('Showing share options dialog...');

      // Test: Try direct share first
      try {
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'تفاصيل طلب التحميل - $supplierName');
        print('Direct share completed');
        return;
      } catch (e) {
        print('Direct share failed: $e');
      }

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
                    print('WhatsApp option tapped');
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
                    print('Telegram option tapped');
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
                    print('Other apps option tapped');
                    Navigator.pop(ctx);
                    await Share.shareXFiles([
                      XFile(file.path),
                    ], text: 'تفاصيل طلب التحميل #$orderId');
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
      print('Share dialog completed');
    } catch (e) {
      print('Share PDF error: $e');
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
      final supplierName = loading['supplier']?['name'] ?? 'مورد غير معروف';
      print('Starting WhatsApp share for order: $orderId');

      // Try WhatsApp scheme first
      final whatsappUrl = Uri.parse('whatsapp://send');
      if (await canLaunchUrl(whatsappUrl)) {
        print('WhatsApp is available, launching...');
        await launchUrl(whatsappUrl);

        // Then share the file
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'تفاصيل طلب التحميل - $supplierName');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم فتح واتساب، يمكنك إرسال الملف')),
          );
        }
      } else {
        print('WhatsApp not available, using general share');
        // Fallback: use general share
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'تفاصيل طلب التحميل - $supplierName');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('واتساب غير مثبت، تم فتح خيارات المشاركة'),
            ),
          );
        }
      }
    } catch (e) {
      print('WhatsApp share error: $e');
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
      final supplierName = loading['supplier']?['name'] ?? 'مورد غير معروف';
      print('Starting Telegram share for order: $orderId');

      // Try Telegram scheme first
      final telegramUrl = Uri.parse('tg://');
      if (await canLaunchUrl(telegramUrl)) {
        print('Telegram is available, launching...');
        await launchUrl(telegramUrl);

        // Then share the file
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'تفاصيل طلب التحميل - $supplierName');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم فتح تيليجرام، يمكنك إرسال الملف')),
          );
        }
      } else {
        print('Telegram not available, using general share');
        // Fallback: use general share
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'تفاصيل طلب التحميل - $supplierName');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تيليجرام غير مثبت، تم فتح خيارات المشاركة'),
            ),
          );
        }
      }
    } catch (e) {
      print('Telegram share error: $e');
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
          title: const Text('تفاصيل طلب التحميل'),
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
          child: _LoadingHistoryViewState()._buildLoadingCard(loading),
        ),
      ),
    );
  }
}

class _EditLoadingDialog extends StatefulWidget {
  final List<Map<String, dynamic>> suppliers;
  final List<Map<String, dynamic>> chickenTypes;
  final String? initialSupplierId;
  final String? initialChickenTypeId;
  final String initialQuantity;
  final String initialNetWeight;
  final String initialLoadingPrice;
  final String initialNotes;
  final DateTime initialDate;

  const _EditLoadingDialog({
    required this.suppliers,
    required this.chickenTypes,
    required this.initialSupplierId,
    required this.initialChickenTypeId,
    required this.initialQuantity,
    required this.initialNetWeight,
    required this.initialLoadingPrice,
    required this.initialNotes,
    required this.initialDate,
  });

  @override
  State<_EditLoadingDialog> createState() => _EditLoadingDialogState();
}

class _EditLoadingDialogState extends State<_EditLoadingDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _netWeightCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _selectedDate;
  String? _selectedSupplierId;
  String? _selectedChickenTypeId;

  @override
  void initState() {
    super.initState();
    _quantityCtrl = TextEditingController(text: widget.initialQuantity);
    _netWeightCtrl = TextEditingController(text: widget.initialNetWeight);
    _priceCtrl = TextEditingController(text: widget.initialLoadingPrice);
    _notesCtrl = TextEditingController(text: widget.initialNotes);
    _selectedDate = widget.initialDate;
    _selectedSupplierId = widget.initialSupplierId;
    _selectedChickenTypeId = widget.initialChickenTypeId;
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _netWeightCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? _tryParseDouble(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  double _safeParseDouble(String value) => _tryParseDouble(value) ?? 0;

  String _extractId(Map<String, dynamic> item) {
    return (item['_id'] ?? item['id'] ?? item['value'] ?? '').toString();
  }

  String _extractName(Map<String, dynamic> item) {
    return (item['name'] ?? item['username'] ?? 'غير معروف').toString();
  }

  double get _totalAmount =>
      _safeParseDouble(_netWeightCtrl.text) * _safeParseDouble(_priceCtrl.text);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تعديل سجل التحميل'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedSupplierId,
                  decoration: const InputDecoration(
                    labelText: 'المورد',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.suppliers
                      .map(
                        (supplier) => DropdownMenuItem<String>(
                          value: _extractId(supplier),
                          child: Text(_extractName(supplier)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedSupplierId = value;
                  }),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'اختر المورد' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedChickenTypeId,
                  decoration: const InputDecoration(
                    labelText: 'نوع الدجاج',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.chickenTypes
                      .map(
                        (chicken) => DropdownMenuItem<String>(
                          value: _extractId(chicken),
                          child: Text(_extractName(chicken)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedChickenTypeId = value;
                  }),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'اختر نوع الدجاج' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الكمية',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'أدخل كمية صحيحة (عدد صحيح)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _netWeightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'الوزن الصافي (كجم)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    setState(() {}); // Update total amount display
                  },
                  validator: (value) {
                    final parsed = _tryParseDouble(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'أدخل وزن صافي صحيح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'سعر التحميل (ج.م/كجم)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    setState(() {}); // Update total amount display
                  },
                  validator: (value) {
                    final parsed = _tryParseDouble(value ?? '');
                    if (parsed == null || parsed < 0) {
                      return 'أدخل سعر صحيح';
                    }
                    return null;
                  },
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
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Text(
                    'إجمالي المبلغ: ${_totalAmount.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                      color: Colors.blue,
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              if (_selectedSupplierId == null ||
                  _selectedSupplierId!.isEmpty ||
                  _selectedChickenTypeId == null ||
                  _selectedChickenTypeId!.isEmpty) {
                return;
              }
              final payload = <String, dynamic>{
                'supplier': _selectedSupplierId,
                'chickenType': _selectedChickenTypeId,
                'quantity': int.parse(_quantityCtrl.text),
                'netWeight': _safeParseDouble(_netWeightCtrl.text),
                'loadingPrice': _safeParseDouble(_priceCtrl.text),
                'loadingDate': _selectedDate.toIso8601String(),
              };
              payload['notes'] = _notesCtrl.text.trim();
              Navigator.of(context).pop(payload);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
