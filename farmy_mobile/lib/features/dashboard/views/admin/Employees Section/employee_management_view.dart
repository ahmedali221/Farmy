import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/services/employee_api_service.dart';

class EmployeeManagementView extends StatefulWidget {
  const EmployeeManagementView({super.key});

  @override
  State<EmployeeManagementView> createState() => _EmployeeManagementViewState();
}

class _EmployeeManagementViewState extends State<EmployeeManagementView> {
  List<Map<String, dynamic>> employeeUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployeeUsers();
  }

  Future<void> _loadEmployeeUsers() async {
    setState(() => isLoading = true);
    try {
      final employeeService = serviceLocator<EmployeeApiService>();
      final employeeUsersList = await employeeService.getAllEmployeeUsers();
      setState(() {
        employeeUsers = employeeUsersList;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('فشل في تحميل بيانات الموظفين: $e');
    }
  }

  Future<void> _deleteEmployeeUser(String id, String username) async {
    final confirmed = await _showConfirmDialog(
      'حذف موظف',
      'هل أنت متأكد من حذف $username؟',
    );
    if (!confirmed) return;

    try {
      final employeeService = serviceLocator<EmployeeApiService>();
      await employeeService.deleteEmployeeUser(id);
      _showSuccessDialog('تم حذف الموظف بنجاح');
      _loadEmployeeUsers();
    } catch (e) {
      _showErrorDialog('فشل في حذف الموظف: $e');
    }
  }

  void _showAddEmployeeUserDialog() {
    showDialog(
      context: context,
      builder: (context) => _EmployeeUserFormDialog(onSave: _addEmployeeUser),
    );
  }

  void _showEditEmployeeUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _EmployeeUserFormDialog(
        user: user,
        onSave: (data) => _updateEmployeeUser(user['_id'], data),
      ),
    );
  }

  Future<void> _addEmployeeUser(Map<String, dynamic> userData) async {
    try {
      final employeeService = serviceLocator<EmployeeApiService>();
      await employeeService.createEmployeeUser(userData);
      _showSuccessDialog('تم إنشاء الموظف بنجاح');
      _loadEmployeeUsers();
    } catch (e) {
      _showErrorDialog('فشل في إنشاء الموظف: $e');
    }
  }

  Future<void> _updateEmployeeUser(
    String id,
    Map<String, dynamic> userData,
  ) async {
    try {
      final employeeService = serviceLocator<EmployeeApiService>();
      await employeeService.updateEmployeeUser(id, userData);
      _showSuccessDialog('تم تحديث الموظف بنجاح');
      _loadEmployeeUsers();
    } catch (e) {
      _showErrorDialog('فشل في تحديث الموظف: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          context.go('/admin-dashboard');
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('إدارة الموظفين'),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/admin-dashboard');
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.account_balance_wallet),
                onPressed: () => context.push('/admin-transfer-money'),
                tooltip: 'تحويل أموال',
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showAddEmployeeUserDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadEmployeeUsers,
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildEmployeeUsersList(),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddEmployeeUserDialog,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('تأكيد'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Widget _buildEmployeeUsersList() {
    if (employeeUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد موظفين', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: employeeUsers.length,
      itemBuilder: (context, index) {
        final user = employeeUsers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                user['username']?.substring(0, 1).toUpperCase() ?? 'م',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              user['username'] ?? 'غير معروف',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الدور: ${user['role'] ?? 'موظف'}'),
                Text('الرقم: ${user['_id'] ?? 'غير متوفر'}'),
                Text(
                  'تاريخ الإنشاء: ${user['createdAt'] != null ? DateTime.parse(user['createdAt']).toString().split(' ')[0] : 'غير متوفر'}',
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('تعديل'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditEmployeeUserDialog(user);
                } else if (value == 'delete') {
                  _deleteEmployeeUser(user['_id'], user['username']);
                }
              },
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('نجح'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('خطأ'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeUserFormDialog extends StatefulWidget {
  final Map<String, dynamic>? user;
  final Function(Map<String, dynamic>) onSave;

  const _EmployeeUserFormDialog({this.user, required this.onSave});

  @override
  State<_EmployeeUserFormDialog> createState() =>
      _EmployeeUserFormDialogState();
}

class _EmployeeUserFormDialogState extends State<_EmployeeUserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isEditing = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      isEditing = true;
      _usernameController.text = widget.user!['username'] ?? '';
      // Don't populate password field for security
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final userData = {
        'username': _usernameController.text.trim(),
        if (!isEditing || _passwordController.text.isNotEmpty)
          'password': _passwordController.text,
      };
      widget.onSave(userData);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(isEditing ? 'تعديل الموظف' : 'إضافة موظف'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'اسم المستخدم مطلوب';
                  }
                  if (value.trim().length < 3) {
                    return 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: isEditing
                      ? 'كلمة المرور الجديدة (اتركها فارغة للاحتفاظ بالحالية)'
                      : 'كلمة المرور',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (!isEditing && (value == null || value.trim().isEmpty)) {
                    return 'كلمة المرور مطلوبة';
                  }
                  if (value != null &&
                      value.isNotEmpty &&
                      value.trim().length < 6) {
                    return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                  }
                  return null;
                },
              ),
              if (isEditing)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'ملاحظة: اترك كلمة المرور فارغة للاحتفاظ بكلمة المرور الحالية',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _save,
            child: Text(isEditing ? 'تحديث' : 'إنشاء'),
          ),
        ],
      ),
    );
  }
}
