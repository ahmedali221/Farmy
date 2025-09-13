import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/services/inventory_api_service.dart';

class InventoryManagementView extends StatefulWidget {
  const InventoryManagementView({super.key});

  @override
  State<InventoryManagementView> createState() =>
      _InventoryManagementViewState();
}

class _InventoryManagementViewState extends State<InventoryManagementView> {
  List<Map<String, dynamic>> chickenTypes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Delay loading to avoid context access issues and ensure service locator is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() {
    // Try to load data with retry mechanism
    int retryCount = 0;
    const maxRetries = 3;

    void tryLoadData() {
      if (!mounted) return;

      if (serviceLocator.isRegistered<InventoryApiService>()) {
        _loadChickenTypes();
      } else if (retryCount < maxRetries) {
        retryCount++;
        Future.delayed(Duration(milliseconds: 100 * retryCount), tryLoadData);
      } else {
        // If all retries failed, show error
        if (mounted) {
          setState(() => isLoading = false);
          _showErrorDialog('الخدمة غير متاحة. يرجى إعادة تشغيل التطبيق.');
        }
      }
    }

    tryLoadData();
  }

  Future<void> _loadChickenTypes() async {
    if (!mounted) return;

    setState(() => isLoading = true);
    try {
      // Ensure service locator is ready
      if (!serviceLocator.isRegistered<InventoryApiService>()) {
        throw Exception(
          'InventoryApiService not registered. Please restart the app.',
        );
      }

      final inventoryService = serviceLocator<InventoryApiService>();
      final chickenTypesList = await inventoryService.getAllChickenTypes();

      if (mounted) {
        setState(() {
          chickenTypes = chickenTypesList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorDialog('فشل في تحميل المخزون: $e');
      }
    }
  }

  void _showAddChickenTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => _ChickenTypeFormDialog(onSave: _addChickenType),
    );
  }

  void _showEditChickenTypeDialog(Map<String, dynamic> chickenType) {
    showDialog(
      context: context,
      builder: (context) => _ChickenTypeFormDialog(
        chickenType: chickenType,
        onSave: (data) => _updateChickenType(chickenType['_id'], data),
      ),
    );
  }

  Future<void> _addChickenType(Map<String, dynamic> chickenTypeData) async {
    try {
      if (!serviceLocator.isRegistered<InventoryApiService>()) {
        throw Exception(
          'InventoryApiService not registered. Please restart the app.',
        );
      }

      final inventoryService = serviceLocator<InventoryApiService>();
      await inventoryService.createChickenType(chickenTypeData);
      _showSuccessDialog('تم إضافة نوع الدجاج بنجاح');
      _loadChickenTypes();
    } catch (e) {
      _showErrorDialog('فشل في إضافة نوع الدجاج: $e');
    }
  }

  Future<void> _updateChickenType(
    String id,
    Map<String, dynamic> chickenTypeData,
  ) async {
    try {
      if (!serviceLocator.isRegistered<InventoryApiService>()) {
        throw Exception(
          'InventoryApiService not registered. Please restart the app.',
        );
      }

      final inventoryService = serviceLocator<InventoryApiService>();
      await inventoryService.updateChickenType(id, chickenTypeData);
      _showSuccessDialog('تم تحديث المخزون بنجاح');
      _loadChickenTypes();
    } catch (e) {
      _showErrorDialog('فشل في تحديث المخزون: $e');
    }
  }

  Future<void> _deleteChickenType(String id, String name) async {
    final confirmed = await _showConfirmDialog(
      'حذف نوع الدجاج',
      'هل أنت متأكد من حذف $name؟',
    );
    if (!confirmed) return;

    try {
      if (!serviceLocator.isRegistered<InventoryApiService>()) {
        throw Exception(
          'InventoryApiService not registered. Please restart the app.',
        );
      }

      final inventoryService = serviceLocator<InventoryApiService>();
      await inventoryService.deleteChickenType(id);
      _showSuccessDialog('تم حذف نوع الدجاج بنجاح');
      _loadChickenTypes();
    } catch (e) {
      _showErrorDialog('فشل في حذف نوع الدجاج: $e');
    }
  }

