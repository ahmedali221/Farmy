import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui show TextDirection;
import '../../../../../../core/di/service_locator.dart';
import '../../../../../../core/services/inventory_api_service.dart';
import '../../../../../../core/services/payment_api_service.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final InventoryApiService _inventoryApi =
      serviceLocator<InventoryApiService>();
  final PaymentApiService _paymentApi = serviceLocator<PaymentApiService>();

  DateTime _selectedDate = DateTime.now();
  bool _loading = false;
  Map<String, dynamic>? _data;
  num _discountsTotal = 0;

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
            dt = DateTime.parse(createdAt);
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
                  const Spacer(),
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
                      _MetricTile(
                        label: 'وزن صافي التحميل',
                        value: netLoading,
                        color: Colors.blue,
                      ),

                      const SizedBox(height: 16),
                      _SectionLabel('وزن صافي التوزيع (محسوب تلقائياً)'),
                      const SizedBox(height: 8),
                      _MetricTile(
                        label: 'وزن صافي التوزيع',
                        value: netDist,
                        color: Colors.orange,
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
                              'الربح = مبلغ إجمالي الوجبات - مبلغ إجمالي التحميل - إجمالي المصروفات - مصروفات التحميل',
                          value: profit,
                          color: Colors.teal,
                        ),
                      ),
                    ],
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color)),
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

class _DailyProfitDetailsPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('تفاصيل الربح - $date')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _MetricTile(
              label:
                  'الربح = مبلغ إجمالي الوجبات - مبلغ إجمالي التحميل - إجمالي المصروفات - مصروفات التحميل',
              value: profit,
              color: Colors.teal,
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Colors.teal.withOpacity(0.02),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.receipt_long, color: Colors.teal),
                    title: const Text('مبلغ إجمالي الوجبات'),
                    trailing: Text(
                      NumberFormat('#,##0.###').format(distributionsTotal),
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
                    title: const Text('مبلغ إجمالي التحميل'),
                    trailing: Text(
                      NumberFormat('#,##0.###').format(loadingsTotal),
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
                    title: const Text('إجمالي ما تم خصمه'),
                    trailing: Text(
                      NumberFormat('#,##0.###').format(discountsTotal),
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
                    title: const Text('مصروفات التحميل (مجموع أسعار التحميل)'),
                    trailing: Text(
                      NumberFormat('#,##0.###').format(loadingPricesSum),
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
