import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/services/payment_api_service.dart';
import '../../../../../core/services/employee_api_service.dart';
import '../../../../../core/services/employee_expense_api_service.dart';

class FinancialDashboardView extends StatefulWidget {
  const FinancialDashboardView({super.key});

  @override
  State<FinancialDashboardView> createState() => _FinancialDashboardViewState();
}

class _FinancialDashboardViewState extends State<FinancialDashboardView>
    with SingleTickerProviderStateMixin {
  late final PaymentApiService _paymentService;
  late final EmployeeApiService _employeeService;
  late final EmployeeExpenseApiService _employeeExpenseService;
  late TabController _tabController;
  bool isLoading = true;
  List<Map<String, dynamic>> employeeCollections = [];
  String? loadError;
  final Map<String, String> _employeeIdToName = {};
  final Map<String, List<Map<String, dynamic>>> _otherExpensesByEmployee = {};

  @override
  void initState() {
    super.initState();
    _paymentService = serviceLocator<PaymentApiService>();
    _employeeService = serviceLocator<EmployeeApiService>();
    _employeeExpenseService = serviceLocator<EmployeeExpenseApiService>();
    _tabController = TabController(length: 2, vsync: this);
    _loadTreasury();
  }

  Future<void> _loadTreasury() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });
    try {
      final list = await _paymentService.getEmployeeCollectionsSummary();
      // map employee ids to usernames for display
      try {
        final users = await _employeeService.getAllEmployeeUsers();
        _employeeIdToName.clear();
        for (final u in users) {
          final String id = (u['_id'] ?? '').toString();
          final String name = (u['username'] ?? u['name'] ?? 'موظف').toString();
          if (id.isNotEmpty) _employeeIdToName[id] = name;
        }
      } catch (_) {}
      // Load existing extra expenses for each employee
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
        employeeCollections = list;
        _otherExpensesByEmployee
          ..clear()
          ..addAll(serverExpenses);
      });
    } catch (e) {
      setState(() {
        loadError = e.toString();
        employeeCollections = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  double _totalCollected() {
    return employeeCollections.fold(0.0, (sum, item) {
      final num v = (item['totalCollected'] ?? 0) as num;
      return sum + v.toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الخزنة'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin-dashboard'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadTreasury,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'الخزنة'),
              Tab(text: 'خزنة الموظفين'),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
            ? _buildError(loadError!)
            : TabBarView(
                controller: _tabController,
                children: [_buildTreasuryBody(), _buildEmployeeSafeTab()],
              ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              'فشل في تحميل الخزنة',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreasuryBody() {
    final double total = _totalCollected();
    final double totalOther = _sumAllOtherExpenses();
    final double net = total - totalOther;
    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary header
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
                _summaryRow('المصاريف الأخرى', totalOther, Colors.orangeAccent),
                const Divider(color: Colors.white70),
                _summaryRow('إجمالي الخزنة', net, Colors.white, bold: true),
              ],
            ),
          ),

          // List of employees collection
          Padding(
            padding: const EdgeInsets.all(16),
            child: employeeCollections.isEmpty
                ? _buildEmptyState(
                    Icons.people_outline,
                    'لا يوجد تحصيلات',
                    'لم يتم العثور على أي مبالغ محصلة للموظفين',
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: employeeCollections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = employeeCollections[index];
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
    );
  }

  Widget _buildEmployeeSafeTab() {
    // Per-employee cards with collected, extra expenses and net
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: employeeCollections.isEmpty
            ? _buildEmptyState(
                Icons.people_outline,
                'لا يوجد موظفون لديهم تحصيل',
                'أعد التحميل بعد تسجيل المدفوعات',
              )
            : Column(
                children: employeeCollections.map((item) {
                  final String employeeId = (item['employeeId'] ?? '')
                      .toString();
                  final String name =
                      _employeeIdToName[employeeId] ?? employeeId;
                  final double collected =
                      ((item['totalCollected'] ?? 0) as num).toDouble();
                  final double extra = _sumEmployeeExpenses(employeeId);
                  final double net = collected - extra;
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
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('إضافة مصروف'),
                                onPressed: () =>
                                    _showAddExpenseDialog(employeeId),
                              ),
                            ),
                            if ((_otherExpensesByEmployee[employeeId] ?? [])
                                .isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: _otherExpensesByEmployee[employeeId]!
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                      final num v =
                                          (entry.value['value'] ?? 0) as num;
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
    );
  }

  double _sumEmployeeExpenses(String employeeId) {
    final list = _otherExpensesByEmployee[employeeId] ?? [];
    return list.fold<double>(0.0, (sum, e) {
      final num v = (e['value'] ?? 0) as num;
      return sum + v.toDouble();
    });
  }

  Widget _employeeCollectionTile(
    String employeeId,
    String name,
    double amount,
    int count,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.person, color: Colors.white),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('عدد عمليات التحصيل: $count'),
            const SizedBox(height: 6),
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
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.2)),
          ),
          child: Text(
            'EGP ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('فشل في حفظ المصروف: $e')));
        }
      }
    }
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
