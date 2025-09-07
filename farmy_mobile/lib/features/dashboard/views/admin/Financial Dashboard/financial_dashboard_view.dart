import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/services/expense_api_service.dart';
import '../../../../../core/services/order_api_service.dart';
import '../../../../../core/services/inventory_api_service.dart';
import '../../../../../core/services/payment_api_service.dart';

class FinancialDashboardView extends StatefulWidget {
  const FinancialDashboardView({super.key});

  @override
  State<FinancialDashboardView> createState() => _FinancialDashboardViewState();
}

class _FinancialDashboardViewState extends State<FinancialDashboardView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> dailyReports = [];
  List<dynamic> orders = [];
  List<dynamic> employees = [];
  Map<String, List<dynamic>> expensesByOrder = {};
  Map<String, dynamic> paymentSummaryByOrder = {};
  Map<String, List<dynamic>> paymentsByOrder = {};
  bool isLoading = true;
  List<Map<String, dynamic>> otherExpenses = [];
  final String baseUrl =
      'https://farmy-3b980tcc5-ahmed-alis-projects-588ffe47.vercel.app/api';
  late final ExpenseApiService _expenseService;
  late final OrderApiService _orderService;
  late final InventoryApiService _inventoryService;
  late final PaymentApiService _paymentService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _expenseService = serviceLocator<ExpenseApiService>();
    _orderService = serviceLocator<OrderApiService>();
    _inventoryService = serviceLocator<InventoryApiService>();
    _paymentService = serviceLocator<PaymentApiService>();
    _loadFinancialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFinancialData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([_loadDailyReports(), _loadOrders(), _loadEmployees()]);
      await _loadOrderDetails();
      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('فشل في تحميل البيانات المالية: $e');
    }
  }

  Future<void> _loadDailyReports() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/finances/daily'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        dailyReports = json.decode(response.body);
      }
    } catch (e) {
      print('Error loading daily reports: $e');
    }
  }

  Future<void> _loadOrders() async {
    try {
      final ordersList = await _orderService.getAllOrders();
      orders = ordersList;
      // Debug: Print first order to see structure
      if (orders.isNotEmpty) {}
    } catch (e) {
      print('Error loading orders: $e');
      orders = []; // Set empty list on error
    }
  }

  Future<void> _loadEmployees() async {
    try {
      print('Loading employee users...'); // Debug log
      final response = await http.get(
        Uri.parse('$baseUrl/employees/users'),
        headers: await _authHeaders(),
      );
      print(
        'Employee users response status: ${response.statusCode}',
      ); // Debug log
      if (response.statusCode == 200) {
        employees = json.decode(response.body);
        print('Loaded ${employees.length} employee users'); // Debug log
        print('Employee users: $employees'); // Debug log
      } else {
        print(
          'Failed to load employee users: ${response.statusCode} - ${response.body}',
        ); // Debug log
      }
    } catch (e) {
      print('Error loading employee users: $e');
    }
  }

  Future<void> _loadOrderDetails() async {
    try {
      final List<Future<void>> futures = [];
      for (final o in orders) {
        final String? id = o['_id']?.toString();
        if (id == null) continue;
        futures.add(_fetchExpensesForOrder(id));
        futures.add(_fetchPaymentSummaryForOrder(id));
        futures.add(_fetchPaymentsForOrder(id));
      }
      await Future.wait(futures);
      print(
        'Loaded expenses for ${expensesByOrder.length} orders',
      ); // Debug log
      print(
        'Loaded payments for ${paymentsByOrder.length} orders',
      ); // Debug log
      print('Expenses by order: $expensesByOrder'); // Debug log
    } catch (e) {
      print('Error loading order details: $e');
    }
  }

  Future<void> _fetchExpensesForOrder(String orderId) async {
    try {
      print('Fetching expenses for order: $orderId'); // Debug log
      final expenses = await _expenseService.getExpensesByOrder(orderId);
      print(
        'Found ${expenses.length} expenses for order $orderId',
      ); // Debug log
      expensesByOrder[orderId] = expenses;
    } catch (e) {
      print('Error loading expenses for order $orderId: $e');
      // Set empty list to avoid null issues
      expensesByOrder[orderId] = [];
    }
  }

  Future<void> _fetchPaymentSummaryForOrder(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payments/summary/$orderId'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        paymentSummaryByOrder[orderId] = json.decode(response.body);
      }
    } catch (e) {
      print('Error loading payment summary for order $orderId: $e');
    }
  }

  Future<void> _fetchPaymentsForOrder(String orderId) async {
    try {
      print('Fetching payments for order: $orderId'); // Debug log
      final payments = await _paymentService.getPaymentsByOrder(orderId);
      print(
        'Found ${payments.length} payments for order $orderId',
      ); // Debug log
      paymentsByOrder[orderId] = payments;
    } catch (e) {
      print('Error loading payments for order $orderId: $e');
      // Set empty list to avoid null issues
      paymentsByOrder[orderId] = [];
    }
  }

  void _showCreateFinancialRecordDialog() {
    showDialog(
      context: context,
      builder: (context) => _FinancialRecordFormDialog(
        employees: employees,
        onSave: _createFinancialRecord,
      ),
    );
  }

  Future<void> _createFinancialRecord(Map<String, dynamic> recordData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/finances'),
        headers: await _authHeaders(),
        body: json.encode(recordData),
      );
      if (response.statusCode == 201) {
        _showSuccessDialog('تم إنشاء السجل المالي بنجاح');
        _loadDailyReports();
      }
    } catch (e) {
      _showErrorDialog('فشل في إنشاء السجل المالي: $e');
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final headers = await _expenseService.getHeaders();
    print('Auth headers: $headers'); // Debug log
    return headers;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/admin-dashboard');
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('لوحة المعلومات المالية'),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/admin-dashboard'),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showCreateFinancialRecordDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadFinancialData,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'التقارير اليومية', icon: Icon(Icons.today)),
                Tab(text: 'الخزنة', icon: Icon(Icons.account_balance)),
                Tab(text: 'مالية الموظفين', icon: Icon(Icons.people)),
              ],
            ),
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDailyReportsTab(),
                    _buildTreasuryTab(),
                    _buildEmployeeFinanceTab(),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showCreateFinancialRecordDialog,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyReportsTab() {
    if (orders.isEmpty) {
      return _buildEmptyState(
        Icons.bar_chart,
        'لا توجد طلبات',
        'لم يتم العثور على أي طلبات لعرض التقارير',
      );
    }

    // Aggregate from orders
    final int totalOrders = orders.length;
    final double totalRevenue = orders.fold(
      0.0,
      (sum, o) => sum + _orderTotalPrice(o),
    );

    final Map<String, Map<String, dynamic>> daily = {};
    for (final o in orders) {
      final String key = _dateKey(o['orderDate']);
      final double revenue = _orderTotalPrice(o);
      if (!daily.containsKey(key)) {
        daily[key] = {'date': key, 'orders': 0, 'revenue': 0.0};
      }
      daily[key]!['orders'] = (daily[key]!['orders'] as int) + 1;
      daily[key]!['revenue'] = (daily[key]!['revenue'] as double) + revenue;
    }

    final List<Map<String, dynamic>> dailyList = daily.values.toList()
      ..sort((a, b) {
        // sort by date desc
        DateTime da = _parseDateKey(a['date']);
        DateTime db = _parseDateKey(b['date']);
        return db.compareTo(da);
      });

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.indigo, Colors.indigo.withOpacity(0.8)],
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.today, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                const Text(
                  'التقارير اليومية',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ملخص الطلبات والإيرادات حسب التاريخ',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Summary Cards
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملخص عام',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedTreasuryCard(
                        'إجمالي الطلبات',
                        totalOrders.toString(),
                        Icons.shopping_cart,
                        Colors.blue,
                        'عدد الطلبات الإجمالي',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEnhancedTreasuryCard(
                        'إجمالي الإيرادات',
                        'EGP ${totalRevenue.toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.green,
                        'إجمالي المبالغ المحصلة',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Daily Reports Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        color: Colors.indigo,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'التقارير اليومية',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...dailyList
                    .map((item) => _buildDailyReportCard(item))
                    .toList(),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTreasuryTab() {
    // Calculate total money collected by all employees based on paid amounts
    double totalMoneyCollected = 0.0;
    Map<String, double> employeeMoney = {};

    for (final employee in employees) {
      final String employeeId = employee['_id'] ?? '';
      double employeeTotal = 0.0;

      // Find orders for this employee by checking payments
      for (final order in orders) {
        final String? orderId = order['_id']?.toString();
        if (orderId != null) {
          final List<dynamic> orderPayments = paymentsByOrder[orderId] ?? [];
          // Check if any payment for this order belongs to this employee
          final bool hasEmployeePayment = orderPayments.any(
            (payment) => payment['employee']?['_id'] == employeeId,
          );
          if (hasEmployeePayment) {
            // Sum up all paid amounts for this employee in this order
            final double orderPaidAmount = orderPayments
                .where((payment) => payment['employee']?['_id'] == employeeId)
                .fold(
                  0.0,
                  (sum, payment) =>
                      sum + ((payment['paidAmount'] ?? 0) as num).toDouble(),
                );
            employeeTotal += orderPaidAmount;
          }
        }
      }

      employeeMoney[employeeId] = employeeTotal;
      totalMoneyCollected += employeeTotal;
    }

    // Calculate total other expenses
    double totalOtherExpenses = otherExpenses.fold(0.0, (sum, expense) {
      return sum + (expense['value'] ?? 0.0);
    });

    // Calculate treasury total
    double treasuryTotal = totalMoneyCollected - totalOtherExpenses;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.account_balance,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                const Text(
                  'الخزنة المالية',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'إجمالي الأموال المحصلة والمصاريف',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Summary Cards Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملخص مالي',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedTreasuryCard(
                        'إجمالي التحصيل',
                        'EGP ${totalMoneyCollected.toStringAsFixed(2)}',
                        Icons.trending_up,
                        Colors.green,
                        'المبلغ الإجمالي المحصل من جميع الموظفين',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEnhancedTreasuryCard(
                        'المصاريف الأخرى',
                        'EGP ${totalOtherExpenses.toStringAsFixed(2)}',
                        Icons.trending_down,
                        Colors.red,
                        'المصاريف الإضافية المضافة يدوياً',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildEnhancedTreasuryCard(
                  'إجمالي الخزنة',
                  'EGP ${treasuryTotal.toStringAsFixed(2)}',
                  Icons.account_balance_wallet,
                  Colors.blue,
                  'الرصيد النهائي بعد خصم المصاريف',
                  isMain: true,
                ),
              ],
            ),
          ),

          // Employee Collection Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.people,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'تحصيل الموظفين',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (employees.isEmpty)
                  _buildEmptyState(
                    Icons.people_outline,
                    'لا يوجد موظفين',
                    'لم يتم العثور على أي موظفين في النظام',
                  )
                else
                  ...employees.map((employee) {
                    final String employeeId = employee['_id'] ?? '';
                    final double employeeTotal =
                        employeeMoney[employeeId] ?? 0.0;
                    return _buildEmployeeCollectionCard(
                      employee,
                      employeeTotal,
                    );
                  }).toList(),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Other Expenses Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.money_off,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'مصاريف أخرى',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _addOtherExpense,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة مصروف'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (otherExpenses.isEmpty)
                  _buildEmptyState(
                    Icons.money_off_outlined,
                    'لا توجد مصاريف أخرى',
                    'اضغط على "إضافة مصروف" لإضافة مصاريف جديدة',
                  )
                else
                  ...otherExpenses.asMap().entries.map((entry) {
                    final index = entry.key;
                    final expense = entry.value;
                    return _buildOtherExpenseCard(expense, index);
                  }).toList(),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmployeeFinanceTab() {
    if (employees.isEmpty) {
      return _buildEmptyState(
        Icons.people_outline,
        'لا توجد بيانات للموظفين',
        'لم يتم العثور على أي موظفين في النظام',
      );
    }

    if (orders.isEmpty) {
      return _buildEmptyState(
        Icons.shopping_cart_outlined,
        'لا توجد طلبات',
        'الطلبات مطلوبة لعرض مصروفات الموظفين',
      );
    }

    // Calculate total expenses across all employees
    double totalEmployeeExpenses = 0.0;
    int totalOrders = 0;
    print(
      'Processing ${employees.length} employees and ${orders.length} orders',
    ); // Debug log

    for (final employee in employees) {
      final String employeeId = employee['_id'] ?? '';
      print(
        'Processing employee: ${employee['username']} (ID: $employeeId)',
      ); // Debug log

      // Find orders for this employee by checking payments
      final List<dynamic> employeeOrders = [];
      for (final order in orders) {
        final String? orderId = order['_id']?.toString();
        if (orderId != null) {
          final List<dynamic> orderPayments = paymentsByOrder[orderId] ?? [];
          // Check if any payment for this order belongs to this employee
          final bool hasEmployeePayment = orderPayments.any(
            (payment) => payment['employee']?['_id'] == employeeId,
          );
          if (hasEmployeePayment) {
            employeeOrders.add(order);
          }
        }
      }

      print(
        'Found ${employeeOrders.length} orders for employee ${employee['username']}',
      ); // Debug log

      totalOrders += employeeOrders.length;
      totalEmployeeExpenses += employeeOrders.fold(0.0, (sum, o) {
        final String? id = o['_id']?.toString();
        final List<dynamic> list = id != null
            ? (expensesByOrder[id] ?? [])
            : [];
        return sum +
            list.fold(
              0.0,
              (s, e) => s + ((e['amount'] ?? 0) as num).toDouble(),
            );
      });
    }

    return Column(
      children: [
        // Summary cards
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildSummaryListTile(
                'إجمالي الموظفين',
                employees.length.toString(),
                Icons.people,
                Colors.blue,
              ),
              _buildSummaryListTile(
                'إجمالي الطلبات',
                totalOrders.toString(),
                Icons.shopping_cart,
                Colors.green,
              ),
              _buildSummaryListTile(
                'إجمالي المصروفات',
                'EGP ${totalEmployeeExpenses.toStringAsFixed(2)}',
                Icons.money_off,
                Colors.red,
              ),
              _buildSummaryListTile(
                'المتوسط لكل طلب',
                totalOrders > 0
                    ? 'EGP ${(totalEmployeeExpenses / totalOrders).toStringAsFixed(2)}'
                    : 'EGP 0.00',
                Icons.calculate,
                Colors.orange,
              ),
            ],
          ),
        ),
        // Employee list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final employee = employees[index];
              return _buildEmployeeCard(employee);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryListTile(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(dynamic employee) {
    final String employeeId = employee['_id'] ?? '';

    // Find orders for this employee by checking payments
    final List<dynamic> employeeOrders = [];
    for (final order in orders) {
      final String? orderId = order['_id']?.toString();
      if (orderId != null) {
        final List<dynamic> orderPayments = paymentsByOrder[orderId] ?? [];
        // Check if any payment for this order belongs to this employee
        final bool hasEmployeePayment = orderPayments.any(
          (payment) => payment['employee']?['_id'] == employeeId,
        );
        if (hasEmployeePayment) {
          employeeOrders.add(order);
        }
      }
    }

    // Calculate employee totals based on paid amounts
    final double employeeRevenue = employeeOrders.fold(0.0, (sum, o) {
      final String? orderId = o['_id']?.toString();
      if (orderId != null) {
        final List<dynamic> orderPayments = paymentsByOrder[orderId] ?? [];
        return sum +
            orderPayments
                .where((payment) => payment['employee']?['_id'] == employeeId)
                .fold(
                  0.0,
                  (paymentSum, payment) =>
                      paymentSum +
                      ((payment['paidAmount'] ?? 0) as num).toDouble(),
                );
      }
      return sum;
    });
    final double employeeExpenses = employeeOrders.fold(0.0, (sum, o) {
      final String? id = o['_id']?.toString();
      final List<dynamic> list = id != null ? (expensesByOrder[id] ?? []) : [];
      return sum +
          list.fold(0.0, (s, e) => s + ((e['amount'] ?? 0) as num).toDouble());
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            employee['username']?.substring(0, 1).toUpperCase() ?? 'E',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          employee['username'] ?? 'موظف غير معروف',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${employeeOrders.length} طلبات • EGP ${employeeExpenses.toStringAsFixed(2)} مصروفات',
        ),
        trailing: employeeOrders.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () => _navigateToEmployeeOrders(
                  context,
                  employee,
                  employeeOrders,
                ),
                tooltip: 'عرض جميع الطلبات',
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employee stats
                _buildEmployeeStatListTile(
                  'الطلبات',
                  employeeOrders.length.toString(),
                  Icons.shopping_cart,
                  Colors.blue,
                ),
                _buildEmployeeStatListTile(
                  'الإيرادات',
                  'EGP ${employeeRevenue.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.green,
                ),
                _buildEmployeeStatListTile(
                  'المصروفات',
                  'EGP ${employeeExpenses.toStringAsFixed(2)}',
                  Icons.money_off,
                  Colors.red,
                ),
                const SizedBox(height: 16),
                // Orders and expenses breakdown
                Text(
                  'الطلبات والمصروفات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...employeeOrders
                    .map((order) => _buildOrderExpenseCard(order))
                    .toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderExpenseCard(dynamic order) {
    final String? orderId = order['_id']?.toString();
    final List<dynamic> orderExpenses = orderId != null
        ? (expensesByOrder[orderId] ?? [])
        : [];
    final List<dynamic> orderPayments = orderId != null
        ? (paymentsByOrder[orderId] ?? [])
        : [];
    final double orderRevenue = orderPayments.fold(
      0.0,
      (sum, payment) => sum + ((payment['paidAmount'] ?? 0) as num).toDouble(),
    );
    final double orderExpenseTotal = orderExpenses.fold(
      0.0,
      (sum, e) => sum + ((e['amount'] ?? 0) as num).toDouble(),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getOrderStatusColor(order['status']),
          child: Icon(
            _getOrderStatusIcon(order['status']),
            color: Colors.white,
            size: 16,
          ),
        ),
        title: Text(
          'طلب رقم #${orderId?.substring(0, 8) ?? 'غير معروف'}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${order['customer']?['name'] ?? 'غير معروف'} • ${order['chickenType']?['name'] ?? 'دجاج'} • الكمية: ${order['quantity'] ?? 0}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'EGP ${orderRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (orderExpenseTotal > 0)
                  Text(
                    'مصروفات: ${orderExpenseTotal.toStringAsFixed(2)} جنيه',
                    style: const TextStyle(color: Colors.red, fontSize: 10),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.visibility, size: 16),
              onPressed: () =>
                  _navigateToOrderDetail(context, order, orderExpenses),
              tooltip: 'عرض تفاصيل الطلب',
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 16),
              onPressed: () => _showOrderStatusDialog(
                orderId!,
                order['status'] ?? 'pending',
              ),
              tooltip: 'تحديث حالة الطلب',
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order details
                _buildOrderDetailListTile(
                  'الإيرادات',
                  'EGP ${orderRevenue.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.green,
                ),
                _buildOrderDetailListTile(
                  'المصروفات',
                  'EGP ${orderExpenseTotal.toStringAsFixed(2)}',
                  Icons.money_off,
                  Colors.red,
                ),
                _buildOrderDetailListTile(
                  'Net',
                  'EGP ${(orderRevenue - orderExpenseTotal).toStringAsFixed(2)}',
                  Icons.account_balance,
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                // Expenses list
                if (orderExpenses.isNotEmpty) ...[
                  Text(
                    'Expense Details',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...orderExpenses
                      .map((expense) => _buildExpenseItem(expense))
                      .toList(),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'No expenses recorded for this order',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailListTile(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          radius: 14,
          child: Icon(icon, color: color, size: 14),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        dense: true,
      ),
    );
  }

  Widget _buildExpenseItem(dynamic expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.money_off, color: Colors.red[600], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense['title'] ?? 'Unknown Expense',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                if (expense['note'] != null &&
                    expense['note'].toString().isNotEmpty)
                  Text(
                    expense['note'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
              ],
            ),
          ),
          Text(
            'EGP ${expense['amount']?.toString() ?? '0'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTreasuryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String description, {
    bool isMain = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isMain ? color.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMain ? color : color.withOpacity(0.3),
          width: isMain ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isMain ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: isMain ? color : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: isMain ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCollectionCard(dynamic employee, double total) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    employee['username']?.substring(0, 1).toUpperCase() ?? 'E',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee['username'] ?? 'موظف غير معروف',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إجمالي التحصيل',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'EGP ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherExpenseCard(Map<String, dynamic> expense, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.money_off, color: Colors.red, size: 20),
          ),
          title: Text(
            expense['name'] ?? 'مصروف غير معروف',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'EGP ${(expense['value'] ?? 0.0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => _removeOtherExpense(index),
                tooltip: 'حذف المصروف',
                color: Colors.red[400],
              ),
            ],
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

  Widget _buildDailyReportCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.indigo, Colors.indigo.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(Icons.today, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تقرير يومي - ${item['date']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الطلبات: ${item['orders']}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'EGP ${(item['revenue'] as double).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeStatListTile(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          radius: 16,
          child: Icon(icon, color: color, size: 16),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        dense: true,
      ),
    );
  }

  // Helpers to compute money from orders and group by date
  double _orderRevenue(dynamic order) {
    try {
      final double quantity = ((order['quantity'] ?? 0) as num).toDouble();
      final double price = ((order['chickenType']?['price'] ?? 0) as num)
          .toDouble();
      return quantity * price;
    } catch (_) {
      return 0.0;
    }
  }

  // Prefer backend payment summary when available
  double _orderTotalPrice(dynamic order) {
    try {
      final String? id = order['_id']?.toString();
      final dynamic summary = id != null ? paymentSummaryByOrder[id] : null;
      if (summary != null && summary is Map<String, dynamic>) {
        final num? total = summary['totalPrice'] as num?;
        if (total != null) return total.toDouble();
      }
    } catch (_) {}
    return _orderRevenue(order);
  }

  String _dateKey(dynamic date) {
    final dt = _safeParseDate(date);
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  DateTime _parseDateKey(String key) {
    try {
      final parts = key.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]) ?? 1;
        final month = int.tryParse(parts[1]) ?? 1;
        final year = int.tryParse(parts[2]) ?? 1970;
        return DateTime(year, month, day);
      }
      return DateTime(1970);
    } catch (_) {
      return DateTime(1970);
    }
  }

  DateTime _safeParseDate(dynamic date) {
    try {
      return DateTime.parse(date.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  Color _getOrderStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getOrderStatusIcon(String? status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نجح'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خطأ'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _navigateToEmployeeOrders(
    BuildContext context,
    Map<String, dynamic> employee,
    List<dynamic> employeeOrders,
  ) {
    context.push(
      '/employee-orders',
      extra: {
        'employee': employee,
        'orders': employeeOrders,
        'expensesByOrder': expensesByOrder,
      },
    );
  }

  void _navigateToOrderDetail(
    BuildContext context,
    Map<String, dynamic> order,
    List<dynamic> orderExpenses,
  ) {
    context.push(
      '/order-detail',
      extra: {
        'order': order,
        'expenses': orderExpenses,
        'paymentSummary': paymentSummaryByOrder[order['_id']?.toString()],
      },
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      // Get the order details first
      final order = orders.firstWhere((o) => o['_id'] == orderId);
      final String? chickenTypeId = order['chickenType']?['_id'];
      final int quantity = order['quantity'] ?? 0;
      final String currentStatus = order['status'] ?? 'pending';

      // Update order status
      await _orderService.updateOrderStatus(orderId, newStatus);

      // Handle inventory changes based on status transition
      if (chickenTypeId != null && quantity > 0) {
        if (currentStatus == 'pending' && newStatus == 'delivered') {
          // Order approved - decrease inventory
          await _decreaseInventoryStock(chickenTypeId, quantity);
        } else if (currentStatus == 'pending' && newStatus == 'cancelled') {
          // Order declined - increase inventory (if it was previously decreased)
          // Note: This assumes the order was never processed before
          // In a real scenario, you might want to track if inventory was already decreased
        } else if (currentStatus == 'delivered' && newStatus == 'cancelled') {
          // Order cancelled after delivery - increase inventory
          await _increaseInventoryStock(chickenTypeId, quantity);
        } else if (currentStatus == 'cancelled' && newStatus == 'delivered') {
          // Order re-approved - decrease inventory
          await _decreaseInventoryStock(chickenTypeId, quantity);
        }
      }

      _showSuccessDialog('تم تحديث حالة الطلب بنجاح');
      _loadFinancialData(); // Reload data to reflect changes
    } catch (e) {
      _showErrorDialog('فشل في تحديث حالة الطلب: $e');
    }
  }

  Future<void> _decreaseInventoryStock(
    String chickenTypeId,
    int quantity,
  ) async {
    try {
      final chickenType = await _inventoryService.getChickenTypeById(
        chickenTypeId,
      );
      if (chickenType != null) {
        final int currentStock = chickenType['stock'] ?? 0;
        final int newStock = currentStock - quantity;
        if (newStock >= 0) {
          await _inventoryService.updateChickenType(chickenTypeId, {
            'stock': newStock,
          });
        }
      }
    } catch (e) {
      print('Error decreasing inventory stock: $e');
    }
  }

  Future<void> _increaseInventoryStock(
    String chickenTypeId,
    int quantity,
  ) async {
    try {
      final chickenType = await _inventoryService.getChickenTypeById(
        chickenTypeId,
      );
      if (chickenType != null) {
        final int currentStock = chickenType['stock'] ?? 0;
        final int newStock = currentStock + quantity;
        await _inventoryService.updateChickenType(chickenTypeId, {
          'stock': newStock,
        });
      }
    } catch (e) {
      print('Error increasing inventory stock: $e');
    }
  }

  void _showOrderStatusDialog(String orderId, String currentStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحديث حالة الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الحالة الحالية: ${_getOrderStatusArabic(currentStatus)}'),
            const SizedBox(height: 16),
            const Text('اختر الحالة الجديدة:'),
            const SizedBox(height: 8),
            ...['pending', 'delivered', 'cancelled']
                .map(
                  (status) => ListTile(
                    leading: Radio<String>(
                      value: status,
                      groupValue: currentStatus,
                      onChanged: (value) {
                        Navigator.of(context).pop();
                        if (value != null && value != currentStatus) {
                          _updateOrderStatus(orderId, value);
                        }
                      },
                    ),
                    title: Text(_getOrderStatusArabic(status)),
                    subtitle: Text(_getStatusDescription(status)),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (status != currentStatus) {
                        _updateOrderStatus(orderId, status);
                      }
                    },
                  ),
                )
                .toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  String _getOrderStatusArabic(String? status) {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'pending':
        return 'الطلب في انتظار الموافقة';
      case 'delivered':
        return 'تمت الموافقة على الطلب وتسليمه';
      case 'cancelled':
        return 'تم إلغاء الطلب';
      default:
        return '';
    }
  }

  void _addOtherExpense() {
    showDialog(
      context: context,
      builder: (context) => _OtherExpenseDialog(
        onSave: (expense) {
          setState(() {
            otherExpenses.add(expense);
          });
        },
      ),
    );
  }

  void _removeOtherExpense(int index) {
    setState(() {
      otherExpenses.removeAt(index);
    });
  }
}

class _FinancialRecordFormDialog extends StatefulWidget {
  final List<dynamic> employees;
  final Function(Map<String, dynamic>) onSave;

  const _FinancialRecordFormDialog({
    required this.employees,
    required this.onSave,
  });

  @override
  State<_FinancialRecordFormDialog> createState() =>
      _FinancialRecordFormDialogState();
}

class _FinancialRecordFormDialogState
    extends State<_FinancialRecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _revenueController = TextEditingController();
  final _expensesController = TextEditingController();
  final _debtsController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String selectedType = 'daily';
  String? selectedEmployeeId;

  @override
  void dispose() {
    _revenueController.dispose();
    _expensesController.dispose();
    _debtsController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final revenue = double.tryParse(_revenueController.text) ?? 0;
      final expenses = double.tryParse(_expensesController.text) ?? 0;
      final recordData = {
        'date': selectedDate.toIso8601String(),
        'type': selectedType,
        'revenue': revenue,
        'expenses': expenses,
        'netProfit': revenue - expenses,
        'outstandingDebts': double.tryParse(_debtsController.text) ?? 0,
        if (selectedEmployeeId != null) 'employee': selectedEmployeeId,
      };
      widget.onSave(recordData);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إنشاء سجل مالي'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'نوع السجل',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('يومي')),
                  DropdownMenuItem(value: 'monthly', child: Text('شهري')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (widget.employees.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedEmployeeId,
                  decoration: const InputDecoration(
                    labelText: 'الموظف (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.employees.map<DropdownMenuItem<String>>((
                    employee,
                  ) {
                    return DropdownMenuItem<String>(
                      value: employee['_id'],
                      child: Text(employee['username'] ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedEmployeeId = value;
                    });
                  },
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _revenueController,
                decoration: const InputDecoration(
                  labelText: 'الإيرادات (جنيه مصري)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الإيرادات مطلوبة';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) < 0) {
                    return 'يرجى إدخال مبلغ إيرادات صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _expensesController,
                decoration: const InputDecoration(
                  labelText: 'المصروفات (جنيه مصري)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'المصروفات مطلوبة';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) < 0) {
                    return 'يرجى إدخال مبلغ مصروفات صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _debtsController,
                decoration: const InputDecoration(
                  labelText: 'الديون المستحقة (جنيه مصري)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (double.tryParse(value) == null ||
                        double.parse(value) < 0) {
                      return 'يرجى إدخال مبلغ دين صحيح';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('إنشاء')),
      ],
    );
  }
}

class _OtherExpenseDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const _OtherExpenseDialog({required this.onSave});

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

  void _save() {
    if (_formKey.currentState!.validate()) {
      final expense = {
        'name': _nameController.text.trim(),
        'value': double.tryParse(_valueController.text) ?? 0.0,
      };
      widget.onSave(expense);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مصروف آخر'),
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
                hintText: 'مثال: البنزين، الكهرباء، إلخ',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'اسم المصروف مطلوب';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'قيمة المصروف (جنيه مصري)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'قيمة المصروف مطلوبة';
                }
                if (double.tryParse(value) == null || double.parse(value) < 0) {
                  return 'يرجى إدخال قيمة صحيحة';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('إضافة')),
      ],
    );
  }
}
