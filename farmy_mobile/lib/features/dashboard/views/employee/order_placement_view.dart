import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/order_api_service.dart';
import '../../../../core/services/inventory_api_service.dart';
import '../../../../core/services/customer_api_service.dart';
import '../../../../core/theme/app_theme.dart';

class OrderPlacementView extends StatefulWidget {
  const OrderPlacementView({super.key});

  @override
  State<OrderPlacementView> createState() => _OrderPlacementViewState();
}

class _OrderPlacementViewState extends State<OrderPlacementView> {
  List<Map<String, dynamic>> chickenTypes = [];
  List<Map<String, dynamic>> customers = [];
  bool isLoading = true;
  bool isSubmitting = false;
  bool isOrderSubmitted = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  String? selectedChickenTypeId;
  String? selectedCustomerId;
  final _quantityController = TextEditingController();
  final _totalPriceController = TextEditingController();
  // Additional controllers
  final _grossWeightController = TextEditingController();
  final _netWeightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _grossWeightController.addListener(_calculateNetWeight);
    _quantityController.addListener(_calculateNetWeight);
    _netWeightController.addListener(_calculateTotalPrice);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _totalPriceController.dispose();
    _grossWeightController.dispose();
    _netWeightController.dispose();
    super.dispose();
  }

  void _calculateNetWeight() {
    final gross = double.tryParse(_grossWeightController.text);
    final count = double.tryParse(_quantityController.text);

    // Only calculate if both values are provided
    if (gross != null && count != null) {
      final net = gross - (count * 8);
      _netWeightController.text = net.toStringAsFixed(2);
      // Recalculate total price when net weight changes
      _calculateTotalPrice();
    } else {
      // Clear the field if either value is missing
      _netWeightController.clear();
      _calculateTotalPrice();
    }
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      final inventoryService = serviceLocator<InventoryApiService>();
      final customerService = serviceLocator<CustomerApiService>();

      final futures = await Future.wait([
        inventoryService.getAllChickenTypes(),
        customerService.getAllCustomers(),
      ]);

      if (mounted) {
        setState(() {
          chickenTypes = futures[0];
          customers = futures[1];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorDialog('فشل في تحميل البيانات: $e');
      }
    }
  }

  void _calculateTotalPrice() {
    if (selectedChickenTypeId != null) {
      final chickenType = chickenTypes.firstWhere(
        (type) => type['_id'] == selectedChickenTypeId,
      );
      final netWeight = double.tryParse(_netWeightController.text);
      final dynamic priceRaw = chickenType['price'];
      final double price = (priceRaw is int)
          ? priceRaw.toDouble()
          : (priceRaw as double);

      if (netWeight != null && netWeight > 0) {
        final totalPrice = netWeight * price;
        _totalPriceController.text = totalPrice.toStringAsFixed(2);
      } else {
        _totalPriceController.clear();
      }
    }
  }

  int _getAvailableStock() {
    try {
      final type = chickenTypes.firstWhere(
        (t) => t['_id'] == selectedChickenTypeId,
      );
      return (type['stock'] as int);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    try {
      final orderService = serviceLocator<OrderApiService>();

      final orderData = {
        'chickenType': selectedChickenTypeId,
        'customer': selectedCustomerId,
        'quantity': double.parse(_quantityController.text),
        'type': selectedChickenTypeId != null
            ? chickenTypes.firstWhere(
                (type) => type['_id'] == selectedChickenTypeId,
              )['name']
            : '',
        'grossWeight': double.tryParse(_grossWeightController.text) ?? 0,
        'netWeight': double.tryParse(_netWeightController.text) ?? 0,
        'todayAccount': double.tryParse(_totalPriceController.text) ?? 0,
        'totalPrice': double.tryParse(_totalPriceController.text) ?? 0,
      };

      await orderService.createOrder(orderData);

      if (mounted) {
        setState(() {
          isOrderSubmitted = true;
        });
        _showSuccessDialog();
        // Refresh inventory to reflect decremented stock
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('فشل في إنشاء الطلب: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    selectedChickenTypeId = null;
    selectedCustomerId = null;
    _quantityController.clear();
    _totalPriceController.clear();
    _grossWeightController.clear();
    _netWeightController.clear();
    setState(() {
      isOrderSubmitted = false;
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نجح'),
        content: const Text('تم إنشاء الطلب بنجاح'),
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

  Future<void> _generateInvoice() async {
    try {
      // Check if required data is available
      if (selectedCustomerId == null ||
          selectedChickenTypeId == null ||
          _quantityController.text.isEmpty) {
        _showErrorDialog('يرجى ملء جميع البيانات المطلوبة أولاً');
        return;
      }

      final customer = customers.firstWhere(
        (c) => c['_id'] == selectedCustomerId,
      );
      final chickenType = chickenTypes.firstWhere(
        (t) => t['_id'] == selectedChickenTypeId,
      );
      final quantity = double.tryParse(_quantityController.text) ?? 0;
      final totalPrice = quantity * chickenType['price'];

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
                          'FARMY',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue,
                          ),
                        ),
                        pw.Text(
                          'Farm Management System',
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
                          'INVOICE',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Date: ${DateTime.now().toString().split(' ')[0]}',
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
                        'Customer Information:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Name: ${customer['name']}'),
                      pw.Text(
                        'Phone: ${customer['contactInfo']?['phone'] ?? 'N/A'}',
                      ),
                      pw.Text(
                        'Address: ${customer['contactInfo']?['address'] ?? 'N/A'}',
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Order Details
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
                        'Order Details:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Chicken Type: ${chickenType['name']}'),
                      pw.Text('Quantity: ${quantity.toStringAsFixed(2)} kg'),
                      pw.Text('Price per kg: EGP ${chickenType['price']}'),
                      pw.Text(
                        'Total Price: EGP ${totalPrice.toStringAsFixed(2)}',
                      ),
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
                        'TOTAL AMOUNT:',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'EGP ${totalPrice.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
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
        '${documentsDir.path}/order_invoice_${customerName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      // Try to open PDF, but handle errors gracefully
      try {
        await OpenFile.open(file.path);
      } catch (openError) {
        // If opening fails, show success with file path info
        _showSuccessDialogWithPath(
          'تم إنشاء الفاتورة بنجاح',
          'تم حفظ الملف في مجلد المستندات: ${file.path}',
        );
        return;
      }

      _showSuccessDialog();
    } catch (e) {
      _showErrorDialog('فشل في إنشاء الفاتورة: $e');
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
                      _HeaderBar(onRefresh: _loadData),
                      const SizedBox(height: 18),

                      if (isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                    items: customers
                                        .map(
                                          (customer) =>
                                              DropdownMenuItem<String>(
                                                value: customer['_id'],
                                                child: Text(customer['name']),
                                              ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedCustomerId = value;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'يرجى اختيار العميل';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Chicken Type Selection
                                _SectionCard(
                                  title: 'نوع الدجاج',
                                  child: _DropdownField(
                                    label: 'نوع الدجاج',
                                    value: selectedChickenTypeId,
                                    items: chickenTypes
                                        .map(
                                          (
                                            chickenType,
                                          ) => DropdownMenuItem<String>(
                                            value: chickenType['_id'],
                                            child: Row(
                                              children: [
                                                Text(chickenType['name']),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '(${chickenType['price']} EGP/kg)',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'متاح: ${chickenType['stock']}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedChickenTypeId = value;
                                      });
                                      _calculateTotalPrice();
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'يرجى اختيار نوع الدجاج';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Quantity and Price
                                _SectionCard(
                                  title: 'الكمية والسعر',
                                  child: Column(
                                    children: [
                                      if (selectedChickenTypeId != null)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8.0,
                                            ),
                                            child: Text(
                                              'المتاح: ${_getAvailableStock()} ',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      _NumField(
                                        label: 'الكمية ',
                                        controller: _quantityController,
                                        onChanged: (value) =>
                                            _calculateTotalPrice(),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'يرجى إدخال الكمية';
                                          }
                                          final quantity = double.tryParse(
                                            value,
                                          );
                                          if (quantity == null ||
                                              quantity <= 0) {
                                            return 'يرجى إدخال كمية صحيحة';
                                          }
                                          final available = _getAvailableStock()
                                              .toDouble();
                                          if (selectedChickenTypeId != null &&
                                              quantity > available) {
                                            return 'الكمية تتجاوز المتاح: ${_getAvailableStock()}';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                      _NumField(
                                        label: 'السعر الإجمالي (EGP)',
                                        controller: _totalPriceController,
                                        enabled: false,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Additional Data Section
                                _SectionCard(
                                  title: 'بيانات إضافية',
                                  child: Column(
                                    children: [
                                      if (selectedChickenTypeId != null)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Text('نوع: '),
                                              Text(
                                                chickenTypes.firstWhere(
                                                  (type) =>
                                                      type['_id'] ==
                                                      selectedChickenTypeId,
                                                )['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 10),
                                      _NumField(
                                        label: 'وزن القايم',
                                        controller: _grossWeightController,
                                      ),
                                      const SizedBox(height: 10),
                                      _NumField(
                                        label: 'وزن الصافي (يحسب تلقائياً)',
                                        controller: _netWeightController,
                                        enabled: false,
                                      ),
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
                                        : _submitOrder,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: isSubmitting
                                        ? const CircularProgressIndicator(
                                            color: Colors.white,
                                          )
                                        : const Text(
                                            'تسجيل الطلب',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Generate Invoice Button
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: isOrderSubmitted
                                        ? _generateInvoice
                                        : null,
                                    icon: Icon(
                                      Icons.receipt,
                                      color: isOrderSubmitted
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.grey,
                                    ),
                                    label: Text(
                                      'إنشاء الفاتورة',
                                      style: TextStyle(
                                        color: isOrderSubmitted
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
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      side: BorderSide(
                                        color: isOrderSubmitted
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
            ],
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
                'تسجيل طلب جديد',
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
          child: Icon(icon, size: 20, color: Colors.black87),
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
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
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
      ),
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
      items: items,
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
      ),
    );
  }
}
