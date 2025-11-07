import 'package:flutter/material.dart';
import '../../../../../../core/di/service_locator.dart';
import '../../../../../../core/services/payment_api_service.dart';
import '../../../../../../core/services/employee_api_service.dart';
import '../../../../../../core/services/employee_expense_api_service.dart';
import '../../../../../../core/services/loading_api_service.dart';
import '../../../../../../core/services/finance_api_service.dart';
import '../../../../../../core/services/distribution_api_service.dart';

class TreasuryTab extends StatefulWidget {
  const TreasuryTab({super.key});

  @override
  State<TreasuryTab> createState() => _TreasuryTabState();
}

class _TreasuryTabState extends State<TreasuryTab> {
  late final PaymentApiService _paymentService;
  late final EmployeeApiService _employeeService;
  late final EmployeeExpenseApiService _employeeExpenseService;
  late final LoadingApiService _loadingService;
  late final FinanceApiService _financeService;
  late final DistributionApiService _distributionService;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _employeeCollections = [];
  final Map<String, String> _employeeIdToName = {};
  final Map<String, List<Map<String, dynamic>>> _otherExpensesByEmployee = {};
  double _totalLoadingAmount = 0.0;
  double _totalExternalRevenue = 0.0;
  List<Map<String, dynamic>> _externalRevenueHistory = [];
  double _totalWithdrawals = 0.0;
  List<Map<String, dynamic>> _withdrawalsHistory = [];
  double _totalDistributions = 0.0;
  double _previousDayTreasury = 0.0;

  // Unfiltered values for total treasury calculation
  double _totalCollectedUnfiltered = 0.0;
  double _totalExternalRevenueUnfiltered = 0.0;
  double _totalLoadingAmountUnfiltered = 0.0;
  double _totalDistributionsUnfiltered = 0.0;
  double _totalOtherExpensesUnfiltered = 0.0;
  double _totalWithdrawalsUnfiltered = 0.0;

  // Daily filter variables
  DateTime _selectedDate = DateTime.now();
  bool _isDailyFilter = false;

  @override
  void initState() {
    super.initState();
    _paymentService = serviceLocator<PaymentApiService>();
    _employeeService = serviceLocator<EmployeeApiService>();
    _employeeExpenseService = serviceLocator<EmployeeExpenseApiService>();
    _loadingService = serviceLocator<LoadingApiService>();
    _financeService = serviceLocator<FinanceApiService>();
    _distributionService = serviceLocator<DistributionApiService>();
    _loadData();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  void _toggleDailyFilter() {
    setState(() {
      _isDailyFilter = !_isDailyFilter;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Load all data in parallel
      final results = await Future.wait([
        _isDailyFilter
            ? _paymentService
                  .getAllPayments() // Get all payments for filtering
            : _paymentService.getUserCollectionsSummary(),
        _loadingService.getAllLoadings(),
        _financeService.getDailyFinancialReports(),
        _distributionService.getAllDistributions(),
      ]);

      final dynamic listOrPayments = results[0];
      final allLoadings = results[1];
      final financeReports = results[2];
      final allDistributions = results[3];

      // Apply daily filter if enabled
      List<Map<String, dynamic>> filteredLoadings = allLoadings;
      List<Map<String, dynamic>> filteredFinanceReports = financeReports;
      List<Map<String, dynamic>> filteredDistributions = allDistributions;

      if (_isDailyFilter) {
        final targetDate = _selectedDate;
        final startOfDay = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        );
        final endOfDay = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day + 1,
        );

        // Filter loadings by date
        filteredLoadings = allLoadings.where((loading) {
          final createdAt = DateTime.parse(loading['createdAt'] ?? '');
          return !createdAt.isBefore(startOfDay) &&
              createdAt.isBefore(endOfDay);
        }).toList();

        // Filter finance reports by date
        filteredFinanceReports = financeReports.where((report) {
          final reportDate = DateTime.parse(report['date'] ?? '');
          return !reportDate.isBefore(startOfDay) &&
              reportDate.isBefore(endOfDay);
        }).toList();

        // Filter distributions by date
        filteredDistributions = allDistributions.where((distribution) {
          final createdAt = DateTime.parse(distribution['createdAt'] ?? '');
          return !createdAt.isBefore(startOfDay) &&
              createdAt.isBefore(endOfDay);
        }).toList();
      }

      // Process payments: filter and group by user if daily filter is enabled
      List<Map<String, dynamic>> list = [];
      if (_isDailyFilter) {
        // Filter payments by date and group by user
        final allPayments = listOrPayments as List<Map<String, dynamic>>;
        final targetDate = _selectedDate;
        final startOfDay = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        );
        final endOfDay = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day + 1,
        );

        final filteredPayments = allPayments.where((payment) {
          final paymentDateStr =
              payment['paymentDate'] ?? payment['createdAt'] ?? '';
          if (paymentDateStr.toString().isEmpty) return false;
          try {
            final paymentDate = DateTime.parse(paymentDateStr.toString());
            return !paymentDate.isBefore(startOfDay) &&
                paymentDate.isBefore(endOfDay);
          } catch (_) {
            return false;
          }
        }).toList();

        // Group filtered payments by user
        final Map<String, Map<String, dynamic>> collectionMap = {};
        for (final payment in filteredPayments) {
          final userId = (payment['user'] is Map)
              ? (payment['user']['_id'] ?? payment['user']['id'] ?? '')
                    .toString()
              : (payment['user'] ?? '').toString();
          if (userId.isEmpty) continue;

          if (!collectionMap.containsKey(userId)) {
            collectionMap[userId] = {
              'userId': userId,
              'totalCollected': 0.0,
              'count': 0,
            };
          }

          final num paidAmount = (payment['paidAmount'] ?? 0) as num;
          collectionMap[userId]!['totalCollected'] =
              ((collectionMap[userId]!['totalCollected'] as num) +
                      paidAmount.toDouble())
                  .toDouble();
          collectionMap[userId]!['count'] =
              ((collectionMap[userId]!['count'] as int) + 1);
        }
        list = collectionMap.values.toList();
      } else {
        // When not filtering, use the summary directly
        list = listOrPayments as List<Map<String, dynamic>>;
      }

