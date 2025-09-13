import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomerLoadingOrdersView extends StatelessWidget {
  final Map<String, dynamic> customer;
  final List<dynamic> loadingOrders;

  const CustomerLoadingOrdersView({
    super.key,
    required this.customer,
    required this.loadingOrders,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate customer totals for loading orders
    final double totalWeight = loadingOrders.fold(
      0.0,
      (sum, order) => sum + ((order['netWeight'] ?? 0) as num).toDouble(),
    );
    final double totalValue = loadingOrders.fold(
      0.0,
      (sum, order) => sum + ((order['totalLoading'] ?? 0) as num).toDouble(),
    );
    final double totalQuantity = loadingOrders.fold(
      0.0,
      (sum, order) => sum + ((order['quantity'] ?? 0) as num).toDouble(),
    );

    // Calculate payment information
    final double totalPaid = loadingOrders.fold(
      0.0,
      (sum, order) => sum + ((order['paidAmount'] ?? 0) as num).toDouble(),
    );
    final double remainingAmount = totalValue - totalPaid;

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
            title: Text('${customer['name']} - طلبات التحميل'),
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
          ),
          body: CustomScrollView(
            slivers: [
              // Customer Summary - Sticky Header
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
                          // Customer Info Header
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.blue,
                                child: Text(
                                  customer['name']
                                          ?.substring(0, 1)
                                          .toUpperCase() ??
                                      'ع',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    customer['name'] ?? 'عميل غير معروف',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                        ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: remainingAmount > 0
                                        ? Colors.red.withOpacity(0.1)
                                        : Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: remainingAmount > 0
                                          ? Colors.red.withOpacity(0.3)
                                          : Colors.green.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        remainingAmount > 0
                                            ? Icons.pending_actions
                                            : Icons.check_circle,
                                        size: 16,
                                        color: remainingAmount > 0
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        remainingAmount > 0 ? 'مدين' : 'مُسدد',
                                        style: TextStyle(
                                          color: remainingAmount > 0
                                              ? Colors.red
                                              : Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.phone,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  title: Text(
                                    customer['contactInfo']?['phone'] ??
                                        'غير متوفر',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  dense: true,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  title: Text(
                                    customer['contactInfo']?['address'] ??
                                        'غير متوفر',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  dense: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Summary List
                          Column(
                            children: [
                              _buildSummaryListTile(
                                'إجمالي طلبات التحميل',
                                loadingOrders.length.toString(),
                                Icons.local_shipping,
                                Colors.blue,
                              ),
                              _buildSummaryListTile(
                                'إجمالي الكمية',
                                '${totalQuantity.toInt()} وحدة',
                                Icons.inventory,
                                Colors.purple,
                              ),
                              _buildSummaryListTile(
                                'إجمالي الوزن الصافي',
                                '${totalWeight.toStringAsFixed(1)} كجم',
                                Icons.scale,
                                Colors.green,
                              ),
                              _buildSummaryListTile(
                                'إجمالي القيمة',
                                'ج.م ${totalValue.toStringAsFixed(2)}',
                                Icons.attach_money,
                                Colors.orange,
                              ),
                              _buildSummaryListTile(
                                'إجمالي المبلغ المدفوع',
                                'ج.م ${totalPaid.toStringAsFixed(2)}',
                                Icons.check_circle,
                                Colors.green,
                              ),
                              _buildSummaryListTile(
                                'إجمالي المبلغ المتبقي',
                                'ج.م ${remainingAmount.toStringAsFixed(2)}',
                                Icons.pending_actions,
                                remainingAmount > 0 ? Colors.red : Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Loading Orders List Header
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.local_shipping,
                      color: Colors.blue,
                      size: 20,
                    ),
                    title: Text(
                      'قائمة طلبات التحميل (${loadingOrders.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    dense: true,
                  ),
                ),
              ),

              // Loading Orders List
              if (loadingOrders.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد طلبات تحميل',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'لم يتم تسجيل أي طلبات تحميل لهذا العميل',
                            style: TextStyle(color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final loadingOrder = loadingOrders[index];
                    return _buildLoadingOrderCard(context, loadingOrder);
                  }, childCount: loadingOrders.length),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryListTile(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOrderCard(
    BuildContext context,
    Map<String, dynamic> loadingOrder,
  ) {
    final orderId =
        loadingOrder['_id']?.toString().substring(0, 8) ?? 'غير معروف';
    final createdAt = _formatDateTime(loadingOrder['createdAt']);
    final quantity = (loadingOrder['quantity'] ?? 0) as num;
    final grossWeight = (loadingOrder['grossWeight'] ?? 0) as num;
    final netWeight = (loadingOrder['netWeight'] ?? 0) as num;
    final chickenType = loadingOrder['chickenType'];
    final notes = loadingOrder['notes']?.toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Navigate to loading order details if needed
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: const Icon(
                        Icons.local_shipping,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'طلب تحميل #$orderId',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            createdAt,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Details as list tiles
                _buildDetailListTile(
                  'الكمية',
                  '${quantity.toInt()} وحدة',
                  Icons.inventory,
                  Colors.purple,
                ),
                _buildDetailListTile(
                  'الوزن القائم',
                  '${grossWeight.toDouble().toStringAsFixed(1)} كجم',
                  Icons.scale,
                  Colors.red,
                ),
                _buildDetailListTile(
                  'الوزن الصافي',
                  '${netWeight.toDouble().toStringAsFixed(1)} كجم',
                  Icons.scale_outlined,
                  Colors.green,
                ),

                // Chicken type
                if (chickenType != null)
                  _buildDetailListTile(
                    'نوع الدجاج',
                    chickenType['name'] ?? 'غير معروف',
                    Icons.pets,
                    Colors.brown,
                  ),

                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.note, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'ملاحظات',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notes,
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
        ),
      ),
    );
  }

  Widget _buildDetailListTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        subtitle: Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        dense: true,
      ),
    );
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'غير معروف';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'تاريخ غير صحيح';
    }
  }
}
