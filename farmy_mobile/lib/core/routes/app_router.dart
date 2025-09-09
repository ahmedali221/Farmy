import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/cubit/auth_cubit.dart';
import '../../features/authentication/cubit/auth_state.dart';
import '../../features/authentication/views/login_view.dart';
import '../../features/dashboard/views/employee/employee_dashboard_view.dart';
import '../../features/dashboard/views/admin/admin_dashboard_view.dart';
import '../../features/dashboard/views/admin/Customers Section/customer_management_view.dart';
import '../../features/dashboard/views/admin/Employees Section/employee_management_view.dart';
import '../../features/dashboard/views/admin/Financial Dashboard/financial_dashboard_view.dart';
import '../../features/dashboard/views/admin/Inventory/inventory_management_view.dart';
import '../../features/dashboard/views/admin/order_detail_view.dart';
import '../../features/dashboard/views/admin/Employees Section/employee_orders_view.dart';
import '../../features/dashboard/views/admin/Customers Section/customer_orders_view.dart';
import '../../features/dashboard/views/employee/daily_report_screen.dart';
import '../../features/dashboard/views/employee/order_placement_view.dart';
import '../../features/dashboard/views/employee/payment_collection_view.dart';
import '../../features/dashboard/views/employee/expense_management_view.dart';
import '../../features/dashboard/views/employee/distribution_view.dart';

class AppRouter {
  static GoRouter createRouter(AuthCubit authCubit) {
    return GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final authState = authCubit.state;
        final isLoginRoute = state.matchedLocation == '/login';

        // If user is not authenticated and not on login page, redirect to login
        if (authState is! AuthAuthenticated && !isLoginRoute) {
          return '/login';
        }

        // If user is authenticated and on login page, redirect to appropriate dashboard
        if (authState is AuthAuthenticated && isLoginRoute) {
          if (authState.user.isAdmin) {
            return '/admin-dashboard';
          } else {
            return '/employee-dashboard';
          }
        }

        // If user is authenticated but trying to access wrong dashboard
        if (authState is AuthAuthenticated) {
          final currentLocation = state.matchedLocation;
          if (authState.user.isAdmin &&
              currentLocation == '/employee-dashboard') {
            return '/admin-dashboard';
          } else if (!authState.user.isAdmin &&
              currentLocation == '/admin-dashboard') {
            return '/employee-dashboard';
          }
        }

        return null; // No redirect needed
      },
      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginView(),
        ),
        GoRoute(
          path: '/employee-dashboard',
          name: 'employee-dashboard',
          builder: (context, state) => const EmployeeDashboardView(),
        ),
        GoRoute(
          path: '/admin-dashboard',
          name: 'admin-dashboard',
          builder: (context, state) => const AdminDashboardView(),
        ),
        // Admin Management Routes
        GoRoute(
          path: '/customer-management',
          name: 'customer-management',
          builder: (context, state) => const CustomerManagementView(),
        ),
        GoRoute(
          path: '/employee-management',
          name: 'employee-management',
          builder: (context, state) => const EmployeeManagementView(),
        ),
        GoRoute(
          path: '/financial-dashboard',
          name: 'financial-dashboard',
          builder: (context, state) => const FinancialDashboardView(),
        ),
        GoRoute(
          path: '/inventory-management',
          name: 'inventory-management',
          builder: (context, state) => const InventoryManagementView(),
        ),
        GoRoute(
          path: '/order-detail',
          name: 'order-detail',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            if (extra == null) {
              return const Scaffold(
                body: Center(child: Text('Order data not found')),
              );
            }
            return OrderDetailView(
              order: extra['order'],
              expenses: extra['expenses'],
              paymentSummary: extra['paymentSummary'],
            );
          },
        ),
        GoRoute(
          path: '/employee-orders',
          name: 'employee-orders',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            if (extra == null) {
              return const Scaffold(
                body: Center(child: Text('Employee data not found')),
              );
            }
            return EmployeeOrdersView(
              employee: extra['employee'],
              orders: extra['orders'],
              expensesByOrder: extra['expensesByOrder'],
            );
          },
        ),
        GoRoute(
          path: '/customer-orders',
          name: 'customer-orders',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            if (extra == null) {
              return const Scaffold(
                body: Center(child: Text('Customer data not found')),
              );
            }
            return CustomerOrdersView(
              customer: extra['customer'],
              orders: extra['orders'],
              expensesByOrder: extra['expensesByOrder'],
            );
          },
        ),
        // Employee Routes
        GoRoute(
          path: '/daily-report',
          name: 'daily-report',
          builder: (context, state) => const DailyReportScreen(),
        ),
        GoRoute(
          path: '/order-placement',
          name: 'order-placement',
          builder: (context, state) => const OrderPlacementView(),
        ),
        GoRoute(
          path: '/payment-collection',
          name: 'payment-collection',
          builder: (context, state) => const PaymentCollectionView(),
        ),
        GoRoute(
          path: '/distribution',
          name: 'distribution',
          builder: (context, state) => const DistributionView(),
        ),
        GoRoute(
          path: '/expenses',
          name: 'expenses',
          builder: (context, state) => const ExpenseManagementView(),
        ),
      ],
      errorPageBuilder: (context, state) => MaterialPage(
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Page Not Found',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'The page you are looking for does not exist.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
