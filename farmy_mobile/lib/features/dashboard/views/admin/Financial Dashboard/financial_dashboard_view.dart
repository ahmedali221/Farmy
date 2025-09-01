import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/services/expense_api_service.dart';
import '../../../../../core/services/order_api_service.dart';
import '../../../../../core/services/inventory_api_service.dart';

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
  bool isLoading = true;
  final String baseUrl =
      'https://farmy-3b980tcc5-ahmed-alis-projects-588ffe47.vercel.app/api';
  late final ExpenseApiService _expenseService;
  late final OrderApiService _orderService;
  late final InventoryApiService _inventoryService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _expenseService = serviceLocator<ExpenseApiService>();
    _orderService = serviceLocator<OrderApiService>();
    _inventoryService = serviceLocator<InventoryApiService>();
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
      }
      await Future.wait(futures);
      print(
        'Loaded expenses for ${expensesByOrder.length} orders',
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
    return Directionality(
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
              Tab(text: 'طلبات العملاء', icon: Icon(Icons.shopping_cart)),
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
                  _buildOrdersTab(),
                  _buildEmployeeFinanceTab(),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreateFinancialRecordDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildDailyReportsTab() {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد طلبات', style: TextStyle(fontSize: 18)),
          ],
        ),
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

    return Column(
      children: [
        // Summary Cards
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildFinancialSummaryCard(
                  'إجمالي الطلبات',
                  totalOrders.toString(),
                  Icons.shopping_cart,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinancialSummaryCard(
                  'إجمالي المال',
                  ' ${totalRevenue.toStringAsFixed(2)} ج.م',
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
            ],
          ),
        ),
        // Daily breakdown
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: dailyList.length,
            itemBuilder: (context, index) {
              final item = dailyList[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.today, color: Colors.white),
                  ),
                  title: Text(
                    'تقرير يومي - ${item['date']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'الطلبات: ${item['orders']}  •  المال: EGP ${(item['revenue'] as double).toStringAsFixed(2)}',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab() {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد طلبات', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    // Calculate order statistics
    int totalOrders = orders.length;
    int pendingOrders = orders
        .where((order) => order['status'] == 'pending')
        .length;
    int deliveredOrders = orders
        .where((order) => order['status'] == 'delivered')
        .length;
    int cancelledOrders = orders
        .where((order) => order['status'] == 'cancelled')
        .length;

    return Column(
      children: [
        // Order Statistics
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildOrderStatCard(
                      'إجمالي الطلبات',
                      totalOrders.toString(),
                      Icons.shopping_cart,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOrderStatCard(
                      'في الانتظار',
                      pendingOrders.toString(),
                      Icons.pending,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildOrderStatCard(
                      'تم التسليم',
                      deliveredOrders.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOrderStatCard(
                      'ملغي',
                      cancelledOrders.toString(),
                      Icons.cancel,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Orders List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getOrderStatusColor(order['status']),
                    child: Icon(
                      _getOrderStatusIcon(order['status']),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    'طلب رقم #${order['_id']?.substring(0, 8) ?? 'غير معروف'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'العميل: ${order['customer']?['name'] ?? 'غير معروف'}',
                      ),
                      Text(
                        'نوع الدجاج: ${order['chickenType']?['name'] ?? 'غير معروف'}',
                      ),
                      Text('الكمية: ${order['quantity'] ?? 0}'),
                      Text(
                        'الحالة: ${_getOrderStatusArabic(order['status'])}',
                        style: TextStyle(
                          color: _getOrderStatusColor(order['status']),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDate(order['orderDate']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 16),
                        onPressed: () {
                          final String? orderId = order['_id']?.toString();
                          final List<dynamic> orderExpenses = orderId != null
                              ? (expensesByOrder[orderId] ?? [])
                              : [];
                          _navigateToOrderDetail(context, order, orderExpenses);
                        },
                        tooltip: 'عرض تفاصيل الطلب',
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeFinanceTab() {
    if (employees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد بيانات للموظفين', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد طلبات', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text(
              'الطلبات مطلوبة لعرض مصروفات الموظفين',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
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

      // Find orders for this employee by checking expenses
      final List<dynamic> employeeOrders = [];
      for (final order in orders) {
        final String? orderId = order['_id']?.toString();
        if (orderId != null) {
          final List<dynamic> orderExpenses = expensesByOrder[orderId] ?? [];
          // Check if any expense for this order belongs to this employee
          final bool hasEmployeeExpense = orderExpenses.any(
            (expense) => expense['employee']?['_id'] == employeeId,
          );
          if (hasEmployeeExpense) {
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

    // Find orders for this employee by checking expenses
    final List<dynamic> employeeOrders = [];
    for (final order in orders) {
      final String? orderId = order['_id']?.toString();
      if (orderId != null) {
        final List<dynamic> orderExpenses = expensesByOrder[orderId] ?? [];
        // Check if any expense for this order belongs to this employee
        final bool hasEmployeeExpense = orderExpenses.any(
          (expense) => expense['employee']?['_id'] == employeeId,
        );
        if (hasEmployeeExpense) {
          employeeOrders.add(order);
        }
      }
    }

    // Calculate employee totals
    final double employeeRevenue = employeeOrders.fold(
      0.0,
      (sum, o) => sum + _orderTotalPrice(o),
    );
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
    final double orderRevenue = _orderTotalPrice(order);
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

  Widget _buildFinancialSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
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

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final DateTime dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Invalid Date';
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
