import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui show TextDirection;
import '../../../../../../core/di/service_locator.dart';
import '../../../../../../core/services/inventory_api_service.dart';
import '../../../../../../core/services/payment_api_service.dart';
import '../../../../../../core/services/distribution_api_service.dart';
import '../../../../../../core/services/waste_api_service.dart';
import '../../../../../../core/services/loading_api_service.dart';
import 'loading_details_page.dart';
import 'distribution_details_page.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final InventoryApiService _inventoryApi =
      serviceLocator<InventoryApiService>();
  final PaymentApiService _paymentApi = serviceLocator<PaymentApiService>();
  final DistributionApiService _distributionApi =
      serviceLocator<DistributionApiService>();
  final WasteApiService _wasteApi = serviceLocator<WasteApiService>();

  DateTime _selectedDate = DateTime.now();
  bool _loading = false;
  Map<String, dynamic>? _data;
  num _discountsTotal = 0;
  Map<String, dynamic>? _shortageData;
  Map<String, dynamic>? _wasteData;
  Map<String, dynamic>? _totalProfitData;

  final TextEditingController _adjController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _adjController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final String dateStr = _formatDate(_selectedDate);
      final data = await _inventoryApi.getDailyInventoryByDate(dateStr);
      final profit = await _inventoryApi.getDailyProfit(dateStr);

      // Load total profit history
      Map<String, dynamic>? totalProfitData;
      try {
        totalProfitData = await _inventoryApi.getTotalProfitHistory();
      } catch (e) {
        debugPrint('[InventoryTab] Failed to load total profit data: $e');
      }

      // Load shortage data
      Map<String, dynamic>? shortageData;
      try {
        shortageData = await _distributionApi.getDistributionShortages(
          _selectedDate,
        );
      } catch (e) {
        debugPrint('[InventoryTab] Failed to load shortage data: $e');
      }

      // Load waste data
      Map<String, dynamic>? wasteData;
      try {
        wasteData = await _wasteApi.getWasteByDate(dateStr);
      } catch (e) {
        debugPrint('[InventoryTab] Failed to load waste data: $e');
      }

      // Compute total discounts for payments on selected date
      num discountsTotal = 0;
      try {
        final payments = await _paymentApi.getAllPayments();
        for (final p in payments) {
          final createdAt = (p['createdAt'] ?? p['paymentDate'] ?? '')
              .toString();
          if (createdAt.isEmpty) continue;
          DateTime dt;
          try {
            dt = DateTime.parse(createdAt).toLocal();
          } catch (_) {
            continue;
          }
          if (dt.year == _selectedDate.year &&
              dt.month == _selectedDate.month &&
              dt.day == _selectedDate.day) {
            final d = (p['discount'] ?? 0) as num;
            discountsTotal += d;
          }
        }
      } catch (_) {}
      debugPrint(
        '[InventoryTab] fetched for date=${_formatDate(_selectedDate)}',
      );
      debugPrint('[InventoryTab] netLoadingWeight=${data['netLoadingWeight']}');
      debugPrint(
        '[InventoryTab] netDistributionWeight=${data['netDistributionWeight']}',
      );
      debugPrint('[InventoryTab] adminAdjustment=${data['adminAdjustment']}');
      setState(() {
        _data = {
          ...data,
          'profit': profit['profit'],
          'distributionsTotal': profit['distributionsTotal'],
          'loadingsTotal': profit['loadingsTotal'],
          'expensesTotal': profit['expensesTotal'],
          'loadingPricesSum': profit['loadingPricesSum'],
        };
        _discountsTotal = discountsTotal;
        _shortageData = shortageData;
        _wasteData = wasteData;
        _totalProfitData = totalProfitData;
        // If backend has a saved adjustment, reflect it; otherwise start from 0
        final num backendAdj = (data['adminAdjustment'] ?? 0) as num;
        _adjController.text = backendAdj.toString();
      });
      debugPrint(
        '[InventoryTab] input(adminAdjustment) now = ' + _adjController.text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تحميل المخزون: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final String dateStr = _formatDate(_selectedDate);
      final num inputAdj = num.tryParse(_adjController.text) ?? 0;
      final num netLoadingBefore = (_data?['netLoadingWeight'] ?? 0) as num;
      final num netDistBefore = (_data?['netDistributionWeight'] ?? 0) as num;
      final num resultBefore = (netLoadingBefore - netDistBefore) - inputAdj;
      debugPrint(
        '[InventoryTab] Saving upsert payload => date=' +
            dateStr +
            ', adminAdjustment=' +
            inputAdj.toString(),
      );
      debugPrint(
        '[InventoryTab] Local before-save calc: (' +
            netLoadingBefore.toString() +
            ' - ' +
            netDistBefore.toString() +
            ') - ' +
            inputAdj.toString() +
            ' = ' +
            resultBefore.toString(),
      );
      final updated = await _inventoryApi.upsertDailyInventory(
        date: dateStr,
        adminAdjustment: inputAdj,
      );
      debugPrint(
        '[InventoryTab] upsert response for date=${_formatDate(_selectedDate)}',
      );
      debugPrint(
        '[InventoryTab] netLoadingWeight=${updated['netLoadingWeight']}',
      );
      debugPrint(
        '[InventoryTab] netDistributionWeight=${updated['netDistributionWeight']}',
      );
      debugPrint(
        '[InventoryTab] adminAdjustment=${updated['adminAdjustment']}',
      );
      final num netLoadingAfter = (updated['netLoadingWeight'] ?? 0) as num;
      final num netDistAfter = (updated['netDistributionWeight'] ?? 0) as num;
      final num adjAfter = (updated['adminAdjustment'] ?? 0) as num;
      final num resultAfter = (netLoadingAfter - netDistAfter) - adjAfter;
      debugPrint(
        '[InventoryTab] Server after-save calc: (' +
            netLoadingAfter.toString() +
            ' - ' +
            netDistAfter.toString() +
            ') - ' +
            adjAfter.toString() +
            ' = ' +
            resultAfter.toString(),
      );
      setState(() {
        _data = updated;
        _adjController.text = adjAfter.toString();
      });
      // Refetch to ensure the page reflects any concurrent data changes
      await _fetch();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final num netLoading = (_data?['netLoadingWeight'] ?? 0) as num;
    final num netDist = (_data?['netDistributionWeight'] ?? 0) as num;
    final num prevAdj = (_data?['adminAdjustment'] ?? 0) as num;
    // Admin adjustment is driven by the field, fallback to backend value
    final num adj =
        num.tryParse(_adjController.text) ??
        (_data?['adminAdjustment'] ?? 0) as num;
    final num result = (netLoading - netDist) - adj;
    final num distributionsTotal = (_data?['distributionsTotal'] ?? 0) as num;
    final num loadingsTotal = (_data?['loadingsTotal'] ?? 0) as num;
    final num expensesTotal = (_data?['expensesTotal'] ?? 0) as num;
    final num loadingPricesSum = (_data?['loadingPricesSum'] ?? 0) as num;
    final num profit = (_data?['profit'] ?? 0) as num;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'تاريخ اليوم: ${_formatDate(_selectedDate)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _pickDate,
                    icon: const Icon(Icons.date_range),
                    label: const Text('اختيار التاريخ'),
                  ),

                  IconButton(
                    onPressed: _loading ? null : _fetch,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(),
              const SizedBox(height: 12),

              // Total Profit Placeholder
              if (_totalProfitData != null) ...[
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_up, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            Text(
                              'إجمالي الربح من جميع الأيام',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'إجمالي الربح: ${NumberFormat('#,##0.###').format(_totalProfitData!['totalProfit'])} ج.م',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'إجمالي التوزيعات: ${NumberFormat('#,##0.###').format(_totalProfitData!['totalDistributions'])} ج.م',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'إجمالي التحميل: ${NumberFormat('#,##0.###').format(_totalProfitData!['totalLoadings'])} ج.م',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'إجمالي المصروفات: ${NumberFormat('#,##0.###').format(_totalProfitData!['totalExpenses'])} ج.م',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'إجمالي الخصومات: ${NumberFormat('#,##0.###').format(_totalProfitData!['totalDiscounts'])} ج.م',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المعادلة: (وزن صافي التحميل - وزن صافي التوزيع) - قيمة',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),

                      // Net loading (read-only)
                      _SectionLabel('وزن صافي التحميل'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LoadingDetailsPage(
                                date: _formatDate(_selectedDate),
                                totalNetWeight: netLoading,
                              ),
                            ),
                          );
                        },
                        child: _MetricTile(
                          label: 'وزن صافي التحميل',
                          value: netLoading,
                          color: Colors.blue,
                        ),
                      ),

                      const SizedBox(height: 16),
                      _SectionLabel('وزن صافي التوزيع (محسوب تلقائياً)'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DistributionDetailsPage(
                                date: _formatDate(_selectedDate),
                                totalNetWeight: netDist,
                              ),
                            ),
                          );
                        },
                        child: _MetricTile(
                          label: 'وزن صافي التوزيع',
                          value: netDist,
                          color: Colors.orange,
                        ),
                      ),

                      const SizedBox(height: 16),
                      _SectionLabel('قيمة (تسوية/هالك)'),
                      const SizedBox(height: 8),
                      _NumberField(
                        controller: _adjController,
                        label: 'اكتب القيمة',
                        onChanged: (_) => setState(() {}),
                      ),

                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'المحفوظ سابقاً: ' +
                                  NumberFormat('#,##0.###').format(prevAdj),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'الإدخال الحالي: ' +
                                  NumberFormat('#,##0.###').format(
                                    num.tryParse(_adjController.text) ?? 0,
                                  ),
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      _SectionLabel('المخزون الحالي'),
                      const SizedBox(height: 8),
                      _ReadOnlyNumberField(
                        label: 'المخزون الحالي',
                        value: result,
                      ),

                      const SizedBox(height: 16),
                      _SectionLabel('المخزون اليومي (ناتج المعادلة)'),
                      const SizedBox(height: 8),
                      _MetricTile(
                        label: 'المخزون اليومي',
                        value: result,
                        color: Colors.green,
                      ),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _save,
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ'),
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      Text(
                        'الربح اليومي',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _DailyProfitDetailsPage(
                                date: _formatDate(_selectedDate),
                                profit: profit,
                                distributionsTotal: distributionsTotal,
                                loadingsTotal: loadingsTotal,
                                expensesTotal: expensesTotal,
                                loadingPricesSum: loadingPricesSum,
                                discountsTotal: _discountsTotal,
                              ),
                            ),
                          );
                        },
                        child: _MetricTile(
                          label:
                              'الربح = إجمالي التوزيعات - إجمالي التحميل - إجمالي المصروفات - إجمالي الخصومات',
                          value: profit,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Shortage Information Section
              if (_shortageData != null &&
                  (_shortageData!['totalShortages'] as num) > 0) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Text(
                              'العجز في التوزيعات',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'عدد أنواع الفراخ التي بها عجز: ${_shortageData!['totalShortages']}',
                          style: TextStyle(
                            color: Colors.red[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...(_shortageData!['shortagesByChickenType'] as List)
                            .map(
                              (shortage) => _ShortageCard(shortage: shortage),
                            )
                            .toList(),
                      ],
                    ),
                  ),
                ),
              ],

              // Waste Information Section
              if (_wasteData != null &&
                  _wasteData!['wasteByChickenType'] != null &&
                  (_wasteData!['wasteByChickenType'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'الهالك من التوزيع الزائد',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'إجمالي الهالك: ${(_wasteData!['totals']['totalQuantity'] as num).toInt()} عدد - ${(_wasteData!['totals']['totalNetWeight'] as num).toStringAsFixed(2)} كجم',
                          style: TextStyle(
                            color: Colors.orange[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...(_wasteData!['wasteByChickenType'] as List)
                            .map((waste) => _WasteCard(waste: waste))
                            .toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final num value;
  final Color color;
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: TextStyle(color: color)),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: color.withOpacity(0.7),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            NumberFormat('#,##0.###').format(value),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _DailyProfitDetailsPage extends StatefulWidget {
  final String date;
  final num profit;
  final num distributionsTotal;
  final num loadingsTotal;
  final num expensesTotal;
  final num loadingPricesSum;
  final num discountsTotal;

  const _DailyProfitDetailsPage({
    required this.date,
    required this.profit,
    required this.distributionsTotal,
    required this.loadingsTotal,
    required this.expensesTotal,
    required this.loadingPricesSum,
    required this.discountsTotal,
  });

  @override
  State<_DailyProfitDetailsPage> createState() =>
      _DailyProfitDetailsPageState();
}

class _DailyProfitDetailsPageState extends State<_DailyProfitDetailsPage> {
  final DistributionApiService _distributionApi =
      serviceLocator<DistributionApiService>();
  final LoadingApiService _loadingApi = serviceLocator<LoadingApiService>();

  List<Map<String, dynamic>> _distributions = [];
  List<Map<String, dynamic>> _loadings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final targetDate = DateTime.parse(widget.date);

      // Load distributions for the selected date
      final allDistributions = await _distributionApi.getAllDistributions();
      final filteredDistributions = allDistributions.where((distribution) {
        try {
          final createdAt = DateTime.parse(
            distribution['createdAt'] ?? '',
          ).toLocal();
          return createdAt.year == targetDate.year &&
              createdAt.month == targetDate.month &&
              createdAt.day == targetDate.day;
        } catch (_) {
          return false;
        }
      }).toList();

      // Load loadings for the selected date
      final allLoadings = await _loadingApi.getAllLoadings();
      final filteredLoadings = allLoadings.where((loading) {
        try {
          final createdAt = DateTime.parse(
            loading['createdAt'] ?? '',
          ).toLocal();
          return createdAt.year == targetDate.year &&
              createdAt.month == targetDate.month &&
              createdAt.day == targetDate.day;
        } catch (_) {
          return false;
        }
      }).toList();

      setState(() {
        _distributions = filteredDistributions;
        _loadings = filteredLoadings;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل تحميل البيانات: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تفاصيل الربح - ${widget.date}'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // إجمالي الربح
                  _MetricTile(
                    label:
                        'الربح الإجمالي = إجمالي التوزيعات - إجمالي التحميل - إجمالي المصروفات - إجمالي الخصومات',
                    value: widget.profit,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 16),

                  // ملخص الإجماليات
                  Card(
                    elevation: 0,
                    color: Colors.teal.withOpacity(0.02),
                    child: Column(
                      children: [
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.receipt_long,
                            color: Colors.teal,
                          ),
                          title: const Text('إجمالي التوزيعات'),
                          trailing: Text(
                            NumberFormat(
                              '#,##0.###',
                            ).format(widget.distributionsTotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.local_shipping,
                            color: Colors.orange,
                          ),
                          title: const Text('إجمالي التحميل'),
                          trailing: Text(
                            NumberFormat(
                              '#,##0.###',
                            ).format(widget.loadingsTotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.money_off,
                            color: Colors.redAccent,
                          ),
                          title: const Text('إجمالي الخصومات'),
                          trailing: Text(
                            NumberFormat(
                              '#,##0.###',
                            ).format(widget.discountsTotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.price_change,
                            color: Colors.purple,
                          ),
                          title: const Text('إجمالي المصروفات'),
                          trailing: Text(
                            NumberFormat(
                              '#,##0.###',
                            ).format(widget.expensesTotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // تفاصيل التوزيعات
                  if (_distributions.isNotEmpty) ...[
                    Text(
                      'تفاصيل التوزيعات (${_distributions.length} طلب)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._distributions.map(
                      (distribution) =>
                          _DistributionProfitCard(distribution: distribution),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // تفاصيل التحميلات
                  if (_loadings.isNotEmpty) ...[
                    Text(
                      'تفاصيل التحميلات (${_loadings.length} طلب)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._loadings.map(
                      (loading) => _LoadingProfitCard(loading: loading),
                    ),
                  ],

                  // رسالة إذا لم توجد طلبات
                  if (_distributions.isEmpty && _loadings.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد طلبات في هذا التاريخ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _DistributionProfitCard extends StatelessWidget {
  final Map<String, dynamic> distribution;

  const _DistributionProfitCard({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final customerName = distribution['customer']?['name'] ?? 'غير محدد';
    final chickenTypeName = distribution['chickenType']?['name'] ?? 'غير محدد';
    final quantity = (distribution['quantity'] ?? 0) as num;
    final totalAmount = (distribution['totalAmount'] ?? 0) as num;
    final createdAt = DateTime.parse(distribution['createdAt'] ?? '').toLocal();
    final timeStr =
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.outbound, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'توزيع للعميل: $customerName',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    label: 'نوع الفراخ',
                    value: chickenTypeName,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoTile(
                    label: 'الكمية',
                    value: '${quantity.toInt()} وجبة',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_money, color: Colors.teal, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'المبلغ: ${NumberFormat('#,##0.###').format(totalAmount)} ج.م',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingProfitCard extends StatelessWidget {
  final Map<String, dynamic> loading;

  const _LoadingProfitCard({required this.loading});

  @override
  Widget build(BuildContext context) {
    final supplierName = loading['supplier']?['name'] ?? 'غير محدد';
    final chickenTypeName = loading['chickenType']?['name'] ?? 'غير محدد';
    final quantity = (loading['quantity'] ?? 0) as num;
    final totalLoading = (loading['totalLoading'] ?? 0) as num;
    final createdAt = DateTime.parse(loading['createdAt'] ?? '').toLocal();
    final timeStr =
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تحميل من المورد: $supplierName',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    label: 'نوع الفراخ',
                    value: chickenTypeName,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoTile(
                    label: 'الكمية',
                    value: '${quantity.toInt()} وحدة',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.money_off, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'المصروف: ${NumberFormat('#,##0.###').format(totalLoading)} ج.م',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final void Function(String)? onChanged;
  const _NumberField({
    required this.controller,
    required this.label,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _ReadOnlyNumberField extends StatelessWidget {
  final String label;
  final num value;
  const _ReadOnlyNumberField({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(
        text: NumberFormat('#,##0.###').format(value),
      ),
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _ShortageCard extends StatelessWidget {
  final Map<String, dynamic> shortage;

  const _ShortageCard({required this.shortage});

  @override
  Widget build(BuildContext context) {
    final chickenTypeName = shortage['chickenTypeName'] ?? 'غير محدد';
    final availableQuantity = (shortage['availableQuantity'] ?? 0) as num;
    final availableNetWeight = (shortage['availableNetWeight'] ?? 0) as num;
    final distributedQuantity = (shortage['distributedQuantity'] ?? 0) as num;
    final distributedNetWeight = (shortage['distributedNetWeight'] ?? 0) as num;
    final quantityShortage = (shortage['quantityShortage'] ?? 0) as num;
    final netWeightShortage = (shortage['netWeightShortage'] ?? 0) as num;
    final distributions = (shortage['distributions'] ?? []) as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pets, color: Colors.red[600], size: 20),
              const SizedBox(width: 8),
              Text(
                chickenTypeName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Available vs Distributed comparison
          Row(
            children: [
              Expanded(
                child: _ShortageInfoTile(
                  title: 'المتاح',
                  quantity: availableQuantity,
                  netWeight: availableNetWeight,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ShortageInfoTile(
                  title: 'الموزع',
                  quantity: distributedQuantity,
                  netWeight: distributedNetWeight,
                  color: Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Shortage amounts
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'العجز: ${quantityShortage.toInt()} عدد - ${netWeightShortage.toStringAsFixed(2)} كجم',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Distribution details
          if (distributions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'تفاصيل التوزيعات:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            ...distributions
                .map(
                  (dist) => Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${dist['customer']} - ${dist['quantity']} عدد - ${(dist['netWeight'] as num).toStringAsFixed(2)} كجم - ${NumberFormat('#,##0.###').format(dist['totalAmount'])} ج.م',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ],
      ),
    );
  }
}

class _ShortageInfoTile extends StatelessWidget {
  final String title;
  final num quantity;
  final num netWeight;
  final Color color;

  const _ShortageInfoTile({
    required this.title,
    required this.quantity,
    required this.netWeight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${quantity.toInt()} عدد',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          Text(
            '${netWeight.toStringAsFixed(2)} كجم',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _WasteCard extends StatelessWidget {
  final Map<String, dynamic> waste;

  const _WasteCard({required this.waste});

  @override
  Widget build(BuildContext context) {
    final chickenTypeName = waste['chickenType']?['name'] ?? 'غير محدد';
    final overDistributionQuantity =
        (waste['overDistributionQuantity'] ?? 0) as num;
    final overDistributionNetWeight =
        (waste['overDistributionNetWeight'] ?? 0) as num;
    final totalWasteQuantity = (waste['totalWasteQuantity'] ?? 0) as num;
    final totalWasteNetWeight = (waste['totalWasteNetWeight'] ?? 0) as num;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pets, color: Colors.orange[600], size: 20),
              const SizedBox(width: 8),
              Text(
                chickenTypeName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Over-distribution waste details
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: Colors.orange[700],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'هالك من التوزيع الزائد: ${overDistributionQuantity.toInt()} عدد - ${overDistributionNetWeight.toStringAsFixed(2)} كجم',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (totalWasteQuantity > overDistributionQuantity) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey[600],
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'إجمالي الهالك: ${totalWasteQuantity.toInt()} عدد - ${totalWasteNetWeight.toStringAsFixed(2)} كجم',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
