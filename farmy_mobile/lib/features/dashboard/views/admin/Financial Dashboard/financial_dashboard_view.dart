import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'tabs/treasury_tab.dart';
import 'tabs/employee_safe_tab.dart';
import 'tabs/inventory_tab.dart';

class FinancialDashboardView extends StatefulWidget {
  const FinancialDashboardView({super.key});

  @override
  State<FinancialDashboardView> createState() => _FinancialDashboardViewState();
}

class _FinancialDashboardViewState extends State<FinancialDashboardView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الخزنة'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin-dashboard'),
          ),
          actions: const [],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'الخزنة'),
              Tab(text: 'خزنة الموظفين'),
              Tab(text: 'المخزون'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [TreasuryTab(), EmployeeSafeTab(), InventoryTab()],
        ),
      ),
    );
  }
}
