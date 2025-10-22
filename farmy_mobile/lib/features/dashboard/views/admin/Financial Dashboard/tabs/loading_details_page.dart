import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui show TextDirection;
import '../../../../../../core/di/service_locator.dart';
import '../../../../../../core/services/loading_api_service.dart';

class LoadingDetailsPage extends StatefulWidget {
  final String date;
  final num totalNetWeight;

  const LoadingDetailsPage({
    super.key,
    required this.date,
    required this.totalNetWeight,
  });

  @override
  State<LoadingDetailsPage> createState() => _LoadingDetailsPageState();
}

class _LoadingDetailsPageState extends State<LoadingDetailsPage> {
  final LoadingApiService _loadingApi = serviceLocator<LoadingApiService>();

  bool _loading = false;
  List<Map<String, dynamic>> _loadings = [];
  Map<String, num> _chickenTypeTotals = {};
  num _totalRemainingWeight = 0;
  num _totalMoneySpent = 0;

  @override
  void initState() {
    super.initState();
    _fetchLoadings();
  }

  Future<void> _fetchLoadings() async {
    setState(() => _loading = true);
    try {
      final loadings = await _loadingApi.getLoadingsByDate(widget.date);

      // Calculate totals by chicken type
      final Map<String, num> chickenTypeTotals = {};
      num totalRemainingWeight = 0;
      num totalMoneySpent = 0;

      for (final loading in loadings) {
        final chickenType = loading['chickenType']?['name'] ?? 'غير محدد';
        final remainingWeight = (loading['remainingNetWeight'] ?? 0) as num;
        final moneySpent = (loading['totalLoading'] ?? 0) as num;

        chickenTypeTotals[chickenType] =
            (chickenTypeTotals[chickenType] ?? 0) + remainingWeight;
        totalRemainingWeight += remainingWeight;
        totalMoneySpent += moneySpent;
      }

      setState(() {
        _loadings = loadings;
        _chickenTypeTotals = chickenTypeTotals;
        _totalRemainingWeight = totalRemainingWeight;
        _totalMoneySpent = totalMoneySpent;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تحميل بيانات التحميل: $e')));
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
          title: Text('تفاصيل التحميل - ${widget.date}'),
          actions: [
            IconButton(
              onPressed: _loading ? null : _fetchLoadings,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
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
                            'ملخص التحميل',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryTile(
                                  title: 'إجمالي الوزن الصافي',
                                  value: widget.totalNetWeight,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _SummaryTile(
                                  title: 'الوزن المتبقي',
                                  value: _totalRemainingWeight,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryTile(
                                  title: 'إجمالي المبلغ المنفق',
                                  value: _totalMoneySpent,
                                  color: Colors.red,
                                  isMoney: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Chicken Type Summary
                  if (_chickenTypeTotals.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'الوزن المتبقي حسب نوع الفراخ',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Chicken Type Cards
                  if (_chickenTypeTotals.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _chickenTypeTotals.length,
                        itemBuilder: (context, index) {
                          final entry = _chickenTypeTotals.entries.elementAt(
                            index,
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.withOpacity(0.1),
                                child: Icon(Icons.pets, color: Colors.blue),
                              ),
                              title: Text(entry.key),
                              trailing: Text(
                                '${NumberFormat('#,##0.###').format(entry.value)} كجم',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Detailed Loading List
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'تفاصيل طلبات التحميل',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _loadings.length,
                            itemBuilder: (context, index) {
                              final loading = _loadings[index];
                              return _LoadingCard(loading: loading);
                            },
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

class _SummaryTile extends StatelessWidget {
  final String title;
  final num value;
  final Color color;
  final bool isMoney;

  const _SummaryTile({
    required this.title,
    required this.value,
    required this.color,
    this.isMoney = false,
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
            isMoney
                ? '${NumberFormat('#,##0.###').format(value)} ج.م'
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

class _LoadingCard extends StatelessWidget {
  final Map<String, dynamic> loading;

  const _LoadingCard({required this.loading});

  @override
  Widget build(BuildContext context) {
    final chickenType = loading['chickenType']?['name'] ?? 'غير محدد';
    final supplier = loading['supplier']?['name'] ?? 'غير محدد';
    final user = loading['user']?['username'] ?? 'غير محدد';
    final quantity = (loading['quantity'] ?? 0) as num;
    final grossWeight = (loading['grossWeight'] ?? 0) as num;
    final netWeight = (loading['netWeight'] ?? 0) as num;
    final remainingWeight = (loading['remainingNetWeight'] ?? 0) as num;
    final distributedWeight = netWeight - remainingWeight;
    final totalLoading = (loading['totalLoading'] ?? 0) as num;
    final loadingDate = loading['loadingDate']?.toString() ?? '';

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(loadingDate);
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
                    chickenType,
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
                    label: 'المورد',
                    value: supplier,
                    icon: Icons.business,
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    label: 'المستخدم',
                    value: user,
                    icon: Icons.person,
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
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    label: 'المتبقي',
                    value:
                        '${NumberFormat('#,##0.###').format(remainingWeight)} كجم',
                    icon: Icons.inventory,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            // Money spent section
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.money_off, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'المبلغ المنفق: ${NumberFormat('#,##0.###').format(totalLoading)} ج.م',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            if (distributedWeight > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'تم توزيع: ${NumberFormat('#,##0.###').format(distributedWeight)} كجم',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
