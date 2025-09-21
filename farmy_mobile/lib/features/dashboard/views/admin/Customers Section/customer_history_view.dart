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

class _CustomerHistoryViewState extends State<CustomerHistoryView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final LoadingApiService _loadingService;
  late final DistributionApiService _distributionService;
  late final PaymentApiService _paymentService;

  List<Map<String, dynamic>> _loadingOrders = [];
  List<Map<String, dynamic>> _distributions = [];
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadingService = serviceLocator<LoadingApiService>();
    _distributionService = serviceLocator<DistributionApiService>();
    _paymentService = serviceLocator<PaymentApiService>();
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        _loadingOrders = customerLoadings;
        _distributions = customerDistributions;
        _payments = customerPayments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.local_shipping), text: 'التحميلات'),
                Tab(icon: Icon(Icons.outbound), text: 'التوزيعات'),
                Tab(icon: Icon(Icons.payment), text: 'المدفوعات'),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _LoadingHistoryTab(
                      customer: widget.customer,
                      loadingOrders: _loadingOrders,
                    ),
                    _DistributionHistoryTab(
                      customer: widget.customer,
                      distributions: _distributions,
                    ),
                    _PaymentHistoryTab(
                      customer: widget.customer,
                      payments: _payments,
                    ),
                  ],
                ),
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

class _LoadingHistoryTab extends StatelessWidget {
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> loadingOrders;

