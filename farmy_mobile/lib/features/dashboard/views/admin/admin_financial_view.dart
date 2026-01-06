import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/payment_api_service.dart';
import '../../../../core/services/customer_api_service.dart';
import '../../../../core/services/transfer_api_service.dart';
import '../../../../core/services/loading_api_service.dart';
import '../../../../core/services/employee_expense_api_service.dart';
import '../../../authentication/cubit/auth_cubit.dart';

class AdminFinancialView extends StatefulWidget {
  const AdminFinancialView({super.key});

  @override
  State<AdminFinancialView> createState() => _AdminFinancialViewState();
}

class _AdminFinancialViewState extends State<AdminFinancialView> {
  late final PaymentApiService _paymentService;
  late final TransferApiService _transferService;
  late final LoadingApiService _loadingService;
  late final EmployeeExpenseApiService _employeeExpenseService;
  final Map<String, String> _customerNameCache = {};

  bool _loading = true;
  String? _error;
  double _totalCollected = 0.0;
  List<Map<String, dynamic>> _dailyCollections = [];

  // Transfer variables
  List<Map<String, dynamic>> _transfers = [];
  double _totalTransfersOut = 0.0;
  double _totalTransfersIn = 0.0;
  double _netTransfers = 0.0;
  double _finalBalance = 0.0;

  // Loading and expenses
  double _totalLoading = 0.0;
  double _totalExpenses = 0.0;

