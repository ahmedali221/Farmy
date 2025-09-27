import 'package:flutter/material.dart';
import '../../../../../../core/di/service_locator.dart';
import '../../../../../../core/services/payment_api_service.dart';
import '../../../../../../core/services/employee_api_service.dart';
import '../../../../../../core/services/employee_expense_api_service.dart';
import '../../../../../../core/services/transfer_api_service.dart';

class EmployeeSafeTab extends StatefulWidget {
  const EmployeeSafeTab({super.key});

  @override
  State<EmployeeSafeTab> createState() => _EmployeeSafeTabState();
}

class _EmployeeSafeTabState extends State<EmployeeSafeTab> {
  late final PaymentApiService _paymentService;
  late final EmployeeApiService _employeeService;
  late final EmployeeExpenseApiService _employeeExpenseService;
  late final TransferApiService _transferService;

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
    _transferService = serviceLocator<TransferApiService>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _paymentService.getUserCollectionsSummary();
      try {
        final users = await _employeeService.getAllEmployeeUsers();
        _employeeIdToName.clear();
        for (final u in users) {
          final String id = (u['_id'] ?? '').toString();
          final String role = (u['role'] ?? '').toString();
          final String name = (u['username'] ?? u['name'] ?? 'موظف').toString();
          // Only include users with employee role
          if (id.isNotEmpty && role == 'employee') {
            _employeeIdToName[id] = name;
          }
        }
      } catch (_) {}

      final Map<String, List<Map<String, dynamic>>> serverExpenses = {};
      for (final it in list) {
        final String empId = (it['userId'] ?? '').toString();
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
                    final String employeeId = (item['userId'] ?? '').toString();
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
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            'تحصيل: ${collected.toStringAsFixed(2)}  •  صافي: ${net.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _EmployeeSafeDetailsPage(
                                  employeeId: employeeId,
                                  employeeName: name,
                                  collected: collected,
                                  transfersIn: transfersIn,
                                  transfersOut: transfersOut,
                                  initialOtherExpenses:
                                      _otherExpensesByEmployee[employeeId] ??
                                      const [],
                                ),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ),
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

class _EmployeeSafeDetailsPage extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final double collected;
  final double transfersIn;
  final double transfersOut;
  final List<Map<String, dynamic>> initialOtherExpenses;

  const _EmployeeSafeDetailsPage({
    required this.employeeId,
    required this.employeeName,
    required this.collected,
    required this.transfersIn,
    required this.transfersOut,
    required this.initialOtherExpenses,
  });

  @override
  State<_EmployeeSafeDetailsPage> createState() =>
      _EmployeeSafeDetailsPageState();
}

class _EmployeeSafeDetailsPageState extends State<_EmployeeSafeDetailsPage> {
  late final EmployeeExpenseApiService _employeeExpenseService;
  late final TransferApiService _transferService;
  late List<Map<String, dynamic>> _otherExpenses;

  @override
  void initState() {
    super.initState();
    _employeeExpenseService = serviceLocator<EmployeeExpenseApiService>();
    _transferService = serviceLocator<TransferApiService>();
    _otherExpenses = [...widget.initialOtherExpenses];
  }

  double get _extraTotal => _otherExpenses.fold<double>(
    0.0,
    (s, e) => s + ((e['value'] ?? 0) as num).toDouble(),
  );

  double get _netAvailable =>
      widget.collected + widget.transfersIn - widget.transfersOut;

  double get _net => _netAvailable - _extraTotal;

