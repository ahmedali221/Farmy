import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/services/customer_api_service.dart';
import '../../../../../core/services/loading_api_service.dart';

class CustomerManagementView extends StatefulWidget {
  const CustomerManagementView({super.key});

  @override
  State<CustomerManagementView> createState() => _CustomerManagementViewState();
}

class _CustomerManagementViewState extends State<CustomerManagementView> {
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> loadingOrders = [];
  bool isLoading = true;
  late final LoadingApiService _loadingService;

  @override
  void initState() {
    super.initState();
    _loadingService = serviceLocator<LoadingApiService>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final customerService = serviceLocator<CustomerApiService>();
      final customersList = await customerService.getAllCustomers();
      final loadingOrdersList = await _loadingService.getAllLoadings();

      setState(() {
        customers = customersList;
        loadingOrders = loadingOrdersList;
      });

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('فشل في تحميل البيانات: $e');
    }
  }

  Future<void> _loadCustomers() async {
    await _loadData();
  }

  Future<void> _deleteCustomer(String id, String name) async {
    final confirmed = await _showConfirmDialog(
      'حذف العميل',
      'هل أنت متأكد من حذف $name؟',
    );
    if (!confirmed) return;

    try {
      final customerService = serviceLocator<CustomerApiService>();
      await customerService.deleteCustomer(id);
      _showSuccessDialog('تم حذف العميل بنجاح');
      _loadCustomers();
    } catch (e) {
      _showErrorDialog('فشل في حذف العميل: $e');
    }
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => _CustomerFormDialog(onSave: _addCustomer),
    );
  }

  void _showEditCustomerDialog(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (context) => _CustomerFormDialog(
        customer: customer,
        onSave: (data) => _updateCustomer(customer['_id'], data),
      ),
    );
  }

  Future<void> _addCustomer(Map<String, dynamic> customerData) async {
    try {
      final customerService = serviceLocator<CustomerApiService>();
      await customerService.createCustomer(customerData);
      _showSuccessDialog('تم إنشاء العميل بنجاح');
      _loadCustomers();
    } catch (e) {
      _showErrorDialog('فشل في إنشاء العميل: $e');
    }
  }

  Future<void> _updateCustomer(
    String id,
    Map<String, dynamic> customerData,
  ) async {
    try {
      final customerService = serviceLocator<CustomerApiService>();
      await customerService.updateCustomer(id, customerData);
      _showSuccessDialog('تم تحديث العميل بنجاح');
      _loadCustomers();
    } catch (e) {
      _showErrorDialog('فشل في تحديث العميل: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          context.go('/admin-dashboard');
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('إدارة العملاء'),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/admin-dashboard');
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showAddCustomerDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadCustomers,
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : customers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('لا توجد عملاء', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(
                            customer['name']?.substring(0, 1).toUpperCase() ??
                                'ع',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          customer['name'] ?? 'غير معروف',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الهاتف: ${customer['contactInfo']?['phone'] ?? 'غير متوفر'}',
                            ),
                            Text(
                              'العنوان: ${customer['contactInfo']?['address'] ?? 'غير متوفر'}',
                            ),
                            Text(
                              'طلبات التحميل: ${_getCustomerLoadingOrdersCount(customer['_id'])}',
                            ),
                            Builder(
                              builder: (context) {
                                final paymentTotals = _getCustomerPaymentTotals(
                                  customer['_id'],
                                );
                                final remaining =
                                    paymentTotals['remaining'] ?? 0.0;
                                return Row(
                                  children: [
                                    Icon(
                                      remaining > 0
                                          ? Icons.pending_actions
                                          : Icons.check_circle,
                                      size: 16,
                                      color: remaining > 0
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      remaining > 0
                                          ? 'مدين: ج.م ${remaining.toStringAsFixed(2)}'
                                          : 'مُسدد بالكامل',
                                      style: TextStyle(
                                        color: remaining > 0
                                            ? Colors.red
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_getCustomerLoadingOrdersCount(
                                  customer['_id'],
                                ) >
                                0)
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 20),
                                onPressed: () =>
                                    _navigateToCustomerLoadingOrders(
                                      context,
                                      customer,
                                    ),
                                tooltip: 'عرض طلبات التحميل',
                              ),
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('تعديل'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'حذف',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditCustomerDialog(customer);
                                } else if (value == 'delete') {
                                  _deleteCustomer(
                                    customer['_id'],
                                    customer['name'],
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddCustomerDialog,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('تأكيد'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('نجح'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('خطأ'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  int _getCustomerLoadingOrdersCount(String? customerId) {
    if (customerId == null) return 0;
    return loadingOrders
        .where((order) => order['customer']?['_id'] == customerId)
        .length;
  }

  Map<String, double> _getCustomerPaymentTotals(String? customerId) {
    if (customerId == null)
      return {'totalValue': 0.0, 'totalPaid': 0.0, 'remaining': 0.0};

    final customerLoadingOrders = loadingOrders
        .where((order) => order['customer']?['_id'] == customerId)
        .toList();

    final double totalValue = customerLoadingOrders.fold(
      0.0,
      (sum, order) => sum + ((order['totalLoading'] ?? 0) as num).toDouble(),
    );

    final double totalPaid = customerLoadingOrders.fold(
      0.0,
      (sum, order) => sum + ((order['paidAmount'] ?? 0) as num).toDouble(),
    );

    final double remaining = totalValue - totalPaid;

    return {
      'totalValue': totalValue,
      'totalPaid': totalPaid,
      'remaining': remaining,
    };
  }

  void _navigateToCustomerLoadingOrders(
    BuildContext context,
    Map<String, dynamic> customer,
  ) {
    // Get loading orders for this specific customer
    final List<dynamic> customerLoadingOrders = loadingOrders
        .where((order) => order['customer']?['_id'] == customer['_id'])
        .toList();

    context.push(
      '/customer-loading-orders',
      extra: {'customer': customer, 'loadingOrders': customerLoadingOrders},
    );
  }
}

class _CustomerFormDialog extends StatefulWidget {
  final Map<String, dynamic>? customer;
  final Function(Map<String, dynamic>) onSave;

  const _CustomerFormDialog({this.customer, required this.onSave});

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      isEditing = true;
      _nameController.text = widget.customer!['name'] ?? '';
      _phoneController.text = widget.customer!['contactInfo']?['phone'] ?? '';
      _addressController.text =
          widget.customer!['contactInfo']?['address'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final customerData = {
        'name': _nameController.text.trim(),
        'contactInfo': {
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
        },
        'outstandingDebts': 0, // Default value
        'orders': [], // Default empty array
        'payments': [], // Default empty array
        'receipts': [], // Default empty array
      };
      widget.onSave(customerData);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(isEditing ? 'تعديل العميل' : 'إضافة عميل'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الاسم مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'الهاتف',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الهاتف مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'العنوان مطلوب';
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
          ElevatedButton(
            onPressed: _save,
            child: Text(isEditing ? 'تحديث' : 'إنشاء'),
          ),
        ],
      ),
    );
  }
}
