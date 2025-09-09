import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/customer_api_service.dart';
import '../../../../core/services/employee_api_service.dart';

class DistributionView extends StatefulWidget {
  const DistributionView({super.key});

  @override
  State<DistributionView> createState() => _DistributionViewState();
}

class _DistributionViewState extends State<DistributionView> {
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic>? _selectedCustomer;

  final TextEditingController _quantityCtrl = TextEditingController();
  final TextEditingController _grossWeightCtrl = TextEditingController();
  final TextEditingController _netWeightCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();

  double _mealAccount = 0;
  double _totalAccount = 0;
  bool _loading = true;
  bool _saving = false;
  bool _posting = false;
  String _debugLog = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    // Removed redundant listeners since onChanged handles updates
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _grossWeightCtrl.dispose();
    _netWeightCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final service = serviceLocator<CustomerApiService>();
      final customers = await service.getAllCustomers();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _loading = false;
      });
      // Debug: Log customer data
      print('Loaded customers: $_customers');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showErrorDialog('فشل تحميل العملاء: $e');
    }
  }

  void _recalculate() {
    final quantity = int.tryParse(_quantityCtrl.text) ?? 0;
    final gross = double.tryParse(_grossWeightCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;

    final net = (gross - (quantity * 8)).clamp(0, double.infinity);
    final mealAccount = price * net;
    final outstanding = (_selectedCustomer != null)
        ? (_selectedCustomer!['outstandingDebts'] as num? ?? 0).toDouble()
        : 0.0;
    final totalAccount = mealAccount + outstanding;

    // Debug: Log calculation inputs and results
    print('Recalculate - Quantity: $quantity, Gross: $gross, Price: $price');
    print('Net: $net, MealAccount: $mealAccount, TotalAccount: $totalAccount');

    setState(() {
      _netWeightCtrl.text = net.toStringAsFixed(2);
      _mealAccount = mealAccount;
      _totalAccount = totalAccount;
    });
  }

  Future<void> _applyToOutstanding() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCustomer == null) {
      _showErrorDialog('يرجى اختيار العميل أولاً');
      return;
    }

    setState(() => _saving = true);
    try {
      _recalculate();
      final currentOutstanding =
          (_selectedCustomer!['outstandingDebts'] as num? ?? 0).toDouble();
      final newOutstanding = (currentOutstanding + _mealAccount)
          .clamp(0, double.infinity)
          .toDouble();

      final service = serviceLocator<CustomerApiService>();
      final updated = await service.incrementOutstanding(
        _selectedCustomer!['_id'] as String,
        _mealAccount,
      );

      if (!mounted) return;
      setState(() {
        _selectedCustomer = {
          ..._selectedCustomer!,
          'outstandingDebts': updated['outstandingDebts'] ?? newOutstanding,
        };
        // Update list item too
        final idx = _customers.indexWhere((c) => c['_id'] == updated['_id']);
        if (idx != -1) {
          _customers[idx] = updated;
        }
        _totalAccount =
            _mealAccount +
            ((_selectedCustomer!['outstandingDebts'] as num?)?.toDouble() ?? 0);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إضافة ${_mealAccount.toStringAsFixed(2)} ج.م إلى مديونية العميل',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('فشل تحديث مديونية العميل: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _postDistributionRecord() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCustomer == null) {
      _showErrorDialog('يرجى اختيار العميل أولاً');
      return;
    }

    setState(() => _posting = true);
    try {
      _recalculate();
      final quantity = int.tryParse(_quantityCtrl.text) ?? 0;
      final gross = double.tryParse(_grossWeightCtrl.text) ?? 0;
      final price = double.tryParse(_priceCtrl.text) ?? 0;
      final net = double.tryParse(_netWeightCtrl.text) ?? 0;
      final total = _mealAccount;

      final service = serviceLocator<EmployeeApiService>();
      final payload = {
        'customer': _selectedCustomer!['_id'],
        'quantity': quantity,
        'grossWeight': gross,
        'price': price,
        'netWeight': net,
        'totalAmount': total,
      };
      final created = await service.createDistribution(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تسجيل التوزيع #${created['_id'] ?? ''}')),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('فشل تسجيل التوزيع: $e');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _submitBoth() async {
    _debugLog = '';
    void log(String m) {
      _debugLog += m + '\n';
      // ignore: avoid_print
      print('[DistributionSubmit] ' + m);
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      log('Validation failed');
      setState(() {});
      return;
    }
    if (_selectedCustomer == null) {
      log('No customer selected');
      _showErrorDialog('يرجى اختيار العميل أولاً');
      setState(() {});
      return;
    }

    setState(() {
      _saving = true;
      _posting = true;
    });

    try {
      _recalculate();
      log(
        'Inputs -> qty=${_quantityCtrl.text}, gross=${_grossWeightCtrl.text}, price=${_priceCtrl.text}',
      );
      log(
        'Calculated -> net=${_netWeightCtrl.text}, meal=${_mealAccount.toStringAsFixed(2)}',
      );

      // Create distribution (backend also increments outstanding)
      final employeeService = serviceLocator<EmployeeApiService>();
      final payload = {
        'customer': _selectedCustomer!['_id'],
        'quantity': int.tryParse(_quantityCtrl.text) ?? 0,
        'grossWeight': double.tryParse(_grossWeightCtrl.text) ?? 0.0,
        'price': double.tryParse(_priceCtrl.text) ?? 0.0,
      };
      log('POST /distributions payload: ' + payload.toString());
      final created = await employeeService.createDistribution(payload);
      log('Created distribution: ${created['_id']}');

      // Optimistically update selected customer outstanding locally
      final updatedOutstanding =
          ((_selectedCustomer?['outstandingDebts'] as num?)?.toDouble() ??
              0.0) +
          _mealAccount;
      setState(() {
        _selectedCustomer = {
          ..._selectedCustomer!,
          'outstandingDebts': updatedOutstanding,
        };
        final idx = _customers.indexWhere(
          (c) => c['_id'] == _selectedCustomer!['_id'],
        );
        if (idx != -1) _customers[idx] = _selectedCustomer!;
        _totalAccount = _mealAccount + updatedOutstanding;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل التوزيع وتحديث المديونية')),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('فشل العملية: $e');
      log('Error: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _posting = false;
      });
    }
  }

  void _onSelectCustomer(String? id) {
    if (id == null) return;
    final selected = _customers.firstWhere((c) => c['_id'] == id);
    setState(() {
      _selectedCustomer = selected;
      // Debug: Log selected customer
      print('Selected customer: $_selectedCustomer');
    });
    _recalculate();
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التوزيع'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/employee-dashboard'),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'العميل',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedCustomer?['_id'],
                          items: _customers
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c['_id'],
                                  child: Text(c['name'] ?? 'Unknown'),
                                ),
                              )
                              .toList(),
                          onChanged: _onSelectCustomer,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'يرجى اختيار العميل'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _quantityCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'العدد',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            print('Quantity changed: $value');
                            _recalculate();
                          },
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'أدخل عدداً صحيحاً';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _grossWeightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'وزن القائم (كجم)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            print('Gross weight changed: $value');
                            _recalculate();
                          },
                          validator: (v) {
                            final d = double.tryParse(v ?? '');
                            if (d == null || d < 0) return 'أدخل وزناً صحيحاً';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _netWeightCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'الوزن الصافي (يُحسب تلقائياً)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'السعر (ج.م/كجم)',
                            border: OutlineInputBorder(),
                            prefixText: 'ج.م ',
                          ),
                          onChanged: (value) {
                            print('Price changed: $value');
                            _recalculate();
                          },
                          validator: (v) {
                            final d = double.tryParse(v ?? '');
                            if (d == null || d < 0) return 'أدخل سعراً صحيحاً';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('حساب الوجبة'),
                                    Text(
                                      '${_mealAccount.toStringAsFixed(2)} ج.م',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('القديم (المستحق)'),
                                    Text(
                                      '${((_selectedCustomer?['outstandingDebts'] as num?) ?? 0).toString()} ج.م',
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'إجمالي الحساب',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${_totalAccount.toStringAsFixed(2)} ج.م',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (_formKey.currentState?.validate() ??
                                      false) {
                                    _recalculate(); // Ensure latest values
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'تم حساب التوزيع: ${_totalAccount.toStringAsFixed(2)} ج.م',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.calculate),
                                label: const Text('حساب'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: (_saving || _posting)
                                    ? null
                                    : _submitBoth,
                                icon: (_saving || _posting)
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.done_all),
                                label: const Text(
                                  'تسجيل وتحديث المديونية معاً',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                _debugLog.isEmpty
                                    ? 'Debug: لا يوجد سجل بعد'
                                    : _debugLog,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
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
