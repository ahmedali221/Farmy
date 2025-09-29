import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/employee_expense_api_service.dart';
import '../../../authentication/cubit/auth_cubit.dart';

class EmployeeExpenseHistoryView extends StatefulWidget {
  const EmployeeExpenseHistoryView({super.key});

  @override
  State<EmployeeExpenseHistoryView> createState() =>
      _EmployeeExpenseHistoryViewState();
}

class _EmployeeExpenseHistoryViewState
    extends State<EmployeeExpenseHistoryView> {
  late final EmployeeExpenseApiService _expenseService;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _grouped = [];

  @override
  void initState() {
    super.initState();
    _expenseService = serviceLocator<EmployeeExpenseApiService>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authCubit = context.read<AuthCubit>();
      final currentUser = authCubit.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      final expenses = await _expenseService.listByEmployee(currentUser.id);
      final grouped = <String, Map<String, dynamic>>{};
      for (final e in expenses) {
        final createdAt = (e['createdAt'] ?? '').toString();
        final dateKey = _yyyyMmDd(createdAt);
        if (dateKey.isEmpty) continue;
        final bucket =
            grouped[dateKey] ??
            {
              'date': dateKey,
              'total': 0.0,
              'count': 0,
              'expenses': <Map<String, dynamic>>[],
            };
        final val = ((e['value'] ?? 0) as num).toDouble();
        (bucket['expenses'] as List).add(e);
        bucket['total'] = ((bucket['total'] ?? 0) as num).toDouble() + val;
        bucket['count'] = ((bucket['count'] ?? 0) as int) + 1;
        grouped[dateKey] = bucket;
      }
      final list = grouped.values.toList()
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      setState(() {
        _grouped = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل المصروفات'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: _grouped.length,
                  itemBuilder: (context, index) {
                    final day = _grouped[index];
                    return InkWell(
                      onTap: () => context.pushNamed(
                        'employee-daily-detail',
                        extra: {'date': day['date']},
                      ),
                      child: _buildDayCard(day),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    final String date = (day['date'] ?? '').toString();
    final double total = ((day['total'] ?? 0) as num).toDouble();
    final int count = (day['count'] ?? 0) as int;
    final List<dynamic> expenses = (day['expenses'] as List<dynamic>? ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ج.م ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'عدد السجلات: $count',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const Divider(height: 16),
            ...expenses.map((e) {
              final double value = ((e['value'] ?? 0) as num).toDouble();
              final String name = (e['name'] ?? '').toString();
              final String note = (e['note'] ?? '').toString();
              final String createdAt = (e['createdAt'] ?? '').toString();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  child: const Icon(Icons.money_off, color: Colors.orange),
                ),
                title: Text(
                  '$name - ج.م ${value.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.isNotEmpty)
                      Text(
                        note,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
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

  String _yyyyMmDd(String dateString) {
    try {
      final d = DateTime.parse(dateString);
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
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
















