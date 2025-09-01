import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/payment_api_service.dart';
import '../../../../core/services/order_api_service.dart';

class PaymentCollectionView extends StatefulWidget {
  const PaymentCollectionView({super.key});

  @override
  State<PaymentCollectionView> createState() => _PaymentCollectionViewState();
}

class _PaymentCollectionViewState extends State<PaymentCollectionView> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  bool isSubmitting = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  String? selectedOrderId;
  final _totalPriceController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _discountController = TextEditingController();
  final _discountPercentageController = TextEditingController();
  final _offerController = TextEditingController();
  final _notesController = TextEditingController();
  final _remainingController = TextEditingController();
  String _selectedPaymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _totalPriceController.dispose();
    _paidAmountController.dispose();
    _discountController.dispose();
    _discountPercentageController.dispose();
    _offerController.dispose();
    _notesController.dispose();
    _remainingController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => isLoading = true);

    try {
      final orderService = serviceLocator<OrderApiService>();
      final orders = await orderService.getOrdersByEmployee();

      // Filter only pending orders
      final pendingOrders = orders
          .where((order) => order['status'] == 'pending')
          .toList();

      if (mounted) {
        setState(() {
          this.orders = pendingOrders;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorDialog('فشل في تحميل الطلبات: $e');
      }
    }
  }

  void _onOrderSelected(String? orderId) {
    setState(() {
      selectedOrderId = orderId;
    });

    if (orderId != null) {
      final order = orders.firstWhere((order) => order['_id'] == orderId);
      final chickenType = order['chickenType'];
      final quantity = order['quantity'];
      final totalPrice = quantity * chickenType['price'];

      _totalPriceController.text = totalPrice.toString();
      _paidAmountController.text = totalPrice.toString();
      _remainingController.text = '0.00';
      _discountController.text = '0';
      _discountPercentageController.text = '0';
    }
  }

  void _calculateDiscount() {
    final totalPrice = double.tryParse(_totalPriceController.text) ?? 0;
    final discountPercentage =
        double.tryParse(_discountPercentageController.text) ?? 0;

    if (totalPrice > 0 && discountPercentage > 0) {
      final discount = (totalPrice * discountPercentage) / 100;
      _discountController.text = discount.toStringAsFixed(2);

      final newTotalPrice = totalPrice - discount;
      _totalPriceController.text = newTotalPrice.toStringAsFixed(2);
      _paidAmountController.text = newTotalPrice.toStringAsFixed(2);
    }
  }

  void _calculateRemaining() {
    final totalPrice = double.tryParse(_totalPriceController.text) ?? 0;
    final paidAmount = double.tryParse(_paidAmountController.text) ?? 0;
    final remaining = totalPrice - paidAmount;

    if (remaining < 0) {
      _paidAmountController.text = totalPrice.toString();
      _remainingController.text = '0.00';
    } else {
      _remainingController.text = remaining.toStringAsFixed(2);
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    try {
      final paymentService = serviceLocator<PaymentApiService>();
      final order = orders.firstWhere(
        (order) => order['_id'] == selectedOrderId,
      );

      final paymentData = {
        'order': selectedOrderId,
        'customer': order['customer']['_id'],
        'totalPrice': double.parse(_totalPriceController.text),
        'paidAmount': double.parse(_paidAmountController.text),
        'discount': double.tryParse(_discountController.text) ?? 0,
        'discountPercentage':
            double.tryParse(_discountPercentageController.text) ?? 0,
        'offer': _offerController.text.isNotEmpty
            ? _offerController.text
            : null,
        'paymentMethod': _selectedPaymentMethod,
        'notes': _notesController.text.isNotEmpty
            ? _notesController.text
            : null,
      };

      await paymentService.createPayment(paymentData);

      if (mounted) {
        _showSuccessDialog();
        _resetForm();
        _loadOrders(); // Reload orders to update status
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
    selectedOrderId = null;
    _totalPriceController.clear();
    _paidAmountController.clear();
    _discountController.clear();
    _discountPercentageController.clear();
    _offerController.clear();
    _notesController.clear();
    _selectedPaymentMethod = 'cash';
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تم التحصيل بنجاح'),
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            // خلفية متدرّجة مع حافة سفلية دائرية
            Container(
              height: size.height * 0.34,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF6ECD8), // cream
                    Color(0xFFFFFFFF),
                  ],
                ),
                borderRadius: BorderRadius.only(
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
                    _HeaderBar(onRefresh: _loadOrders),
                    const SizedBox(height: 18),

                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (orders.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'لا توجد طلبات معلقة للتحصيل',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Order Selection
                              _SectionCard(
                                title: 'اختيار الطلب',
                                child: _DropdownField(
                                  label: 'الطلب',
                                  value: selectedOrderId,
                                  items: orders.map((order) {
                                    final customer = order['customer'];
                                    final chickenType = order['chickenType'];
                                    final quantity = order['quantity'];
                                    final totalPrice =
                                        quantity * chickenType['price'];

                                    return DropdownMenuItem<String>(
                                      value: order['_id'],
                                      child: Text(
                                        '${customer['name']} - ${chickenType['name']} - $quantity كيلو - ${totalPrice.toStringAsFixed(0)} EGP',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: _onOrderSelected,
                                  validator: (value) {
                                    if (value == null) {
                                      return 'يرجى اختيار الطلب';
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
                                    _NumField(
                                      label: 'السعر الإجمالي (EGP)',
                                      controller: _totalPriceController,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'يرجى إدخال السعر الإجمالي';
                                        }
                                        final price = double.tryParse(value);
                                        if (price == null || price < 0) {
                                          return 'يرجى إدخال سعر صحيح';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 10),

                                    // Discount Percentage
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _NumField(
                                            label: 'نسبة الخصم (%)',
                                            controller:
                                                _discountPercentageController,
                                            onChanged: (value) =>
                                                _calculateDiscount(),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _NumField(
                                            label: 'قيمة الخصم (EGP)',
                                            controller: _discountController,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    _NumField(
                                      label: 'المبلغ المدفوع (EGP)',
                                      controller: _paidAmountController,
                                      onChanged: (value) =>
                                          _calculateRemaining(),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'يرجى إدخال المبلغ المدفوع';
                                        }
                                        final amount = double.tryParse(value);
                                        if (amount == null || amount < 0) {
                                          return 'يرجى إدخال مبلغ صحيح';
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
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const SizedBox(height: 10),

                                    // Offer
                                    _NumField(
                                      label: 'العرض (اختياري)',
                                      controller: _offerController,
                                      enabled: true,
                                    ),
                                    const SizedBox(height: 10),

                                    // Notes
                                    _NumField(
                                      label: 'ملاحظات (اختياري)',
                                      controller: _notesController,
                                      enabled: true,
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
                                      : _submitPayment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0EA57A),
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
                                          'تسجيل الدفع',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
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
                'تحصيل الدفع',
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
