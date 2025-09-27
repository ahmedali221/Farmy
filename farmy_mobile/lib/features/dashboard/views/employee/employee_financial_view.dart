import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/payment_api_service.dart';
import '../../../../core/services/employee_expense_api_service.dart';
import '../../../../core/services/customer_api_service.dart';
import '../../../authentication/cubit/auth_cubit.dart';

class EmployeeFinancialView extends StatefulWidget {
  const EmployeeFinancialView({super.key});

  @override
  State<EmployeeFinancialView> createState() => _EmployeeFinancialViewState();
}

class _EmployeeFinancialViewState extends State<EmployeeFinancialView> {
  late final PaymentApiService _paymentService;
  late final EmployeeExpenseApiService _employeeExpenseService;
  final Map<String, String> _customerNameCache = {};

  bool _loading = true;
  String? _error;
  double _totalCollected = 0.0;
  List<Map<String, dynamic>> _expenses = [];
  double _totalExpenses = 0.0;
  double _netBalance = 0.0;
  List<Map<String, dynamic>> _dailyCollections = [];

  @override
  void initState() {
    super.initState();
    _paymentService = serviceLocator<PaymentApiService>();
    _employeeExpenseService = serviceLocator<EmployeeExpenseApiService>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authCubit = context.read<AuthCubit>();
      final currentUser = authCubit.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final employeeId = currentUser.id;

      // Get user collections summary (overall totals)
      final collectionsSummary = await _paymentService
          .getUserCollectionsSummary();

      // Find current user's data
      final userData = collectionsSummary.firstWhere(
        (item) => (item['userId'] ?? '').toString() == employeeId,
        orElse: () => {'totalCollected': 0},
      );

      _totalCollected = ((userData['totalCollected'] ?? 0) as num).toDouble();

      // Get user daily grouped collections (history)
      _dailyCollections = await _paymentService.getUserDailyCollections(
        employeeId,
      );

      // Get employee expenses
      _expenses = await _employeeExpenseService.listByEmployee(employeeId);
      _totalExpenses = _expenses.fold<double>(
        0.0,
        (sum, expense) => sum + ((expense['value'] ?? 0) as num).toDouble(),
      );

      _netBalance = _totalCollected - _totalExpenses;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<String> _resolveCustomerName(dynamic customerField) async {
    try {
      if (customerField is Map<String, dynamic>) {
        final name = customerField['name']?.toString();
        if (name != null && name.isNotEmpty) return name;
        final id = customerField['_id']?.toString();
        if (id != null && id.isNotEmpty) {
          if (_customerNameCache.containsKey(id))
            return _customerNameCache[id]!;
          final svc = serviceLocator<CustomerApiService>();
          final data = await svc.getCustomerById(id);
          final fetched = data?['name']?.toString() ?? 'عميل';
          _customerNameCache[id] = fetched;
          return fetched;
        }
      } else if (customerField is String && customerField.isNotEmpty) {
        if (_customerNameCache.containsKey(customerField)) {
          return _customerNameCache[customerField]!;
        }
        final svc = serviceLocator<CustomerApiService>();
        final data = await svc.getCustomerById(customerField);
        final fetched = data?['name']?.toString() ?? 'عميل';
        _customerNameCache[customerField] = fetched;
        return fetched;
      }
    } catch (_) {}
    return 'عميل غير معروف';
  }

  Future<void> _showAddExpenseDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _AddExpenseDialog(),
    );

