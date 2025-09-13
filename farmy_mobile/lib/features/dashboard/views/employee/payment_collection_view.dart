import 'package:flutter/material.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/payment_api_service.dart';
import '../../../../core/services/customer_api_service.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../authentication/cubit/auth_cubit.dart';
import '../../../authentication/cubit/auth_state.dart';

class PaymentCollectionView extends StatefulWidget {
  const PaymentCollectionView({super.key});

  @override
  State<PaymentCollectionView> createState() => _PaymentCollectionViewState();
}

class _PaymentCollectionViewState extends State<PaymentCollectionView> {
  List<Map<String, dynamic>> customers = [];
  bool isLoading = true;
  bool isSubmitting = false;
  bool isPaymentSubmitted = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  String? selectedCustomerId;
  final _totalOutstandingController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _discountController = TextEditingController();
  final _remainingController = TextEditingController();
  String _selectedPaymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    // Auto-calc remaining when discount or paid change
    _paidAmountController.addListener(_calculateRemaining);
    _discountController.addListener(_calculateRemaining);
  }

  @override
  void dispose() {
    _totalOutstandingController.dispose();
    _paidAmountController.dispose();
    _discountController.dispose();
    _remainingController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => isLoading = true);

    try {
      final customerService = serviceLocator<CustomerApiService>();
      final result = await customerService.getAllCustomers();
      if (mounted) {
        setState(() {
          customers = result;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorDialog('فشل في تحميل العملاء: $e');
      }
    }
  }

  void _onCustomerSelected(String? id) {
    setState(() {
      selectedCustomerId = id;
    });
    if (id != null) {
      final customer = customers.firstWhere((c) => c['_id'] == id);
      final outstanding = (customer['outstandingDebts'] as num? ?? 0)
          .toDouble();
      _totalOutstandingController.text = outstanding.toStringAsFixed(2);
      _paidAmountController.text = '';
      _discountController.text = '0';
      _remainingController.text = outstanding.toStringAsFixed(2);
    }
  }

  void _calculateRemaining() {
    final totalPrice = double.tryParse(_totalOutstandingController.text) ?? 0;
    final paidAmount = double.tryParse(_paidAmountController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0;
    // Clamp values to valid ranges
    final effectiveDiscount = discount.clamp(0, totalPrice);
    final maxPayable = (totalPrice - effectiveDiscount).clamp(0, totalPrice);
    final effectivePaid = paidAmount.clamp(0, maxPayable);
    final remaining = (totalPrice - effectiveDiscount - effectivePaid).clamp(
      0,
      double.infinity,
    );

    if (effectiveDiscount != discount) {
      _discountController.text = effectiveDiscount.toStringAsFixed(2);
    }
    if (effectivePaid != paidAmount) {
      _paidAmountController.text = effectivePaid.toStringAsFixed(2);
    }
    _remainingController.text = (remaining as double).toStringAsFixed(2);
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    try {
      final paymentService = serviceLocator<PaymentApiService>();
      final totalPrice = double.parse(_totalOutstandingController.text);
      final paidAmount = double.parse(_paidAmountController.text);
      final discount = double.tryParse(_discountController.text) ?? 0;
      final remainingAmount =
          totalPrice - paidAmount - discount; // for display only

      final paymentData = {
        'customer': selectedCustomerId,
        'totalPrice': totalPrice,
        'paidAmount': paidAmount,
        'discount': discount,
        'paymentMethod': _selectedPaymentMethod,
      };

      await paymentService.createPayment(paymentData);

      if (mounted) {
        setState(() {
          isPaymentSubmitted = true;
        });
        _showSuccessDialog();
        await _loadCustomers(); // Reload customers to update outstanding
        // Re-apply selection to refresh the displayed totals/remaining
        if (selectedCustomerId != null) {
          _onCustomerSelected(selectedCustomerId);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('فشل في تسجيل الدفع: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    selectedCustomerId = null;
    _totalOutstandingController.clear();
    _paidAmountController.clear();
    _discountController.clear();
    _selectedPaymentMethod = 'cash';
    setState(() {
      isPaymentSubmitted = false;
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نجح'),
        content: const Text('تم تسجيل الدفع بنجاح'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خطأ'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  bool _isEmployee() {
    try {
      final authState = context.read<AuthCubit>().state;
      if (authState is AuthAuthenticated) {
        return authState.user.role == 'employee';
      }
      return true; // Default to employee if not authenticated
    } catch (e) {
      return true; // Default to employee on error
    }
  }

  Future<void> _showPaymentHistory() async {
    await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: _PaymentHistoryDialog(),
          ),
        ),
      ),
    );
  }

  void _showSuccessDialogWithPath(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تم إنشاء الملف بنجاح!'),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  String _formatToday() {
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
  }

  Future<void> _generateReceipt() async {
    try {
      // Check if required data is available
      if (selectedCustomerId == null) {
        _showErrorDialog('يرجى اختيار العميل أولاً');
        return;
      }
      final customer = customers.firstWhere(
        (c) => c['_id'] == selectedCustomerId,
      );
      final totalPrice = double.tryParse(_totalOutstandingController.text) ?? 0;
      final paidAmount = double.tryParse(_paidAmountController.text) ?? 0;
      final discount = double.tryParse(_discountController.text) ?? 0;
      final remaining = totalPrice - paidAmount - discount;

      // Get current employee info from auth cubit
      String employeeName = 'موظف النظام';
      final authState = context.read<AuthCubit>().state;
      if (authState is AuthAuthenticated) {
        employeeName = authState.user.username;
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'فارمي',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue,
                          ),
                        ),
                        pw.Text(
                          'نظام إدارة المزرعة',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'إيصال دفع',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'التاريخ: ${_formatToday()}',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),

                // Customer Information
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'معلومات العميل:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('الاسم: ${customer['name']}'),
                      pw.Text(
                        'الهاتف: ${customer['contactInfo']?['phone'] ?? 'غير متوفر'}',
                      ),
                      pw.Text(
                        'العنوان: ${customer['contactInfo']?['address'] ?? 'غير متوفر'}',
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Employee Information
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'معلومات الموظف:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('الموظف: $employeeName'),
                      pw.Text('التاريخ: ${_formatToday()}'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Balance Details
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'تفاصيل الرصيد:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'إجمالي الحساب: ${totalPrice.toStringAsFixed(2)} ج.م',
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Payment Details
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'تفاصيل الدفع:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('الخصم: ${discount.toStringAsFixed(2)} ج.م'),
                      pw.Text(
                        'المبلغ المدفوع: ${paidAmount.toStringAsFixed(2)} ج.م',
                      ),
                      pw.Text('المتبقي: ${remaining.toStringAsFixed(2)} ج.م'),
                      pw.Text('طريقة الدفع: نقداً'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Total
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey300,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'إجمالي المدفوع:',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '${paidAmount.toStringAsFixed(2)} ج.م',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Footer
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ملاحظات:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        '• هذا الإيصال صالح لمدة 30 يوم من تاريخ الإصدار',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        '• في حالة وجود أي استفسار، يرجى التواصل مع إدارة المزرعة',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        '• شكراً لثقتكم في منتجاتنا',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF to documents folder with customer name
      final documentsDir = await getApplicationDocumentsDirectory();
      final customerName = customer['name']
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final file = File(
        '${documentsDir.path}/payment_receipt_${customerName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      // Try to open PDF, but handle errors gracefully
      try {
        await OpenFile.open(file.path);
      } catch (openError) {
        // If opening fails, show success with file path info
        _showSuccessDialogWithPath(
          'تم إنشاء الإيصال بنجاح',
          'تم حفظ الملف في مجلد المستندات: ${file.path}',
        );
        return;
      }

      _showSuccessDialog();
    } catch (e) {
      _showErrorDialog('فشل في إنشاء الإيصال: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Use Navigator.pop() to go back to previous page
          Navigator.of(context).pop();
        }
      },
      child: Theme(
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
                  child: RefreshIndicator(
                    onRefresh: _loadCustomers,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _HeaderBar(onRefresh: _loadCustomers),
                          const SizedBox(height: 18),

                          if (isLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (customers.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text(
                                  'لا يوجد عملاء متاحون',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // Customer Selection
                                    _SectionCard(
                                      title: 'اختيار العميل',
                                      child: _DropdownField(
                                        label: 'العميل',
                                        value: selectedCustomerId,
                                        items: customers.map((c) {
                                          return DropdownMenuItem<String>(
                                            value: c['_id'],
                                            child: Text(
                                              c['name'] ?? '',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.black,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: _onCustomerSelected,
                                        validator: (value) {
                                          if (value == null) {
                                            return 'يرجى اختيار العميل';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Payment Details
                                    _SectionCard(
                                      title: 'تفاصيل الدفع',
                                      child: Column(
                                        children: [
                                          if (selectedCustomerId != null)
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[50],
                                                border: Border.all(
                                                  color: Colors.blue[200]!,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.info_outline,
                                                    color: Colors.blue[700],
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'العميل المحدد: ',
                                                    style: TextStyle(
                                                      color: Colors.blue[700],
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      customers.firstWhere(
                                                            (c) =>
                                                                c['_id'] ==
                                                                selectedCustomerId,
                                                          )['name'] ??
                                                          '',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: Colors.blue[700],
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'المستحق: ${_totalOutstandingController.text}',
                                                    style: TextStyle(
                                                      color: Colors.blue[600],
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (selectedCustomerId != null)
                                            const SizedBox(height: 12),
                                          _NumField(
                                            label: 'إجمالي الحساب (EGP)',
                                            controller:
                                                _totalOutstandingController,
                                            enabled: false,
                                          ),
                                          const SizedBox(height: 10),
                                          _NumField(
                                            label: 'قيمة الخصم (EGP)',
                                            controller: _discountController,
                                            onChanged: (v) =>
                                                _calculateRemaining(),
                                          ),
                                          const SizedBox(height: 10),

                                          _NumField(
                                            label: 'المبلغ المدفوع (EGP)',
                                            controller: _paidAmountController,
                                            onChanged: (value) =>
                                                _calculateRemaining(),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'يرجى إدخال المبلغ المدفوع';
                                              }
                                              final amount = double.tryParse(
                                                value,
                                              );
                                              if (amount == null ||
                                                  amount < 0) {
                                                return 'يرجى إدخال مبلغ صحيح';
                                              }
                                              final total =
                                                  double.tryParse(
                                                    _totalOutstandingController
                                                        .text,
                                                  ) ??
                                                  0;
                                              final discount =
                                                  double.tryParse(
                                                    _discountController.text,
                                                  ) ??
                                                  0;
                                              final maxPay = (total - discount)
                                                  .clamp(0, total);
                                              if (amount > maxPay) {
                                                return 'الحد الأقصى للدفع: ${maxPay.toStringAsFixed(2)}';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 10),

                                          // Remaining amount (read-only)
                                          _NumField(
                                            label: 'المتبقي (EGP)',
                                            controller: _remainingController,
                                            enabled: false,
                                          ),
                                          const SizedBox(height: 10),

                                          // Payment Method (cash only)
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              'طريقة الدفع: نقداً',
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium?.color,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          const SizedBox(height: 10),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Submit Button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: isSubmitting
                                            ? null
                                            : _submitPayment,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: isSubmitting
                                            ? const CircularProgressIndicator(
                                                color: Colors.white,
                                              )
                                            : const Text(
                                                'تسجيل الدفع',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // History Button - Only show if user is not an employee
                                    if (!_isEmployee()) ...[
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: _showPaymentHistory,
                                          icon: Icon(
                                            Icons.history,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          label: Text(
                                            'سجل المدفوعات',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            side: BorderSide(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 16),

                                    // Generate Receipt Button
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: isPaymentSubmitted
                                            ? _generateReceipt
                                            : null,
                                        icon: Icon(
                                          Icons.receipt,
                                          color: isPaymentSubmitted
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Colors.grey,
                                        ),
                                        label: Text(
                                          'إنشاء الإيصال',
                                          style: TextStyle(
                                            color: isPaymentSubmitted
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                : Colors.grey,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          side: BorderSide(
                                            color: isPaymentSubmitted
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ===================== Header =====================
class _HeaderBar extends StatelessWidget {
  final VoidCallback? onRefresh;

  const _HeaderBar({this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 8),
          // صورة/أفاتار
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFEFEFEF),
            child: Icon(
              Icons.person,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تحصيل الدفع',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                _formatToday(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const Spacer(),
          _RoundIconButton(icon: Icons.refresh, onTap: onRefresh),
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
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// ===================== Inputs =====================
class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const _NumField({
    required this.label,
    required this.controller,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        alignLabelWithHint: true,
      ),
      style: const TextStyle(overflow: TextOverflow.ellipsis),
      maxLines: 1,
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item.value,
          child: DefaultTextStyle(
            style: const TextStyle(overflow: TextOverflow.ellipsis),
            maxLines: 1,
            child: item.child,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        alignLabelWithHint: true,
      ),
      dropdownColor: Colors.white,
      icon: const Icon(Icons.arrow_drop_down),
    );
  }
}

class _PaymentHistoryDialog extends StatefulWidget {
  @override
  _PaymentHistoryDialogState createState() => _PaymentHistoryDialogState();
}

class _PaymentHistoryDialogState extends State<_PaymentHistoryDialog> {
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
      final query = _searchQuery.toLowerCase();

      return customerName.contains(query);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المدفوعات'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
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
                    hintText: 'البحث في العملاء...',
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('خطأ: $_error'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _loadPaymentsForDate(_selectedDate),
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
                            payment['customer']?['name'] ?? 'عميل غير معروف',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
        ],
      ),
    );
  }
}
