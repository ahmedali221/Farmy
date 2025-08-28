import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/authentication/cubit/auth_cubit.dart';
import '../../features/authentication/cubit/auth_state.dart';
import '../../features/authentication/views/login_view.dart';
import '../../features/dashboard/views/employee_dashboard_view.dart';
import '../../features/dashboard/views/admin_dashboard_view.dart';

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
          if (authState.user.isAdmin && currentLocation == '/employee-dashboard') {
            return '/admin-dashboard';
          } else if (!authState.user.isAdmin && currentLocation == '/admin-dashboard') {
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
      ],
      errorPageBuilder: (context, state) => MaterialPage(
        child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
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