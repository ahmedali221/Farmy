import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/customer_api_service.dart';
import '../../../../core/services/distribution_api_service.dart';
import '../../../../core/services/inventory_api_service.dart';
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
  final TextEditingController _customerNameCtrl = TextEditingController();

  // Chicken type selection
  List<Map<String, dynamic>> _chickenTypes = [];
  Map<String, dynamic>? _selectedChickenType;

  // Available quantities information
  Map<String, dynamic>? _availableQuantities;
  bool _loadingQuantities = false;

  final TextEditingController _quantityCtrl = TextEditingController();
  final TextEditingController _grossWeightCtrl = TextEditingController();
  final TextEditingController _emptyWeightCtrl = TextEditingController();
  final TextEditingController _netWeightCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();

  double _mealAccount = 0;
  double _totalAccount = 0;
  double _oldOutstandingSnapshot = 0;
  bool _loading = true;
  bool _posting = false;

  String _debugLog = '';

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _loadChickenTypes();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculate());
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _quantityCtrl.dispose();
    _grossWeightCtrl.dispose();
    _emptyWeightCtrl.dispose();
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
      print('Loaded customers: $_customers');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showErrorDialog('فشل تحميل العملاء: $e');
    }
  }

  Future<void> _loadChickenTypes() async {
    try {
      final distributionService = serviceLocator<DistributionApiService>();
      final chickenTypes = await distributionService.getAvailableChickenTypes(
        _selectedDate,
      );
      if (!mounted) return;
      setState(() {
        _chickenTypes = chickenTypes;
        _selectedChickenType = null;
      });
      print('Loaded available chicken types: $_chickenTypes');
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('فشل تحميل أنواع الفراخ المتاحة: $e');
    }
  }

  Future<void> _loadAvailableQuantities() async {
    if (_selectedChickenType == null) {
      setState(() {
        _availableQuantities = null;
      });
      return;
    }

    setState(() {
      _loadingQuantities = true;
    });

    try {
      final distributionService = serviceLocator<DistributionApiService>();
      final quantities = await distributionService.getAvailableQuantities(
        _selectedDate,
        _selectedChickenType!['_id'] as String,
      );
      if (!mounted) return;
      setState(() {
        _availableQuantities = quantities;
        _loadingQuantities = false;
      });
      print('Loaded available quantities: $_availableQuantities');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingQuantities = false;
      });
      _showErrorDialog('فشل تحميل الكميات المتاحة: $e');
    }
  }

  Future<String> _ensureCustomerIdFromName() async {
    final name = _customerNameCtrl.text.trim();
    if (name.isEmpty) {
      throw Exception('يرجى إدخال اسم العميل');
    }

    try {
      final existing = _customers.firstWhere(
        (c) =>
            (c['name']?.toString().toLowerCase() ?? '') == name.toLowerCase(),
      );
      setState(() {
        _selectedCustomer = existing;
      });
      return existing['_id'] as String;
    } catch (_) {
      final customerService = serviceLocator<CustomerApiService>();
      final created = await customerService.createCustomer({'name': name});
      setState(() {
        _customers = [..._customers, created];
        _selectedCustomer = created;
      });
      return created['_id'] as String;
    }
  }

  void _onCustomerNameChanged(String value) {
    try {
      final match = _customers.firstWhere(
        (c) =>
            (c['name']?.toString().toLowerCase() ?? '') ==
            value.trim().toLowerCase(),
      );
      setState(() {
        _selectedCustomer = match;
      });
    } catch (_) {
      setState(() {
        _selectedCustomer = null;
      });
    }
    _recalculate();
  }

  void _recalculate() {
    final quantity = int.tryParse(_quantityCtrl.text) ?? 0;
    final gross = double.tryParse(_grossWeightCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;

    final emptyWeight = quantity * 8;
    final net = (gross - emptyWeight).clamp(0, double.infinity);
    final mealAccount = price * net;
    final outstanding = (_selectedCustomer != null)
        ? (_selectedCustomer!['outstandingDebts'] as num? ?? 0).toDouble()
        : 0.0;
    final totalAccount = mealAccount + outstanding;

    print('Recalculate - Quantity: $quantity, Gross: $gross, Price: $price');
    print(
      'EmptyWeight: $emptyWeight, Net: $net, MealAccount: $mealAccount, TotalAccount: $totalAccount',
    );

    setState(() {
      _emptyWeightCtrl.text = emptyWeight.toStringAsFixed(2);
      _netWeightCtrl.text = net.toStringAsFixed(2);
      _mealAccount = mealAccount;
      _totalAccount = totalAccount;
      _oldOutstandingSnapshot = outstanding;
    });
  }

  // Calculate over-distribution (excess quantity/weight)
  Map<String, dynamic>? _calculateOverDistribution() {
    if (_availableQuantities == null || _selectedChickenType == null) {
      return null;
    }

    final requestedQuantity = int.tryParse(_quantityCtrl.text) ?? 0;
    final requestedNetWeight = double.tryParse(_netWeightCtrl.text) ?? 0.0;

    final availableQuantity =
        (_availableQuantities!['totalAvailableQuantity'] as num?)?.toInt() ?? 0;
    final availableNetWeight =
        (_availableQuantities!['totalAvailableNetWeight'] as num?)
            ?.toDouble() ??
        0.0;

    final quantityExcess = requestedQuantity > availableQuantity
        ? requestedQuantity - availableQuantity
        : 0;
    final netWeightExcess = requestedNetWeight > availableNetWeight
        ? requestedNetWeight - availableNetWeight
        : 0.0;

    if (quantityExcess > 0 || netWeightExcess > 0) {
      return {
        'quantityExcess': quantityExcess,
        'netWeightExcess': netWeightExcess,
        'availableQuantity': availableQuantity,
        'availableNetWeight': availableNetWeight,
      };
    }

    return null;
  }

  bool _isAdminOrManager() {
    try {
      final authState = context.read<AuthCubit>().state;
      if (authState is AuthAuthenticated) {
        return authState.user.role == 'manager' ||
            authState.user.role == 'employee';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _generateAndPrintPdf({
    required double oldOutstanding,
    required double mealAccount,
    required double newOutstanding,
  }) async {
    try {
      final pdf = pw.Document();

      final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(16.0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'إيصال توزيع',
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text(
                      'العميل: ${_selectedCustomer?['name'] ?? 'غير معروف'}',
                      style: pw.TextStyle(font: ttf, fontSize: 16),
                    ),
                    pw.Text(
                      'نوع الفراخ: ${_selectedChickenType?['name'] ?? 'غير محدد'}',
                      style: pw.TextStyle(font: ttf, fontSize: 16),
                    ),
                    pw.Text(
                      'التاريخ: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} - ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                      style: pw.TextStyle(font: ttf, fontSize: 16),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Table(
                      border: pw.TableBorder.all(),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(3),
                      },
                      children: [
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'القيمة',
                                style: pw.TextStyle(
                                  font: ttf,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'البيان',
                                style: pw.TextStyle(
                                  font: ttf,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        _buildTableRow('العدد', _quantityCtrl.text, ttf),
                        _buildTableRow(
                          'وزن القائم (كجم)',
                          _grossWeightCtrl.text,
                          ttf,
                        ),
                        _buildTableRow(
                          'الوزن الفارغ (كجم)',
                          _emptyWeightCtrl.text,
                          ttf,
                        ),
                        _buildTableRow(
                          'الوزن الصافي (كجم)',
                          _netWeightCtrl.text,
                          ttf,
                        ),
                        _buildTableRow('السعر (ج.م/كجم)', _priceCtrl.text, ttf),
                        _buildTableRow(
                          'حساب الوجبة (ج.م)',
                          mealAccount.toStringAsFixed(2),
                          ttf,
                        ),
                        _buildTableRow(
                          'المستحق القديم قبل الفاتورة (ج.م)',
                          oldOutstanding.toStringAsFixed(2),
                          ttf,
                        ),
                        _buildTableRow(
                          'المستحق الجديد بعد الفاتورة (ج.م)',
                          newOutstanding.toStringAsFixed(2),
                          ttf,
                          isBold: true,
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                    pw.Center(
                      child: pw.Text(
                        'تم إنشاء هذا الإيصال تلقائياً بواسطة النظام',
                        style: pw.TextStyle(font: ttf, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      _showErrorDialog('خطأ أثناء إنشاء ملف PDF: $e');
      _debugLog += 'PDF Generation Error: $e\n';
      setState(() {});
    }
  }

  pw.TableRow _buildTableRow(
    String label,
    String value,
    pw.Font font, {
    bool isBold = false,
  }) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : null,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitBoth() async {
    _debugLog = '';
    void log(String m) {
      _debugLog += m + '\n';
      print('[DistributionSubmit] ' + m);
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      log('Validation failed');
      setState(() {});
      return;
    }
    if (_customerNameCtrl.text.trim().isEmpty) {
      log('No customer name');
      _showErrorDialog('يرجى إدخال اسم العميل أولاً');
      setState(() {});
      return;
    }
    if (_selectedChickenType == null) {
      log('No chicken type selected');
      _showErrorDialog('يرجى اختيار نوع الفراخ أولاً');
      setState(() {});
      return;
    }

    setState(() {
      _posting = true;
    });

    try {
      // Debug: capture pre-submit stock snapshot for the day
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      try {
        final inventoryService = serviceLocator<InventoryApiService>();
        final before = await inventoryService.getDailyInventoryByDate(
          day.toIso8601String(),
        );
        debugPrint(
          '[DistributionSubmit] before.netDistributionWeight=${before['netDistributionWeight']}',
        );
      } catch (e) {
        debugPrint(
          '[DistributionSubmit] failed to fetch before daily stock: $e',
        );
      }
      _recalculate();
      log(
        'Inputs -> qty=${_quantityCtrl.text}, gross=${_grossWeightCtrl.text}, price=${_priceCtrl.text}',
      );
      log(
        'Calculated -> net=${_netWeightCtrl.text}, meal=${_mealAccount.toStringAsFixed(2)}',
      );

      // Ensure customer exists or create it, then post
      final customerId = await _ensureCustomerIdFromName();

      final distributionService = serviceLocator<DistributionApiService>();
      final payload = {
        'customer': customerId,
        'chickenType': _selectedChickenType!['_id'],
        'quantity': int.tryParse(_quantityCtrl.text) ?? 0,
        'grossWeight': double.tryParse(_grossWeightCtrl.text) ?? 0.0,
        'price': double.tryParse(_priceCtrl.text) ?? 0.0,
        // Use user-selected distribution date (can be old date)
        'distributionDate': _selectedDate.toIso8601String(),
      };
      log('POST /distributions payload: ' + payload.toString());
      final created = await distributionService.createDistribution(payload);
      log('Created distribution: ${created['_id']}');
      // Show record net weight
      final net = double.tryParse(_netWeightCtrl.text) ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تسجيل التوزيع. الوزن الصافي للطلب: ${net.toStringAsFixed(2)} كجم',
            ),
          ),
        );
      }

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
        _totalAccount = updatedOutstanding;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل التوزيع وتحديث المديونية')),
      );

      // Capture snapshot values for the PDF to ensure "old outstanding" reflects pre-order value
      final oldOutstanding = _oldOutstandingSnapshot;
      final mealAccount = _mealAccount;
      final newOutstanding = oldOutstanding + mealAccount;

      await _generateAndPrintPdf(
        oldOutstanding: oldOutstanding,
        mealAccount: mealAccount,
        newOutstanding: newOutstanding,
      );
      log('PDF generated successfully');
      // Debug: fetch after-submit stock snapshot
      try {
        final inventoryService = serviceLocator<InventoryApiService>();
        final after = await inventoryService.getDailyInventoryByDate(
          day.toIso8601String(),
        );
        debugPrint(
          '[DistributionSubmit] after.netDistributionWeight=${after['netDistributionWeight']}',
        );
      } catch (e) {
        debugPrint(
          '[DistributionSubmit] failed to fetch after daily stock: $e',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('فشل العملية: $e');
      log('Error: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _posting = false;
      });
      // Reset form after successful submission
      _resetDistributionForm();
    }
  }

  void _resetDistributionForm() {
    setState(() {
      _customerNameCtrl.clear();
      _selectedCustomer = null;
      _selectedChickenType = null;
      _availableQuantities = null;
      _quantityCtrl.clear();
      _grossWeightCtrl.clear();
      _emptyWeightCtrl.clear();
      _netWeightCtrl.clear();
      _priceCtrl.clear();
      _mealAccount = 0;
      _totalAccount = 0;
      _selectedDate = DateTime.now();
    });
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
      return true;
    } catch (e) {
      return true;
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
                            // Date selector
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 18),
                                const SizedBox(width: 8),
                                const Text('تاريخ التوزيع:'),
                                const Spacer(),
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                  ),
                                  label: Text(
                                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  ),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate: DateTime(2024, 1, 1),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setState(() => _selectedDate = picked);
                                      _loadChickenTypes();
                                      _loadAvailableQuantities();
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Autocomplete<String>(
                                optionsBuilder: (TextEditingValue value) {
                                  final query = value.text.trim().toLowerCase();
                                  if (query.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  return _customers
                                      .map((c) => c['name']?.toString() ?? '')
                                      .where(
                                        (name) =>
                                            name.toLowerCase().contains(query),
                                      )
                                      .take(10);
                                },
                                onSelected: (String selection) {
                                  _customerNameCtrl.text = selection;
                                  _onCustomerNameChanged(selection);
                                },
                                fieldViewBuilder:
                                    (
                                      context,
                                      textEditingController,
                                      focusNode,
                                      onFieldSubmitted,
                                    ) {
                                      // Keep controller in sync with our state controller
                                      textEditingController.text =
                                          _customerNameCtrl.text;
                                      textEditingController.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset: textEditingController
                                                  .text
                                                  .length,
                                            ),
                                          );
                                      return TextFormField(
                                        controller: _customerNameCtrl,
                                        focusNode: focusNode,
                                        decoration: const InputDecoration(
                                          labelText: 'اسم العميل',
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: _onCustomerNameChanged,
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                            ? 'يرجى إدخال اسم العميل'
                                            : null,
                                      );
                                    },
                                optionsViewBuilder:
                                    (context, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topRight,
                                        child: Material(
                                          elevation: 4,
                                          child: SizedBox(
                                            width:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width -
                                                32,
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              itemCount: options.length,
                                              itemBuilder: (context, index) {
                                                final option = options
                                                    .elementAt(index);
                                                return ListTile(
                                                  title: Text(option),
                                                  onTap: () =>
                                                      onSelected(option),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Chicken Type Selection
                            DropdownButtonFormField<Map<String, dynamic>>(
                              value: _selectedChickenType,
                              decoration: const InputDecoration(
                                labelText: 'نوع الفراخ',
                                border: OutlineInputBorder(),
                              ),
                              items: _chickenTypes.map((chickenType) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: chickenType,
                                  child: Text(
                                    chickenType['name'] ?? 'غير محدد',
                                  ),
                                );
                              }).toList(),
                              onChanged: (Map<String, dynamic>? value) {
                                setState(() {
                                  _selectedChickenType = value;
                                });
                                _loadAvailableQuantities();
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'يرجى اختيار نوع الفراخ';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Available Quantities Information
                            if (_selectedChickenType != null) ...[
                              if (_loadingQuantities)
                                const Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                )
                              else if (_availableQuantities != null)
                                Card(
                                  color: Colors.blue[50],
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              color: Colors.blue[700],
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'الكميات المتاحة',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue[700],
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _InfoCard(
                                                title: 'العدد المتاح',
                                                value:
                                                    '${_availableQuantities!['totalAvailableQuantity']}',
                                                icon: Icons.numbers,
                                                color: Colors.green,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _InfoCard(
                                                title: 'الوزن الصافي المتاح',
                                                value:
                                                    '${(_availableQuantities!['totalAvailableNetWeight'] as num).toStringAsFixed(2)} كجم',
                                                icon: Icons.scale,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Over-distribution warning
                                        if (_calculateOverDistribution() !=
                                                null &&
                                            _isAdminOrManager()) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.orange[300]!,
                                                width: 2,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      color: Colors.orange[700],
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'توزيع زائد عن المتاح',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Colors.orange[900],
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                if (_calculateOverDistribution()!['quantityExcess'] >
                                                    0)
                                                  Text(
                                                    'الزيادة في العدد: ${_calculateOverDistribution()!['quantityExcess']} (المتاح: ${_calculateOverDistribution()!['availableQuantity']})',
                                                    style: TextStyle(
                                                      color: Colors.orange[800],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                if (_calculateOverDistribution()!['netWeightExcess'] >
                                                    0) ...[
                                                  if (_calculateOverDistribution()!['quantityExcess'] >
                                                      0)
                                                    const SizedBox(height: 4),
                                                  Text(
                                                    'الزيادة في الوزن الصافي: ${(_calculateOverDistribution()!['netWeightExcess'] as num).toStringAsFixed(2)} كجم (المتاح: ${(_calculateOverDistribution()!['availableNetWeight'] as num).toStringAsFixed(2)} كجم)',
                                                    style: TextStyle(
                                                      color: Colors.orange[800],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                            ],

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
                                setState(
                                  () {},
                                ); // Refresh to show over-distribution warning
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
                                setState(
                                  () {},
                                ); // Refresh to show over-distribution warning
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
                              controller: _emptyWeightCtrl,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'الوزن الفارغ (يُحسب تلقائياً)',
                                border: OutlineInputBorder(),
                              ),
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
                                        const Text(
                                          'المستحق القديم قبل الفاتورة',
                                        ),
                                        Text(
                                          '${((_selectedCustomer?['outstandingDebts'] as num?) ?? 0).toString()} ج.م',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
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
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'المستحق الجديد بعد الفاتورة',
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
                                    onPressed: _posting ? null : _submitBoth,
                                    icon: const Icon(Icons.check_circle),
                                    label: Text(
                                      _posting
                                          ? 'جارٍ الإرسال...'
                                          : 'تسجيل التوزيع',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

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
      final filteredDistributions = allDistributions.where((distribution) {
        final distributionDate = DateTime.parse(
          distribution['distributionDate'] ?? distribution['createdAt'] ?? '',
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
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
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
                                'التاريخ: ${_formatDateTime(distribution['distributionDate'] ?? distribution['createdAt'])}',
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

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
