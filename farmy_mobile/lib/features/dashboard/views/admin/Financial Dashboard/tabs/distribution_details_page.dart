import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui show TextDirection;
import '../../../../../../core/di/service_locator.dart';
import '../../../../../../core/services/distribution_api_service.dart';

class DistributionDetailsPage extends StatefulWidget {
  final String date;
  final num totalNetWeight;

  const DistributionDetailsPage({
    super.key,
    required this.date,
    required this.totalNetWeight,
  });

  @override
  State<DistributionDetailsPage> createState() =>
      _DistributionDetailsPageState();
}

class _DistributionDetailsPageState extends State<DistributionDetailsPage> {
  final DistributionApiService _distributionApi =
      serviceLocator<DistributionApiService>();

  bool _loading = false;
  List<Map<String, dynamic>> _distributions = [];
  Map<String, num> _chickenTypeTotals = {};
  Map<String, num> _customerTotals = {};
  num _totalDistributedWeight = 0;

  @override
  void initState() {
    super.initState();
    _fetchDistributions();
  }

  Future<void> _fetchDistributions() async {
    setState(() => _loading = true);
    try {
      final distributions = await _distributionApi.getDistributionsByDate(
        widget.date,
      );

      // Calculate totals by chicken type and customer
      final Map<String, num> chickenTypeTotals = {};
      final Map<String, num> customerTotals = {};
      num totalDistributedWeight = 0;

      for (final distribution in distributions) {
        final chickenType = distribution['chickenType']?['name'] ?? 'غير محدد';
        final customer = distribution['customer']?['name'] ?? 'غير محدد';
        final netWeight = (distribution['netWeight'] ?? 0) as num;

        chickenTypeTotals[chickenType] =
            (chickenTypeTotals[chickenType] ?? 0) + netWeight;
        customerTotals[customer] = (customerTotals[customer] ?? 0) + netWeight;
        totalDistributedWeight += netWeight;
      }

      setState(() {
        _distributions = distributions;
        _chickenTypeTotals = chickenTypeTotals;
        _customerTotals = customerTotals;
        _totalDistributedWeight = totalDistributedWeight;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تحميل بيانات التوزيع: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تفاصيل التوزيع - ${widget.date}'),
          actions: [
            IconButton(
              onPressed: _loading ? null : _fetchDistributions,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    // Summary Card
                    Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ملخص التوزيع',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryTile(
                                    title: 'إجمالي الوزن الموزع',
                                    value: _totalDistributedWeight,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _SummaryTile(
                                    title: 'عدد التوزيعات',
                                    value: _distributions.length.toDouble(),
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tab Bar
                    TabBar(
                      tabs: const [
                        Tab(text: 'حسب نوع الفراخ'),
                        Tab(text: 'حسب العميل'),
                        Tab(text: 'التفاصيل'),
                      ],
                    ),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Chicken Type Summary
                          _buildChickenTypeSummary(),
                          // Customer Summary
                          _buildCustomerSummary(),
                          // Detailed List
                          _buildDetailedList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildChickenTypeSummary() {
    if (_chickenTypeTotals.isEmpty) {
      return const Center(child: Text('لا توجد بيانات توزيع لهذا اليوم'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _chickenTypeTotals.length,
      itemBuilder: (context, index) {
        final entry = _chickenTypeTotals.entries.elementAt(index);
        final percentage = _totalDistributedWeight > 0
            ? (entry.value / _totalDistributedWeight * 100)
            : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  child: Icon(Icons.pets, color: Colors.orange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat('#,##0.###').format(entry.value)} كجم',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${NumberFormat('#,##0.#').format(percentage)}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'من الإجمالي',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerSummary() {
    if (_customerTotals.isEmpty) {
      return const Center(child: Text('لا توجد بيانات توزيع لهذا اليوم'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _customerTotals.length,
      itemBuilder: (context, index) {
        final entry = _customerTotals.entries.elementAt(index);
        final percentage = _totalDistributedWeight > 0
            ? (entry.value / _totalDistributedWeight * 100)
            : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: Icon(Icons.person, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat('#,##0.###').format(entry.value)} كجم',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${NumberFormat('#,##0.#').format(percentage)}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'من الإجمالي',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailedList() {
    if (_distributions.isEmpty) {
      return const Center(child: Text('لا توجد بيانات توزيع لهذا اليوم'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _distributions.length,
      itemBuilder: (context, index) {
        final distribution = _distributions[index];
        return _DistributionCard(distribution: distribution);
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final num value;
  final Color color;

  const _SummaryTile({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.05),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            title.contains('عدد')
                ? '${NumberFormat('#,##0').format(value)}'
                : '${NumberFormat('#,##0.###').format(value)} كجم',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  final Map<String, dynamic> distribution;

  const _DistributionCard({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final customer = distribution['customer']?['name'] ?? 'غير محدد';
    final chickenType = distribution['chickenType']?['name'] ?? 'غير محدد';
    final user = distribution['user']?['username'] ?? 'غير محدد';
    final quantity = (distribution['quantity'] ?? 0) as num;
    final grossWeight = (distribution['grossWeight'] ?? 0) as num;
    final netWeight = (distribution['netWeight'] ?? 0) as num;
    final price = (distribution['price'] ?? 0) as num;
    final totalAmount = (distribution['totalAmount'] ?? 0) as num;
    final distributionDate = distribution['distributionDate']?.toString() ?? '';

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(distributionDate);
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    customer,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (parsedDate != null)
                  Text(
                    DateFormat('HH:mm').format(parsedDate),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    label: 'نوع الفراخ',
                    value: chickenType,
                    icon: Icons.pets,
                    color: Colors.orange,
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    label: 'المستخدم',
                    value: user,
                    icon: Icons.person,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    label: 'العدد',
                    value: '${NumberFormat('#,##0').format(quantity)}',
                    icon: Icons.numbers,
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    label: 'الوزن القائم',
                    value:
                        '${NumberFormat('#,##0.###').format(grossWeight)} كجم',
                    icon: Icons.scale,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    label: 'الوزن الصافي',
                    value: '${NumberFormat('#,##0.###').format(netWeight)} كجم',
                    icon: Icons.straighten,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    label: 'السعر',
                    value: '${NumberFormat('#,##0.###').format(price)} ج.م/كجم',
                    icon: Icons.attach_money,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'إجمالي المبلغ: ${NumberFormat('#,##0.###').format(totalAmount)} ج.م',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
