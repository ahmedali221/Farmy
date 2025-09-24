import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../../core/di/service_locator.dart';
import '../../../../../../core/services/payment_api_service.dart';
import '../../../../../../core/services/employee_api_service.dart';
import '../../../../../../core/services/employee_expense_api_service.dart';

class EmployeeSafeTab extends StatefulWidget {
  const EmployeeSafeTab({super.key});

  @override
  State<EmployeeSafeTab> createState() => _EmployeeSafeTabState();
}

class _EmployeeSafeTabState extends State<EmployeeSafeTab> {
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
      if (mounted) setState(() => _loading = false);
    }
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
        ).showSnackBar(SnackBar(content: Text('فشل في保存 المصروف: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _employeeCollections.isEmpty
              ? _buildEmptyState(
                  Icons.people_outline,
                  'لا يوجد موظفون لديهم تحصيل',
                  'أعد التحميل بعد تسجيل المدفوعات',
                )
              : Column(
                  children: _employeeCollections.map((item) {
                    final String employeeId = (item['employeeId'] ?? '')
                        .toString();
                    final String name =
                        _employeeIdToName[employeeId] ?? employeeId;
                    final double collected =
                        ((item['totalCollected'] ?? 0) as num).toDouble();
                    final double transfersIn =
                        ((item['transfersIn'] ?? 0) as num).toDouble();
                    final double transfersOut =
                        ((item['transfersOut'] ?? 0) as num).toDouble();
                    final double netAvailable =
                        ((item['netAvailable'] ??
                                    (collected + transfersIn - transfersOut))
                                as num)
                            .toDouble();
                    final double extra = _sumEmployeeExpenses(employeeId);
                    final double net = netAvailable - extra;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor,
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'EGP ${collected.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'تحويلات: +${transfersIn.toStringAsFixed(2)} / -${transfersOut.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.purple,
                                        ),
                                      ),
                                      Text(
                                        'مصروفات: ${extra.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.orange,
                                        ),
                                      ),
                                      Text(
                                        'صافي: ${net.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('إضافة مصروف'),
                                      onPressed: () =>
                                          _showAddExpenseDialog(employeeId),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(
                                        Icons.swap_horiz,
                                        size: 16,
                                      ),
                                      label: const Text('تحويل أموال'),
                                      onPressed: () async {
                                        final name =
                                            _employeeIdToName[employeeId] ??
                                            employeeId;
                                        final result = await context.pushNamed(
                                          'transfer-money',
                                          extra: {
                                            'fromEmployeeId': employeeId,
                                            'fromEmployeeName': name,
                                          },
                                        );
                                        if (result == true) {
                                          _loadData();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              if ((_otherExpensesByEmployee[employeeId] ?? [])
                                  .isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children:
                                      _otherExpensesByEmployee[employeeId]!
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                            final num v =
                                                (entry.value['value'] ?? 0)
                                                    as num;
                                            return _expenseChip(
                                              employeeId,
                                              entry.key,
                                              entry.value['name'] ?? 'مصروف',
                                              v.toDouble(),
                                            );
                                          })
                                          .toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ),
    );
  }

  Widget _expenseChip(String employeeId, int index, String name, double value) {
    return Chip(
      label: Text('$name: ${value.toStringAsFixed(2)}'),
      backgroundColor: Colors.red.withOpacity(0.08),
      side: BorderSide(color: Colors.red.withOpacity(0.2)),
      labelStyle: const TextStyle(color: Colors.red),
      onDeleted: () {
        final item = _otherExpensesByEmployee[employeeId]?[index];
        final String? id = item?['_id']?.toString();
        Future<void> doDelete() async {
          try {
            if (id != null && id.isNotEmpty) {
              await _employeeExpenseService.deleteExpense(id);
            }
            setState(() {
              _otherExpensesByEmployee[employeeId]?.removeAt(index);
            });
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('فشل في حذف المصروف: $e')));
            }
          }
        }

        doDelete();
      },
      deleteIcon: const Icon(Icons.close, size: 16, color: Colors.red),
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
}
