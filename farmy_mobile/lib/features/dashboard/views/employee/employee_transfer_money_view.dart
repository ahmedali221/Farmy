import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/services/transfer_api_service.dart';
import '../../../../core/services/employee_api_service.dart';
import '../../../../core/services/payment_api_service.dart';
import '../../../authentication/cubit/auth_cubit.dart';

class EmployeeTransferMoneyView extends StatefulWidget {
  const EmployeeTransferMoneyView({super.key});

  @override
  State<EmployeeTransferMoneyView> createState() => _EmployeeTransferMoneyViewState();
}

class _EmployeeTransferMoneyViewState extends State<EmployeeTransferMoneyView> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _toUserId;
  bool _submitting = false;
  List<Map<String, dynamic>> _allUsers = []; // Employees + Managers

  late final TransferApiService _transferService;
  late final EmployeeApiService _employeeService;
  late final PaymentApiService _paymentService;

  bool _loading = true;
  double? _availableAmount;
  String? _currentUserId;
  String? _currentUserName;

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
      final authCubit = context.read<AuthCubit>();
      final currentUser = authCubit.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      _currentUserId = currentUser.id;
      _currentUserName = currentUser.username;

      // Get all users (employees + managers)
      final allUsers = await _employeeService.getAllUsers();
      
      // Filter out current user from the list
      final filteredUsers = allUsers
          .where((user) => (user['_id'] ?? '').toString() != _currentUserId)
          .toList();

      // Get available amount for current user
      final summary = await _paymentService.getUserCollectionsSummary();
      double? available;
      for (final it in summary) {
        final String id = (it['userId'] ?? '').toString();
        if (id == _currentUserId) {
          // Prefer netAfterExpenses if provided; otherwise compute fallback
          if (it.containsKey('netAfterExpenses')) {
            available = ((it['netAfterExpenses'] ?? 0) as num).toDouble();
          } else {
            final double totalCollected = ((it['totalCollected'] ?? 0) as num)
                .toDouble();
            final double transfersIn = ((it['transfersIn'] ?? 0) as num)
                .toDouble();
            final double transfersOut = ((it['transfersOut'] ?? 0) as num)
                .toDouble();
            final double totalExpenses = ((it['totalExpenses'] ?? 0) as num)
                .toDouble();
            available =
                totalCollected + transfersIn - transfersOut - totalExpenses;
          }
          break;
        }
      }

      setState(() {
        _allUsers = filteredUsers;
        _availableAmount = available ?? 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في تحميل البيانات: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
    if (_toUserId == null || _toUserId!.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تنبيه'),
          content: const Text('اختر المستلم'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }
    if (_currentUserId == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('خطأ'),
          content: const Text('المستخدم غير معروف'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _transferService.createTransfer(
        fromUser: _currentUserId!,
        toUser: _toUserId!,
        amount: double.parse(_amountController.text),
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('نجاح'),
          content: const Text('تم التحويل بنجاح'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('خطأ'),
          content: Text('فشل التحويل: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _getUserDisplayName(Map<String, dynamic> user) {
    final username = (user['username'] ?? 'مستخدم').toString();
    final role = (user['role'] ?? 'employee').toString();
    final roleLabel = role == 'manager' ? ' (مدير)' : ' (موظف)';
    return '$username$roleLabel';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحويل أموال'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentUserName ?? 'موظف',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'المتاح للتحويل: EGP ${(_availableAmount ?? 0).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _toUserId,
                        isExpanded: true,
                        items: _allUsers
                            .map(
                              (user) => DropdownMenuItem<String>(
                                value: (user['_id'] ?? '').toString(),
                                child: Text(_getUserDisplayName(user)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _toUserId = v),
                        decoration: const InputDecoration(
                          labelText: 'إلى',
                          border: OutlineInputBorder(),
                          hintText: 'اختر المستلم (موظف أو مدير)',
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'اختر المستلم' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ (EGP)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'المبلغ مطلوب';
                          final d = double.tryParse(v);
                          if (d == null || d <= 0) return 'أدخل قيمة صحيحة';
                          if (_availableAmount != null &&
                              d > _availableAmount!) {
                            return 'القيمة تتجاوز المتاح للتحويل';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      if (_availableAmount != null)
                        Text(
                          'المتاح: EGP ${_availableAmount!.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظة (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: const Icon(Icons.send),
                          label: Text(
                            _submitting ? 'جارٍ التحويل...' : 'تحويل',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
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

