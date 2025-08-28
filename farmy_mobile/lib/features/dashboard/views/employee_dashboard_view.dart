import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../authentication/cubit/auth_cubit.dart';

class EmployeeDashboardView extends StatelessWidget {
  const EmployeeDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final user = authCubit.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        user?.username.substring(0, 1).toUpperCase() ?? 'E',
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
                            'Welcome back!',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.username ?? 'Employee',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Employee',
                              style: TextStyle(
                                color: Colors.green[800],
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

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildActionCard(
                  context,
                  'Orders',
                  Icons.shopping_cart,
                  Colors.blue,
                  () => _showFeatureDialog(context, 'Orders'),
                ),
                _buildActionCard(
                  context,
                  'Deliveries',
                  Icons.local_shipping,
                  Colors.orange,
                  () => _showFeatureDialog(context, 'Deliveries'),
                ),
                _buildActionCard(
                  context,
                  'Customers',
                  Icons.people,
                  Colors.green,
                  () => _showFeatureDialog(context, 'Customers'),
                ),
                _buildActionCard(
                  context,
                  'Profile',
                  Icons.person,
                  Colors.purple,
                  () => _showFeatureDialog(context, 'Profile'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Activity
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 5,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: Icon(
                        _getActivityIcon(index),
                        color: Colors.grey[600],
                      ),
                    ),
                    title: Text(_getActivityTitle(index)),
                    subtitle: Text(_getActivitySubtitle(index)),
                    trailing: Text(
                      _getActivityTime(index),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getActivityIcon(int index) {
    switch (index) {
      case 0:
        return Icons.add_shopping_cart;
      case 1:
        return Icons.local_shipping;
      case 2:
        return Icons.person_add;
      case 3:
        return Icons.edit;
      default:
        return Icons.info;
    }
  }

  String _getActivityTitle(int index) {
    switch (index) {
      case 0:
        return 'New order created';
      case 1:
        return 'Delivery completed';
      case 2:
        return 'Customer added';
      case 3:
        return 'Profile updated';
      default:
        return 'System notification';
    }
  }

  String _getActivitySubtitle(int index) {
    switch (index) {
      case 0:
        return 'Order #1234 for John Doe';
      case 1:
        return 'Delivery to Main Street';
      case 2:
        return 'Jane Smith added to system';
      case 3:
        return 'Contact information updated';
      default:
        return 'General system update';
    }
  }

  String _getActivityTime(int index) {
    switch (index) {
      case 0:
        return '2 hours ago';
      case 1:
        return '4 hours ago';
      case 2:
        return '1 day ago';
      case 3:
        return '2 days ago';
      default:
        return '3 days ago';
    }
  }

  void _showFeatureDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text('$feature feature will be implemented in future updates.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthCubit>().logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}