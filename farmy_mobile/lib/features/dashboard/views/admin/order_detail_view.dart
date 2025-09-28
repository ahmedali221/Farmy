import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/order_api_service.dart';
import '../../../../core/services/inventory_api_service.dart';

class OrderDetailView extends StatefulWidget {
  final Map<String, dynamic> order;
  final List<dynamic> expenses;
  final Map<String, dynamic>? paymentSummary;

  const OrderDetailView({
    super.key,
    required this.order,
    required this.expenses,
    this.paymentSummary,
  });

  @override
  State<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends State<OrderDetailView> {
  late final OrderApiService _orderService;
  late final InventoryApiService _inventoryService;
  Map<String, dynamic> order = {};
  List<dynamic> expenses = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _orderService = serviceLocator<OrderApiService>();
    _inventoryService = serviceLocator<InventoryApiService>();
    order = widget.order;
    expenses = widget.expenses;
  }

  Future<void> _refreshOrderData() async {
    try {
      // Refresh order data
      final refreshedOrder = await _orderService.getOrderById(order['_id']);
      if (refreshedOrder != null) {
        setState(() {
          order = refreshedOrder;
        });
      }
    } catch (e) {
      // Handle error silently or show a snackbar
      print('Error refreshing order data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double orderRevenue = _calculateOrderRevenue();
    final double totalExpenses = expenses.fold(
      0.0,
      (sum, e) => sum + ((e['amount'] ?? 0) as num).toDouble(),
    );
    final double netProfit = orderRevenue - totalExpenses;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!didPop) {
          context.go('/admin-dashboard');
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'طلب رقم #${order['_id']?.substring(0, 8) ?? 'غير معروف'}',
            ),
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
                tooltip: 'حذف هذا التحميل',
                icon: const Icon(Icons.delete_forever),
                onPressed: _confirmAndDeleteOrder,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshOrderData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _getOrderStatusColor(
                              order['status'],
                            ),
                            child: Icon(
                              _getOrderStatusIcon(order['status']),
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'حالة الطلب',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _getOrderStatusArabic(order['status']),
                                  style: TextStyle(
                                    color: _getOrderStatusColor(
                                      order['status'],
                                    ),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatDate(order['orderDate']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showOrderStatusDialog(),
                            tooltip: 'تحديث حالة الطلب',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Financial Summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الملخص المالي',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildFinancialListTile(
                            'الإيرادات',
                            'ج.م ${orderRevenue.toStringAsFixed(2)}',
                            Icons.attach_money,
                            Colors.green,
                          ),
                          _buildFinancialListTile(
                            'المصروفات',
                            'ج.م ${totalExpenses.toStringAsFixed(2)}',
                            Icons.money_off,
                            Colors.red,
                          ),
                          _buildFinancialListTile(
                            'صافي الربح',
                            'ج.م ${netProfit.toStringAsFixed(2)}',
                            Icons.account_balance,
                            netProfit >= 0 ? Colors.blue : Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Order Details
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تفاصيل الطلب',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            'معرّف الطلب',
                            order['_id']?.toString() ?? 'غير معروف',
                          ),
                          _buildDetailRow(
                            'الكمية',
                            '${order['quantity'] ?? 0} وحدة',
                          ),
                          _buildDetailRow(
                            'تاريخ الطلب',
                            _formatDate(order['orderDate']),
                          ),
                          if (order['offer'] != null &&
                              order['offer'].toString().isNotEmpty)
                            _buildDetailRow('العرض', order['offer']),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer Information
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'معلومات العميل',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            'الاسم',
                            order['customer']?['name'] ?? 'غير معروف',
                          ),
                          if (order['customer']?['contactInfo']?['phone'] !=
                              null)
                            _buildDetailRow(
                              'الهاتف',
                              order['customer']?['contactInfo']?['phone'],
                            ),
                          if (order['customer']?['contactInfo']?['address'] !=
                              null)
                            _buildDetailRow(
                              'العنوان',
                              order['customer']?['contactInfo']?['address'],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Chicken Type Information
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'معلومات المنتج',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            'نوع الدجاج',
                            order['chickenType']?['name'] ?? 'غير معروف',
                          ),
                          _buildDetailRow(
                            'السعر للوحدة',
                            'ج.م ${order['chickenType']?['price'] ?? 0}',
                          ),
                          _buildDetailRow(
                            'السعر الإجمالي',
                            'ج.م ${orderRevenue.toStringAsFixed(2)}',
                          ),
                          _buildDetailRow(
                            'المخزون المتاح',
                            '${order['chickenType']?['stock'] ?? 0} وحدة',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Employee Information (from expenses)
                  if (expenses.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'معلومات الموظف',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow(
                              'الموظف',
                              expenses[0]['employee']?['username'] ??
                                  'غير معروف',
                            ),
                            _buildDetailRow(
                              'الدور',
                              expenses[0]['employee']?['role'] ?? 'غير معروف',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Expenses Details
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تفاصيل المصروفات',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          if (expenses.isEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'لا توجد مصروفات مسجلة لهذا الطلب',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            ...expenses
                                .map((expense) => _buildExpenseItem(expense))
                                .toList(),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'إجمالي المصروفات',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                  Text(
                                    'ج.م ${totalExpenses.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[700],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialListTile(
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(dynamic expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  expense['title'] ?? 'Unknown Expense',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                'EGP ${expense['amount']?.toString() ?? '0'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (expense['note'] != null &&
              expense['note'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              expense['note'],
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Added: ${_formatDate(expense['createdAt'])}',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  double _calculateOrderRevenue() {
    try {
      final double quantity = ((order['quantity'] ?? 0) as num).toDouble();
      final double price = ((order['chickenType']?['price'] ?? 0) as num)
          .toDouble();
      return quantity * price;
    } catch (_) {
      return 0.0;
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
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() => isLoading = true);
    try {
      final String? chickenTypeId = order['chickenType']?['_id'];
      final int quantity = order['quantity'] ?? 0;
      final String currentStatus = order['status'] ?? 'pending';

      // Update order status
      await _orderService.updateOrderStatus(order['_id'], newStatus);

      // Handle inventory changes based on status transition
      if (chickenTypeId != null && quantity > 0) {
        if (currentStatus == 'pending' && newStatus == 'delivered') {
          // Order approved - decrease inventory
          await _decreaseInventoryStock(chickenTypeId, quantity);
        } else if (currentStatus == 'pending' && newStatus == 'cancelled') {
          // Order declined - no inventory change
        } else if (currentStatus == 'delivered' && newStatus == 'cancelled') {
          // Order cancelled after delivery - increase inventory
          await _increaseInventoryStock(chickenTypeId, quantity);
        } else if (currentStatus == 'cancelled' && newStatus == 'delivered') {
          // Order re-approved - decrease inventory
          await _decreaseInventoryStock(chickenTypeId, quantity);
        }
      }

      // Update local state
      setState(() {
        order['status'] = newStatus;
        isLoading = false;
      });

      _showSuccessDialog('تم تحديث حالة الطلب بنجاح');
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('فشل تحديث حالة الطلب: $e');
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

  void _showOrderStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحديث حالة الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الحالة الحالية: ${_getOrderStatusArabic(order['status'])}'),
            const SizedBox(height: 16),
            const Text('اختر الحالة الجديدة:'),
            const SizedBox(height: 8),
            ...['pending', 'delivered', 'cancelled']
                .map(
                  (status) => ListTile(
                    leading: Radio<String>(
                      value: status,
                      groupValue: order['status'] ?? 'pending',
                      onChanged: (value) {
                        Navigator.of(context).pop();
                        if (value != null && value != order['status']) {
                          _updateOrderStatus(value);
                        }
                      },
                    ),
                    title: Text(_getOrderStatusArabic(status)),
                    subtitle: Text(_getStatusDescription(status)),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (status != order['status']) {
                        _updateOrderStatus(status);
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
}

extension on _OrderDetailViewState {
  Future<void> _confirmAndDeleteOrder() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف سجل التحميل هذا؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final String id = (order['_id'] ?? '').toString();
      if (id.isEmpty) throw Exception('معرّف غير صالح');
      await _orderService.deleteOrder(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف سجل التحميل')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }
}
