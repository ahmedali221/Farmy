import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmployeeOrdersView extends StatelessWidget {
  final Map<String, dynamic> employee;
  final List<dynamic> orders;
  final Map<String, List<dynamic>> expensesByOrder;

  const EmployeeOrdersView({
    super.key,
    required this.employee,
    required this.orders,
    required this.expensesByOrder,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate employee totals
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
          title: Text('${employee['username']} - الطلبات'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            // Employee Summary - Sticky Header
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Employee Info Header
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                employee['username']
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    'م',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            employee['username'] ?? 'موظف غير معروف',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                          ),
                          subtitle: Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'الدور: ${employee['role'] ?? 'غير معروف'}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Summary List
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
            ),

            // Orders List Header
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.list_alt,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                  title: Text(
                    'قائمة الطلبات (${orders.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  dense: true,
                ),
              ),
            ),

            // Orders List
            orders.isEmpty
                ? const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد طلبات',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'لم يتم تسجيل أي طلبات لهذا الموظف بعد',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final order = orders[index];
                        return _buildOrderCard(context, order);
                      }, childCount: orders.length),
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
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getOrderStatusColor(order['status']),
          child: Icon(
            _getOrderStatusIcon(order['status']),
            color: Colors.white,
            size: 18,
          ),
        ),
        title: Text(
          'طلب رقم #${orderId?.substring(0, 8) ?? 'غير معروف'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'العميل: ${order['customer']?['name'] ?? 'غير معروف'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              'نوع الدجاج: ${order['chickenType']?['name'] ?? 'دجاج'} • الكمية: ${order['quantity'] ?? 0}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getOrderStatusColor(order['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getOrderStatusColor(order['status']).withOpacity(0.3),
                ),
              ),
              child: Text(
                _getOrderStatusArabic(order['status']),
                style: TextStyle(
                  color: _getOrderStatusColor(order['status']),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'ج.م ${orderRevenue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.green,
              ),
            ),
            Text(
              _formatDate(order['orderDate']),
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Order Details
                _buildOrderDetailListTile(
                  'الكمية',
                  '${order['quantity'] ?? 0}',
                  Icons.inventory,
                  Colors.blue,
                ),
                _buildOrderDetailListTile(
                  'نوع الدجاج',
                  order['chickenType']?['name'] ?? 'دجاج',
                  Icons.category,
                  Colors.green,
                ),
                _buildOrderDetailListTile(
                  'الإيرادات',
                  'ج.م ${orderRevenue.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.green,
                ),
                _buildOrderDetailListTile(
                  'المصروفات',
                  'ج.م ${orderExpenseTotal.toStringAsFixed(2)}',
                  Icons.money_off,
                  Colors.red,
                ),
                _buildOrderDetailListTile(
                  'صافي الربح',
                  'ج.م ${netProfit.toStringAsFixed(2)}',
                  Icons.account_balance,
                  netProfit >= 0 ? Colors.blue : Colors.orange,
                ),

                // Expenses Preview
                if (orderExpenses.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
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
                          children: [
                            Icon(
                              Icons.receipt_long,
                              color: Colors.red[700],
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'المصروفات (${orderExpenses.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...orderExpenses
                            .take(2)
                            .map(
                              (expense) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.red[400],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        expense['title'] ?? 'مصروف غير معروف',
                                        style: TextStyle(
                                          color: Colors.red[700],
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'ج.م ${expense['amount']}',
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        if (orderExpenses.length > 2)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '... و ${orderExpenses.length - 2} مصروفات أخرى',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Action Button
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _navigateToOrderDetail(context, order, orderExpenses),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('عرض التفاصيل الكاملة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
