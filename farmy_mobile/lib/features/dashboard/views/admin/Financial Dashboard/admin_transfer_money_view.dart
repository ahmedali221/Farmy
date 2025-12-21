import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../../../core/services/transfer_api_service.dart';
import '../../../../../core/services/employee_api_service.dart';
import '../../../../../core/services/payment_api_service.dart';

class AdminTransferMoneyView extends StatefulWidget {
  const AdminTransferMoneyView({super.key});

  @override
  State<AdminTransferMoneyView> createState() => _AdminTransferMoneyViewState();
}

class _AdminTransferMoneyViewState extends State<AdminTransferMoneyView> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _fromEmployeeId;
  String? _toUserId;
  bool _submitting = false;
  List<Map<String, dynamic>> _allUsers = []; // All users (Employees + Managers)
  bool _loading = true;
  double? _availableAmount;

  late final TransferApiService _transferService;
  late final EmployeeApiService _employeeService;
  late final PaymentApiService _paymentService;

  @override
  void initState() {
    super.initState();
    _transferService = GetIt.I<TransferApiService>();
    _employeeService = GetIt.I<EmployeeApiService>();
    _paymentService = GetIt.I<PaymentApiService>();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      // Get all users (employees + managers)
      final allUsers = await _employeeService.getAllUsers();
      
      if (mounted) {
        setState(() {
          _allUsers = allUsers;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('فشل في تحميل البيانات: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAvailableAmount(String? userId) async {
    if (userId == null || userId.isEmpty) {
      setState(() => _availableAmount = null);
      return;
    }

    try {
      final summary = await _paymentService.getUserCollectionsSummary();
      double? available;
      for (final it in summary) {
        final String id = (it['userId'] ?? '').toString();
        if (id == userId) {
          if (it.containsKey('netAfterExpenses')) {
            available = ((it['netAfterExpenses'] ?? 0) as num).toDouble();
          } else {
            final double totalCollected =
                ((it['totalCollected'] ?? 0) as num).toDouble();
            final double transfersIn =
                ((it['transfersIn'] ?? 0) as num).toDouble();
            final double transfersOut =
                ((it['transfersOut'] ?? 0) as num).toDouble();
            final double totalExpenses =
                ((it['totalExpenses'] ?? 0) as num).toDouble();
            available =
                totalCollected + transfersIn - transfersOut - totalExpenses;
          }
          break;
        }
      }
      setState(() {
        _availableAmount = available ?? 0;
      });
    } catch (e) {
      setState(() => _availableAmount = null);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromEmployeeId == null || _fromEmployeeId!.isEmpty) {
      await _showErrorDialog('اختر الموظف المرسل');
      return;
    }
    if (_toUserId == null || _toUserId!.isEmpty) {
      await _showErrorDialog('اختر المستلم');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _transferService.createTransfer(
        fromUser: _fromEmployeeId!,
        toUser: _toUserId!,
        amount: double.parse(_amountController.text),
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      await _showSuccessDialog('تم التحويل بنجاح');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog('فشل التحويل: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _getUserDisplayName(Map<String, dynamic> user) {
    final username = user['username']?.toString() ?? 'غير معروف';
    final role = user['role']?.toString() ?? '';
    if (role == 'manager') {
      return '$username (أدمن)';
    }
    return username;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحويل أموال (أدمن)'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // From User Selection (Any User)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'من (أي مستخدم)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _fromEmployeeId,
                                  isExpanded: true,
                                  items: _allUsers
                                      .map(
                                        (u) => DropdownMenuItem<String>(
                                          value: (u['_id'] ?? '').toString(),
                                          child: Row(
                                            children: [
                                              Icon(
                                                u['role'] == 'manager'
                                                    ? Icons.admin_panel_settings
                                                    : Icons.person,
                                                size: 18,
                                                color: u['role'] == 'manager'
                                                    ? Colors.purple
                                                    : Colors.blue,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(_getUserDisplayName(u)),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _fromEmployeeId = v;
                                      _toUserId = null; // Reset destination
                                    });
                                    _loadAvailableAmount(v);
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'اختر المرسل',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty)
                                          ? 'اختر المرسل'
                                          : null,
                                ),
                                if (_availableAmount != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          color: Colors.blue,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'المتاح: EGP ${_availableAmount!.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // To User Selection (Employees + Admin)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'إلى (أي مستخدم)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _toUserId,
                                  isExpanded: true,
                                  items: _allUsers
                                      .where((u) =>
                                          (u['_id']?.toString() ?? '') !=
                                          _fromEmployeeId)
                                      .map(
                                        (u) => DropdownMenuItem<String>(
                                          value: (u['_id'] ?? '').toString(),
                                          child: Row(
                                            children: [
                                              Icon(
                                                u['role'] == 'manager'
                                                    ? Icons.admin_panel_settings
                                                    : Icons.person,
                                                size: 18,
                                                color: u['role'] == 'manager'
                                                    ? Colors.purple
                                                    : Colors.blue,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(_getUserDisplayName(u)),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _toUserId = v),
                                  decoration: const InputDecoration(
                                    labelText: 'اختر المستلم',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty)
                                          ? 'اختر مستلمًا'
                                          : null,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'يمكنك التحويل من وإلى أي موظف أو مدير',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Amount
                        TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ (EGP)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'المبلغ مطلوب';
                            }
                            final d = double.tryParse(v);
                            if (d == null || d <= 0) {
                              return 'أدخل قيمة صحيحة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Note
                        TextFormField(
                          controller: _noteController,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظة (اختياري)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.note),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: const Icon(Icons.send),
                            label: Text(
                              _submitting ? 'جارٍ التحويل...' : 'تحويل',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
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

  Future<void> _showSuccessDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('نجاح'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('خطأ'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }
}

