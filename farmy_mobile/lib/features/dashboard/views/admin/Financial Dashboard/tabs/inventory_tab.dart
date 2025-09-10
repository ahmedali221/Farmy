import 'package:flutter/material.dart';
import '../../../../../../core/di/service_locator.dart';
import '../../../../../../core/services/employee_api_service.dart';
import '../../../../../../core/services/loading_api_service.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  late final LoadingApiService _loadingService;
  DateTime _selectedInventoryDate = DateTime.now();
  double _dailyDistributionNet = 0.0;
  int _dailyDistributionCount = 0;
  double _dailyLoadingNet = 0.0;
  bool _inventoryLoading = false;
  final TextEditingController _adminSubtractCtrl = TextEditingController();
  double _adminSubtractKg = 0.0;
  final TextEditingController _adminNotesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadingService = serviceLocator<LoadingApiService>();
    _loadInventoryForDate(_selectedInventoryDate);
  }

  @override
  void dispose() {
    _adminSubtractCtrl.dispose();
    _adminNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryForDate(DateTime date) async {
    setState(() {
      _inventoryLoading = true;
    });
    try {
      final dist = await serviceLocator<EmployeeApiService>()
          .getDailyDistributionNetWeight(date: date);
      _dailyDistributionNet = ((dist['totalNetWeight'] ?? 0) as num).toDouble();
      _dailyDistributionCount = ((dist['count'] ?? 0) as num).toInt();

      final start = DateTime(date.year, date.month, date.day).toIso8601String();
      final end = DateTime(
        date.year,
        date.month,
        date.day + 1,
      ).toIso8601String();
      final stats = await _loadingService.getLoadingStats(
        startDate: start,
        endDate: end,
      );
      _dailyLoadingNet = ((stats['totalNetWeight'] ?? 0) as num).toDouble();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل تحميل بيانات المخزون: $e')));
      }
    } finally {
      if (mounted) setState(() => _inventoryLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text(
                  'المخزون اليومي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.today, size: 16),
                  label: Text(
                    '${_selectedInventoryDate.year}-${_selectedInventoryDate.month.toString().padLeft(2, '0')}-${_selectedInventoryDate.day.toString().padLeft(2, '0')}',
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2024, 1, 1),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      initialDate: _selectedInventoryDate,
                    );
                    if (picked != null) {
                      setState(() => _selectedInventoryDate = picked);
                      _loadInventoryForDate(picked);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_inventoryLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  _inventoryCard(
                    title: 'صافي وزن التوزيع اليومي',
                    value: _dailyDistributionNet,
                    subtitle: 'عدد العمليات: $_dailyDistributionCount',
                    color: Colors.orange,
                    icon: Icons.outbond,
                  ),
                  const SizedBox(height: 12),
                  _inventoryCard(
                    title: 'صافي وزن التحميل اليومي',
                    value: _dailyLoadingNet,
                    subtitle: 'من تبويب التحميل',
                    color: Colors.green,
                    icon: Icons.move_up,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'مدخل إداري (كجم)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _adminSubtractCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'قيمة تُخصم من المخزون',
                              border: OutlineInputBorder(),
                              hintText: 'أدخل قيمة بالكيلو جرام',
                            ),
                            onChanged: (v) {
                              final val = double.tryParse(v) ?? 0.0;
                              setState(() => _adminSubtractKg = val);
                            },
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _adminNotesCtrl,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظات (اختياري)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              onPressed: _inventoryLoading
                                  ? null
                                  : () async {
                                      try {
                                        setState(
                                          () => _inventoryLoading = true,
                                        );
                                        final saved =
                                            await serviceLocator<
                                                  EmployeeApiService
                                                >()
                                                .upsertDailyStock(
                                                  date: _selectedInventoryDate,
                                                  netDistributionWeight:
                                                      _dailyDistributionNet,
                                                  adminAdjustment:
                                                      _adminSubtractKg,
                                                  notes: _adminNotesCtrl.text,
                                                );
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'تم حفظ مخزون اليوم: ${saved['result']?.toStringAsFixed(2) ?? saved['result']}',
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'فشل حفظ المخزون: $e',
                                            ),
                                          ),
                                        );
                                      } finally {
                                        if (mounted)
                                          setState(
                                            () => _inventoryLoading = false,
                                          );
                                      }
                                    },
                              icon: const Icon(Icons.save),
                              label: const Text('حفظ مخزون اليوم'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _inventorySummaryCard(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _inventorySummaryCard() {
    final double difference = _dailyLoadingNet - _dailyDistributionNet;
    final double stock = difference - _adminSubtractKg;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'حساب المخزون اليومي',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _formulaRow('التحميل الصافي', _dailyLoadingNet, Colors.green),
            _formulaRow('التوزيع الصافي', _dailyDistributionNet, Colors.orange),
            const Divider(),
            _formulaRow('الفرق (تحميل - توزيع)', difference, Colors.blue),
            _formulaRow('خصم إداري', _adminSubtractKg, Colors.red),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'المخزون اليومي',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${stock.toStringAsFixed(2)} كجم',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulaRow(String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          '${value.toStringAsFixed(2)} كجم',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _inventoryCard({
    required String title,
    required double value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '${value.toStringAsFixed(2)} كجم',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


