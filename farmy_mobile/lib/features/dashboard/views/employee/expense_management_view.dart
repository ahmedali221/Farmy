import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/order_api_service.dart';
import '../../../../core/services/expense_api_service.dart';
import '../../../../core/theme/app_theme.dart';

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
    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
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
                      DropdownButtonFormField<String>(
                        value: selectedOrderId,
                        decoration: const InputDecoration(
                          labelText: 'اختر الطلب',
                          border: OutlineInputBorder(),
                        ),
                        items: orders.map<DropdownMenuItem<String>>((o) {
                          final c = o['customer'];
                          final t = o['chickenType'];
                          final q = o['quantity'];
                          return DropdownMenuItem<String>(
                            value: o['_id']?.toString(),
                            child: Text('${c['name']} - ${t['name']} - $q ك'),
                          );
                        }).toList(),
                        onChanged: (String? v) async {
                          setState(() => selectedOrderId = v);
                          await _loadExpenses();
                        },
                      ),
                      const SizedBox(height: 12),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _titleCtrl,
                              decoration: const InputDecoration(
                                labelText: 'البند',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'مطلوب' : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _amountCtrl,
                              decoration: const InputDecoration(
                                labelText: 'القيمة (ج.م)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                if (n == null || n < 0) return 'قيمة غير صالحة';
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _noteCtrl,
                              decoration: const InputDecoration(
                                labelText: 'ملاحظة (اختياري)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _addExpense,
                                child: const Text('إضافة مصروف'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: expenses.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      size: 64,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No expenses recorded yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.7),
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add expenses for the selected order above',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.5),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: expenses.length,
                                itemBuilder: (context, i) {
                                  final e = expenses[i];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 2,
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.error.withOpacity(0.15),
                                        child: Icon(
                                          Icons.money_off,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        e['title'] ?? 'Unknown Expense',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      subtitle:
                                          e['note'] != null &&
                                              e['note'].toString().isNotEmpty
                                          ? Text(
                                              e['note'],
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.7),
                                                    fontSize: 14,
                                                  ),
                                            )
                                          : null,
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error.withOpacity(0.07),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error
                                                .withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          'EGP ${e['amount']?.toString() ?? '0'}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      isThreeLine:
                                          e['note'] != null &&
                                          e['note'].toString().isNotEmpty,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