  Future<void> _addExpense() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _OtherExpenseDialog(),
    );
    if (result != null) {
      try {
        final created = await _employeeExpenseService.createExpense(
          widget.employeeId,
          (result['name'] ?? 'مصروف') as String,
          ((result['value'] ?? 0) as num).toDouble(),
          note: (result['note'] ?? '') as String,
        );
        setState(() {
          _otherExpenses.add(created);
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل في保存 المصروف: $e')));
      }
    }
  }

  Future<void> _deleteExpense(int index) async {
    final id = _otherExpenses[index]['_id']?.toString();
    try {
      if (id != null && id.isNotEmpty) {
        await _employeeExpenseService.deleteExpense(id);
      }
      setState(() {
        _otherExpenses.removeAt(index);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل في حذف المصروف: $e')));
    }
  }

  Future<void> _showTransferDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _TransferDialog(
        fromUserId: widget.employeeId,
        fromUserName: widget.employeeName,
        availableAmount: _net,
      ),
    );

    if (result != null) {
      try {
        await _transferService.createTransfer(
          fromUser: result['fromUser'] as String,
          toUser: result['toUser'] as String,
          amount: result['amount'] as double,
          note: result['note'] as String?,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إجراء التحويل بنجاح')));

        // Navigate back to refresh the data
        Navigator.of(context).pop();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل في إجراء التحويل: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('خزنة ${widget.employeeName}')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.green,
                      ),
                      title: const Text('إجمالي التحصيل'),
                      trailing: Text(
                        widget.collected.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.call_received,
                        color: Colors.purple,
                      ),
                      title: const Text('تحويلات واردة'),
                      trailing: Text(
                        widget.transfersIn.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.call_made,
                        color: Colors.purple,
                      ),
                      title: const Text('تحويلات صادرة'),
                      trailing: Text(
                        widget.transfersOut.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.summarize,
                        color: Colors.indigo,
                      ),
                      title: const Text('صافي المتاح قبل المصروفات'),
                      trailing: Text(
                        _netAvailable.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.receipt_long,
                        color: Colors.orange,
                      ),
                      title: const Text('مصروفات أخرى'),
                      trailing: Text(
                        _extraTotal.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.check_circle,
                        color: Colors.blue,
                      ),
                      title: const Text('الصافي'),
                      trailing: Text(
                        _net.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _addExpense,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('إضافة مصروف'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _net > 0 ? _showTransferDialog : null,
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('تحويل أموال'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_otherExpenses.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'المصروفات الأخرى',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._otherExpenses.asMap().entries.map((entry) {
                final i = entry.key;
                final expense = entry.value;
                final double value = ((expense['value'] ?? 0) as num)
                    .toDouble();
                final String name = (expense['name'] ?? 'مصروف').toString();
                final String note = (expense['note'] ?? '').toString();
                final String createdAt = expense['createdAt']?.toString() ?? '';

                // Format date
                String formattedDate = '';
                if (createdAt.isNotEmpty) {
                  try {
                    final date = DateTime.parse(createdAt);
                    formattedDate = '${date.day}/${date.month}/${date.year}';
                  } catch (e) {
                    formattedDate = 'تاريخ غير محدد';
                  }
                } else {
                  formattedDate = 'تاريخ غير محدد';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      child: Icon(Icons.receipt, color: Colors.red, size: 20),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            note,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${value.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _deleteExpense(i),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    isThreeLine: note.isNotEmpty,
                  ),
                );
              }).toList(),
            ],
          ],
        ),
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
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _noteController.dispose();
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
                'note': _noteController.text.trim(),
              });
            }
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}

class _TransferDialog extends StatefulWidget {
  final String fromUserId;
  final String fromUserName;
  final double availableAmount;

  const _TransferDialog({
    required this.fromUserId,
    required this.fromUserName,
    required this.availableAmount,
  });

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedToUserId;
  List<Map<String, dynamic>> _availableUsers = [];
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableUsers() async {
    try {
      final employeeService = serviceLocator<EmployeeApiService>();
      final users = await employeeService.getAllEmployeeUsers();
      setState(() {
        _availableUsers = users
            .where(
              (user) =>
                  user['_id']?.toString() != widget.fromUserId &&
                  user['role']?.toString() == 'employee',
            )
            .toList();
        _loadingUsers = false;
      });
    } catch (e) {
      setState(() => _loadingUsers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تحويل أموال'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('من: ${widget.fromUserName}'),
            Text(
              'المبلغ المتاح: ${widget.availableAmount.toStringAsFixed(2)} ج.م',
            ),
            const SizedBox(height: 16),

            if (_loadingUsers)
              const CircularProgressIndicator()
            else ...[
              DropdownButtonFormField<String>(
                value: _selectedToUserId,
                decoration: const InputDecoration(
                  labelText: 'إلى',
                  border: OutlineInputBorder(),
                ),
                items: _availableUsers.map((user) {
                  return DropdownMenuItem<String>(
                    value: user['_id']?.toString(),
                    child: Text(user['username']?.toString() ?? 'غير معروف'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedToUserId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى اختيار المستخدم';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'المبلغ مطلوب';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'أدخل مبلغ صحيح';
                  }
                  if (amount > widget.availableAmount) {
                    return 'المبلغ أكبر من المتاح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _selectedToUserId != null && !_loadingUsers
              ? () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(context, {
                      'fromUser': widget.fromUserId,
                      'toUser': _selectedToUserId!,
                      'amount': double.parse(_amountController.text),
                      'note': _noteController.text.trim().isNotEmpty
                          ? _noteController.text.trim()
                          : null,
                    });
                  }
                }
              : null,
          child: const Text('تحويل'),
        ),
      ],
    );
  }
}
