import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/customer_api_service.dart';
import '../../../../core/services/employee_api_service.dart';
import '../../../../core/services/distribution_api_service.dart';
import '../../../authentication/cubit/auth_cubit.dart';
import '../../../authentication/cubit/auth_state.dart';

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

  Future<void> _showDistributionHistory() async {
    await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: _DistributionHistoryDialog(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Use Navigator.pop() to go back to previous page
          Navigator.of(context).pop();
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('التوزيع'),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadCustomers,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
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
                                if (n == null || n <= 0)
                                  return 'أدخل عدداً صحيحاً';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _grossWeightCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                                if (d == null || d < 0)
                                  return 'أدخل وزناً صحيحاً';
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                                if (d == null || d < 0)
                                  return 'أدخل سعراً صحيحاً';
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                                // Only show history button if user is not an employee
                                if (!_isEmployee()) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _showDistributionHistory,
                                      icon: const Icon(Icons.history),
                                      label: const Text('سجل التوزيعات'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
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
        ),
      ),
    );
  }
}

class _DistributionHistoryDialog extends StatefulWidget {
  @override
  _DistributionHistoryDialogState createState() =>
      _DistributionHistoryDialogState();
}

class _DistributionHistoryDialogState
    extends State<_DistributionHistoryDialog> {
  late final DistributionApiService _distributionService;
  List<Map<String, dynamic>> _distributions = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _distributionService = serviceLocator<DistributionApiService>();
    _loadDistributionsForDate(_selectedDate);
  }

  Future<void> _loadDistributionsForDate(DateTime date) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allDistributions = await _distributionService.getAllDistributions();

      // Filter distributions by selected date
      final filteredDistributions = allDistributions.where((distribution) {
        final distributionDate = DateTime.parse(
          distribution['createdAt'] ?? distribution['distributionDate'] ?? '',
        );
        return distributionDate.year == date.year &&
            distributionDate.month == date.month &&
            distributionDate.day == date.day;
      }).toList();

      setState(() {
        _distributions = filteredDistributions;
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
      _loadDistributionsForDate(picked);
    }
  }

  List<Map<String, dynamic>> get _filteredDistributions {
    if (_searchQuery.isEmpty) return _distributions;

    return _distributions.where((distribution) {
      final customerName =
          distribution['customer']?['name']?.toString().toLowerCase() ?? '';
      final employeeName =
          distribution['employee']?['username']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return customerName.contains(query) || employeeName.contains(query);
    }).toList();
  }

  double _calculateTotalWeight() {
    return _filteredDistributions.fold<double>(0.0, (sum, distribution) {
      final netWeight = (distribution['netWeight'] ?? 0) as num;
      return sum + netWeight.toDouble();
    });
  }

  double _calculateTotalValue() {
    return _filteredDistributions.fold<double>(0.0, (sum, distribution) {
      final totalAmount = (distribution['totalAmount'] ?? 0) as num;
      return sum + totalAmount.toDouble();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التوزيعات'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDistributionsForDate(_selectedDate),
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
                      'تاريخ التوزيع:',
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
          if (!_isLoading && _filteredDistributions.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.scale,
                              color: Colors.blue,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_calculateTotalWeight().toStringAsFixed(1)} كجم',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text('إجمالي الوزن'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
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
                              '${_calculateTotalValue().toStringAsFixed(0)} ج.م',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text('إجمالي القيمة'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Distribution list
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
                          onPressed: () =>
                              _loadDistributionsForDate(_selectedDate),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : _filteredDistributions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('لا توجد توزيعات في هذا التاريخ'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredDistributions.length,
                    itemBuilder: (context, index) {
                      final distribution = _filteredDistributions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange[100],
                            child: const Icon(
                              Icons.outbound,
                              color: Colors.orange,
                            ),
                          ),
                          title: Text(
                            distribution['customer']?['name'] ??
                                'عميل غير معروف',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الموظف: ${distribution['employee']?['username'] ?? 'غير محدد'}',
                              ),
                              Text('الكمية: ${distribution['quantity']}'),
                              Text(
                                'الوزن الصافي: ${distribution['netWeight']} كجم',
                              ),
                              Text(
                                'إجمالي المبلغ: ${distribution['totalAmount']} ج.م',
                              ),
                              Text(
                                'التاريخ: ${_formatDateTime(distribution['createdAt'])}',
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