      // Calculate total loading amount (filtered for display)
      final totalLoading = filteredLoadings.fold<double>(0.0, (sum, loading) {
        final num totalLoadingAmount = (loading['totalLoading'] ?? 0) as num;
        return sum + totalLoadingAmount.toDouble();
      });

      // Calculate total loading amount (unfiltered for total treasury)
      final totalLoadingUnfiltered = allLoadings.fold<double>(0.0, (
        sum,
        loading,
      ) {
        final num totalLoadingAmount = (loading['totalLoading'] ?? 0) as num;
        return sum + totalLoadingAmount.toDouble();
      });

      // Calculate total distributions amount (filtered for display)
      final totalDistributions = filteredDistributions.fold<double>(0.0, (
        sum,
        distribution,
      ) {
        final num totalAmount = (distribution['totalAmount'] ?? 0) as num;
        return sum + totalAmount.toDouble();
      });

      // Calculate total distributions amount (unfiltered for total treasury)
      final totalDistributionsUnfiltered = allDistributions.fold<double>(0.0, (
        sum,
        distribution,
      ) {
        final num totalAmount = (distribution['totalAmount'] ?? 0) as num;
        return sum + totalAmount.toDouble();
      });

      // Calculate previous day treasury (only for daily filter)
      double previousDayTreasury = 0.0;
      if (_isDailyFilter) {
        final previousDay = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day - 1,
        );
        final previousDayStart = DateTime(
          previousDay.year,
          previousDay.month,
          previousDay.day,
        );
        final previousDayEnd = DateTime(
          previousDay.year,
          previousDay.month,
          previousDay.day + 1,
        );

        // Calculate previous day's treasury using the same logic
        final previousDayLoadings = allLoadings.where((loading) {
          final createdAt = DateTime.parse(loading['createdAt'] ?? '');
          return !createdAt.isBefore(previousDayStart) &&
              createdAt.isBefore(previousDayEnd);
        }).toList();

        final previousDayDistributions = allDistributions.where((distribution) {
          final createdAt = DateTime.parse(distribution['createdAt'] ?? '');
          return !createdAt.isBefore(previousDayStart) &&
              createdAt.isBefore(previousDayEnd);
        }).toList();

