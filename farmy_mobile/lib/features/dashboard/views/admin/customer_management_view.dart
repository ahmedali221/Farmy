import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CustomerManagementView extends StatefulWidget {
  const CustomerManagementView({super.key});

  @override
  State<CustomerManagementView> createState() => _CustomerManagementViewState();
}

class _CustomerManagementViewState extends State<CustomerManagementView> {
  List<dynamic> customers = [];
  bool isLoading = true;
  final String baseUrl = 'http://localhost:3000/api';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/customers'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        setState(() {
          customers = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Failed to load customers: $e');
    }
  }

  Future<void> _deleteCustomer(String id, String name) async {
    final confirmed = await _showConfirmDialog(
      'Delete Customer',
      'Are you sure you want to delete $name?',
    );
    if (!confirmed) return;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/customers/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        _showSuccessDialog('Customer deleted successfully');
        _loadCustomers();
      }
    } catch (e) {
      _showErrorDialog('Failed to delete customer: $e');
    }
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => _CustomerFormDialog(
        onSave: _addCustomer,
      ),
    );
  }

  void _showEditCustomerDialog(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (context) => _CustomerFormDialog(
        customer: customer,
        onSave: (data) => _updateCustomer(customer['_id'], data),
      ),
    );
  }

  Future<void> _addCustomer(Map<String, dynamic> customerData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/customers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(customerData),
      );
      if (response.statusCode == 201) {
        _showSuccessDialog('Customer created successfully');
        _loadCustomers();
      }
    } catch (e) {
      _showErrorDialog('Failed to create customer: $e');
    }
  }

  Future<void> _updateCustomer(String id, Map<String, dynamic> customerData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/customers/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(customerData),
      );
      if (response.statusCode == 200) {
        _showSuccessDialog('Customer updated successfully');
        _loadCustomers();
      }
    } catch (e) {
      _showErrorDialog('Failed to update customer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Management'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddCustomerDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomers,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : customers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No customers found', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(
                            customer['name']?.substring(0, 1).toUpperCase() ?? 'C',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          customer['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Phone: ${customer['contactInfo']?['phone'] ?? 'Not provided'}'),
                            Text('Address: ${customer['contactInfo']?['address'] ?? 'Not provided'}'),
                            Text('Orders: ${customer['orders']?.length ?? 0}'),
                            Text('Outstanding Debt: ₹${customer['outstandingDebt'] ?? 0}'),
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
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditCustomerDialog(customer);
                            } else if (value == 'delete') {
                              _deleteCustomer(customer['_id'], customer['name']);
                            }
                          },
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _CustomerFormDialog extends StatefulWidget {
  final Map<String, dynamic>? customer;
  final Function(Map<String, dynamic>) onSave;

  const _CustomerFormDialog({
    this.customer,
    required this.onSave,
  });

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      isEditing = true;
      _nameController.text = widget.customer!['name'] ?? '';
      _phoneController.text = widget.customer!['contactInfo']?['phone'] ?? '';
      _addressController.text = widget.customer!['contactInfo']?['address'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final customerData = {
        'name': _nameController.text.trim(),
        'contactInfo': {
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
        },
        'outstandingDebt': 0, // Default value
        'orders': [], // Default empty array
        'payments': [], // Default empty array
        'receipts': [], // Default empty array
      };
      widget.onSave(customerData);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit Customer' : 'Add Customer'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Address is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}