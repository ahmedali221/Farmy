import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../authentication/cubit/auth_cubit.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/employee_api_service.dart';
import '../../../../core/services/customer_api_service.dart';
import '../../../../core/services/supplier_api_service.dart';
import '../../../../core/services/inventory_api_service.dart';
import 'distribution_history_view.dart';
import 'loading_history_view.dart';
import 'payment_history_view.dart';
import '../employee/distribution_view.dart';
import '../employee/payment_collection_view.dart';
import '../employee/order_placement_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  Map<String, dynamic> dashboardData = {
    'employees': 0,
    'customers': 0,
    'suppliers': 0,
    'inventoryItems': 0,
    'totalInventoryValue': 0.0,
  };
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);

    try {
      // Load employee count
      final employeeService = serviceLocator<EmployeeApiService>();
      final employees = await employeeService.getAllEmployeeUsers();

      // Load customer count
      final customerService = serviceLocator<CustomerApiService>();
      final customers = await customerService.getAllCustomers();

      // Load supplier count
      final supplierService = serviceLocator<SupplierApiService>();
      final suppliers = await supplierService.getAllSuppliers();

      // Load inventory data
      final inventoryService = serviceLocator<InventoryApiService>();
      final inventoryItems = await inventoryService.getAllChickenTypes();

      // Calculate total inventory value
      double totalValue = 0.0;
      for (var item in inventoryItems) {
        final price = (item['price'] is int)
            ? (item['price'] as int).toDouble()
            : (item['price'] as double);
        final stock = item['stock'] as int;
        totalValue += price * stock;
      }

      if (mounted) {
        setState(() {
          dashboardData = {
            'employees': employees.length,
            'customers': customers.length,
            'suppliers': suppliers.length,
            'inventoryItems': inventoryItems.length,
            'totalInventoryValue': totalValue,
          };
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحميل بيانات لوحة التحكم: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final user = authCubit.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة تحكم المدير'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDashboardData,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showLogoutDialog(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Card(
                elevation: 4,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Colors.blue[700]!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Text(
                            user?.username.substring(0, 1).toUpperCase() ?? 'م',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'مرحباً بك، المدير!',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.username ?? 'المدير',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'مدير النظام',
                                  style: TextStyle(
                                    color: Colors.white,
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
              ),
              const SizedBox(height: 24),

              // History Section
              Text(
                'السجلات والتقارير',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildActionCard(
                    context,
                    'سجل التوزيعات',
                    Icons.outbound,
                    Colors.green,
                    () =>
                        _navigateToHistoryView(const DistributionHistoryView()),
                  ),
                  _buildActionCard(
                    context,
                    'سجل التحميلات',
                    Icons.local_shipping,
                    Colors.blue,
                    () => _navigateToHistoryView(const LoadingHistoryView()),
                  ),
                  _buildActionCard(
                    context,
                    'سجل المدفوعات',
                    Icons.payment,
                    Colors.orange,
                    () => _navigateToHistoryView(const PaymentHistoryView()),
                  ),
                  _buildActionCard(
                    context,
                    'لوحة التحكم المالية',
                    Icons.analytics,
                    Colors.purple,
                    () => context.go('/financial-dashboard'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Section
              Text(
                'إضافة السجلات',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildActionCard(
                    context,
                    'تسجيل التوزيع',
                    Icons.outbound_outlined,
                    Colors.green,
                    () => _navigateToActionView(const DistributionView()),
                  ),
                  _buildActionCard(
                    context,
                    'تحصيل الدفع',
                    Icons.payment_outlined,
                    Colors.orange,
                    () => _navigateToActionView(const PaymentCollectionView()),
                  ),
                  _buildActionCard(
                    context,
                    'تسجيل التحميل',
                    Icons.local_shipping_outlined,
                    Colors.blue,
                    () => _navigateToActionView(const OrderPlacementView()),
                  ),
                  _buildActionCard(
                    context,
                    'إدارة الموظفين',
                    Icons.group,
                    Colors.purple,
                    () => context.go('/employee-management'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Management Section
              Text(
                'الإدارة العامة',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildActionCard(
                    context,
                    'إدارة العملاء',
                    Icons.person,
                    Colors.teal,
                    () => context.go('/customer-management'),
                  ),
                  _buildActionCard(
                    context,
                    'إدارة الموردين',
                    Icons.business,
                    Colors.indigo,
                    () => context.go('/supplier-management'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    String change,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),

            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToHistoryView(Widget historyView) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => historyView,
        fullscreenDialog: false,
      ),
    );
  }

  void _navigateToActionView(Widget actionView) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => actionView,
        fullscreenDialog: false,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<AuthCubit>().logout();
              },
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }
}