  @override
  void initState() {
    super.initState();
    _paymentService = serviceLocator<PaymentApiService>();
    _transferService = serviceLocator<TransferApiService>();
    _loadingService = serviceLocator<LoadingApiService>();
    _employeeExpenseService = serviceLocator<EmployeeExpenseApiService>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authCubit = context.read<AuthCubit>();
      final currentUser = authCubit.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final adminId = currentUser.id;

      // Get user collections summary (includes backend-calculated values)
      final collectionsSummary = await _paymentService
          .getUserCollectionsSummary();

      // Get total loading amount from dedicated endpoint
      final totalLoadingAmount = await _loadingService.getTotalLoadingAmount();

      // Find current user's data
      final userData = collectionsSummary.firstWhere(
        (item) => (item['userId'] ?? '').toString() == adminId,
        orElse: () => {
          'totalCollected': 0,
          'transfersIn': 0,
          'transfersOut': 0,
          'totalExpenses': 0,
          'totalLoading': 0,
          'adminBalance': 0,
        },
      );

      _totalCollected = ((userData['totalCollected'] ?? 0) as num).toDouble();
      final double transfersIn = ((userData['transfersIn'] ?? 0) as num)
          .toDouble();
      final double transfersOut = ((userData['transfersOut'] ?? 0) as num)
          .toDouble();
      _totalExpenses = ((userData['totalExpenses'] ?? 0) as num).toDouble();
      _totalLoading = totalLoadingAmount;

      // Use backend-calculated adminBalance if available, otherwise calculate
      if (userData.containsKey('adminBalance')) {
        _finalBalance = ((userData['adminBalance'] ?? 0) as num).toDouble();
      } else {
        // Fallback calculation: employee balance - total loading
        // Employee balance = totalCollected + transfersIn - transfersOut - totalExpenses
        // Admin balance = employee balance - totalLoading
        _finalBalance =
            _totalCollected +
            transfersIn -
            transfersOut -
            _totalExpenses -
            _totalLoading;
      }

      // Get user daily grouped collections (history)
      _dailyCollections = await _paymentService.getUserDailyCollections(
        adminId,
      );

      // Load transfers for current user (for display)
      _transfers = await _transferService.listTransfers(userId: adminId);

      // Calculate transfer totals for display
      _totalTransfersOut = _transfers
          .where(
            (transfer) => transfer['fromUser']?['_id']?.toString() == adminId,
          )
          .fold<double>(
            0.0,
            (sum, transfer) =>
                sum + ((transfer['amount'] ?? 0) as num).toDouble(),
          );

      _totalTransfersIn = _transfers
          .where(
            (transfer) => transfer['toUser']?['_id']?.toString() == adminId,
          )
          .fold<double>(
            0.0,
            (sum, transfer) =>
                sum + ((transfer['amount'] ?? 0) as num).toDouble(),
          );

      _netTransfers = _totalTransfersIn - _totalTransfersOut;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<String> _resolveCustomerName(dynamic customerField) async {
    try {
      if (customerField is Map<String, dynamic>) {
        final name = customerField['name']?.toString();
        if (name != null && name.isNotEmpty) return name;
        final id = customerField['_id']?.toString();
        if (id != null && id.isNotEmpty) {
          if (_customerNameCache.containsKey(id))
            return _customerNameCache[id]!;
          final svc = serviceLocator<CustomerApiService>();
          final data = await svc.getCustomerById(id);
          final fetched = data?['name']?.toString() ?? 'عميل';
          _customerNameCache[id] = fetched;
          return fetched;
        }
      } else if (customerField is String && customerField.isNotEmpty) {
        if (_customerNameCache.containsKey(customerField)) {
          return _customerNameCache[customerField]!;
        }
        final svc = serviceLocator<CustomerApiService>();
        final data = await svc.getCustomerById(customerField);
        final fetched = data?['name']?.toString() ?? 'عميل';
        _customerNameCache[customerField] = fetched;
        return fetched;
      }
    } catch (_) {}
    return 'عميل غير معروف';
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final currentUser = authCubit.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('البيانات المالية'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'حدث خطأ في تحميل البيانات',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Admin Info Card
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Theme.of(context).primaryColor,
                                child: Text(
                                  currentUser?.username
                                          .substring(0, 1)
                                          .toUpperCase() ??
                                      'م',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentUser?.username ?? 'مدير',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'مدير',
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 24),

                      // Financial Summary Cards
                      _buildSummaryCard(
                        'إجمالي التحصيل',
                        _totalCollected,
                        Icons.account_balance_wallet,
                        Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryCard(
                        'إجمالي التحميل',
                        _totalLoading,
                        Icons.local_shipping,
                        Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      // Total Loading Placeholder
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_shipping,
                              color: Colors.blue[700],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'إجمالي التحميل من الخادم',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ج.م ${_totalLoading.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Debug: Show calculation breakdown
                      Card(
                        elevation: 1,
                        color: Colors.amber[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تفاصيل الحساب (للتصحيح)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[900],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'التحصيل: ${_totalCollected.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              Text(
                                'التحويلات الواردة: ${_totalTransfersIn.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              Text(
                                'التحويلات المرسلة: ${_totalTransfersOut.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              Text(
                                'المصروفات: ${_totalExpenses.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              Text(
                                'التحميل: $_totalLoading',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'الرصيد النهائي: ${_finalBalance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryCard(
                        'إجمالي المصروفات',
                        _totalExpenses,
                        Icons.money_off,
                        Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryCard(
                        'الرصيد النهائي (بعد التحويلات والمصروفات والتحميل)',
                        _finalBalance,
                        Icons.account_balance_wallet,
                        _finalBalance >= 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(height: 24),

                      // Daily Collections History
                      Text(
                        'سجل التحصيل اليومي',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_dailyCollections.isEmpty)
                        _buildEmptyState(
                          Icons.history,
                          'لا يوجد سجلات تحصيل',
                          'لم يتم تسجيل أي تحصيلات حتى الآن',
                        )
                      else ...[
                        for (final day in _dailyCollections)
                          _buildDailyHistoryCard(day),
                      ],

                      const SizedBox(height: 24),

                      // Transfers Section
                      Text(
                        'التحويلات المالية',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Transfer Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'التحويلات المرسلة',
                              _totalTransfersOut,
                              Icons.send,
                              Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'التحويلات المستلمة',
                              _totalTransfersIn,
                              Icons.call_received,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryCard(
                        'صافي التحويلات',
                        _netTransfers,
                        Icons.swap_horiz,
                        _netTransfers >= 0 ? Colors.blue : Colors.red,
                      ),
                      const SizedBox(height: 16),

                      if (_transfers.isEmpty)
                        _buildEmptyState(
                          Icons.swap_horiz,
                          'لا توجد تحويلات',
                          'لم يتم تسجيل أي تحويلات مالية بعد',
                        )
                      else
                        ..._transfers.map(
                          (transfer) => _buildTransferCard(transfer),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ج.م ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyHistoryCard(Map<String, dynamic> day) {
    final String date = (day['date'] ?? '').toString();
    final double totalPaid = ((day['totalPaid'] ?? 0) as num).toDouble();
    final int count = (day['count'] ?? 0) as int;
    final List<dynamic> payments = (day['payments'] as List<dynamic>? ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDate(date),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ج.م ${totalPaid.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'عدد السجلات: $count',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...payments.map((p) {
              final double paidAmount = ((p['paidAmount'] ?? 0) as num)
                  .toDouble();
              final double discount = ((p['discount'] ?? 0) as num).toDouble();
              final String createdAt = (p['createdAt'] ?? '').toString();
              final dynamic customerField = p['customer'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(Icons.payments, color: Colors.blue),
                ),
                title: Text(
                  'تحصيل: ج.م ${paidAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: _resolveCustomerName(customerField),
                      builder: (context, snap) {
                        final name = snap.data ?? '...';
                        return Text(
                          'العميل: $name',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        );
                      },
                    ),
                    if (discount > 0)
                      Text(
                        'خصم: ج.م ${discount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    if (createdAt.isNotEmpty)
                      Text(
                        _formatTime(createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferCard(Map<String, dynamic> transfer) {
    final authCubit = context.read<AuthCubit>();
    final currentUser = authCubit.currentUser;
    final adminId = currentUser?.id ?? '';

    final amount = ((transfer['amount'] ?? 0) as num).toDouble();
    final note = transfer['note'] ?? '';
    final createdAt = transfer['createdAt'] ?? '';
    final fromUser = transfer['fromUser'];
    final toUser = transfer['toUser'];

    // Determine if this is an outgoing or incoming transfer
    final isOutgoing = fromUser?['_id']?.toString() == adminId;
    final otherUser = isOutgoing ? toUser : fromUser;
    final otherUserName = otherUser?['username'] ?? 'غير معروف';
    final otherUserRole = otherUser?['role'] ?? 'employee';
    final roleLabel = otherUserRole == 'manager' ? ' (مدير)' : ' (موظف)';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOutgoing
              ? Colors.red.withOpacity(0.1)
              : Colors.green.withOpacity(0.1),
          child: Icon(
            isOutgoing ? Icons.send : Icons.call_received,
            color: isOutgoing ? Colors.red : Colors.green,
          ),
        ),
        title: Text(
          isOutgoing
              ? 'تحويل إلى: $otherUserName$roleLabel'
              : 'تحويل من: $otherUserName$roleLabel',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isOutgoing ? '-' : '+'} ج.م ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isOutgoing ? Colors.red : Colors.green,
              ),
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                note,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _formatDate(createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOutgoing
                ? Colors.red.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isOutgoing ? 'مرسل' : 'مستلم',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isOutgoing ? Colors.red : Colors.green,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (e) {
      return '';
    }
  }
}
