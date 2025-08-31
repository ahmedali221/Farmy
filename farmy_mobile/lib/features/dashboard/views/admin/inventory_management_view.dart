import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InventoryManagementView extends StatefulWidget {
  const InventoryManagementView({super.key});

  @override
  State<InventoryManagementView> createState() => _InventoryManagementViewState();
}

class _InventoryManagementViewState extends State<InventoryManagementView> {
  List<dynamic> chickenTypes = [];
  bool isLoading = true;
  final String baseUrl = 'http://localhost:3000/api';

  @override
  void initState() {
    super.initState();
    _loadChickenTypes();
  }

  Future<void> _loadChickenTypes() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/managers/chicken-types'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        setState(() {
          chickenTypes = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Failed to load inventory: $e');
    }
  }

  void _showAddChickenTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => _ChickenTypeFormDialog(
        onSave: _addChickenType,
      ),
    );
  }

  void _showEditChickenTypeDialog(Map<String, dynamic> chickenType) {
    showDialog(
      context: context,
      builder: (context) => _ChickenTypeFormDialog(
        chickenType: chickenType,
        onSave: (data) => _updateChickenType(chickenType['_id'], data),
      ),
    );
  }

  Future<void> _addChickenType(Map<String, dynamic> chickenTypeData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/managers/chicken-types'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(chickenTypeData),
      );
      if (response.statusCode == 201) {
        _showSuccessDialog('Chicken type added successfully');
        _loadChickenTypes();
      }
    } catch (e) {
      _showErrorDialog('Failed to add chicken type: $e');
    }
  }

  Future<void> _updateChickenType(String id, Map<String, dynamic> chickenTypeData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/managers/chicken-types/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(chickenTypeData),
      );
      if (response.statusCode == 200) {
        _showSuccessDialog('Inventory updated successfully');
        _loadChickenTypes();
      }
    } catch (e) {
      _showErrorDialog('Failed to update inventory: $e');
    }
  }

  void _showStockUpdateDialog(Map<String, dynamic> chickenType) {
    final stockController = TextEditingController(
      text: chickenType['stock'].toString(),
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Stock - ${chickenType['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: ${chickenType['stock']}'),
            const SizedBox(height: 16),
            TextField(
              controller: stockController,
              decoration: const InputDecoration(
                labelText: 'New Stock Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newStock = int.tryParse(stockController.text);
              if (newStock != null && newStock >= 0) {
                final updatedData = {
                  'name': chickenType['name'],
                  'price': chickenType['price'],
                  'stock': newStock,
                };
                _updateChickenType(chickenType['_id'], updatedData);
                Navigator.of(context).pop();
              } else {
                _showErrorDialog('Please enter a valid stock quantity');
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Color _getStockStatusColor(int stock) {
    if (stock == 0) return Colors.red;
    if (stock < 10) return Colors.orange;
    return Colors.green;
  }

  String _getStockStatusText(int stock) {
    if (stock == 0) return 'Out of Stock';
    if (stock < 10) return 'Low Stock';
    return 'In Stock';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddChickenTypeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChickenTypes,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : chickenTypes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No inventory items found', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary Cards
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Total Items',
                              chickenTypes.length.toString(),
                              Icons.inventory,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Total Stock',
                              chickenTypes.fold<int>(0, (sum, item) => sum + (item['stock'] as int)).toString(),
                              Icons.storage,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Low Stock',
                              chickenTypes.where((item) => item['stock'] < 10).length.toString(),
                              Icons.warning,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Inventory List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: chickenTypes.length,
                        itemBuilder: (context, index) {
                          final chickenType = chickenTypes[index];
                          final stock = chickenType['stock'] as int;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _getStockStatusColor(stock).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.egg_outlined,
                                  color: _getStockStatusColor(stock),
                                  size: 30,
                                ),
                              ),
                              title: Text(
                                chickenType['name'] ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Price: ₹${chickenType['price']}'),
                                  Text(
                                    'Stock: $stock - ${_getStockStatusText(stock)}',
                                    style: TextStyle(
                                      color: _getStockStatusColor(stock),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'update_stock',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('Update Stock'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.settings, size: 20),
                                        SizedBox(width: 8),
                                        Text('Edit Details'),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'update_stock') {
                                    _showStockUpdateDialog(chickenType);
                                  } else if (value == 'edit') {
                                    _showEditChickenTypeDialog(chickenType);
                                  }
                                },
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddChickenTypeDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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

class _ChickenTypeFormDialog extends StatefulWidget {
  final Map<String, dynamic>? chickenType;
  final Function(Map<String, dynamic>) onSave;

  const _ChickenTypeFormDialog({
    this.chickenType,
    required this.onSave,
  });

  @override
  State<_ChickenTypeFormDialog> createState() => _ChickenTypeFormDialogState();
}

class _ChickenTypeFormDialogState extends State<_ChickenTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  String? selectedChickenType;
  bool isEditing = false;

  final List<String> chickenTypeOptions = [
    'تسمين',
    'بلدي',
    'احمر',
    'ساسو',
    'بط'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.chickenType != null) {
      isEditing = true;
      selectedChickenType = widget.chickenType!['name'];
      _priceController.text = widget.chickenType!['price'].toString();
      _stockController.text = widget.chickenType!['stock'].toString();
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate() && selectedChickenType != null) {
      final chickenTypeData = {
        'name': selectedChickenType!,
        'price': double.parse(_priceController.text),
        'stock': int.parse(_stockController.text),
      };
      widget.onSave(chickenTypeData);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit Chicken Type' : 'Add Chicken Type'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedChickenType,
                decoration: const InputDecoration(
                  labelText: 'Chicken Type',
                  border: OutlineInputBorder(),
                ),
                items: chickenTypeOptions.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: isEditing ? null : (String? newValue) {
                  setState(() {
                    selectedChickenType = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a chicken type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (₹)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Price is required';
                  }
                  if (double.tryParse(value) == null || double.parse(value) < 0) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(
                  labelText: 'Stock Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Stock quantity is required';
                  }
                  if (int.tryParse(value) == null || int.parse(value) < 0) {
                    return 'Please enter a valid stock quantity';
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