  const _LoadingHistoryTab({
    required this.customer,
    required this.loadingOrders,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate totals
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

    return CustomScrollView(
      slivers: [
        // Summary Card
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
                    Row(
                      children: [
                        Icon(
                          Icons.local_shipping,
                          color: Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ملخص التحميلات',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'إجمالي الطلبات',
                            loadingOrders.length.toString(),
                            Icons.inventory,
                            Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            'إجمالي الكمية',
                            '${totalQuantity.toInt()}',
                            Icons.scale,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'إجمالي الوزن',
                            '${totalWeight.toStringAsFixed(1)} كجم',
                            Icons.scale_outlined,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            'إجمالي القيمة',
                            'ج.م ${totalValue.toStringAsFixed(2)}',
                            Icons.attach_money,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
                      'لا توجد تحميلات',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
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
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
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
    final emptyWeight = (loadingOrder['emptyWeight'] ?? 0) as num;
    final netWeight = (loadingOrder['netWeight'] ?? 0) as num;
    final totalLoading = (loadingOrder['totalLoading'] ?? 0) as num;
    final chickenType = loadingOrder['chickenType'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: const Icon(Icons.local_shipping, color: Colors.blue),
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

              // Details
              _buildDetailRow(
                'الكمية',
                '${quantity.toInt()} وحدة',
                Icons.inventory,
                Colors.purple,
              ),
              _buildDetailRow(
                'الوزن القائم',
                '${grossWeight.toDouble().toStringAsFixed(1)} كجم',
                Icons.scale,
                Colors.red,
              ),
              _buildDetailRow(
                'الوزن الفارغ',
                '${emptyWeight.toDouble().toStringAsFixed(1)} كجم',
                Icons.scale_outlined,
                Colors.orange,
              ),
              _buildDetailRow(
                'الوزن الصافي',
                '${netWeight.toDouble().toStringAsFixed(1)} كجم',
                Icons.scale_outlined,
                Colors.green,
              ),
              _buildDetailRow(
                'إجمالي التحميل',
                'ج.م ${totalLoading.toDouble().toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.red,
              ),

              if (chickenType != null)
                _buildDetailRow(
                  'نوع الدجاج',
                  chickenType['name'] ?? 'غير معروف',
                  Icons.pets,
                  Colors.brown,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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

class _DistributionHistoryTab extends StatelessWidget {
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> distributions;

  const _DistributionHistoryTab({
    required this.customer,
    required this.distributions,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate totals
    final double totalWeight = distributions.fold(
      0.0,
      (sum, dist) => sum + ((dist['netWeight'] ?? 0) as num).toDouble(),
    );
    final double totalValue = distributions.fold(
      0.0,
      (sum, dist) => sum + ((dist['totalAmount'] ?? 0) as num).toDouble(),
    );
    final double totalQuantity = distributions.fold(
      0.0,
      (sum, dist) => sum + ((dist['quantity'] ?? 0) as num).toDouble(),
    );

    return CustomScrollView(
      slivers: [
        // Summary Card
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
                    Row(
                      children: [
                        Icon(Icons.outbound, color: Colors.orange, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'ملخص التوزيعات',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'إجمالي التوزيعات',
                            distributions.length.toString(),
                            Icons.inventory,
                            Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            'إجمالي الكمية',
                            '${totalQuantity.toInt()}',
                            Icons.scale,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'إجمالي الوزن',
                            '${totalWeight.toStringAsFixed(1)} كجم',
                            Icons.scale_outlined,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            'إجمالي القيمة',
                            'ج.م ${totalValue.toStringAsFixed(2)}',
                            Icons.attach_money,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Distributions List
        if (distributions.isEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.outbound_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد توزيعات',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final distribution = distributions[index];
              return _buildDistributionCard(context, distribution);
            }, childCount: distributions.length),
          ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionCard(
    BuildContext context,
    Map<String, dynamic> distribution,
  ) {
    final distId =
        distribution['_id']?.toString().substring(0, 8) ?? 'غير معروف';
    final createdAt = _formatDateTime(distribution['createdAt']);
    final quantity = (distribution['quantity'] ?? 0) as num;
    final grossWeight = (distribution['grossWeight'] ?? 0) as num;
    final emptyWeight = (distribution['emptyWeight'] ?? 0) as num;
    final netWeight = (distribution['netWeight'] ?? 0) as num;
    final price = (distribution['price'] ?? 0) as num;
    final totalAmount = (distribution['totalAmount'] ?? 0) as num;
    final employee = distribution['employee'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    child: const Icon(Icons.outbound, color: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'توزيع #$distId',
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

              // Details
              _buildDetailRow(
                'الكمية',
                '${quantity.toInt()} وحدة',
                Icons.inventory,
                Colors.purple,
              ),
              _buildDetailRow(
                'الوزن القائم',
                '${grossWeight.toDouble().toStringAsFixed(1)} كجم',
                Icons.scale,
                Colors.red,
              ),
              _buildDetailRow(
                'الوزن الفارغ',
                '${emptyWeight.toDouble().toStringAsFixed(1)} كجم',
                Icons.scale_outlined,
                Colors.orange,
              ),
              _buildDetailRow(
                'الوزن الصافي',
                '${netWeight.toDouble().toStringAsFixed(1)} كجم',
                Icons.scale_outlined,
                Colors.green,
              ),
              _buildDetailRow(
                'السعر',
                'ج.م ${price.toDouble().toStringAsFixed(2)}/كجم',
                Icons.attach_money,
                Colors.blue,
              ),
              _buildDetailRow(
                'إجمالي المبلغ',
                'ج.م ${totalAmount.toDouble().toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.red,
              ),

              if (employee != null)
                _buildDetailRow(
                  'الموظف',
                  employee['username'] ?? 'غير معروف',
                  Icons.person,
                  Colors.brown,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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

class _PaymentHistoryTab extends StatelessWidget {
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> payments;

  const _PaymentHistoryTab({required this.customer, required this.payments});

  @override
  Widget build(BuildContext context) {
    // Calculate totals
    final double totalPaid = payments.fold(
      0.0,
      (sum, payment) => sum + ((payment['amount'] ?? 0) as num).toDouble(),
    );

    return CustomScrollView(
      slivers: [
        // Summary Card
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
                    Row(
                      children: [
                        Icon(Icons.payment, color: Colors.green, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'ملخص المدفوعات',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'إجمالي المدفوعات',
                            payments.length.toString(),
                            Icons.receipt,
                            Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            'إجمالي المبلغ',
                            'ج.م ${totalPaid.toStringAsFixed(2)}',
                            Icons.attach_money,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Payments List
        if (payments.isEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.payment_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد مدفوعات',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final payment = payments[index];
              return _buildPaymentCard(context, payment);
            }, childCount: payments.length),
          ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, Map<String, dynamic> payment) {
    final paymentId = payment['_id']?.toString().substring(0, 8) ?? 'غير معروف';
    final createdAt = _formatDateTime(payment['createdAt']);
    final amount = (payment['amount'] ?? 0) as num;
    final paymentMethod = payment['paymentMethod'] ?? 'غير محدد';
    final notes = payment['notes']?.toString();
    final employee = payment['employee'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green.withOpacity(0.1),
                    child: const Icon(Icons.payment, color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'دفعة #$paymentId',
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

              // Details
              _buildDetailRow(
                'المبلغ',
                'ج.م ${amount.toDouble().toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.green,
              ),
              _buildDetailRow(
                'طريقة الدفع',
                _getPaymentMethodText(paymentMethod),
                Icons.payment,
                Colors.blue,
              ),

              if (employee != null)
                _buildDetailRow(
                  'الموظف',
                  employee['username'] ?? 'غير معروف',
                  Icons.person,
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
        return method;
    }
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
