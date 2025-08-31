import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  bool isLoading = true;
  final String baseUrl = 'http://localhost:3000/api';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Failed to load financial data: $e');
    }
  }

  Future<void> _loadDailyReports() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/finances/daily'),
        headers: {'Content-Type': 'application/json'},
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
      final response = await http.get(
        Uri.parse('$baseUrl/orders'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        orders = json.decode(response.body);
      }
    } catch (e) {
      print('Error loading orders: $e');
    }
  }

  Future<void> _loadEmployees() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/employees'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        employees = json.decode(response.body);
      }
    } catch (e) {
      print('Error loading employees: $e');
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
        headers: {'Content-Type': 'application/json'},
        body: json.encode(recordData),
      );
      if (response.statusCode == 201) {
        _showSuccessDialog('Financial record created successfully');
        _loadDailyReports();
      }
    } catch (e) {
      _showErrorDialog('Failed to create financial record: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
            Tab(text: 'Daily Reports', icon: Icon(Icons.today)),
            Tab(text: 'Orders', icon: Icon(Icons.shopping_cart)),
            Tab(text: 'Employee Finance', icon: Icon(Icons.people)),
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
    );
  }

  Widget _buildDailyReportsTab() {
    if (dailyReports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No daily reports found', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    // Calculate totals
    double totalRevenue = dailyReports.fold(
      0.0,
      (sum, report) => sum + (report['revenue'] ?? 0),
    );
    double totalExpenses = dailyReports.fold(
      0.0,
      (sum, report) => sum + (report['expenses'] ?? 0),
    );
    double totalProfit = totalRevenue - totalExpenses;
    double totalDebts = dailyReports.fold(
      0.0,
      (sum, report) => sum + (report['outstandingDebts'] ?? 0),
    );

    return Column(
      children: [
        // Summary Cards
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildFinancialSummaryCard(
                      'Total Revenue',
                      '₹${totalRevenue.toStringAsFixed(2)}',
                      Icons.trending_up,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFinancialSummaryCard(
                      'Total Expenses',
                      '₹${totalExpenses.toStringAsFixed(2)}',
                      Icons.trending_down,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFinancialSummaryCard(
                      'Net Profit',
                      '₹${totalProfit.toStringAsFixed(2)}',
                      Icons.account_balance_wallet,
                      totalProfit >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFinancialSummaryCard(
                      'Outstanding Debts',
                      '₹${totalDebts.toStringAsFixed(2)}',
                      Icons.warning,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Reports List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: dailyReports.length,
            itemBuilder: (context, index) {
              final report = dailyReports[index];
              final netProfit =
                  (report['revenue'] ?? 0) - (report['expenses'] ?? 0);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: netProfit >= 0 ? Colors.green : Colors.red,
                    child: Icon(
                      netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    'Daily Report - ${_formatDate(report['date'])}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Revenue: ₹${report['revenue'] ?? 0}'),
                      Text('Expenses: ₹${report['expenses'] ?? 0}'),
                      Text(
                        'Net Profit: ₹${netProfit.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: netProfit >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
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

  Widget _buildOrdersTab() {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No orders found', style: TextStyle(fontSize: 18)),
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
                      'Total Orders',
                      totalOrders.toString(),
                      Icons.shopping_cart,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOrderStatCard(
                      'Pending',
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
                      'Delivered',
                      deliveredOrders.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOrderStatCard(
                      'Cancelled',
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
                    'Order #${order['_id']?.substring(0, 8) ?? 'Unknown'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer: ${order['customer']?['name'] ?? 'Unknown'}',
                      ),
                      Text(
                        'Chicken Type: ${order['chickenType']?['name'] ?? 'Unknown'}',
                      ),
                      Text('Quantity: ${order['quantity'] ?? 0}'),
                      Text(
                        'Status: ${order['status']?.toUpperCase() ?? 'UNKNOWN'}',
                        style: TextStyle(
                          color: _getOrderStatusColor(order['status']),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    _formatDate(order['orderDate']),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
            Text('No employee data found', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final employee = employees[index];
        final dailyLogs = employee['dailyLogs'] as List? ?? [];

        // Calculate totals from daily logs
        double totalCollections = dailyLogs.fold(
          0.0,
          (sum, log) => sum + (log['collections'] ?? 0),
        );
        double totalExpenses = dailyLogs.fold(
          0.0,
          (sum, log) => sum + (log['expenses'] ?? 0),
        );
        double totalBalance = dailyLogs.fold(
          0.0,
          (sum, log) => sum + (log['balance'] ?? 0),
        );
        int totalOrdersDelivered = dailyLogs.fold<int>(
          0,
          (sum, log) => sum + (log['ordersDelivered'] as int? ?? 0),
        );
        int totalReceiptsIssued = dailyLogs.fold<int>(
          0,
          (sum, log) => sum + (log['receiptsIssued'] as int? ?? 0),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                employee['name']?.substring(0, 1).toUpperCase() ?? 'E',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              employee['name'] ?? 'Unknown Employee',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Total Balance: ₹${totalBalance.toStringAsFixed(2)} | Orders: $totalOrdersDelivered',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildEmployeeStatCard(
                            'Collections',
                            '₹${totalCollections.toStringAsFixed(2)}',
                            Icons.account_balance_wallet,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEmployeeStatCard(
                            'Expenses',
                            '₹${totalExpenses.toStringAsFixed(2)}',
                            Icons.money_off,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEmployeeStatCard(
                            'Orders Delivered',
                            totalOrdersDelivered.toString(),
                            Icons.delivery_dining,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEmployeeStatCard(
                            'Receipts Issued',
                            totalReceiptsIssued.toString(),
                            Icons.receipt,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    if (dailyLogs.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Recent Daily Logs',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...dailyLogs
                          .take(3)
                          .map(
                            (log) => ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.calendar_today,
                                size: 16,
                              ),
                              title: Text(
                                _formatDate(log['date']),
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                'Collections: ₹${log['collections'] ?? 0} | Balance: ₹${log['balance'] ?? 0}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildEmployeeStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
      title: const Text('Create Financial Record'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Record Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
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
                    labelText: 'Employee (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.employees.map<DropdownMenuItem<String>>((
                    employee,
                  ) {
                    return DropdownMenuItem<String>(
                      value: employee['_id'],
                      child: Text(employee['name'] ?? 'Unknown'),
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
                  labelText: 'Revenue (₹)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Revenue is required';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) < 0) {
                    return 'Please enter a valid revenue amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _expensesController,
                decoration: const InputDecoration(
                  labelText: 'Expenses (₹)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Expenses is required';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) < 0) {
                    return 'Please enter a valid expenses amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _debtsController,
                decoration: const InputDecoration(
                  labelText: 'Outstanding Debts (₹)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (double.tryParse(value) == null ||
                        double.parse(value) < 0) {
                      return 'Please enter a valid debt amount';
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Create')),
      ],
    );
  }
}
