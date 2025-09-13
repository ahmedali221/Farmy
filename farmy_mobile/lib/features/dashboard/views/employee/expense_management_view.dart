import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/employee_expense_api_service.dart';
import '../../../../features/authentication/services/token_service.dart';
import '../../../../core/theme/app_theme.dart';

class ExpenseManagementView extends StatefulWidget {
  const ExpenseManagementView({super.key});

  @override
  State<ExpenseManagementView> createState() => _ExpenseManagementViewState();
}

class _ExpenseManagementViewState extends State<ExpenseManagementView> {
  List<Map<String, dynamic>> expenses = [];
  String? employeeId;
  bool loading = true;

  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController(text: '');
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    setState(() => loading = true);
    final tokenService = serviceLocator<TokenService>();
    final user = await tokenService.getUser();
    if (!mounted) return;
    setState(() {
      employeeId = user?.id;
    });
    await _loadExpenses();
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _loadExpenses() async {
    if (employeeId == null) return;
    final expenseService = serviceLocator<EmployeeExpenseApiService>();
    final list = await expenseService.listByEmployee(employeeId!);
    if (!mounted) return;
    setState(() => expenses = list);
  }

  Future<void> _addExpense() async {
    if (!_formKey.currentState!.validate() || employeeId == null) return;
    final expenseService = serviceLocator<EmployeeExpenseApiService>();
    await expenseService.createExpense(
      employeeId!,
      _titleCtrl.text,
      double.parse(_amountCtrl.text),
      note: _noteCtrl.text,
    );
    _titleCtrl.clear();
    _amountCtrl.clear();
    _noteCtrl.text = '';
    await _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          context.go('/employee-dashboard');
        }
      },
      child: Theme(
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
                : RefreshIndicator(
                    onRefresh: _loadExpenses,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Employee personal expenses form
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _titleCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'اسم المصروف',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.right,
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? 'مطلوب' : null,
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _amountCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'القيمة (ج.م)',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.right,
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
                                    alignLabelWithHint: true,
                                  ),
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.receipt_long,
                                          size: 64,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.7),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'لا توجد مصروفات مسجلة بعد',
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
                                          'أضف مصروفاتك باستخدام النموذج بالأعلى',
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
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        elevation: 2,
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .error
                                                .withOpacity(0.15),
                                            child: Icon(
                                              Icons.money_off,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                              size: 20,
                                            ),
                                          ),
                                          title: Text(
                                            e['name']?.toString() ?? 'مصروف',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                e['createdAt']
                                                        ?.toString()
                                                        .split('T')
                                                        .first ??
                                                    '',
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
                                              ),
                                              if ((e['note']
                                                      ?.toString()
                                                      .trim()
                                                      .isNotEmpty ??
                                                  false))
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Text(
                                                    e['note'],
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withOpacity(
                                                                    0.7,
                                                                  ),
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error
                                                  .withOpacity(0.07),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'EGP ${e['value']?.toString() ?? '0'}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 20,
                                                  ),
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                                  tooltip: 'حذف',
                                                  onPressed: () async {
                                                    final id = e['_id']
                                                        ?.toString();
                                                    if (id == null) return;
                                                    final expenseService =
                                                        serviceLocator<
                                                          EmployeeExpenseApiService
                                                        >();
                                                    await expenseService
                                                        .deleteExpense(id);
                                                    await _loadExpenses();
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          isThreeLine: false,
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
        ),
      ),
    );
  }
}
