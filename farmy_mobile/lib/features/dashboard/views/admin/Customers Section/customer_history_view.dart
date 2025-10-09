import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/services/payment_api_service.dart';
import '../../../../../core/services/distribution_api_service.dart';

class CustomerHistoryView extends StatefulWidget {
  final Map<String, dynamic> customer;

  const CustomerHistoryView({super.key, required this.customer});

  @override
  State<CustomerHistoryView> createState() => _CustomerHistoryViewState();
}

class _CustomerHistoryViewState extends State<CustomerHistoryView> {
  late final PaymentApiService _paymentService;
  late final DistributionApiService _distributionService;

  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _distributions = [];
  List<_DailyHistoryGroup> _dailyGroups = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _paymentService = serviceLocator<PaymentApiService>();
    _distributionService = serviceLocator<DistributionApiService>();
    _loadAllData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final customerId = widget.customer['_id'];

      // Load all data in parallel
      final results = await Future.wait([
        _paymentService.getAllPayments(),
        _distributionService.getAllDistributions(),
      ]);

      final allPayments = results[0];
      final allDistributions = results[1];

      final customerPayments = allPayments
          .where((payment) => payment['customer']?['_id'] == customerId)
          .toList();

      final customerDistributions = allDistributions.where((distribution) {
        try {
          return distribution['customer']?['_id'] == customerId;
        } catch (e) {
          print('Error filtering distribution: $e');
          return false;
        }
      }).toList();

      // Sort by date (newest first)
      customerPayments.sort((a, b) {
        final dateA = a['createdAt'] ?? '';
        final dateB = b['createdAt'] ?? '';
        return dateB.toString().compareTo(dateA.toString());
      });

      customerDistributions.sort((a, b) {
        try {
          final dateA = a['createdAt'] ?? '';
          final dateB = b['createdAt'] ?? '';
          return dateB.toString().compareTo(dateA.toString());
        } catch (e) {
          print('Error sorting distribution: $e');
          return 0;
        }
      });

