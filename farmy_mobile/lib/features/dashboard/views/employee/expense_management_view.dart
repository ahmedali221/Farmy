import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/order_api_service.dart';
import '../../../../core/services/expense_api_service.dart';

class ExpenseManagementView extends StatefulWidget {
  const ExpenseManagementView({super.key});

  @override
  State<ExpenseManagementView> createState() => _ExpenseManagementViewState();
}

class _ExpenseManagementViewState extends State<ExpenseManagementView> {
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> expenses = [];
  String? selectedOrderId;
  bool loading = true;

  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => loading = true);
    final orderService = serviceLocator<OrderApiService>();
    final list = await orderService.getOrdersByEmployee();
    if (!mounted) return;
    setState(() {
      orders = list;
      loading = false;
    });
  }

  Future<void> _loadExpenses() async {
    if (selectedOrderId == null) return;
    final expenseService = serviceLocator<ExpenseApiService>();
    final list = await expenseService.getExpensesByOrder(selectedOrderId!);
    if (!mounted) return;
    setState(() => expenses = list);
  }

  Future<void> _addExpense() async {
    if (!_formKey.currentState!.validate() || selectedOrderId == null) return;
    final expenseService = serviceLocator<ExpenseApiService>();
    await expenseService.createExpense({
      'order': selectedOrderId,
      'title': _titleCtrl.text,
      'amount': double.parse(_amountCtrl.text),
      'note': _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
    });
    _titleCtrl.clear();
    _amountCtrl.clear();
    _noteCtrl.clear();
    await _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مصروفات الطلب'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/employee-dashboard'),
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Order Selection
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.shopping_cart,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'اختر الطلب',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: selectedOrderId,
                              decoration: const InputDecoration(
                                labelText: 'الطلب',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.list_alt),
                              ),
                              items: orders.map<DropdownMenuItem<String>>((o) {
                                final c = o['customer'];
                                final t = o['chickenType'];
                                final q = o['quantity'];
                                return DropdownMenuItem<String>(
                                  value: o['_id']?.toString(),
                                  child: Text(
                                    '${c['name']} - ${t['name']} - $q ك',
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? v) async {
                                setState(() => selectedOrderId = v);
                                await _loadExpenses();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Add Expense Form
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.add_circle,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'إضافة مصروف جديد',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _titleCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'البند',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.title),
                                    ),
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'مطلوب'
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _amountCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'القيمة (ج.م)',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.attach_money),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      final n = double.tryParse(v ?? '');
                                      if (n == null || n < 0)
                                        return 'قيمة غير صالحة';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _noteCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'ملاحظة (اختياري)',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.note),
                                    ),
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _addExpense,
                                      icon: const Icon(Icons.add),
                                      label: const Text('إضافة مصروف'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
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
                    const SizedBox(height: 16),

                    // Expenses List Header
                    Row(
                      children: [
                        Icon(Icons.list, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'قائمة المصروفات',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${expenses.length} مصروف',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Expenses List
                    Expanded(
                      child: expenses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد مصروفات',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'اختر طلباً وأضف مصروفات له',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: expenses.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final e = expenses[i];
                                return Card(
                                  elevation: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red[50],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.money_off,
                                            color: Colors.red[600],
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                e['title'] ?? 'مصروف غير معروف',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (e['note'] != null &&
                                                  e['note']
                                                      .toString()
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  e['note'],
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.access_time,
                                                    size: 16,
                                                    color: Colors.grey[500],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _formatDate(e['createdAt']),
                                                    style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red[100],
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            'ج.م ${e['amount']?.toString() ?? '0'}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red[700],
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'غير معروف';
    try {
      final DateTime dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'تاريخ غير صحيح';
    }
  }
}
