import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/payment_api_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../authentication/cubit/auth_cubit.dart';
import '../../../authentication/cubit/auth_state.dart';

class PaymentHistoryView extends StatefulWidget {
  const PaymentHistoryView({super.key});

  @override
  State<PaymentHistoryView> createState() => _PaymentHistoryViewState();
}

class _PaymentHistoryViewState extends State<PaymentHistoryView> {
  late final PaymentApiService _paymentService;
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _paymentService = serviceLocator<PaymentApiService>();
    _loadPaymentsForDate(_selectedDate);
  }

  Future<void> _loadPaymentsForDate(DateTime date) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allPayments = await _paymentService.getAllPayments();

      // Filter payments by selected date
      final filteredPayments = allPayments.where((payment) {
        final paymentDate = DateTime.parse(
          payment['createdAt'] ?? payment['paymentDate'] ?? '',
        );
        return paymentDate.year == date.year &&
            paymentDate.month == date.month &&
            paymentDate.day == date.day;
      }).toList();

      setState(() {
        _payments = filteredPayments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadPaymentsForDate(picked);
    }
  }

  List<Map<String, dynamic>> get _filteredPayments {
    if (_searchQuery.isEmpty) return _payments;

    return _payments.where((payment) {
      final customerName =
          payment['customer']?['name']?.toString().toLowerCase() ?? '';
      final employeeName =
          payment['employee']?['username']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return customerName.contains(query) || employeeName.contains(query);
    }).toList();
  }

  double _calculateTotalPaid() {
    return _filteredPayments.fold<double>(0.0, (sum, payment) {
      final paidAmount = (payment['paidAmount'] ?? 0) as num;
      return sum + paidAmount.toDouble();
    });
  }

  double _calculateTotalDiscount() {
    return _filteredPayments.fold<double>(0.0, (sum, payment) {
      final discount = (payment['discount'] ?? 0) as num;
      return sum + discount.toDouble();
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: true,
        onPopInvoked: (didPop) {
          if (!didPop) {
            context.go('/admin-dashboard');
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('سجل المدفوعات'),
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
                onPressed: () => _loadPaymentsForDate(_selectedDate),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _loadPaymentsForDate(_selectedDate),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Header with date selector and search
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[50],
                    child: Column(
                      children: [
                        // Date selector
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'تاريخ الدفع:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(_formatDate(_selectedDate)),
                              onPressed: _selectDate,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Search bar
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'البحث في العملاء أو الموظفين...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // Summary cards
                  if (!_isLoading && _filteredPayments.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Card(
                              color: Colors.green[50],
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.attach_money,
                                      color: Colors.green,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_calculateTotalPaid().toStringAsFixed(0)} ج.م',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text('إجمالي المدفوع'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Card(
                              color: Colors.orange[50],
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.discount,
                                      color: Colors.orange,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_calculateTotalDiscount().toStringAsFixed(0)} ج.م',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text('إجمالي الخصم'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Payment list (compact → details on tap)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error,
                                  size: 64,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text('خطأ: $_error'),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () =>
                                      _loadPaymentsForDate(_selectedDate),
                                  child: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          )
                        : _filteredPayments.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('لا توجد مدفوعات في هذا التاريخ'),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredPayments.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final m = _filteredPayments[index];
                              final String title =
                                  m['customer']?['name'] ?? 'عميل غير معروف';
                              final String subtitle = _formatDateTime(
                                m['createdAt'],
                              );
                              final num paid = (m['paidAmount'] ?? 0) as num;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.withOpacity(
                                    0.1,
                                  ),
                                  child: const Icon(
                                    Icons.payment,
                                    color: Colors.green,
                                  ),
                                ),
                                title: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(subtitle),
                                trailing: Text(
                                  '${paid.toDouble().toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                tileColor: Colors.white,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          _PaymentDetailsPage(payment: m),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentDetailsPage extends StatelessWidget {
  final Map<String, dynamic> payment;
  const _PaymentDetailsPage({required this.payment});

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'غير معروف';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'تاريخ غير صحيح';
    }
  }

  String _getPaymentMethodText(String? method) {
    switch (method) {
      case 'cash':
        return 'نقداً';
      case 'card':
        return 'بطاقة';
      case 'bank_transfer':
        return 'تحويل بنكي';
      default:
        return 'غير محدد';
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = payment['customer'];
    final employee = payment['employee'];
    final total = ((payment['totalPrice'] ?? 0) as num).toDouble();
    final paid = ((payment['paidAmount'] ?? 0) as num).toDouble();
    final discount = ((payment['discount'] ?? 0) as num).toDouble();
    final remaining =
        ((payment['remainingAmount'] ?? (total - paid - discount)) as num)
            .toDouble();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الدفع')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withOpacity(0.1),
                      child: const Icon(Icons.payment, color: Colors.green),
                    ),
                    title: Text(
                      customer?['name'] ?? 'عميل غير معروف',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(_formatDateTime(payment['createdAt'])),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: const Icon(
                        Icons.person,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    title: const Text('القائم بالتحصيل'),
                    subtitle: Builder(
                      builder: (context) {
                        final name = (employee?['username'] ?? '')
                            .toString()
                            .trim();
                        if (name.isNotEmpty) return Text(name);
                        try {
                          final authState = context.read<AuthCubit>().state;
                          if (authState is AuthAuthenticated &&
                              authState.user.role != 'employee') {
                            final adminName = authState.user.username;
                            final adminId = authState.user.id;
                            return Text(
                              adminId.isEmpty
                                  ? 'المدير: $adminName'
                                  : 'المدير: $adminName (ID: $adminId)',
                            );
                          }
                        } catch (_) {}
                        return const Text('غير محدد');
                      },
                    ),
                    dense: true,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.1),
                      child: const Icon(
                        Icons.pending_actions,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    title: const Text('إجمالي المستحق وقتها'),
                    subtitle: Text('ج.م ${total.toStringAsFixed(2)}'),
                    dense: true,
                  ),
                  const Divider(height: 1),
                  if (discount > 0) ...[
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepOrange.withOpacity(0.1),
                        child: const Icon(
                          Icons.percent,
                          color: Colors.deepOrange,
                          size: 20,
                        ),
                      ),
                      title: const Text('الخصم'),
                      subtitle: Text('ج.م ${discount.toStringAsFixed(2)}'),
                      dense: true,
                    ),
                    const Divider(height: 1),
                  ],
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withOpacity(0.1),
                      child: const Icon(
                        Icons.attach_money,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    title: const Text('المدفوع'),
                    subtitle: Text('ج.م ${paid.toStringAsFixed(2)}'),
                    dense: true,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      child: Icon(
                        remaining > 0
                            ? Icons.error_outline
                            : Icons.check_circle,
                        color: remaining > 0 ? Colors.red : Colors.green,
                        size: 20,
                      ),
                    ),
                    title: const Text('المتبقي بعد الدفع'),
                    subtitle: Text('ج.م ${remaining.toStringAsFixed(2)}'),
                    dense: true,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.withOpacity(0.1),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.purple,
                        size: 20,
                      ),
                    ),
                    title: const Text('طريقة الدفع'),
                    subtitle: Text(
                      _getPaymentMethodText(payment['paymentMethod']),
                    ),
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
