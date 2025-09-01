import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/order_api_service.dart';
import '../../../../core/services/payment_api_service.dart';
import '../../../../core/services/expense_api_service.dart';
import '../../../../core/theme/app_theme.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  bool _isLoading = true;
  int _ordersCount = 0;
  int _pendingCount = 0;
  int _deliveredCount = 0;
  int _receiptsCount = 0;
  double _totalCollected = 0;
  double _totalExpenses = 0;
  double _finalBalance = 0;

  @override
  void initState() {
    super.initState();
    // Load after first frame to avoid context/localization issues
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final orderService = serviceLocator<OrderApiService>();
      final paymentService = serviceLocator<PaymentApiService>();
      final expenseService = serviceLocator<ExpenseApiService>();

      // 1) Orders for current employee
      final orders = await orderService.getOrdersByEmployee();

      int delivered = 0;
      int pending = 0;
      for (final o in orders) {
        final status = (o['status'] ?? '').toString();
        if (status == 'delivered') delivered++;
        if (status == 'pending') pending++;
      }

      // 2) Aggregate payments and expenses per order
      int receipts = 0;
      double collected = 0;
      double expenses = 0;

      for (final o in orders) {
        final orderId = o['_id'];
        try {
          final payments = await paymentService.getPaymentsByOrder(orderId);
          receipts += payments.length;
          for (final p in payments) {
            final paid = (p['paidAmount'] is int)
                ? (p['paidAmount'] as int).toDouble()
                : (p['paidAmount'] as num?)?.toDouble() ?? 0.0;
            collected += paid;
          }
        } catch (_) {}

        try {
          final orderExpenses = await expenseService.getExpensesByOrder(
            orderId,
          );
          for (final e in orderExpenses) {
            final amt = (e['amount'] is int)
                ? (e['amount'] as int).toDouble()
                : (e['amount'] as num?)?.toDouble() ?? 0.0;
            expenses += amt;
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _ordersCount = orders.length;
        _pendingCount = pending;
        _deliveredCount = delivered;
        _receiptsCount = receipts;
        _totalCollected = collected;
        _totalExpenses = expenses;
        _finalBalance = collected - expenses;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Theme(
      data: AppTheme.lightTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Stack(
            children: [
              // خلفية متدرّجة مع حافة سفلية دائرية
              Container(
                height: size.height * 0.34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.background,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                ),
              ),

              // المحتوى
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _HeaderBar(),
                      const SizedBox(height: 18),

                      // Navigation Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => context.go('/order-placement'),
                                icon: const Icon(Icons.add_shopping_cart),
                                label: const Text('تسجيل طلب'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF37B2A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    context.go('/payment-collection'),
                                icon: const Icon(Icons.payment),
                                label: const Text('تحصيل الدفع'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0EA57A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // الكروت الملوّنة
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: const [
                            // Values updated below in non-const section
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                titleTop: 'الطلبات',
                                value: _isLoading ? '—' : '$_ordersCount',
                                color: const Color(0xFFF37B2A),
                                icon: Icons.shopping_bag_rounded,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _StatCard(
                                titleTop: 'قيد التنفيذ',
                                value: _isLoading ? '—' : '$_pendingCount',
                                color: const Color(0xFF0EA57A),
                                icon: Icons.timelapse_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // نظرة عامة (قابلة للتحديث من الباك)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _SectionCard(
                          title: 'نظرة عامة',
                          child: _OverviewGrid(
                            delivered: _deliveredCount,
                            receipts: _receiptsCount,
                            collected: _totalCollected,
                            expenses: _totalExpenses,
                            finalBalance: _finalBalance,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===================== Header =====================
class _HeaderBar extends StatelessWidget {
  const _HeaderBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/employee-dashboard'),
          ),
          const SizedBox(width: 8),
          // صورة/أفاتار
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFEFEFEF),
            child: Icon(Icons.person, color: Colors.grey.shade700, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'مرحباً، موظف',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              Text(
                _formatToday(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          _RoundIconButton(
            icon: Icons.refresh,
            onTap: () {
              // Refresh functionality can be added here later
            },
          ),
          const SizedBox(width: 8),
          const _RoundIconButton(
            icon: Icons.star_rounded,
            onTap: null,
            filled: true,
          ),
        ],
      ),
    );
  }

  static String _formatToday() {
    final now = DateTime.now();
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}';
    // Ex: 28 أغسطس 2025
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surface;
    final fg = filled
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: filled ? 2 : 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}

/// ===================== Chips =====================
class _SegmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// ===================== Stat Cards =====================
class _StatCard extends StatelessWidget {
  final String titleTop;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.titleTop,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -8,
            top: -8,
            child: Icon(
              icon,
              size: 80,
              color: Theme.of(context).shadowColor.withOpacity(0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SmallBadge(icon: icon),
                const Spacer(),
                Text(
                  titleTop,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final IconData icon;
  const _SmallBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).shadowColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(6),
      child: Icon(
        icon,
        size: 16,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}

/// ===================== Section Card Wrapper =====================
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// ===================== Overview Grid =====================
class _OverviewGrid extends StatelessWidget {
  final int delivered;
  final int receipts;
  final double collected;
  final double expenses;
  final double finalBalance;

  const _OverviewGrid({
    required this.delivered,
    required this.receipts,
    required this.collected,
    required this.expenses,
    required this.finalBalance,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ['الطلبات المسلَّمة', '$delivered'],
      ['الإيصالات المُعطاة', '$receipts'],
      ['الأموال المحصلة', '${collected.toStringAsFixed(0)} ج.م'],
      ['المصروفات', '${expenses.toStringAsFixed(0)} ج.م'],
      ['الرصيد النهائي', '${finalBalance.toStringAsFixed(0)} ج.م'],
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.9,
      ),
      itemBuilder: (context, i) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                items[i][0],
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                items[i][1],
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      },
    );
  }
}
