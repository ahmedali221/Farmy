import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomerOrdersView extends StatelessWidget {
  final Map<String, dynamic> customer;
  final List<dynamic> orders;
  final Map<String, List<dynamic>> expensesByOrder;

  const CustomerOrdersView({
    super.key,
    required this.customer,
    required this.orders,
    required this.expensesByOrder,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate customer totals
    final double totalRevenue = orders.fold(
      0.0,
      (sum, o) => sum + _calculateOrderRevenue(o),
    );
    final double totalExpenses = orders.fold(0.0, (sum, o) {
      final String? id = o['_id']?.toString();
      final List<dynamic> list = id != null ? (expensesByOrder[id] ?? []) : [];
      return sum +
          list.fold(0.0, (s, e) => s + ((e['amount'] ?? 0) as num).toDouble());
    });
    final double netProfit = totalRevenue - totalExpenses;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${customer['name']} - الطلبات'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Column(
          children: [
            // Customer Summary
            Container(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
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
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer['name'] ?? 'عميل غير معروف',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'الهاتف: ${customer['contactInfo']?['phone'] ?? 'غير متوفر'}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                                Text(
                                  'العنوان: ${customer['contactInfo']?['address'] ?? 'غير متوفر'}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          _buildSummaryListTile(
                            'إجمالي الطلبات',
                            orders.length.toString(),
                            Icons.shopping_cart,
                            Colors.blue,
                          ),
                          _buildSummaryListTile(
                            'إجمالي الإيرادات',
                            'ج.م ${totalRevenue.toStringAsFixed(2)}',
                            Icons.attach_money,
                            Colors.green,
                          ),
                          _buildSummaryListTile(
                            'إجمالي المصروفات',
                            'ج.م ${totalExpenses.toStringAsFixed(2)}',
                            Icons.money_off,
                            Colors.red,
                          ),
                          _buildSummaryListTile(
                            'صافي الربح',
                            'ج.م ${netProfit.toStringAsFixed(2)}',
                            Icons.account_balance,
                            netProfit >= 0 ? Colors.blue : Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Orders List
            Expanded(
              child: orders.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text('لا توجد طلبات', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return _buildOrderCard(context, order);
                      },
                    ),
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
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

  Widget _buildOrderCard(BuildContext context, dynamic order) {
    final String? orderId = order['_id']?.toString();
    final List<dynamic> orderExpenses = orderId != null
        ? (expensesByOrder[orderId] ?? [])
        : [];
    final double orderRevenue = _calculateOrderRevenue(order);
    final double orderExpenseTotal = orderExpenses.fold(
      0.0,
      (sum, e) => sum + ((e['amount'] ?? 0) as num).toDouble(),
    );
    final double netProfit = orderRevenue - orderExpenseTotal;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToOrderDetail(context, order, orderExpenses),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getOrderStatusColor(order['status']),
                    child: Icon(
                      _getOrderStatusIcon(order['status']),
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلب رقم #${orderId?.substring(0, 8) ?? 'غير معروف'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${order['chickenType']?['name'] ?? 'دجاج'} • الكمية: ${order['quantity'] ?? 0}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'ج.م ${orderRevenue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatDate(order['orderDate']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Order Details
              Column(
                children: [
                  _buildOrderDetailListTile(
                    'الكمية',
                    '${order['quantity'] ?? 0}',
                    Icons.inventory,
                    Colors.blue,
                  ),
                  _buildOrderDetailListTile(
                    'المصروفات',
                    'ج.م ${orderExpenseTotal.toStringAsFixed(2)}',
                    Icons.money_off,
                    Colors.red,
                  ),
                  _buildOrderDetailListTile(
                    'صافي',
                    'ج.م ${netProfit.toStringAsFixed(2)}',
                    Icons.account_balance,
                    netProfit >= 0 ? Colors.green : Colors.orange,
                  ),
                ],
              ),

              // Expenses Preview
              if (orderExpenses.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المصروفات (${orderExpenses.length}):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...orderExpenses
                          .take(2)
                          .map(
                            (expense) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '• ${expense['title']}: ج.م ${expense['amount']}',
                                style: TextStyle(
                                  color: Colors.red[600],
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      if (orderExpenses.length > 2)
                        Text(
                          '• ... و ${orderExpenses.length - 2} أخرى',
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // Tap to view details
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'اضغط لعرض التفاصيل',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderDetailItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailListTile(
    String label,
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
          label,
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

  void _navigateToOrderDetail(
    BuildContext context,
    dynamic order,
    List<dynamic> expenses,
  ) {
    context.push(
      '/order-detail',
      extra: {'order': order, 'expenses': expenses},
    );
  }

  double _calculateOrderRevenue(dynamic order) {
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
    if (date == null) return 'غير معروف';
    try {
      final DateTime dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'تاريخ غير صحيح';
    }
  }
}