      setState(() {
        _payments = customerPayments;
        _distributions = customerDistributions;
        _dailyGroups = _groupHistoryByDate(
          customerPayments,
          customerDistributions,
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<_DailyHistoryGroup> _groupHistoryByDate(
    List<Map<String, dynamic>> payments,
    List<Map<String, dynamic>> distributions,
  ) {
    String keyFor(String? iso) {
      try {
        if (iso == null || iso.isEmpty) return '0000-00-00';
        final dt = DateTime.parse(iso).toLocal();
        return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        return '0000-00-00';
      }
    }

    final Map<String, _DailyHistoryGroup> dateToGroup = {};

    for (final payment in payments) {
      final k = keyFor(payment['createdAt']);
      dateToGroup.putIfAbsent(k, () => _DailyHistoryGroup(dateKey: k));
      dateToGroup[k]!.payments.add(payment);
    }

    for (final distribution in distributions) {
      final k = keyFor(distribution['createdAt']);
      dateToGroup.putIfAbsent(k, () => _DailyHistoryGroup(dateKey: k));
      dateToGroup[k]!.distributions.add(distribution);
    }

    final groups = dateToGroup.values.toList();
    groups.sort((a, b) => (b.dateKey ?? '').compareTo(a.dateKey ?? ''));

    // Sort items within each day (newest first)
    for (final group in groups) {
      group.payments.sort((a, b) {
        final dateA = a['createdAt'] ?? '';
        final dateB = b['createdAt'] ?? '';
        return dateB.toString().compareTo(dateA.toString());
      });

      group.distributions.sort((a, b) {
        final dateA = a['createdAt'] ?? '';
        final dateB = b['createdAt'] ?? '';
        return dateB.toString().compareTo(dateA.toString());
      });
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
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
            title: Text('${widget.customer['name']} - السجل التاريخي'),
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
                icon: const Icon(Icons.analytics),
                onPressed: _showSummaryDialog,
                tooltip: 'ملخص الإحصائيات',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadAllData,
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildErrorWidget()
              : _buildGroupedPaymentsList(),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('خطأ في تحميل البيانات: $_error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAllData,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  void _showSummaryDialog() {
    final totalPayments = _payments.length;
    final totalDistributions = _distributions.length;

    final totalPaidValue = _payments.fold(0.0, (sum, payment) {
      final paidAmount = payment['paidAmount'] ?? payment['amount'] ?? 0;
      if (paidAmount is num) {
        return sum + paidAmount.toDouble();
      } else if (paidAmount is String) {
        return sum + (double.tryParse(paidAmount) ?? 0.0);
      }
      return sum;
    });

    final totalDistributionValue = _distributions.fold(0.0, (
      sum,
      distribution,
    ) {
      final amount = distribution['totalAmount'] ?? 0;
      if (amount is num) {
        return sum + amount.toDouble();
      } else if (amount is String) {
        return sum + (double.tryParse(amount) ?? 0.0);
      }
      return sum;
    });

    final totalDiscount = _payments.fold(0.0, (sum, payment) {
      final discount = payment['discount'] ?? 0;
      if (discount is num) {
        return sum + discount.toDouble();
      } else if (discount is String) {
        return sum + (double.tryParse(discount) ?? 0.0);
      }
      return sum;
    });

    final remaining = (totalDistributionValue - totalPaidValue).clamp(
      0.0,
      double.infinity,
    );

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('ملخص إحصائيات ${widget.customer['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryCard(
                'إجمالي التوزيعات',
                'ج.م ${totalDistributionValue.toStringAsFixed(2)}',
                Icons.outbound,
                Colors.orange,
                '$totalDistributions توزيع',
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                'إجمالي المدفوعات',
                'ج.م ${totalPaidValue.toStringAsFixed(2)}',
                Icons.payment,
                Colors.green,
                '$totalPayments دفعة',
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                'إجمالي الخصومات',
                'ج.م ${totalDiscount.toStringAsFixed(2)}',
                Icons.percent,
                Colors.deepOrange,
                'خصومات مطبقة',
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                'المتبقي',
                'ج.م ${remaining.toStringAsFixed(2)}',
                Icons.pending_actions,
                remaining > 0 ? Colors.red : Colors.green,
                remaining > 0 ? 'مطلوب الدفع' : 'مدفوع بالكامل',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
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
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedPaymentsList() {
    if (_dailyGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'لا يوجد سجل لهذا العميل',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _dailyGroups.length,
      itemBuilder: (context, index) {
        final group = _dailyGroups[index];
        return _buildDayGroup(group);
      },
    );
  }

  Widget _buildDayGroup(_DailyHistoryGroup group) {
    final dateLabel = _formatDateOnly(group.dateKey ?? '0000-00-00');
    final hasPayments = group.payments.isNotEmpty;
    final hasDistributions = group.distributions.isNotEmpty;

    // Calculate day totals
    final dayPaymentTotal = group.payments.fold(0.0, (sum, payment) {
      final paidAmount = payment['paidAmount'] ?? payment['amount'] ?? 0;
      if (paidAmount is num) {
        return sum + paidAmount.toDouble();
      } else if (paidAmount is String) {
        return sum + (double.tryParse(paidAmount) ?? 0.0);
      }
      return sum;
    });

    final dayDistributionTotal = group.distributions.fold(0.0, (
      sum,
      distribution,
    ) {
      final amount = distribution['totalAmount'] ?? 0;
      if (amount is num) {
        return sum + amount.toDouble();
      } else if (amount is String) {
        return sum + (double.tryParse(amount) ?? 0.0);
      }
      return sum;
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    if (hasDistributions)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${group.distributions.length} توزيع',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (hasPayments)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${group.payments.length} دفعة',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (dayDistributionTotal > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Text(
                      'توزيعات: ج.م ${dayDistributionTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (dayPaymentTotal > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      'مدفوعات: ج.م ${dayPaymentTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Show distributions first
            if (hasDistributions) ...[
              _buildSectionHeader(
                'طلبات التوزيع',
                Icons.outbound,
                Colors.orange,
              ),
              const SizedBox(height: 8),
              ...group.distributions.map(
                (distribution) => _buildDistributionTile(distribution),
              ),
              const SizedBox(height: 12),
            ],

            // Then show payments
            if (hasPayments) ...[
              _buildSectionHeader('المدفوعات', Icons.payment, Colors.green),
              const SizedBox(height: 8),
              ...group.payments.map((payment) => _buildPaymentTile(payment)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTile(Map<String, dynamic> payment) {
    final idStr = payment['_id']?.toString() ?? '';
    final paymentId = idStr.length >= 8
        ? idStr.substring(0, 8)
        : (idStr.isEmpty ? 'غير معروف' : idStr);
    final createdAt = _formatDateTime(payment['createdAt']);
    final totalPriceValue = payment['totalPrice'] ?? 0;
    final paidAmountValue = payment['paidAmount'] ?? payment['amount'] ?? 0;

    final totalPrice = totalPriceValue is num
        ? totalPriceValue.toDouble()
        : 0.0;
    final paidAmount = paidAmountValue is num
        ? paidAmountValue.toDouble()
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.green.withOpacity(0.1),
          child: const Icon(Icons.payment, size: 18, color: Colors.green),
        ),
        title: Text(
          'دفعة #$paymentId',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          'المدفوع: ج.م ${paidAmount.toStringAsFixed(2)} • المستحق: ج.م ${totalPrice.toStringAsFixed(2)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              createdAt,
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
        onTap: () => _navigateToPaymentDetails(payment),
      ),
    );
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'غير معروف';
    try {
      final dt = DateTime.parse(dateTime).toLocal();
      final two = (int v) => v.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return 'تاريخ غير صحيح';
    }
  }

  String _formatDateOnly(String? dateKey) {
    try {
      if (dateKey == null || dateKey.isEmpty) return 'غير معروف';
      final parts = dateKey.split('-');
      if (parts.length != 3) return dateKey;

      // Safely access array elements
      final yearStr = parts.length > 0 ? parts[0] : '0';
      final monthStr = parts.length > 1 ? parts[1] : '0';
      final dayStr = parts.length > 2 ? parts[2] : '0';

      final y = int.tryParse(yearStr) ?? 0;
      final m = int.tryParse(monthStr) ?? 0;
      final d = int.tryParse(dayStr) ?? 0;

      if (y == 0 || m == 0 || d == 0) return dateKey;
      return '$d/$m/$y';
    } catch (_) {
      return dateKey ?? 'غير معروف';
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 6),
        Expanded(child: Divider(color: color.withOpacity(0.2))),
      ],
    );
  }

  Widget _buildDistributionTile(Map<String, dynamic> distribution) {
    final idStr = distribution['_id']?.toString() ?? '';
    final distId = idStr.length >= 8
        ? idStr.substring(0, 8)
        : (idStr.isEmpty ? 'غير معروف' : idStr);
    final createdAt = _formatDateTime(distribution['createdAt']);
    final quantityValue = distribution['quantity'] ?? 0;
    final totalAmountValue = distribution['totalAmount'] ?? 0;

    final quantity = quantityValue is num
        ? quantityValue.toInt()
        : (quantityValue is String ? int.tryParse(quantityValue) ?? 0 : 0);
    final totalAmount = totalAmountValue is num
        ? totalAmountValue.toDouble()
        : (totalAmountValue is String
              ? double.tryParse(totalAmountValue) ?? 0.0
              : 0.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.orange.withOpacity(0.1),
          child: const Icon(Icons.outbound, size: 18, color: Colors.orange),
        ),
        title: Text(
          'توزيع #$distId',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          'الكمية: $quantity وحدة • ج.م ${totalAmount.toStringAsFixed(2)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              createdAt,
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
        onTap: () => _navigateToDistributionDetails(distribution),
      ),
    );
  }

  void _navigateToDistributionDetails(Map<String, dynamic> distribution) async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get detailed distribution data with debt information
      final distributionId = distribution['_id']?.toString();
      if (distributionId == null) {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorDialog('خطأ: معرف التوزيع غير صحيح');
        return;
      }

      final detailedDistribution = await _distributionService
          .getDistributionById(distributionId);

      // Debug: Print the received data
      print('Detailed Distribution Data: $detailedDistribution');
      print(
        'Outstanding Before: ${detailedDistribution['outstandingBeforeDistribution']}',
      );
      print(
        'Outstanding After: ${detailedDistribution['outstandingAfterDistribution']}',
      );
      print('Total Amount: ${detailedDistribution['totalAmount']}');
      print(
        'Total Distributions Before: ${detailedDistribution['totalDistributionsBeforeThis']}',
      );
      print(
        'Total Distributions Up To: ${detailedDistribution['totalDistributionsUpToThis']}',
      );
      print(
        'Total Payments Up To: ${detailedDistribution['totalPaymentsUpToThis']}',
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show detailed distribution dialog
      showDialog(
        context: context,
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('تفاصيل التوزيع #${distributionId.substring(0, 8)}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Debt progression section
                  _buildDebtProgressionSection(detailedDistribution),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Distribution details section
                  _buildDistributionDetailsSection(detailedDistribution),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      _showErrorDialog('خطأ في تحميل تفاصيل التوزيع: $e');
    }
  }

  void _navigateToPaymentDetails(Map<String, dynamic> payment) {
    // TODO: Navigate to payment details page
    // For now, show a dialog with payment details
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'تفاصيل الدفعة #${payment['_id']?.toString().substring(0, 8) ?? 'غير معروف'}',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('إسم الموظف', payment['user']['username']),
              _buildDetailRow(
                'إجمالي المستحق',
                'ج.م ${payment['totalPrice'] ?? 0}',
              ),
              _buildDetailRow(
                'المدفوع',
                'ج.م ${payment['paidAmount'] ?? payment['amount'] ?? 0}',
              ),
              _buildDetailRow('الخصم', 'ج.م ${payment['discount'] ?? 0}'),
              _buildDetailRow(
                'المتبقي',
                'ج.م ${((payment['totalPrice'] ?? 0) - (payment['paidAmount'] ?? payment['amount'] ?? 0) - (payment['discount'] ?? 0)).toStringAsFixed(2)}',
              ),
              _buildDetailRow(
                'طريقة الدفع',
                _getPaymentMethodText(
                  payment['paymentMethod']?.toString() ?? '',
                ),
              ),
              _buildDetailRow(
                'تاريخ الدفع',
                _formatDateTime(payment['createdAt']),
              ),
              if (payment['employee'] != null)
                _buildDetailRow(
                  'جامع المال',
                  payment['employee']['username'] ??
                      payment['employee']['name'] ??
                      'غير معروف',
                ),
              if (payment['notes'] != null &&
                  payment['notes'].toString().isNotEmpty)
                _buildDetailRow('ملاحظات', payment['notes'].toString()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodText(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'نقداً';
      case 'bank':
        return 'تحويل بنكي';
      case 'credit':
        return 'آجل';
      default:
        return method.isEmpty ? 'غير محدد' : method;
    }
  }

  Widget _buildDebtProgressionSection(Map<String, dynamic> distribution) {
    final debtBefore = (distribution['outstandingBeforeDistribution'] ?? 0)
        .toDouble();
    final distributionAmount = (distribution['totalAmount'] ?? 0).toDouble();
    final debtAfter = (distribution['outstandingAfterDistribution'] ?? 0)
        .toDouble();

    // Debug: Print the values being used
    print('Debt Before: $debtBefore');
    print('Distribution Amount: $distributionAmount');
    print('Debt After: $debtAfter');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'تطور المديونية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Debt before
          _buildDebtRow(
            'المديونية قبل التوزيع',
            debtBefore,
            Icons.arrow_back,
            Colors.orange,
          ),

          const SizedBox(height: 8),

          // Distribution amount
          _buildDebtRow(
            'مبلغ التوزيع',
            distributionAmount,
            Icons.add,
            Colors.red,
          ),

          const SizedBox(height: 8),

          // Debt after
          _buildDebtRow(
            'المديونية بعد التوزيع',
            debtAfter,
            Icons.arrow_forward,
            Colors.green,
          ),

          // Show calculation breakdown if values are 0
          if (debtBefore == 0 && debtAfter == 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفاصيل الحساب:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'إجمالي التوزيعات قبل هذا التوزيع: ج.م ${distribution['totalDistributionsBeforeThis'] ?? 0}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                  Text(
                    'إجمالي المدفوعات حتى تاريخ التوزيع: ج.م ${distribution['totalPaymentsUpToThis'] ?? 0}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                  Text(
                    'المديونية قبل التوزيع = التوزيعات - المدفوعات = ج.م ${debtBefore.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebtRow(
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        const Spacer(),
        Text(
          'ج.م ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionDetailsSection(Map<String, dynamic> distribution) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory, color: Colors.purple, size: 20),
            const SizedBox(width: 8),
            Text(
              'تفاصيل التوزيع',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildDetailRow('الكمية', '${distribution['quantity'] ?? 0} وحدة'),
        _buildDetailRow(
          'الوزن القائم',
          '${distribution['grossWeight'] ?? 0} كجم',
        ),
        _buildDetailRow(
          'الوزن الفارغ',
          '${distribution['emptyWeight'] ?? 0} كجم',
        ),
        _buildDetailRow(
          'الوزن الصافي',
          '${distribution['netWeight'] ?? 0} كجم',
        ),
        _buildDetailRow('سعر الكيلو', 'ج.م ${distribution['price'] ?? 0}'),
        _buildDetailRow(
          'إجمالي المبلغ',
          'ج.م ${distribution['totalAmount'] ?? 0}',
        ),
        _buildDetailRow(
          'تاريخ التوزيع',
          _formatDateTime(
            distribution['distributionDate'] ?? distribution['createdAt'],
          ),
        ),
        if (distribution['user'] != null)
          _buildDetailRow(
            'الموظف',
            distribution['user']['username'] ??
                distribution['user']['name'] ??
                'غير معروف',
          ),
      ],
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
              child: const Text('موافق'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyHistoryGroup {
  final String? dateKey; // yyyy-mm-dd
  final List<Map<String, dynamic>> payments = [];
  final List<Map<String, dynamic>> distributions = [];

  _DailyHistoryGroup({required this.dateKey});
}
