import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/payment_api_service.dart';
import '../../../../core/services/employee_expense_api_service.dart';
import '../../../../core/services/customer_api_service.dart';
import '../../../authentication/cubit/auth_cubit.dart';

class EmployeeDailyDetailView extends StatefulWidget {
  final String date; // expects YYYY-MM-DD
  const EmployeeDailyDetailView({super.key, required this.date});

  @override
  State<EmployeeDailyDetailView> createState() =>
      _EmployeeDailyDetailViewState();
}

class _EmployeeDailyDetailViewState extends State<EmployeeDailyDetailView> {
  late final PaymentApiService _paymentService;
  late final EmployeeExpenseApiService _expenseService;
  final Map<String, String> _customerNameCache = {};

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _expenses = [];
  double _totalCollected = 0.0;
  double _totalExpenses = 0.0;
  double _net = 0.0;

  @override
  void initState() {
    super.initState();
    _paymentService = serviceLocator<PaymentApiService>();
    _expenseService = serviceLocator<EmployeeExpenseApiService>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authCubit = context.read<AuthCubit>();
      final currentUser = authCubit.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Load all and filter client-side by date since backend grouping endpoints differ
      final paymentsGrouped = await _paymentService.getUserDailyCollections(
        currentUser.id,
      );
      final today = paymentsGrouped.firstWhere(
        (d) => (d['date'] ?? '') == widget.date,
        orElse: () => {'payments': <Map<String, dynamic>>[]},
      );
      _payments =
          (today['payments'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [];

      final allExpenses = await _expenseService.listByEmployee(currentUser.id);
      _expenses = allExpenses
          .where(
            (e) => _yyyyMmDd((e['createdAt'] ?? '').toString()) == widget.date,
          )
          .cast<Map<String, dynamic>>()
          .toList();

      _totalCollected = _payments.fold<double>(
        0.0,
        (sum, p) => sum + ((p['paidAmount'] ?? 0) as num).toDouble(),
      );
      _totalExpenses = _expenses.fold<double>(
        0.0,
        (sum, e) => sum + ((e['value'] ?? 0) as num).toDouble(),
      );
      _net = _totalCollected - _totalExpenses;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<String> _resolveCustomerName(dynamic customerField) async {
    try {
      if (customerField is Map<String, dynamic>) {
        final name = customerField['name']?.toString();
        if (name != null && name.isNotEmpty) return name;
        final id = customerField['_id']?.toString();
        if (id != null && id.isNotEmpty) {
          if (_customerNameCache.containsKey(id))
            return _customerNameCache[id]!;
          final svc = serviceLocator<CustomerApiService>();
          final data = await svc.getCustomerById(id);
          final fetched = data?['name']?.toString() ?? 'عميل';
          _customerNameCache[id] = fetched;
          return fetched;
        }
      } else if (customerField is String && customerField.isNotEmpty) {
        if (_customerNameCache.containsKey(customerField)) {
          return _customerNameCache[customerField]!;
        }
        final svc = serviceLocator<CustomerApiService>();
        final data = await svc.getCustomerById(customerField);
        final fetched = data?['name']?.toString() ?? 'عميل';
        _customerNameCache[customerField] = fetched;
        return fetched;
      }
    } catch (_) {}
    return 'عميل غير معروف';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تفاصيل يوم ${_formatDate(widget.date)}'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildSummaryCard(),
                    const SizedBox(height: 12),
                    _buildSectionHeader('التحصيلات (${_payments.length})'),
                    if (_payments.isEmpty)
                      _buildEmpty('لا توجد تحصيلات لهذا اليوم')
                    else
                      ..._payments.map(_buildPaymentTile),
                    const SizedBox(height: 16),
                    _buildSectionHeader('المصروفات (${_expenses.length})'),
                    if (_expenses.isEmpty)
                      _buildEmpty('لا توجد مصروفات لهذا اليوم')
                    else
                      ..._expenses.map(_buildExpenseTile),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.summarize, size: 18),
                const SizedBox(width: 8),
                Text(
                  'ملخص اليوم (${_formatDate(widget.date)})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMiniMetric(
                    'التحصيل',
                    _totalCollected,
                    Colors.green,
                    Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'المصروفات',
                    _totalExpenses,
                    Colors.orange,
                    Icons.money_off,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniMetric(
                    'الصافي',
                    _net,
                    _net >= 0 ? Colors.blue : Colors.red,
                    Icons.account_balance,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetric(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ج.م ${amount.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  );

  Widget _buildEmpty(String text) => Padding(
    padding: const EdgeInsets.all(12),
    child: Center(
      child: Text(text, style: TextStyle(color: Colors.grey[600])),
    ),
  );

  Widget _buildPaymentTile(Map<String, dynamic> p) {
    final double paidAmount = ((p['paidAmount'] ?? 0) as num).toDouble();
    final double discount = ((p['discount'] ?? 0) as num).toDouble();
    final String createdAt = (p['createdAt'] ?? '').toString();
    final dynamic customerField = p['customer'];
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.withOpacity(0.1),
        child: const Icon(Icons.payments, color: Colors.blue),
      ),
      title: Text(
        'تحصيل: ج.م ${paidAmount.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String>(
            future: _resolveCustomerName(customerField),
            builder: (context, snap) {
              final name = snap.data ?? '...';
              return Text(
                'العميل: $name',
                style: TextStyle(fontSize: 12, color: Colors.blue[700]),
              );
            },
          ),
          if (discount > 0)
            Text(
              'خصم: ج.م ${discount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.orange[700]),
            ),
          Text(
            _formatTime(createdAt),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(Map<String, dynamic> e) {
    final double value = ((e['value'] ?? 0) as num).toDouble();
    final String name = (e['name'] ?? '').toString();
    final String note = (e['note'] ?? '').toString();
    final String createdAt = (e['createdAt'] ?? '').toString();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.orange.withOpacity(0.1),
        child: const Icon(Icons.money_off, color: Colors.orange),
      ),
      title: Text(
        '$name - ج.م ${value.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note.isNotEmpty)
            Text(note, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(
            _formatTime(createdAt),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _yyyyMmDd(String dateString) {
    try {
      final d = DateTime.parse(dateString);
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (e) {
      return '';
    }
  }
}
