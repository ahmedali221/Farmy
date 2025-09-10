import 'package:flutter/material.dart';
import '../../../../../../core/di/service_locator.dart';
import '../../../../../../core/services/payment_api_service.dart';
import '../../../../../../core/services/employee_api_service.dart';
import '../../../../../../core/services/employee_expense_api_service.dart';

class TreasuryTab extends StatefulWidget {
  const TreasuryTab({super.key});

  @override
  State<TreasuryTab> createState() => _TreasuryTabState();
}

class _TreasuryTabState extends State<TreasuryTab> {
  late final PaymentApiService _paymentService;
  late final EmployeeApiService _employeeService;
  late final EmployeeExpenseApiService _employeeExpenseService;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _employeeCollections = [];
  final Map<String, String> _employeeIdToName = {};
  final Map<String, List<Map<String, dynamic>>> _otherExpensesByEmployee = {};

  @override
  void initState() {
    super.initState();
    _paymentService = serviceLocator<PaymentApiService>();
    _employeeService = serviceLocator<EmployeeApiService>();
    _employeeExpenseService = serviceLocator<EmployeeExpenseApiService>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _paymentService.getEmployeeCollectionsSummary();
      try {
        final users = await _employeeService.getAllEmployeeUsers();
        _employeeIdToName.clear();
        for (final u in users) {
          final String id = (u['_id'] ?? '').toString();
          final String name = (u['username'] ?? u['name'] ?? 'موظف').toString();
          if (id.isNotEmpty) _employeeIdToName[id] = name;
        }
      } catch (_) {}

      final Map<String, List<Map<String, dynamic>>> serverExpenses = {};
      for (final it in list) {
        final String empId = (it['employeeId'] ?? '').toString();
        if (empId.isEmpty) continue;
        try {
          final items = await _employeeExpenseService.listByEmployee(empId);
          serverExpenses[empId] = items;
        } catch (_) {}
      }

      setState(() {
        _employeeCollections = list;
        _otherExpensesByEmployee
          ..clear()
          ..addAll(serverExpenses);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _employeeCollections = [];
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  double _totalCollected() {
    return _employeeCollections.fold(0.0, (sum, item) {
      final num v = (item['totalCollected'] ?? 0) as num;
      return sum + v.toDouble();
    });
  }

  double _sumAllOtherExpenses() {
    double sum = 0.0;
    _otherExpensesByEmployee.forEach((_, list) {
      for (final e in list) {
        final num v = (e['value'] ?? 0) as num;
        sum += v.toDouble();
      }
    });
    return sum;
  }

  double _sumEmployeeExpenses(String employeeId) {
    final list = _otherExpensesByEmployee[employeeId] ?? [];
    return list.fold<double>(0.0, (sum, e) {
      final num v = (e['value'] ?? 0) as num;
      return sum + v.toDouble();
    });
  }

  Future<void> _showAddExpenseDialog(String employeeId) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _OtherExpenseDialog(),
    );
    if (result != null) {
      try {
        final created = await _employeeExpenseService.createExpense(
          employeeId,
          (result['name'] ?? 'مصروف') as String,
          ((result['value'] ?? 0) as num).toDouble(),
        );
        setState(() {
          _otherExpensesByEmployee.putIfAbsent(employeeId, () => []);
          _otherExpensesByEmployee[employeeId]!.add(created);
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل في حفظ المصروف: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }

    final double total = _totalCollected();
    final double totalOther = _sumAllOtherExpenses();
    final double net = total - totalOther;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.85),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.account_balance,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'الخزنة المالية',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _summaryRow('إجمالي التحصيل', total, Colors.greenAccent),
                  const SizedBox(height: 6),
                  _summaryRow(
                    'المصاريف الأخرى',
                    totalOther,
                    Colors.orangeAccent,
                  ),
                  const Divider(color: Colors.white70),
                  _summaryRow('إجمالي الخزنة', net, Colors.white, bold: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _employeeCollections.isEmpty
                  ? _buildEmptyState(
                      Icons.people_outline,
                      'لا يوجد تحصيلات',
                      'لم يتم العثور على أي مبالغ محصلة للموظفين',
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _employeeCollections.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _employeeCollections[index];
                        final String employeeId = (item['employeeId'] ?? '')
                            .toString();
                        final double amount =
                            ((item['totalCollected'] ?? 0) as num).toDouble();
                        final int count = ((item['count'] ?? 0) as num).toInt();
                        final displayName =
                            _employeeIdToName[employeeId] ?? employeeId;
                        return _employeeCollectionTile(
                          employeeId,
                          displayName,
                          amount,
                          count,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String title,
    double value,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        Text(
          'EGP ${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: bold ? 18 : 16,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _employeeCollectionTile(
    String employeeId,
    String name,
    double amount,
    int count,
  ) {
    final double expenses = _sumEmployeeExpenses(employeeId);
    final double net = amount - expenses;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'عدد عمليات التحصيل: $count',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _amountPill('تحصيل', amount, Colors.green),
                    const SizedBox(height: 4),
                    _amountPill('مصروفات', expenses, Colors.orange),
                    const SizedBox(height: 4),
                    _amountPill('صافي', net, Colors.blue),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة مصروف'),
                onPressed: () => _showAddExpenseDialog(employeeId),
              ),
            ),
            if ((_otherExpensesByEmployee[employeeId] ?? []).isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _otherExpensesByEmployee[employeeId]!
                    .asMap()
                    .entries
                    .map((entry) {
                      final num v = (entry.value['value'] ?? 0) as num;
                      return Chip(
                        label: Text(
                          '${entry.value['name'] ?? 'مصروف'}: ${v.toDouble().toStringAsFixed(2)}',
                        ),
                        backgroundColor: Colors.red.withOpacity(0.08),
                        side: BorderSide(color: Colors.red.withOpacity(0.2)),
                        labelStyle: const TextStyle(color: Colors.red),
                      );
                    })
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _amountPill(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(2)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _OtherExpenseDialog extends StatefulWidget {
  const _OtherExpenseDialog();

  @override
  State<_OtherExpenseDialog> createState() => _OtherExpenseDialogState();
}

class _OtherExpenseDialogState extends State<_OtherExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مصروف للموظف'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم المصروف',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'اسم المصروف مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'قيمة المصروف (EGP)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'القيمة مطلوبة';
                final d = double.tryParse(v);
                if (d == null || d < 0) return 'أدخل قيمة صحيحة';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'value': double.parse(_valueController.text),
              });
            }
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }

  // no separate error widget; errors shown inline
}