        final previousDayFinanceReports = financeReports.where((report) {
          final reportDate = DateTime.parse(report['date'] ?? '');
          return !reportDate.isBefore(previousDayStart) &&
              reportDate.isBefore(previousDayEnd);
        }).toList();

        final prevLoading = previousDayLoadings.fold<double>(0.0, (
          sum,
          loading,
        ) {
          final num totalLoadingAmount = (loading['totalLoading'] ?? 0) as num;
          return sum + totalLoadingAmount.toDouble();
        });

        final prevDistributions = previousDayDistributions.fold<double>(0.0, (
          sum,
          distribution,
        ) {
          final num totalAmount = (distribution['totalAmount'] ?? 0) as num;
          return sum + totalAmount.toDouble();
        });

        double prevWithdrawals = 0.0;
        for (final rec in previousDayFinanceReports) {
          final bool hasEmployee =
              rec['employee'] != null && rec['employee'].toString().isNotEmpty;
          if (hasEmployee) continue;
          final num expenses = (rec['expenses'] ?? 0) as num;
          if (expenses > 0) {
            prevWithdrawals += expenses.toDouble();
          }
        }

        // Previous day treasury calculation (simplified - you might need to adjust this)
        previousDayTreasury = prevDistributions - prevLoading - prevWithdrawals;
      }

      // External revenue and withdrawals (no employee) - filtered for display
      final List<Map<String, dynamic>> externalList = [];
      final List<Map<String, dynamic>> withdrawalsList = [];
      double external = 0.0;
      double withdrawals = 0.0;
      for (final rec in filteredFinanceReports) {
        final bool hasEmployee =
            rec['employee'] != null && rec['employee'].toString().isNotEmpty;
        if (hasEmployee) continue;
        final num revenue = (rec['revenue'] ?? 0) as num;
        final num expenses = (rec['expenses'] ?? 0) as num;
        if (revenue > 0) {
          externalList.add(rec);
          external += revenue.toDouble();
        }
        if (expenses > 0) {
          withdrawalsList.add(rec);
          withdrawals += expenses.toDouble();
        }
      }

      // External revenue and withdrawals (unfiltered for total treasury)
      double externalUnfiltered = 0.0;
      double withdrawalsUnfiltered = 0.0;
      for (final rec in financeReports) {
        final bool hasEmployee =
            rec['employee'] != null && rec['employee'].toString().isNotEmpty;
        if (hasEmployee) continue;
        final num revenue = (rec['revenue'] ?? 0) as num;
        final num expenses = (rec['expenses'] ?? 0) as num;
        if (revenue > 0) {
          externalUnfiltered += revenue.toDouble();
        }
        if (expenses > 0) {
          withdrawalsUnfiltered += expenses.toDouble();
        }
      }

      try {
        final users = await _employeeService.getAllEmployeeUsers();
        _employeeIdToName.clear();
        for (final u in users) {
          final String id = (u['_id'] ?? '').toString();
          final String name = (u['username'] ?? u['name'] ?? 'موظف').toString();
          if (id.isNotEmpty) _employeeIdToName[id] = name;
        }
      } catch (_) {}

      final Map<String, List<Map<String, dynamic>>> serverExpenses = {};
      final Map<String, List<Map<String, dynamic>>> serverExpensesUnfiltered =
          {};

      // Get all employee IDs for calculating unfiltered values
      final Set<String> allEmployeeIds = {};
      if (_isDailyFilter) {
        // Get all payments to find all employees
        final allPayments = listOrPayments as List<Map<String, dynamic>>;
        for (final payment in allPayments) {
          final userId = (payment['user'] is Map)
              ? (payment['user']['_id'] ?? payment['user']['id'] ?? '')
                    .toString()
              : (payment['user'] ?? '').toString();
          if (userId.isNotEmpty) allEmployeeIds.add(userId);
        }
      } else {
        for (final it in list) {
          final String empId = (it['userId'] ?? '').toString();
          if (empId.isNotEmpty) allEmployeeIds.add(empId);
        }
      }

      if (_isDailyFilter) {
        // Filter expenses by date
        final targetDate = _selectedDate;
        final startOfDay = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        );
        final endOfDay = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day + 1,
        );

        for (final it in list) {
          final String empId = (it['userId'] ?? '').toString();
          if (empId.isEmpty) continue;
          try {
            final allItems = await _employeeExpenseService.listByEmployee(
              empId,
            );
            // Filter expenses by date
            final filteredItems = allItems.where((expense) {
              final createdAtStr = expense['createdAt'] ?? '';
              if (createdAtStr.toString().isEmpty) return false;
              try {
                final createdAt = DateTime.parse(createdAtStr.toString());
                return !createdAt.isBefore(startOfDay) &&
                    createdAt.isBefore(endOfDay);
              } catch (_) {
                return false;
              }
            }).toList();
            serverExpenses[empId] = filteredItems;
            serverExpensesUnfiltered[empId] = allItems;
          } catch (_) {}
        }

        // Also get expenses for employees not in filtered list (for unfiltered calculation)
        for (final empId in allEmployeeIds) {
          if (!serverExpensesUnfiltered.containsKey(empId)) {
            try {
              final allItems = await _employeeExpenseService.listByEmployee(
                empId,
              );
              serverExpensesUnfiltered[empId] = allItems;
            } catch (_) {}
          }
        }
      } else {
        // When not filtering, get all expenses
        for (final it in list) {
          final String empId = (it['userId'] ?? '').toString();
          if (empId.isEmpty) continue;
          try {
            final items = await _employeeExpenseService.listByEmployee(empId);
            serverExpenses[empId] = items;
            serverExpensesUnfiltered[empId] = items;
          } catch (_) {}
        }
      }

      // Calculate unfiltered total collected (includes transfers)
      double totalCollectedUnfiltered = 0.0;
      if (_isDailyFilter) {
        // Get all payments and sum them (we need to get summary for transfers)
        // For now, use payments only, but ideally should fetch summary
        final allPayments = listOrPayments;
        totalCollectedUnfiltered = (allPayments as List<Map<String, dynamic>>)
            .fold<double>(0.0, (sum, payment) {
              final num paidAmount = (payment['paidAmount'] ?? 0) as num;
              return sum + paidAmount.toDouble();
            });
        // TODO: Add transfers calculation for unfiltered total
        // This requires fetching all transfers or using summary API
      } else {
        // Use netAvailable which includes transfers
        totalCollectedUnfiltered = list.fold<double>(0.0, (sum, item) {
          final double collected = ((item['totalCollected'] ?? 0) as num)
              .toDouble();
          final double transfersIn = ((item['transfersIn'] ?? 0) as num)
              .toDouble();
          final double transfersOut = ((item['transfersOut'] ?? 0) as num)
              .toDouble();
          final double netAvailable = item['netAvailable'] != null
              ? ((item['netAvailable'] ?? 0) as num).toDouble()
              : collected + transfersIn - transfersOut;
          return sum + netAvailable;
        });
      }

      // Calculate unfiltered total other expenses
      double totalOtherExpensesUnfiltered = 0.0;
      serverExpensesUnfiltered.forEach((_, expenseList) {
        for (final expense in expenseList) {
          final num v = (expense['value'] ?? 0) as num;
          totalOtherExpensesUnfiltered += v.toDouble();
        }
      });

      if (!mounted) return;
      setState(() {
        _employeeCollections = list;
        _totalLoadingAmount = totalLoading;
        _totalDistributions = totalDistributions;
        _previousDayTreasury = previousDayTreasury;
        _totalExternalRevenue = external;
        _externalRevenueHistory = externalList;
        _totalWithdrawals = withdrawals;
        _withdrawalsHistory = withdrawalsList;
        _otherExpensesByEmployee
          ..clear()
          ..addAll(serverExpenses);

        // Store unfiltered values for total treasury calculation
        _totalCollectedUnfiltered = totalCollectedUnfiltered;
        _totalExternalRevenueUnfiltered = externalUnfiltered;
        _totalLoadingAmountUnfiltered = totalLoadingUnfiltered;
        _totalDistributionsUnfiltered = totalDistributionsUnfiltered;
        _totalOtherExpensesUnfiltered = totalOtherExpensesUnfiltered;
        _totalWithdrawalsUnfiltered = withdrawalsUnfiltered;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _employeeCollections = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  double _totalCollected() {
    return _employeeCollections.fold(0.0, (sum, item) {
      // Use netAvailable which includes transfers
      final double collected = ((item['totalCollected'] ?? 0) as num)
          .toDouble();
      final double transfersIn = ((item['transfersIn'] ?? 0) as num).toDouble();
      final double transfersOut = ((item['transfersOut'] ?? 0) as num)
          .toDouble();
      final double netAvailable = item['netAvailable'] != null
          ? ((item['netAvailable'] ?? 0) as num).toDouble()
          : collected + transfersIn - transfersOut;
      return sum + netAvailable;
    });
  }

  double _sumAllOtherExpenses() {
    double sum = 0.0;
    _otherExpensesByEmployee.forEach((_, list) {
      for (final e in list) {
        final num v = (e['value'] ?? 0) as num;
        sum += v.toDouble();
      }
    });
    return sum;
  }

  double _sumEmployeeExpenses(String employeeId) {
    final list = _otherExpensesByEmployee[employeeId] ?? [];
    return list.fold<double>(0.0, (sum, e) {
      final num v = (e['value'] ?? 0) as num;
      return sum + v.toDouble();
    });
  }

  Future<void> _showAddExpenseDialog(String employeeId) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _OtherExpenseDialog(),
    );
    if (result != null) {
      try {
        final created = await _employeeExpenseService.createExpense(
          employeeId,
          (result['name'] ?? 'مصروف') as String,
          ((result['value'] ?? 0) as num).toDouble(),
        );
        setState(() {
          _otherExpensesByEmployee.putIfAbsent(employeeId, () => []);
          _otherExpensesByEmployee[employeeId]!.add(created);
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل في حفظ المصروف: $e')));
      }
    }
  }

  Future<void> _showAddExternalRevenueDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _ExternalRevenueDialog(),
    );
    if (result != null) {
      try {
        final double value = ((result['value'] ?? 0) as num).toDouble();
        final String? source = (result['source'] as String?)?.trim();
        final String? notes = (result['notes'] as String?)?.trim();
        await _financeService.createFinancialRecord(
          date: DateTime.now(),
          type: 'daily',
          revenue: value,
          source: source?.isEmpty == true ? null : source,
          notes: notes?.isEmpty == true ? null : notes,
        );
        setState(() {
          _totalExternalRevenue += value;
          _externalRevenueHistory.insert(0, {
            'date': DateTime.now().toIso8601String(),
            'revenue': value,
            if (source != null && source.isNotEmpty) 'source': source,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
          });
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إضافة الإيراد الخارجي')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل في إضافة الإيراد: $e')));
      }
    }
  }

  Future<void> _showWithdrawDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _WithdrawDialog(),
    );
    if (result != null) {
      try {
        final double value = ((result['value'] ?? 0) as num).toDouble();
        final String? toWhom = (result['toWhom'] as String?)?.trim();
        final String? notes = (result['notes'] as String?)?.trim();
        await _financeService.createFinancialRecord(
          date: DateTime.now(),
          type: 'daily',
          expenses: value,
          source: toWhom?.isEmpty == true ? null : toWhom,
          notes: notes?.isEmpty == true ? null : notes,
        );
        setState(() {
          _totalWithdrawals += value;
          _withdrawalsHistory.insert(0, {
            'date': DateTime.now().toIso8601String(),
            'expenses': value,
            if (toWhom != null && toWhom.isNotEmpty) 'source': toWhom,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
          });
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تسجيل سحب من الخزنة')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل في تسجيل السحب: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 3),
              SizedBox(height: 16),
              Text('جاري تحميل البيانات...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                const Text(
                  'حدث خطأ في تحميل البيانات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final double total = _totalCollected();
    final double totalOther = _sumAllOtherExpenses();

    // Calculate total treasury using unfiltered values (always show total)
    final double netTotal =
        _totalCollectedUnfiltered +
        _totalExternalRevenueUnfiltered -
        _totalLoadingAmountUnfiltered -
        _totalOtherExpensesUnfiltered -
        _totalWithdrawalsUnfiltered;

    // Calculate filtered total treasury (only for daily filter display)
    final double netFiltered = _isDailyFilter
        ? total +
              _totalExternalRevenue -
              _totalLoadingAmount -
              totalOther -
              _totalWithdrawals
        : netTotal;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Daily Filter Controls
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.filter_list,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'تصفية البيانات',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _isDailyFilter,
                          onChanged: (value) => _toggleDailyFilter(),
                          activeColor: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                    if (_isDailyFilter) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('تحديث'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Header Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isDailyFilter
                          ? 'الخزنة المالية - ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'
                          : 'الخزنة المالية',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSummaryCard(
                      'إجمالي التحصيل',
                      total,
                      Colors.greenAccent,
                      Icons.money,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryCard(
                      'إيرادات خارجية',
                      _totalExternalRevenue,
                      Colors.purpleAccent,
                      Icons.account_balance,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryCard(
                      'إجمالي التحميل',
                      _totalLoadingAmount,
                      Colors.blueAccent,
                      Icons.local_shipping,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryCard(
                      'المصاريف الأخرى',
                      totalOther,
                      Colors.orangeAccent,
                      Icons.receipt_long,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryCard(
                      'سحوبات',
                      _totalWithdrawals,
                      Colors.redAccent,
                      Icons.outbox,
                    ),
                    const SizedBox(height: 20),
                    // Daily treasury (filtered)
                    if (_isDailyFilter)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: _summaryRow(
                          'إجمالي الخزنة - ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          netFiltered,
                          Colors.white,
                          bold: true,
                        ),
                      ),
                    // Total treasury (unfiltered)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: _summaryRow(
                        _isDailyFilter
                            ? 'إجمالي الخزنة الكلية'
                            : 'إجمالي الخزنة',
                        netTotal,
                        Colors.white,
                        bold: true,
                      ),
                    ),
                    if (_isDailyFilter) const SizedBox(height: 12),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 24,
                            ),
                            label: const Text(
                              'إضافة إيراد خارجي',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _showAddExternalRevenueDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.outbox, size: 24),
                            label: const Text(
                              'سحب من الخزنة',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _showWithdrawDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // External Revenue History Section
              if (_externalRevenueHistory.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.history,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'سجل الإيرادات الخارجية',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _externalRevenueHistory.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final item = _externalRevenueHistory[i];
                          final String source = (item['source'] ?? 'غير محدد')
                              .toString();
                          final String notes = (item['notes'] ?? '').toString();
                          final num revenueNum = (item['revenue'] ?? 0) as num;
                          final double revenue = revenueNum.toDouble();
                          final String dateStr = (item['date'] ?? '')
                              .toString();
                          DateTime? dt;
                          try {
                            dt = DateTime.tryParse(dateStr);
                          } catch (_) {}
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.attach_money,
                                      color: Colors.purple,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'EGP ${revenue.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'المصدر: $source',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        if (notes.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'ملاحظات: $notes',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                        if (dt != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

              // Withdrawals History Section
              if (_withdrawalsHistory.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.history_toggle_off,
                            color: Colors.redAccent,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'سجل السحوبات',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _withdrawalsHistory.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final item = _withdrawalsHistory[i];
                          final String toWhom = (item['source'] ?? 'غير محدد')
                              .toString();
                          final String notes = (item['notes'] ?? '').toString();
                          final num expensesNum =
                              (item['expenses'] ?? 0) as num;
                          final double expenses = expensesNum.toDouble();
                          final String dateStr = (item['date'] ?? '')
                              .toString();
                          DateTime? dt;
                          try {
                            dt = DateTime.tryParse(dateStr);
                          } catch (_) {}
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.outbox,
                                      color: Colors.redAccent,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'EGP ${expenses.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'إلى: $toWhom',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        if (notes.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'ملاحظات: $notes',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                        if (dt != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

              // Employee Collections Section
              Container(
                margin: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'تحصيلات الموظفين',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _employeeCollections.isEmpty
                        ? _buildEmptyState(
                            Icons.people_outline,
                            'لا يوجد تحصيلات',
                            'لم يتم العثور على أي مبالغ محصلة للموظفين',
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _employeeCollections.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _employeeCollections[index];
                              final String employeeId = (item['userId'] ?? '')
                                  .toString();
                              // Use netAvailable which includes transfersIn and transfersOut
                              final double collected =
                                  ((item['totalCollected'] ?? 0) as num)
                                      .toDouble();
                              final double transfersIn =
                                  ((item['transfersIn'] ?? 0) as num)
                                      .toDouble();
                              final double transfersOut =
                                  ((item['transfersOut'] ?? 0) as num)
                                      .toDouble();
                              final double amount =
                                  (item['netAvailable'] != null
                                  ? ((item['netAvailable'] ?? 0) as num)
                                        .toDouble()
                                  : collected + transfersIn - transfersOut);
                              final int count = ((item['count'] ?? 0) as num)
                                  .toInt();
                              final displayName =
                                  _employeeIdToName[employeeId] ?? employeeId;
                              return _employeeCollectionTile(
                                employeeId,
                                displayName,
                                amount,
                                count,
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            'EGP ${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String title,
    double value,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        Text(
          'EGP ${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: bold ? 18 : 16,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(icon, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _employeeCollectionTile(
    String employeeId,
    String name,
    double amount,
    int count,
  ) {
    final double expenses = _sumEmployeeExpenses(employeeId);
    final double net = amount - expenses;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'عدد عمليات التحصيل: $count',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _amountPill('تحصيل', amount, Colors.green)),
                const SizedBox(width: 8),
                Expanded(
                  child: _amountPill('مصروفات', expenses, Colors.orange),
                ),
                const SizedBox(width: 8),
                Expanded(child: _amountPill('صافي', net, Colors.blue)),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة مصروف'),
                onPressed: () => _showAddExpenseDialog(employeeId),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if ((_otherExpensesByEmployee[employeeId] ?? []).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'المصاريف المضافة:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _otherExpensesByEmployee[employeeId]!
                    .asMap()
                    .entries
                    .map((entry) {
                      final num v = (entry.value['value'] ?? 0) as num;
                      return Chip(
                        label: Text(
                          '${entry.value['name'] ?? 'مصروف'}: ${v.toDouble().toStringAsFixed(2)}',
                        ),
                        backgroundColor: Colors.red.withOpacity(0.08),
                        side: BorderSide(color: Colors.red.withOpacity(0.2)),
                        labelStyle: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      );
                    })
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _amountPill(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'EGP ${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _OtherExpenseDialog extends StatefulWidget {
  const _OtherExpenseDialog();

  @override
  State<_OtherExpenseDialog> createState() => _OtherExpenseDialogState();
}

class _OtherExpenseDialogState extends State<_OtherExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إضافة مصروف للموظف'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المصروف',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'اسم المصروف مطلوب'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valueController,
                decoration: const InputDecoration(
                  labelText: 'قيمة المصروف (EGP)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'القيمة مطلوبة';
                  final d = double.tryParse(v);
                  if (d == null || d < 0) return 'أدخل قيمة صحيحة';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context, {
                  'name': _nameController.text.trim(),
                  'value': double.parse(_valueController.text),
                });
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

class _ExternalRevenueDialog extends StatefulWidget {
  const _ExternalRevenueDialog();

  @override
  State<_ExternalRevenueDialog> createState() => _ExternalRevenueDialogState();
}

class _ExternalRevenueDialogState extends State<_ExternalRevenueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _sourceController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _valueController.dispose();
    _sourceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إضافة إيراد خارجي للخزنة'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _valueController,
                decoration: const InputDecoration(
                  labelText: 'قيمة الإيراد (EGP)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'القيمة مطلوبة';
                  final d = double.tryParse(v);
                  if (d == null || d <= 0) return 'أدخل قيمة صحيحة (> 0)';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sourceController,
                decoration: const InputDecoration(
                  labelText: 'من طرف (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context, {
                  'value': double.parse(_valueController.text),
                  'source': _sourceController.text,
                  'notes': _notesController.text,
                });
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog();

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _toWhomController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _valueController.dispose();
    _toWhomController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('سحب من الخزنة'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _valueController,
                decoration: const InputDecoration(
                  labelText: 'قيمة السحب (EGP)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'القيمة مطلوبة';
                  final d = double.tryParse(v);
                  if (d == null || d <= 0) return 'أدخل قيمة صحيحة (> 0)';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _toWhomController,
                decoration: const InputDecoration(
                  labelText: 'إلى من (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context, {
                  'value': double.parse(_valueController.text),
                  'toWhom': _toWhomController.text,
                  'notes': _notesController.text,
                });
              }
            },
            child: const Text('سحب'),
          ),
        ],
      ),
    );
  }
}