    if (result != null) {
      try {
        final authCubit = context.read<AuthCubit>();
        final currentUser = authCubit.currentUser;

        if (currentUser == null) {
          throw Exception('User not authenticated');
        }

        final created = await _employeeExpenseService.createExpense(
          currentUser.id,
          (result['name'] ?? 'مصروف') as String,
          ((result['value'] ?? 0) as num).toDouble(),
          note: (result['note'] ?? '') as String,
        );

        setState(() {
          _expenses.add(created);
          _totalExpenses += ((result['value'] ?? 0) as num).toDouble();
          _netBalance = _totalCollected - _totalExpenses;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إضافة المصروف بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('فشل في إضافة المصروف: $e')));
        }
      }
    }
  }

  Future<void> _deleteExpense(int index) async {
    final expense = _expenses[index];
    final expenseId = expense['_id']?.toString();

    if (expenseId == null || expenseId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا يمكن حذف هذا المصروف')));
      return;
    }

    try {
      await _employeeExpenseService.deleteExpense(expenseId);

      final expenseValue = ((expense['value'] ?? 0) as num).toDouble();
      setState(() {
        _expenses.removeAt(index);
        _totalExpenses -= expenseValue;
        _netBalance = _totalCollected - _totalExpenses;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف المصروف بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل في حذف المصروف: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final currentUser = authCubit.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('البيانات المالية'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'حدث خطأ في تحميل البيانات',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employee Info Card
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Theme.of(context).primaryColor,
                                child: Text(
                                  currentUser?.username
                                          .substring(0, 1)
                                          .toUpperCase() ??
                                      'م',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentUser?.username ?? 'موظف',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'موظف',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Financial Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  context.pushNamed('employee-payment-history'),
                              child: _buildSummaryCard(
                                'إجمالي التحصيل',
                                _totalCollected,
                                Icons.account_balance_wallet,
                                Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  context.pushNamed('employee-expense-history'),
                              child: _buildSummaryCard(
                                'إجمالي المصروفات',
                                _totalExpenses,
                                Icons.money_off,
                                Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryCard(
                        'الرصيد الصافي',
                        _netBalance,
                        Icons.account_balance,
                        _netBalance >= 0 ? Colors.blue : Colors.red,
                      ),
                      const SizedBox(height: 24),

                      // Daily Collections History
                      Text(
                        'سجل التحصيل اليومي',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_dailyCollections.isEmpty)
                        _buildEmptyState(
                          Icons.history,
                          'لا يوجد سجلات تحصيل',
                          'لم يتم تسجيل أي تحصيلات حتى الآن',
                        )
                      else ...[
                        for (final day in _dailyCollections)
                          InkWell(
                            onTap: () => context.pushNamed(
                              'employee-daily-detail',
                              extra: {'date': (day['date'] ?? '').toString()},
                            ),
                            child: _buildDailyHistoryCard(day),
                          ),
                      ],

                      const SizedBox(height: 24),

                      // Expenses Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المصروفات',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('إضافة مصروف'),
                            onPressed: _showAddExpenseDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_expenses.isEmpty)
                        _buildEmptyState(
                          Icons.money_off,
                          'لا توجد مصروفات',
                          'لم يتم تسجيل أي مصروفات بعد',
                        )
                      else
                        ..._expenses.asMap().entries.map((entry) {
                          final index = entry.key;
                          final expense = entry.value;
                          return _buildExpenseCard(index, expense);
                        }),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ج.م ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyHistoryCard(Map<String, dynamic> day) {
    final String date = (day['date'] ?? '').toString();
    final double totalPaid = ((day['totalPaid'] ?? 0) as num).toDouble();
    final int count = (day['count'] ?? 0) as int;
    final List<dynamic> payments = (day['payments'] as List<dynamic>? ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDate(date),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ج.م ${totalPaid.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'عدد السجلات: $count',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...payments.map((p) {
              final double paidAmount = ((p['paidAmount'] ?? 0) as num)
                  .toDouble();
              final double discount = ((p['discount'] ?? 0) as num).toDouble();
              final String createdAt = (p['createdAt'] ?? '').toString();
              final dynamic customerField = p['customer'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(Icons.payments, color: Colors.blue),
                ),
                title: Text(
                  'تحصيل: ج.م ${paidAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: _resolveCustomerName(customerField),
                      builder: (context, snap) {
                        final name = snap.data ?? '...';
                        return Text(
                          'العميل: $name',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        );
                      },
                    ),
                    if (discount > 0)
                      Text(
                        'خصم: ج.م ${discount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    if (createdAt.isNotEmpty)
                      Text(
                        _formatTime(createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(int index, Map<String, dynamic> expense) {
    final name = expense['name'] ?? 'مصروف';
    final value = ((expense['value'] ?? 0) as num).toDouble();
    final note = expense['note'] ?? '';
    final createdAt = expense['createdAt'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withOpacity(0.1),
          child: const Icon(Icons.money_off, color: Colors.red),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ج.م ${value.toStringAsFixed(2)}'),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                note,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _formatDate(createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _showDeleteConfirmation(index),
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

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا المصروف؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteExpense(index);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (e) {
      return '';
    }
  }
}

class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog();

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
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
      title: const Text('إضافة مصروف جديد'),
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
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'اسم المصروف مطلوب'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'قيمة المصروف (ج.م)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'القيمة مطلوبة';
                final d = double.tryParse(value);
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
