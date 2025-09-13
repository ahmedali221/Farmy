import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/payment_api_service.dart';

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
          body: Column(
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
                        const Icon(Icons.calendar_today, color: Colors.blue),
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

              // Payment list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _loadPaymentsForDate(_selectedDate),
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
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredPayments.length,
                          itemBuilder: (context, index) {
                            final payment = _filteredPayments[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green[100],
                                  child: const Icon(
                                    Icons.payment,
                                    color: Colors.green,
                                  ),
                                ),
                                title: Text(
                                  payment['customer']?['name'] ??
                                      'عميل غير معروف',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'الموظف: ${payment['employee']?['username'] ?? 'غير محدد'}',
                                    ),
                                    Text(
                                      'المبلغ المدفوع: ${payment['paidAmount']} ج.م',
                                    ),
                                    Text('الخصم: ${payment['discount']} ج.م'),
                                    Text(
                                      'طريقة الدفع: ${_getPaymentMethodText(payment['paymentMethod'])}',
                                    ),
                                    Text(
                                      'التاريخ: ${_formatDateTime(payment['createdAt'])}',
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
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
