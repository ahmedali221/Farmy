import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/services/loading_api_service.dart';
import '../../../../../core/services/distribution_api_service.dart';
import '../../../../../core/services/payment_api_service.dart';

class CustomerHistoryView extends StatefulWidget {
  final Map<String, dynamic> customer;

  const CustomerHistoryView({super.key, required this.customer});

  @override
  State<CustomerHistoryView> createState() => _CustomerHistoryViewState();
}

class _CustomerHistoryViewState extends State<CustomerHistoryView> {
  late final LoadingApiService _loadingService;
  late final DistributionApiService _distributionService;
  late final PaymentApiService _paymentService;

  List<_DailyCustomerHistoryGroup> _dailyGroups = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadingService = serviceLocator<LoadingApiService>();
    _distributionService = serviceLocator<DistributionApiService>();
    _paymentService = serviceLocator<PaymentApiService>();
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
        _loadingService.getAllLoadings(),
        _distributionService.getAllDistributions(),
        _paymentService.getAllPayments(),
      ]);

      final allLoadings = results[0];
      final allDistributions = results[1];
      final allPayments = results[2];

      // Filter data for this specific customer
      final customerLoadings = allLoadings
          .where((loading) => loading['customer']?['_id'] == customerId)
          .toList();

      final customerDistributions = allDistributions
          .where(
            (distribution) => distribution['customer']?['_id'] == customerId,
          )
          .toList();

      final customerPayments = allPayments
          .where((payment) => payment['customer']?['_id'] == customerId)
          .toList();

      setState(() {
        _dailyGroups = _groupHistoryByDay(
          loadings: customerLoadings,
          distributions: customerDistributions,
          payments: customerPayments,
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

  List<_DailyCustomerHistoryGroup> _groupHistoryByDay({
    required List<Map<String, dynamic>> loadings,
    required List<Map<String, dynamic>> distributions,
    required List<Map<String, dynamic>> payments,
  }) {
    String keyFor(String? iso) {
      try {
        if (iso == null) return '0000-00-00';
        final dt = DateTime.parse(iso).toLocal();
        return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        return '0000-00-00';
      }
    }

    final Map<String, _DailyCustomerHistoryGroup> dateToGroup = {};

    void addLoading(Map<String, dynamic> m) {
      final k = keyFor(m['createdAt']);
      dateToGroup.putIfAbsent(k, () => _DailyCustomerHistoryGroup(dateKey: k));
      dateToGroup[k]!.loadings.add(m);
    }

    void addDistribution(Map<String, dynamic> m) {
      final k = keyFor(m['createdAt']);
      dateToGroup.putIfAbsent(k, () => _DailyCustomerHistoryGroup(dateKey: k));
      dateToGroup[k]!.distributions.add(m);
    }

    void addPayment(Map<String, dynamic> m) {
      final k = keyFor(m['createdAt']);
      dateToGroup.putIfAbsent(k, () => _DailyCustomerHistoryGroup(dateKey: k));
      dateToGroup[k]!.payments.add(m);
    }

    for (final m in loadings) {
      addLoading(m);
    }
    for (final m in distributions) {
      addDistribution(m);
    }
    for (final m in payments) {
      addPayment(m);
    }

    final groups = dateToGroup.values.toList();
    groups.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    // Optional: sort inside-day items newest first
    for (final g in groups) {
      g.loadings.sort(
        (a, b) => (b['createdAt'] ?? '').toString().compareTo(
          (a['createdAt'] ?? '').toString(),
        ),
      );
      g.distributions.sort(
        (a, b) => (b['createdAt'] ?? '').toString().compareTo(
          (a['createdAt'] ?? '').toString(),
        ),
      );
      g.payments.sort(
        (a, b) => (b['createdAt'] ?? '').toString().compareTo(
          (a['createdAt'] ?? '').toString(),
        ),
      );
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
                icon: const Icon(Icons.refresh),
                onPressed: _loadAllData,
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildErrorWidget()
              : _buildUnifiedDailyHistory(),
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
}

class _DailyCustomerHistoryGroup {
  final String dateKey; // yyyy-mm-dd
  final List<Map<String, dynamic>> loadings = [];
  final List<Map<String, dynamic>> distributions = [];
  final List<Map<String, dynamic>> payments = [];

  _DailyCustomerHistoryGroup({required this.dateKey});
}

extension on _CustomerHistoryViewState {
  Widget _buildUnifiedDailyHistory() {
    if (_dailyGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'لا يوجد سجل لهذا العميل',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final group = _dailyGroups[index];
            return _buildDayCard(context, group);
          }, childCount: _dailyGroups.length),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _buildDayCard(BuildContext context, _DailyCustomerHistoryGroup group) {
    final dateLabel = _formatDateOnly(group.dateKey);
    final hasLoadings = group.loadings.isNotEmpty;
    final hasDistributions = group.distributions.isNotEmpty;
    final hasPayments = group.payments.isNotEmpty;

    // Day totals (quick summary)
    final double dayDistributionValue = group.distributions.fold(
      0.0,
      (sum, m) => sum + ((m['totalAmount'] ?? 0) as num).toDouble(),
    );
    final double dayPayments = group.payments.fold(
      0.0,
      (sum, m) =>
          sum + ((m['amount'] ?? m['paidAmount'] ?? 0) as num).toDouble(),
    );
    final double dayTotal =
        dayDistributionValue; // only distributions contribute to amount
    final double dayRemaining = (dayTotal - dayPayments) < 0
        ? 0
        : (dayTotal - dayPayments);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 3,
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
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _chip(
                          'التحميلات: ${group.loadings.length}',
                          Theme.of(context).colorScheme.primary,
                        ),
                        _chip(
                          'التوزيعات: ${group.distributions.length}',
                          Theme.of(context).colorScheme.primary,
                        ),
                        _chip(
                          'المدفوعات: ${group.payments.length}',
                          Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (dayDistributionValue > 0)
                    _summaryPill(
                      'قيمة التوزيعات',
                      dayDistributionValue,
                      Theme.of(context).colorScheme.primary,
                    ),
                  if (dayPayments > 0)
                    _summaryPill(
                      'المدفوعات',
                      dayPayments,
                      Theme.of(context).colorScheme.primary,
                    ),
                  if (dayPayments > 0)
                    _summaryPill(
                      'المتبقي',
                      dayRemaining,
                      dayRemaining > 0 ? Colors.red : Colors.green,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (hasLoadings) ...[
                _sectionHeader(
                  'طلبات التحميل',
                  Icons.local_shipping,
                  Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                for (final m in group.loadings)
                  _buildLoadingOrderItem(context, m),
                const SizedBox(height: 12),
              ],

              if (hasDistributions) ...[
                _sectionHeader(
                  'طلبات التوزيع',
                  Icons.outbound,
                  Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                for (final m in group.distributions)
                  _buildDistributionItem(context, m),
                const SizedBox(height: 12),
              ],

              if (hasPayments) ...[
                _sectionHeader(
                  'المدفوعات',
                  Icons.payment,
                  Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                for (final m in group.payments)
                  _buildPaymentItem(context, m, group),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _summaryPill(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_money, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$title: ج.م ${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
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

  Widget _buildLoadingOrderItem(
    BuildContext context,
    Map<String, dynamic> loadingOrder,
  ) {
    final orderId =
        loadingOrder['_id']?.toString().substring(0, 8) ?? 'غير معروف';
    final createdAt = _formatDateTime(loadingOrder['createdAt']);
    final quantity = (loadingOrder['quantity'] ?? 0) as num;
    final netWeight = (loadingOrder['netWeight'] ?? 0) as num;
    // final totalLoading = (loadingOrder['totalLoading'] ?? 0) as num; // hidden per request
    final chickenType = loadingOrder['chickenType'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.15)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.1),
                  child: const Icon(
                    Icons.local_shipping,
                    size: 16,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'طلب تحميل #$orderId',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  createdAt,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _kvTile(
              'الكمية',
              '${quantity.toInt()} وحدة',
              Icons.inventory,
              Colors.purple,
            ),
            _kvTile(
              'الوزن الصافي',
              '${netWeight.toDouble().toStringAsFixed(1)} كجم',
              Icons.scale_outlined,
              Colors.green,
            ),
            if (chickenType != null)
              _kvTile(
                'نوع الدجاج',
                chickenType['name'] ?? 'غير معروف',
                Icons.pets,
                Colors.brown,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionItem(
    BuildContext context,
    Map<String, dynamic> distribution,
  ) {
    final distId =
        distribution['_id']?.toString().substring(0, 8) ?? 'غير معروف';
    final createdAt = _formatDateTime(distribution['createdAt']);
    final quantity = (distribution['quantity'] ?? 0) as num;
    final netWeight = (distribution['netWeight'] ?? 0) as num;
    final totalAmount = (distribution['totalAmount'] ?? 0) as num;
    final employee = distribution['employee'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.15)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.1),
                  child: const Icon(
                    Icons.outbound,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'توزيع #$distId',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  createdAt,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _kvTile(
              'الكمية',
              '${quantity.toInt()} وحدة',
              Icons.inventory,
              Colors.purple,
            ),
            _kvTile(
              'الوزن الصافي',
              '${netWeight.toDouble().toStringAsFixed(1)} كجم',
              Icons.scale_outlined,
              Colors.green,
            ),
            _kvTile(
              'إجمالي المبلغ',
              'ج.م ${totalAmount.toDouble().toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.red,
            ),
            if (employee != null)
              _kvTile(
                'الموظف',
                employee['username'] ?? 'غير معروف',
                Icons.person,
                Colors.brown,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentItem(
    BuildContext context,
    Map<String, dynamic> payment,
    _DailyCustomerHistoryGroup group,
  ) {
    final paymentId = payment['_id']?.toString().substring(0, 8) ?? 'غير معروف';
    final createdAt = _formatDateTime(payment['createdAt']);
    final totalPrice = ((payment['totalPrice'] ?? 0) as num).toDouble();
    final discount = ((payment['discount'] ?? 0) as num).toDouble();
    final paidAmount =
        ((payment['paidAmount'] ?? payment['amount'] ?? 0) as num).toDouble();
    final remainingAfter =
        ((payment['remainingAmount'] ?? (totalPrice - paidAmount - discount))
                as num)
            .toDouble()
            .clamp(0, double.infinity);
    final method = (payment['paymentMethod'] ?? '').toString();
    final notes = payment['notes']?.toString();
    final employee = payment['employee'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.15)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.1),
                  child: const Icon(
                    Icons.payment,
                    size: 16,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'دفعة #$paymentId',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  createdAt,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),

            _kvTile(
              'إجمالي المستحق وقتها',
              'ج.م ${totalPrice.toStringAsFixed(2)}',
              Icons.pending_actions,
              Colors.orange,
            ),
            const SizedBox(height: 6),
            if (discount > 0)
              _kvTile(
                'الخصم',
                'ج.م ${discount.toStringAsFixed(2)}',
                Icons.percent,
                Colors.deepOrange,
              ),
            _kvTile(
              'المدفوع',
              'ج.م ${paidAmount.toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.green,
            ),
            _kvTile(
              'المتبقي بعد الدفع',
              'ج.م ${remainingAfter.toStringAsFixed(2)}',
              Icons.check_circle,
              remainingAfter > 0 ? Colors.red : Colors.green,
            ),
            if (method.isNotEmpty)
              _kvTile(
                'طريقة الدفع',
                _getPaymentMethodText(method),
                Icons.payment,
                Colors.blue,
              ),
            if (employee != null)
              _kvTile(
                'الموظف',
                employee['username'] ?? 'غير معروف',
                Icons.person,
                Colors.brown,
              ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'ملاحظات: $notes',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kvTile(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          textDirection: TextDirection.rtl,
        ),
        subtitle: Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textDirection: TextDirection.rtl,
        ),
        dense: true,
      ),
    );
  }

  // Deprecated: replaced by _kvTile

  String _formatDateOnly(String dateKey) {
    try {
      final parts = dateKey.split('-');
      if (parts.length != 3) return dateKey;
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      return '$d/$m/$y';
    } catch (_) {
      return dateKey;
    }
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

  String _getPaymentMethodText(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'نقداً';
      case 'bank':
        return 'تحويل بنكي';
      case 'credit':
        return 'آجل';
      default:
        return method;
    }
  }
}
