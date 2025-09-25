import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/payment_api_service.dart';
import '../../../../core/services/customer_api_service.dart';
import '../../../authentication/cubit/auth_cubit.dart';

class EmployeePaymentHistoryView extends StatefulWidget {
  const EmployeePaymentHistoryView({super.key});

  @override
  State<EmployeePaymentHistoryView> createState() =>
      _EmployeePaymentHistoryViewState();
}

class _EmployeePaymentHistoryViewState
    extends State<EmployeePaymentHistoryView> {
  late final PaymentApiService _paymentService;
  final Map<String, String> _customerNameCache = {};

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _dailyCollections = [];

  @override
  void initState() {
    super.initState();
    _paymentService = serviceLocator<PaymentApiService>();
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
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      final data = await _paymentService.getEmployeeDailyCollections(
        currentUser.id,
      );
      setState(() {
        _dailyCollections = data;
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
          title: const Text('سجل التحصيل'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: _dailyCollections.length,
                  itemBuilder: (context, index) {
                    final day = _dailyCollections[index];
                    return _buildDailyCard(day);
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildDailyCard(Map<String, dynamic> day) {
    final String date = (day['date'] ?? '').toString();
    final double totalPaid = ((day['totalPaid'] ?? 0) as num).toDouble();
    final int count = (day['count'] ?? 0) as int;
    final List<dynamic> payments = (day['payments'] as List<dynamic>? ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDate(date),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ج.م ${totalPaid.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'عدد السجلات: $count',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const Divider(height: 16),
            ...payments.map((p) {
              final double paidAmount = ((p['paidAmount'] ?? 0) as num)
                  .toDouble();
              final double discount = ((p['discount'] ?? 0) as num).toDouble();
              final String createdAt = (p['createdAt'] ?? '').toString();
              final dynamic customerField = p['customer'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        );
                      },
                    ),
                    if (discount > 0)
                      Text(
                        'خصم: ج.م ${discount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    Text(
                      _formatTime(createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
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
