import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/loading_api_service.dart';
import '../../../../core/services/customer_api_service.dart';
import '../../../../core/services/inventory_api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/pdf_arabic_utils.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../authentication/cubit/auth_cubit.dart';
import '../../../authentication/cubit/auth_state.dart';

class OrderPlacementView extends StatefulWidget {
  const OrderPlacementView({super.key});

  @override
  State<OrderPlacementView> createState() => _OrderPlacementViewState();
}

class _OrderPlacementViewState extends State<OrderPlacementView> {
  // Static list of predefined chicken types from backend enum
  static const List<Map<String, String>> predefinedChickenTypes = [
    {'id': 'أبيض', 'name': 'أبيض'},
    {'id': 'تسمين', 'name': 'تسمين'},
    {'id': 'بلدي', 'name': 'بلدي'},
    {'id': 'احمر', 'name': 'احمر'},
    {'id': 'ساسو', 'name': 'ساسو'},
    {'id': 'بط', 'name': 'بط'},
  ];

  List<Map<String, dynamic>> customers = [];
  bool isLoading = true;
  bool isSubmitting = false;
  bool isOrderSubmitted = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  String? selectedChickenTypeId;
  String? selectedCustomerId;
  final _customerNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _totalPriceController = TextEditingController();
  // التحميل controllers
  final _grossWeightController = TextEditingController();
  final _emptyWeightController = TextEditingController();
  final _netWeightController = TextEditingController();
  final _loadingPriceController = TextEditingController();
  final _totalLoadingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _grossWeightController.addListener(_calculateLoadingValues);
    _quantityController.addListener(_calculateLoadingValues);
    _loadingPriceController.addListener(_calculateLoadingValues);
    _quantityController.addListener(_onQuantityChanged);
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _quantityController.dispose();
    _totalPriceController.dispose();
    _grossWeightController.dispose();
    _emptyWeightController.dispose();
    _netWeightController.dispose();
    _loadingPriceController.dispose();
    _totalLoadingController.dispose();
    super.dispose();
  }

  void _onQuantityChanged() {
    setState(() {
      // Trigger rebuild to show/hide warning immediately
    });
  }

  void _calculateLoadingValues() {
    final gross = double.tryParse(_grossWeightController.text);
    final count = double.tryParse(_quantityController.text);
    final loadingPrice = double.tryParse(_loadingPriceController.text);

    // Only calculate if all required values are provided
    if (gross != null && count != null && loadingPrice != null) {
      // الوزن الفارغ = العدد × 8
      final emptyWeight = count * 8;
      _emptyWeightController.text = emptyWeight.toStringAsFixed(2);

      // الوزن الصافي = الوزن القائم - الوزن الفارغ
      final netWeight = gross - emptyWeight;
      _netWeightController.text = netWeight.toStringAsFixed(2);

      // إجمالي التحميل = الوزن الصافي × سعر التحميل
      final totalLoading = netWeight * loadingPrice;
      _totalLoadingController.text = totalLoading.toStringAsFixed(2);

      // Update legacy fields for backward compatibility
      _totalPriceController.text = totalLoading.toStringAsFixed(2);
    } else {
      // Clear calculated fields if any required value is missing
      _emptyWeightController.clear();
      _netWeightController.clear();
      _totalLoadingController.clear();
      _totalPriceController.clear();
    }
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      final customerService = serviceLocator<CustomerApiService>();
      final customersList = await customerService.getAllCustomers();

      if (mounted) {
        setState(() {
          customers = customersList;
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

  // Removed stock checking logic as per requirements

  // Resolve or create customer by typed name
  Future<String> _ensureCustomerIdFromName() async {
    final name = _customerNameController.text.trim();
    if (name.isEmpty) {
      throw Exception('يرجى إدخال اسم العميل');
    }

    // Try local list first (case-insensitive match)
    try {
      final existing = customers.firstWhere(
        (c) =>
            (c['name']?.toString().toLowerCase() ?? '') == name.toLowerCase(),
      );
      return existing['_id'] as String;
    } catch (_) {
      // Not found → create new customer
      final customerService = serviceLocator<CustomerApiService>();
      final created = await customerService.createCustomer({'name': name});
      // Update local cache
      customers = [...customers, created];
      return created['_id'] as String;
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

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
          '[OrderPlacement] before.netLoadingWeight=${before['netLoadingWeight']}',
        );
      } catch (e) {
        debugPrint('[OrderPlacement] failed to fetch before daily stock: $e');
      }

      final loadingService = serviceLocator<LoadingApiService>();

      // Resolve or create customer from typed name
      selectedCustomerId = await _ensureCustomerIdFromName();

      final loadingData = {
        'chickenType': selectedChickenTypeId,
        'customer': selectedCustomerId,
        'quantity': double.parse(_quantityController.text),
        'grossWeight': double.tryParse(_grossWeightController.text) ?? 0,
        'loadingPrice': double.tryParse(_loadingPriceController.text) ?? 0,
        // Hint backend to set loadingDate explicitly to today (matches stock window)
        'loadingDate': DateTime.now().toIso8601String(),
        'notes': null, // Default to null as per requirements
      };

      await loadingService.createLoading(loadingData);

      if (mounted) {
        setState(() {
          isOrderSubmitted = true;
        });
        // User feedback
        final net = double.tryParse(_netWeightController.text) ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تسجيل التحميل. الوزن الصافي للطلب: ${net.toStringAsFixed(2)} كجم',
            ),
          ),
        );
        // Debug: fetch after-submit stock snapshot
        try {
          final inventoryService = serviceLocator<InventoryApiService>();
          final after = await inventoryService.getDailyInventoryByDate(
            day.toIso8601String(),
          );
          debugPrint(
            '[OrderPlacement] after.netLoadingWeight=${after['netLoadingWeight']}',
          );
        } catch (e) {
          debugPrint('[OrderPlacement] failed to fetch after daily stock: $e');
        }
        // Refresh data
        await _loadData();
        await _generateAndPrintPdf();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('فشل في إنشاء التحميل: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> _generateAndPrintPdf() async {
    try {
      const appName = 'Farmy';
      final customerName = _customerNameController.text.trim().isEmpty
          ? 'غير معروف'
          : _customerNameController.text.trim();

      final now = DateTime.now();
      final qty = _quantityController.text;
      final gross = _grossWeightController.text;
      final empty = _emptyWeightController.text;
      final net = _netWeightController.text;
      final price = _loadingPriceController.text;
      final total = _totalLoadingController.text;

      final html =
          '''
<div dir="rtl" style="font-family: NotoArabic, sans-serif;">
  <div style="display:flex;justify-content:space-between;align-items:center;background:#e3f2fd;border-radius:8px;padding:12px 14px;margin-bottom:14px;">
    <div style="font-weight:700;font-size:18px;color:#0d47a1;">$appName</div>
    <div style="font-size:12px;color:#0d47a1;">${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}</div>
  </div>
  <h2 style="margin:6px 0 10px 0;">إيصال تحميل</h2>
  <div style="border:1px solid #e0e0e0;border-radius:8px;padding:10px;margin-bottom:12px;background:#fafafa;">
    <div><strong>العميل:</strong> $customerName</div>
  </div>
  <table style="width:100%;border-collapse:collapse;margin-top:8px;">
    <tr><td style="border:1px solid #e0e0e0;padding:8px;width:40%;">العدد</td><td style="border:1px solid #e0e0e0;padding:8px;">$qty</td></tr>
    <tr><td style="border:1px solid #e0e0e0;padding:8px;">وزن القائم (كجم)</td><td style="border:1px solid #e0e0e0;padding:8px;">$gross</td></tr>
    <tr><td style="border:1px solid #e0e0e0;padding:8px;">الوزن الفارغ (كجم)</td><td style="border:1px solid #e0e0e0;padding:8px;">$empty</td></tr>
    <tr><td style="border:1px solid #e0e0e0;padding:8px;">الوزن الصافي (كجم)</td><td style="border:1px solid #e0e0e0;padding:8px;">$net</td></tr>
    <tr><td style="border:1px solid #e0e0e0;padding:8px;">سعر التحميل (ج.م/كجم)</td><td style="border:1px solid #e0e0e0;padding:8px;">$price</td></tr>
    <tr><td style="border:1px solid #e0e0e0;padding:8px;font-weight:700;">إجمالي التحميل (ج.م)</td><td style="border:1px solid #e0e0e0;padding:8px;font-weight:700;">$total</td></tr>
  </table>
  <div style="margin-top:14px;text-align:center;color:#555;">شكراً لاستخدامك تطبيق $appName</div>
</div>
''';

      await PdfArabicUtils.printArabicHtml(htmlBody: html);
    } catch (_) {}
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

  Future<void> _showLoadingHistory() async {
    await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: _LoadingHistoryDialog(),
          ),
        ),
      ),
    );
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
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // Customer Selection (text input)
                                    _SectionCard(
                                      title: 'المكان',
                                      child: Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: Autocomplete<String>(
                                          optionsBuilder:
                                              (TextEditingValue value) {
                                                final query = value.text
                                                    .trim()
                                                    .toLowerCase();
                                                if (query.isEmpty) {
                                                  return const Iterable<
                                                    String
                                                  >.empty();
                                                }
                                                return customers
                                                    .map(
                                                      (c) =>
                                                          c['name']
                                                              ?.toString() ??
                                                          '',
                                                    )
                                                    .where(
                                                      (name) => name
                                                          .toLowerCase()
                                                          .contains(query),
                                                    )
                                                    .take(10);
                                              },
                                          onSelected: (String selection) {
                                            _customerNameController.text =
                                                selection;
                                            _onQuantityChanged();
                                          },
                                          fieldViewBuilder:
                                              (
                                                context,
                                                textEditingController,
                                                focusNode,
                                                onFieldSubmitted,
                                              ) {
                                                textEditingController.text =
                                                    _customerNameController
                                                        .text;
                                                textEditingController
                                                        .selection =
                                                    TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset:
                                                            textEditingController
                                                                .text
                                                                .length,
                                                      ),
                                                    );
                                                return TextFormField(
                                                  controller:
                                                      _customerNameController,
                                                  focusNode: focusNode,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'اسم العميل',
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
                                                  onChanged: (v) {
                                                    // keep same behavior as before
                                                    _onQuantityChanged();
                                                  },
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.trim().isEmpty) {
                                                      return 'يرجى إدخال اسم العميل';
                                                    }
                                                    return null;
                                                  },
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
                                                        padding:
                                                            EdgeInsets.zero,
                                                        itemCount:
                                                            options.length,
                                                        itemBuilder:
                                                            (context, index) {
                                                              final option =
                                                                  options
                                                                      .elementAt(
                                                                        index,
                                                                      );
                                                              return ListTile(
                                                                title: Text(
                                                                  option,
                                                                ),
                                                                onTap: () =>
                                                                    onSelected(
                                                                      option,
                                                                    ),
                                                              );
                                                            },
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Chicken Type Selection
                                    _SectionCard(
                                      title: 'نوع الدجاج',
                                      child: Column(
                                        children: [
                                          const SizedBox(height: 8),
                                          _DropdownField(
                                            label: 'نوع الدجاج',
                                            value: selectedChickenTypeId,
                                            items: predefinedChickenTypes
                                                .map(
                                                  (
                                                    chickenType,
                                                  ) => DropdownMenuItem<String>(
                                                    value: chickenType['id'],
                                                    child: Text(
                                                      chickenType['name']!,
                                                      style: const TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                selectedChickenTypeId = value;
                                              });
                                            },
                                            validator: (value) {
                                              if (value == null) {
                                                return 'يرجى اختيار نوع الدجاج';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // التحميل - Input Fields
                                    _SectionCard(
                                      title: 'بيانات التحميل',
                                      child: Column(
                                        children: [
                                          if (selectedChickenTypeId != null)
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
                                                    'النوع المحدد: ',
                                                    style: TextStyle(
                                                      color: Colors.blue[700],
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    predefinedChickenTypes
                                                            .firstWhere(
                                                              (c) =>
                                                                  c['id'] ==
                                                                  selectedChickenTypeId,
                                                              orElse: () => {
                                                                'name':
                                                                    'غير معروف',
                                                              },
                                                            )['name'] ??
                                                        'غير معروف',
                                                    style: TextStyle(
                                                      color: Colors.blue[900],
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          const SizedBox(height: 16),

                                          // Input Fields - Vertical Layout
                                          _NumField(
                                            label: 'العدد',
                                            controller: _quantityController,
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'يرجى إدخال العدد';
                                              }
                                              final quantity = double.tryParse(
                                                value,
                                              );
                                              if (quantity == null ||
                                                  quantity <= 0) {
                                                return 'يرجى إدخال عدد صحيح';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 12),

                                          _NumField(
                                            label: 'الوزن القائم (كيلو)',
                                            controller: _grossWeightController,
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'يرجى إدخال الوزن القائم';
                                              }
                                              final weight = double.tryParse(
                                                value,
                                              );
                                              if (weight == null ||
                                                  weight <= 0) {
                                                return 'يرجى إدخال وزن صحيح';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 12),

                                          _NumField(
                                            label: 'سعر التحميل (EGP/كيلو)',
                                            controller: _loadingPriceController,
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'يرجى إدخال سعر التحميل';
                                              }
                                              final price = double.tryParse(
                                                value,
                                              );
                                              if (price == null || price <= 0) {
                                                return 'يرجى إدخال سعر صحيح';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 12),

                                          _NumField(
                                            label:
                                                'الوزن الفارغ (يحسب تلقائياً)',
                                            controller: _emptyWeightController,
                                            enabled: false,
                                          ),
                                          const SizedBox(height: 12),

                                          _NumField(
                                            label:
                                                'الوزن الصافي (يحسب تلقائياً)',
                                            controller: _netWeightController,
                                            enabled: false,
                                          ),
                                          const SizedBox(height: 12),

                                          _NumField(
                                            label: 'إجمالي التحميل (EGP)',
                                            controller: _totalLoadingController,
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
                                                'تسجيل التحميل',
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
                                          onPressed: _showLoadingHistory,
                                          icon: Icon(
                                            Icons.history,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          label: Text(
                                            'سجل التحميلات',
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

                                    // Removed PDF generation action button
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
            child: Icon(Icons.person, color: Colors.grey.shade700, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تسجيل التحميل',
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
  final String? Function(String?)? validator;

  const _NumField({
    required this.label,
    required this.controller,
    this.enabled = true,
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
      style: const TextStyle(
        overflow: TextOverflow.ellipsis,
        color: Colors.black,
        fontWeight: FontWeight.w500,
      ),
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
            style: const TextStyle(
              overflow: TextOverflow.ellipsis,
              color: Colors.black,
            ),
            maxLines: 1,
            child: item.child,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
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
      icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
    );
  }
}

// Removed legacy _TextField widget; replaced by Autocomplete-based field above

class _LoadingHistoryDialog extends StatefulWidget {
  @override
  _LoadingHistoryDialogState createState() => _LoadingHistoryDialogState();
}

class _LoadingHistoryDialogState extends State<_LoadingHistoryDialog> {
  late final LoadingApiService _loadingService;
  List<Map<String, dynamic>> _loadings = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadingService = serviceLocator<LoadingApiService>();
    _loadLoadingsForDate(_selectedDate);
  }

  Future<void> _loadLoadingsForDate(DateTime date) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allLoadings = await _loadingService.getAllLoadings();

      // Filter loadings by selected date
      final filteredLoadings = allLoadings.where((loading) {
        final loadingDate = DateTime.parse(
          loading['createdAt'] ?? loading['date'] ?? '',
        );
        return loadingDate.year == date.year &&
            loadingDate.month == date.month &&
            loadingDate.day == date.day;
      }).toList();

      setState(() {
        _loadings = filteredLoadings;
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
      _loadLoadingsForDate(picked);
    }
  }

  List<Map<String, dynamic>> get _filteredLoadings {
    if (_searchQuery.isEmpty) return _loadings;

    return _loadings.where((loading) {
      final customerName =
          loading['customer']?['name']?.toString().toLowerCase() ?? '';
      final chickenType =
          loading['chickenType']?['name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return customerName.contains(query) || chickenType.contains(query);
    }).toList();
  }

  double _calculateTotalWeight() {
    return _filteredLoadings.fold<double>(0.0, (sum, loading) {
      final netWeight = (loading['netWeight'] ?? 0) as num;
      return sum + netWeight.toDouble();
    });
  }

  double _calculateTotalValue() {
    return _filteredLoadings.fold<double>(0.0, (sum, loading) {
      final totalLoading = (loading['totalLoading'] ?? 0) as num;
      return sum + totalLoading.toDouble();
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
        title: const Text('سجل التحميلات'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadLoadingsForDate(_selectedDate),
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
                      'تاريخ التحميل:',
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
                    hintText: 'البحث في العملاء أو نوع الدجاج...',
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
          if (!_isLoading && _filteredLoadings.isNotEmpty) ...[
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

          // Loading list
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
                          onPressed: () => _loadLoadingsForDate(_selectedDate),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : _filteredLoadings.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('لا توجد تحميلات في هذا التاريخ'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredLoadings.length,
                    itemBuilder: (context, index) {
                      final loading = _filteredLoadings[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: const Icon(
                              Icons.local_shipping,
                              color: Colors.blue,
                            ),
                          ),
                          title: Text(
                            loading['customer']?['name'] ?? 'عميل غير معروف',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'نوع الدجاج: ${loading['chickenType']?['name'] ?? 'غير محدد'}',
                              ),
                              Text('الكمية: ${loading['quantity']}'),
                              Text('الوزن الصافي: ${loading['netWeight']} كجم'),
                              Text(
                                'إجمالي التحميل: ${loading['totalLoading']} ج.م',
                              ),
                              Text(
                                'التاريخ: ${_formatDateTime(loading['createdAt'])}',
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
