import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/services/supplier_api_service.dart';
import '../../../../../core/services/loading_api_service.dart';

class SupplierManagementView extends StatefulWidget {
  const SupplierManagementView({super.key});

  @override
  State<SupplierManagementView> createState() => _SupplierManagementViewState();
}

class _SupplierManagementViewState extends State<SupplierManagementView> {
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> loadingOrders = [];
  List<Map<String, dynamic>> filteredSuppliers = [];
  bool isLoading = true;
  late final LoadingApiService _loadingService;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadingService = serviceLocator<LoadingApiService>();
    _searchController.addListener(_filterSuppliers);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSuppliers() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredSuppliers = suppliers;
      } else {
        filteredSuppliers = suppliers.where((supplier) {
          final name = supplier['name']?.toString().toLowerCase() ?? '';
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final supplierService = serviceLocator<SupplierApiService>();
      final suppliersList = await supplierService.getAllSuppliers();
      final loadingOrdersList = await _loadingService.getAllLoadings();

      setState(() {
        suppliers = suppliersList;
        loadingOrders = loadingOrdersList;
        filteredSuppliers = suppliers;
        print('Debug - Suppliers count: ${suppliers.length}');
        if (suppliers.isNotEmpty) {
          print('Debug - First supplier: ${suppliers.first}');
        }
        print('Debug - Loading orders count: ${loadingOrders.length}');
        if (loadingOrders.isNotEmpty) {
          print('Debug - First loading order: ${loadingOrders.first}');
        }
      });

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('فشل في تحميل البيانات: $e');
    }
  }

  Future<void> _loadSuppliers() async {
    await _loadData();
  }

  Future<void> _deleteSupplier(String id, String name) async {
    final confirmed = await _showConfirmDialog(
      'حذف المورد',
      'هل أنت متأكد من حذف $name؟',
    );
    if (!confirmed) return;

    try {
      final supplierService = serviceLocator<SupplierApiService>();
      await supplierService.deleteSupplier(id);
      _showSuccessDialog('تم حذف المورد بنجاح');
      _loadSuppliers();
    } catch (e) {
      _showErrorDialog('فشل في حذف المورد: $e');
    }
  }

  void _showAddSupplierDialog() {
    showDialog(
      context: context,
      builder: (context) => _SupplierFormDialog(onSave: _addSupplier),
    );
  }

  void _showEditSupplierDialog(Map<String, dynamic> supplier) {
    showDialog(
      context: context,
      builder: (context) => _SupplierFormDialog(
        supplier: supplier,
        onSave: (data) => _updateSupplier(supplier['_id'], data),
      ),
    );
  }

  Future<void> _addSupplier(Map<String, dynamic> supplierData) async {
    try {
      final supplierService = serviceLocator<SupplierApiService>();
      await supplierService.createSupplier(supplierData);
      _showSuccessDialog('تم إنشاء المورد بنجاح');
      _loadSuppliers();
    } catch (e) {
      _showErrorDialog('فشل في إنشاء المورد: $e');
    }
  }

  Future<void> _updateSupplier(
    String id,
    Map<String, dynamic> supplierData,
  ) async {
    try {
      final supplierService = serviceLocator<SupplierApiService>();
      await supplierService.updateSupplier(id, supplierData);
      _showSuccessDialog('تم تحديث المورد بنجاح');
      _loadSuppliers();
    } catch (e) {
      _showErrorDialog('فشل في تحديث المورد: $e');
    }
  }

  int _getSupplierLoadingOrdersCount(String supplierId) {
    return loadingOrders.where((order) {
      final supplier = order['supplier'];
      if (supplier == null) return false;

      if (supplier is Map<String, dynamic>) {
        return supplier['_id'] == supplierId;
      }
      if (supplier is String) {
        return supplier == supplierId;
      }
      return false;
    }).length;
  }

  Map<String, dynamic> _getSupplierLoadingTotals(String supplierId) {
    final supplierOrders = loadingOrders.where((order) {
      final supplier = order['supplier'];
      if (supplier == null) return false;

      if (supplier is Map<String, dynamic>) {
        return supplier['_id'] == supplierId;
      }
      if (supplier is String) {
        return supplier == supplierId;
      }
      return false;
    });

    double totalValue = 0.0;
    double totalWeight = 0.0;

    for (var order in supplierOrders) {
      totalValue += (order['totalLoading'] ?? 0).toDouble();
      totalWeight += (order['netWeight'] ?? 0).toDouble();
    }

    return {'totalValue': totalValue, 'totalWeight': totalWeight};
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
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
        ) ??
        false;
  }

  void _showSuccessDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _navigateToLoadingOrders(
    BuildContext context,
    Map<String, dynamic> supplier,
  ) {
    context.push(
      '/supplier-loading-orders',
      extra: {'supplierId': supplier['_id']},
    );
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
            title: const Text('إدارة الموردين'),
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
                onPressed: _showAddSupplierDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadSuppliers,
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'البحث باسم المورد',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterSuppliers();
                            },
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredSuppliers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'لا توجد موردين',
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredSuppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = filteredSuppliers[index];
                          final supplierId = supplier['_id'];
                          print('Debug - Supplier ID: $supplierId');
                          final totals = _getSupplierLoadingTotals(supplierId);
                          final loadingCount = _getSupplierLoadingOrdersCount(
                            supplierId,
                          );

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Icon(
                                  Icons.business,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                supplier['name'] ?? 'غير معروف',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الهاتف: ${supplier['phone'] ?? 'غير متوفر'}',
                                  ),
                                  Text(
                                    'العنوان: ${supplier['address'] ?? 'غير متوفر'}',
                                  ),
                                  Text('طلبات التحميل: $loadingCount'),
                                  if (totals['totalValue'] > 0) ...[
                                    Text(
                                      'إجمالي القيمة: ${totals['totalValue'].toStringAsFixed(0)} ج.م',
                                    ),
                                    Text(
                                      'إجمالي الوزن: ${totals['totalWeight'].toStringAsFixed(1)} كجم',
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.local_shipping,
                                      size: 20,
                                    ),
                                    onPressed: () => _navigateToLoadingOrders(
                                      context,
                                      supplier,
                                    ),
                                    tooltip: 'طلبات التحميل',
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
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showEditSupplierDialog(supplier);
                                      } else if (value == 'delete') {
                                        _deleteSupplier(
                                          supplier['_id'],
                                          supplier['name'],
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplierFormDialog extends StatefulWidget {
  final Map<String, dynamic>? supplier;
  final Function(Map<String, dynamic>) onSave;

  const _SupplierFormDialog({this.supplier, required this.onSave});

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.supplier != null) {
      isEditing = true;
      _nameController.text = widget.supplier!['name'] ?? '';
      _phoneController.text = widget.supplier!['phone'] ?? '';
      _addressController.text = widget.supplier!['address'] ?? '';
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
      final supplierData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
      };
      widget.onSave(supplierData);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                isEditing ? 'تعديل المورد' : 'إضافة مورد جديد',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSectionTitle('معلومات المورد'),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم المورد *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال اسم المورد';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'العنوان',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: _save,
                    child: Text(isEditing ? 'تحديث' : 'إضافة'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}
