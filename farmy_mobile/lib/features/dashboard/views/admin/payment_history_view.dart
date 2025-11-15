import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/payment_api_service.dart';
import '../../../../core/utils/pdf_arabic_utils.dart';

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
          payment['paymentDate'] ?? payment['createdAt'] ?? '',
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
      final userName =
          payment['user']?['username']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return customerName.contains(query) || userName.contains(query);
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

  Future<void> _editPayment(Map<String, dynamic> m) async {
    final totalCtrl = TextEditingController(
      text: (m['totalPrice'] ?? 0).toString(),
    );
    final paidCtrl = TextEditingController(
      text: (m['paidAmount'] ?? 0).toString(),
    );
    final discountCtrl = TextEditingController(
      text: (m['discount'] ?? 0).toString(),
    );
    DateTime selectedDate;
    try {
      final raw = (m['paymentDate'] ?? m['createdAt'])?.toString();
      selectedDate = raw != null ? DateTime.parse(raw) : DateTime.now();
    } catch (_) {
      selectedDate = DateTime.now();
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل سجل الدفع'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    const Text('تاريخ الدفع:'),
                    const Spacer(),
                    StatefulBuilder(
                      builder: (context, setInner) => OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2024, 1, 1),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setInner(() => selectedDate = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: totalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'إجمالي المستحق',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: paidCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'المدفوع',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'الخصم',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        final String id = (m['_id'] ?? '').toString();
        if (id.isEmpty) throw Exception('معرّف غير صالح');
        final updated = await _paymentService.updatePayment(id, {
          'totalPrice':
              double.tryParse(totalCtrl.text) ??
              (m['totalPrice'] ?? 0).toDouble(),
          'paidAmount':
              double.tryParse(paidCtrl.text) ??
              (m['paidAmount'] ?? 0).toDouble(),
          'discount':
              double.tryParse(discountCtrl.text) ??
              (m['discount'] ?? 0).toDouble(),
          'paymentDate': selectedDate.toIso8601String(),
        });
        if (!mounted) return;
        setState(() {
          final idx = _payments.indexWhere((x) => x['_id'] == id);
          if (idx != -1) _payments[idx] = updated;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث سجل الدفع')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
      }
    }
  }

  Future<void> _confirmAndDeletePayment(Map<String, dynamic> m) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف سجل الدفع هذا؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final String id = (m['_id'] ?? '').toString();
      if (id.isEmpty) throw Exception('معرّف غير صالح');
      await _paymentService.deletePayment(id);
      if (!mounted) return;
      setState(() {
        _payments.removeWhere((x) => x['_id'] == id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف سجل الدفع')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
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
              IconButton(
                icon: const Icon(Icons.delete_forever),
                tooltip: 'حذف كل سجلات المدفوعات',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('تأكيد الحذف'),
                      content: const Text(
                        'هل أنت متأكد من حذف جميع سجلات المدفوعات؟ لا يمكن التراجع.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('إلغاء'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final pwd = await showDialog<String?>(
                      context: context,
                      builder: (ctx) {
                        final ctrl = TextEditingController();
                        return AlertDialog(
                          title: const Text('إدخال كلمة المرور'),
                          content: TextField(
                            controller: ctrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'كلمة المرور',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(null),
                              child: const Text('إلغاء'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(ctx).pop(ctrl.text.trim()),
                              child: const Text('تأكيد'),
                            ),
                          ],
                        );
                      },
                    );
                    if (pwd == null || pwd.isEmpty) return;
                    if (pwd != 'delete') {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'كلمة المرور غير صحيحة. استخدم "delete"',
                          ),
                        ),
                      );
                      return;
                    }
                    try {
                      await _paymentService.deleteAllPayments();
                      if (!mounted) return;
                      setState(() {
                        _payments = [];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم حذف جميع سجلات المدفوعات بنجاح'),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('فشل حذف المدفوعات: $e')),
                      );
                    }
                  }
                },
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
                            hintText: 'البحث في العملاء أو المستخدمين...',
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
                                m['paymentDate'] ?? m['createdAt'],
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${paid.toDouble().toStringAsFixed(0)} ج.م',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'تعديل هذا السجل',
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blueAccent,
                                      ),
                                      onPressed: () => _editPayment(m),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف هذا السجل',
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () =>
                                          _confirmAndDeletePayment(m),
                                    ),
                                  ],
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

  String _buildPaymentHtml() {
    final customer = payment['customer'];
    final dynamic user = payment['user'];
    String collectorName = '';
    if (user is Map<String, dynamic>) {
      collectorName = (user['username'] ?? user['name'] ?? '')
          .toString()
          .trim();
    }
    final total = ((payment['totalPrice'] ?? 0) as num).toDouble();
    final paid = ((payment['paidAmount'] ?? 0) as num).toDouble();
    final discount = ((payment['discount'] ?? 0) as num).toDouble();
    final remaining =
        ((payment['remainingAmount'] ?? (total - paid - discount)) as num)
            .toDouble();
    final customerName = customer?['name'] ?? 'عميل غير معروف';
    final paymentId = payment['_id']?.toString().substring(0, 8) ?? 'غير معروف';
    final createdAt = _formatDateTime(
      payment['paymentDate'] ?? payment['createdAt'],
    );
    final paymentMethod = _getPaymentMethodText(payment['paymentMethod']);

    return '''
      <div style="padding: 20px; max-width: 800px; margin: 0 auto;">
        <h1 style="text-align: center; color: #388e3c;">تفاصيل الدفع</h1>
        <hr style="border: 1px solid #388e3c; margin: 20px 0;">
        
        <div style="background: #e8f5e9; padding: 15px; border-radius: 8px; margin-bottom: 20px;">
          <h2 style="margin: 0 0 10px 0;">معلومات الدفع</h2>
          <p><strong>رقم الدفع:</strong> #$paymentId</p>
          <p><strong>التاريخ:</strong> $createdAt</p>
          <p><strong>العميل:</strong> $customerName</p>
        </div>

        <div style="margin-bottom: 20px;">
          <h3 style="background: #f5f5f5; padding: 10px; border-radius: 5px;">تفاصيل المبالغ</h3>
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>إجمالي المستحق وقتها:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">ج.م ${total.toStringAsFixed(2)}</td>
            </tr>
            ${discount > 0 ? '''
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>الخصم:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd; color: #ff6f00;">ج.م ${discount.toStringAsFixed(2)}</td>
            </tr>
            ''' : ''}
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>المدفوع:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd; color: #388e3c; font-weight: bold;">ج.م ${paid.toStringAsFixed(2)}</td>
            </tr>
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>المتبقي بعد الدفع:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd; color: ${remaining > 0 ? '#d32f2f' : '#388e3c'}; font-weight: bold;">ج.م ${remaining.toStringAsFixed(2)}</td>
            </tr>
          </table>
        </div>

        <div style="margin-bottom: 20px;">
          <h3 style="background: #f5f5f5; padding: 10px; border-radius: 5px;">معلومات إضافية</h3>
          <table style="width: 100%; border-collapse: collapse;">
            ${collectorName.isNotEmpty ? '''
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>القائم بالتحصيل:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">$collectorName${payment['user']?['role'] == 'employee' ? ' (موظف)' : ''}</td>
            </tr>
            ''' : ''}
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>طريقة الدفع:</strong></td>
              <td style="padding: 8px; border-bottom: 1px solid #ddd;">$paymentMethod</td>
            </tr>
          </table>
        </div>

        <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 2px solid #388e3c;">
          <p style="color: #666; font-size: 12px;">تم إنشاء هذا التقرير من نظام إدارة المزرعة</p>
        </div>
      </div>
    ''';
  }

  Future<void> _printPdf(BuildContext context) async {
    try {
      final html = _buildPaymentHtml();
      await PdfArabicUtils.printArabicHtml(htmlBody: html);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل الطباعة: $e')));
      }
    }
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final html = _buildPaymentHtml();
      final pdfBytes = await PdfArabicUtils.generateArabicHtmlPdf(
        htmlBody: html,
      );

      final tempDir = await getTemporaryDirectory();
      final paymentId = payment['_id']?.toString().substring(0, 8) ?? 'unknown';
      final customerName = payment['customer']?['name'] ?? 'عميل غير معروف';
      final createdAt = _formatDateTime(
      payment['paymentDate'] ?? payment['createdAt'],
    );
      final dateStr = createdAt
          .replaceAll('/', '-')
          .replaceAll(' ', '_')
          .replaceAll(':', '-');
      final fileName = 'دفع_${customerName}_$dateStr.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      if (!context.mounted) return;

      // Show share options dialog
      await showModalBottomSheet(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'مشاركة PDF عبر',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF25D366),
                    child: Image.asset(
                      'assets/whatsapp_icon.png',
                      width: 24,
                      height: 24,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.chat, color: Colors.white),
                    ),
                  ),
                  title: const Text('واتساب'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _shareViaWhatsApp(context, file, paymentId);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF0088CC),
                    child: Icon(Icons.telegram, color: Colors.white),
                  ),
                  title: const Text('تيليجرام'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _shareViaTelegram(context, file, paymentId);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.share, color: Colors.white),
                  ),
                  title: const Text('تطبيقات أخرى'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Share.shareXFiles([
                      XFile(file.path),
                    ], text: 'تفاصيل الدفع - $customerName');
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل المشاركة: $e')));
      }
    }
  }

  Future<void> _shareViaWhatsApp(
    BuildContext context,
    File file,
    String paymentId,
  ) async {
    try {
      final customerName = payment['customer']?['name'] ?? 'عميل غير معروف';
      // Try to share directly via WhatsApp using share_plus with result
      final result = await Share.shareXFiles([
        XFile(file.path),
      ], text: 'تفاصيل الدفع - $customerName');

      // If sharing was successful, try to open WhatsApp explicitly
      if (result.status == ShareResultStatus.success) {
        // Try WhatsApp scheme
        final whatsappUrl = Uri.parse('whatsapp://send');
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl);
        }
      } else {
        // Fallback: try to open WhatsApp directly
        final whatsappUrl = Uri.parse('whatsapp://send');
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('قم بإرفاق الملف من معرض الصور')),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('واتساب غير مثبت على هذا الجهاز')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل المشاركة عبر واتساب: $e')));
      }
    }
  }

  Future<void> _shareViaTelegram(
    BuildContext context,
    File file,
    String paymentId,
  ) async {
    try {
      final customerName = payment['customer']?['name'] ?? 'عميل غير معروف';
      // Share the file first
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'تفاصيل الدفع - $customerName');

      // Try to open Telegram
      final telegramUrl = Uri.parse('tg://');
      if (await canLaunchUrl(telegramUrl)) {
        await launchUrl(telegramUrl);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تيليجرام غير مثبت على هذا الجهاز')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل المشاركة عبر تيليجرام: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = payment['customer'];
    final dynamic user = payment['user'];
    String collectorName = '';
    if (user is Map<String, dynamic>) {
      collectorName = (user['username'] ?? user['name'] ?? '')
          .toString()
          .trim();
    } else if (user is String) {
      // Older records may only have an ID string; show as ID for now
      collectorName = '';
    }
    final total = ((payment['totalPrice'] ?? 0) as num).toDouble();
    final paid = ((payment['paidAmount'] ?? 0) as num).toDouble();
    final discount = ((payment['discount'] ?? 0) as num).toDouble();
    final remaining =
        ((payment['remainingAmount'] ?? (total - paid - discount)) as num)
            .toDouble();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الدفع'),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'طباعة',
              onPressed: () => _printPdf(context),
            ),
          ],
        ),
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
                    subtitle: Text(
                      collectorName.isNotEmpty
                          ? '$collectorName${payment['user']?['role'] == 'employee' ? ' (موظف)' : ''}'
                          : 'غير محدد',
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
