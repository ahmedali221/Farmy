import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/services/loading_api_service.dart';

class SupplierLoadingOrdersView extends StatefulWidget {
  final String supplierId;

  const SupplierLoadingOrdersView({super.key, required this.supplierId});

  @override
  State<SupplierLoadingOrdersView> createState() =>
      _SupplierLoadingOrdersViewState();
}

class _SupplierLoadingOrdersViewState extends State<SupplierLoadingOrdersView> {
  late final LoadingApiService _loadingService;
  List<Map<String, dynamic>> loadingOrders = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadingService = serviceLocator<LoadingApiService>();
    _loadLoadingOrders();
  }

  Future<void> _loadLoadingOrders() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Use the backend API to get loadings for this specific supplier
      final supplierLoadings = await _loadingService.getLoadingsBySupplier(
        widget.supplierId,
      );

      print('Debug - Supplier ID: ${widget.supplierId}');
      print('Debug - Loadings count: ${supplierLoadings.length}');
      if (supplierLoadings.isNotEmpty) {
        print('Debug - First loading: ${supplierLoadings.first}');
      }

      setState(() {
        loadingOrders = supplierLoadings;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!didPop) {
          context.go('/supplier-management');
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('طلبات التحميل'),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/supplier-management');
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadLoadingOrders,
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? _buildErrorWidget()
              : loadingOrders.isEmpty
              ? _buildEmptyWidget()
              : _buildLoadingOrdersList(),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('خطأ في تحميل البيانات: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadLoadingOrders,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'لا توجد طلبات تحميل لهذا المورد',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOrdersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: loadingOrders.length,
      itemBuilder: (context, index) {
        final loading = loadingOrders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: const Icon(Icons.local_shipping, color: Colors.white),
            ),
            title: Text(
              'طلب تحميل #${loading['_id']?.toString().substring(0, 8) ?? 'غير معروف'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الكمية: ${loading['quantity'] ?? 0} وحدة'),
                Text(
                  'الوزن الصافي: ${(loading['netWeight'] ?? 0).toStringAsFixed(1)} كجم',
                ),
                Text(
                  'نوع الدجاج: ${loading['chickenType']?['name'] ?? 'غير معروف'}',
                ),
                Text('التاريخ: ${_formatDate(loading['createdAt'])}'),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _navigateToLoadingDetails(loading),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  void _navigateToLoadingDetails(Map<String, dynamic> loading) {
    context.push(
      '/supplier-loading-details',
      extra: {'loadingId': loading['_id']},
    );
  }

  String _formatDate(String? dateTime) {
    if (dateTime == null) return 'غير معروف';
    try {
      final dt = DateTime.parse(dateTime).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'تاريخ غير صحيح';
    }
  }
}