  void _showStockUpdateDialog(Map<String, dynamic> chickenType) {
    final stockController = TextEditingController(
      text: chickenType['stock'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تحديث المخزون - ${chickenType['name']} (${_formatPrice(chickenType['price'])} ج.م/كجم)',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المخزون الحالي: ${chickenType['stock']}'),
            const SizedBox(height: 16),
            TextField(
              controller: stockController,
              decoration: const InputDecoration(
                labelText: 'الكمية الجديدة',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final newStock = int.tryParse(stockController.text);
              if (newStock != null && newStock >= 0) {
                final updatedData = {
                  'name': chickenType['name'],
                  'price': chickenType['price'],
                  'stock': newStock,
                };
                _updateChickenType(chickenType['_id'], updatedData);
                Navigator.of(context).pop();
              } else {
                _showErrorDialog('يرجى إدخال كمية صحيحة');
              }
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }

  Color _getStockStatusColor(int stock) {
    if (stock == 0) return Colors.red;
    if (stock < 10) return Colors.orange;
    return Colors.green;
  }

  String _getStockStatusText(int stock) {
    if (stock == 0) return 'نفذ المخزون';
    if (stock < 10) return 'مخزون منخفض';
    return 'متوفر';
  }

  double _calculateTotalValue() {
    return chickenTypes.fold<double>(0, (sum, item) {
      final price = (item['price'] is int)
          ? (item['price'] as int).toDouble()
          : (item['price'] as double);
      final stock = item['stock'] as int;
      return sum + (price * stock);
    });
  }

  String _formatPrice(dynamic price) {
    if (price is int) {
      return price.toString();
    } else if (price is double) {
      return price.toStringAsFixed(2);
    }
    return price.toString();
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
            title: const Text('إدارة المخزون (ج.م)'),
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
                onPressed: _showAddChickenTypeDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadChickenTypes,
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : chickenTypes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد عناصر في المخزون',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'أضف أنواع الدجاج مع الأسعار بالجنية المصري لكل كيلو',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary Cards
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'إجمالي العناصر',
                                  chickenTypes.length.toString(),
                                  Icons.inventory,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'إجمالي المخزون',
                                  chickenTypes
                                      .fold<int>(
                                        0,
                                        (sum, item) =>
                                            sum + (item['stock'] as int),
                                      )
                                      .toString(),
                                  Icons.storage,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'مخزون منخفض',
                                  chickenTypes
                                      .where((item) => item['stock'] < 10)
                                      .length
                                      .toString(),
                                  Icons.warning,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'القيمة الإجمالية',
                                  '${_calculateTotalValue().toStringAsFixed(0)} ج.م',
                                  Icons.attach_money,
                                  Colors.purple,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Inventory List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: chickenTypes.length,
                        itemBuilder: (context, index) {
                          final chickenType = chickenTypes[index];
                          final stock = chickenType['stock'] as int;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _getStockStatusColor(
                                    stock,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.egg_outlined,
                                  color: _getStockStatusColor(stock),
                                  size: 30,
                                ),
                              ),
                              title: Text(
                                chickenType['name'] ?? 'غير معروف',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'السعر: ${_formatPrice(chickenType['price'])} ج.م/كجم',
                                  ),
                                  Text(
                                    'المخزون: $stock - ${_getStockStatusText(stock)}',
                                    style: TextStyle(
                                      color: _getStockStatusColor(stock),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'update_stock',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('تحديث المخزون'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.settings, size: 20),
                                        SizedBox(width: 8),
                                        Text('تعديل التفاصيل'),
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
                                  if (value == 'update_stock') {
                                    _showStockUpdateDialog(chickenType);
                                  } else if (value == 'edit') {
                                    _showEditChickenTypeDialog(chickenType);
                                  } else if (value == 'delete') {
                                    _deleteChickenType(
                                      chickenType['_id'],
                                      chickenType['name'],
                                    );
                                  }
                                },
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddChickenTypeDialog,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
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
                fontSize: 20,
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

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نجح'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
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
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
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
        ) ??
        false;
  }
}

class _ChickenTypeFormDialog extends StatefulWidget {
  final Map<String, dynamic>? chickenType;
  final Function(Map<String, dynamic>) onSave;

  const _ChickenTypeFormDialog({this.chickenType, required this.onSave});

  @override
  State<_ChickenTypeFormDialog> createState() => _ChickenTypeFormDialogState();
}

class _ChickenTypeFormDialogState extends State<_ChickenTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  String? selectedChickenType;
  bool isEditing = false;

  final List<String> chickenTypeOptions = [
    'تسمين',
    'بلدي',
    'أحمر',
    'ساسو',
    'بط',
    'فراخ بيضاء',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.chickenType != null) {
      isEditing = true;
      selectedChickenType = widget.chickenType!['name'];
      _priceController.text = widget.chickenType!['price'].toString();
      _stockController.text = widget.chickenType!['stock'].toString();
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate() && selectedChickenType != null) {
      final chickenTypeData = {
        'name': selectedChickenType!,
        'price': double.parse(_priceController.text),
        'stock': int.parse(_stockController.text),
      };
      widget.onSave(chickenTypeData);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(
          isEditing ? 'تعديل نوع الدجاج' : 'إضافة نوع دجاج (السعر لكل كيلو)',
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedChickenType,
                  decoration: const InputDecoration(
                    labelText: 'نوع الدجاج',
                    border: OutlineInputBorder(),
                  ),
                  items: chickenTypeOptions.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: isEditing
                      ? null
                      : (String? newValue) {
                          setState(() {
                            selectedChickenType = newValue;
                          });
                        },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى اختيار نوع الدجاج';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'السعر لكل كيلو (ج.م)',
                    border: OutlineInputBorder(),
                    prefixText: 'ج.م ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'السعر لكل كيلو مطلوب';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price < 0) {
                      return 'يرجى إدخال سعر صحيح بالجنية المصري';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(
                    labelText: 'كمية المخزون',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'كمية المخزون مطلوبة';
                    }
                    if (int.tryParse(value) == null || int.parse(value) < 0) {
                      return 'يرجى إدخال كمية مخزون صحيحة';
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
