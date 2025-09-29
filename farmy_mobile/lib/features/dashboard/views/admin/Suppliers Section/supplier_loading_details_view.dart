import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/services/loading_api_service.dart';

class SupplierLoadingDetailsView extends StatefulWidget {
  final String loadingId;

  const SupplierLoadingDetailsView({super.key, required this.loadingId});

  @override
  State<SupplierLoadingDetailsView> createState() =>
      _SupplierLoadingDetailsViewState();
}

class _SupplierLoadingDetailsViewState
    extends State<SupplierLoadingDetailsView> {
  late final LoadingApiService _loadingService;
  Map<String, dynamic>? loading;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadingService = serviceLocator<LoadingApiService>();
    _loadLoadingDetails();
  }

  Future<void> _loadLoadingDetails() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final loadingDetails = await _loadingService.getLoadingById(
        widget.loadingId,
      );

      if (loadingDetails == null) {
        setState(() {
          error = 'طلب التحميل غير موجود';
          isLoading = false;
        });
        return;
      }

      setState(() {
        loading = loadingDetails;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'فشل في تحميل تفاصيل الطلب: $e';
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
            title: const Text('تفاصيل طلب التحميل'),
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
                onPressed: _loadLoadingDetails,
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? _buildErrorWidget()
              : loading == null
              ? _buildNotFoundWidget()
              : _buildContent(),
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
          Text('خطأ: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadLoadingDetails,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('طلب التحميل غير موجود'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildDetailsCard(),
          const SizedBox(height: 16),
          _buildSupplierCard(),
          const SizedBox(height: 16),
          _buildChickenTypeCard(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.local_shipping, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب تحميل #${loading?['_id']?.toString().substring(0, 8) ?? 'غير معروف'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'بواسطة: ${(((loading?['user'] ?? const {})['username']) ?? ((loading?['user'] ?? const {})['name']) ?? 'غير معروف')}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                      Text(
                        _formatDateTime(loading?['createdAt']),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تفاصيل الطلب',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'الكمية',
              '${loading?['quantity'] ?? 0} وحدة',
              Icons.inventory,
              Colors.purple,
            ),
            _buildDetailRow(
              'الوزن الإجمالي',
              '${(loading?['grossWeight'] ?? 0).toStringAsFixed(1)} كجم',
              Icons.scale,
              Colors.blue,
            ),
            _buildDetailRow(
              'الوزن الفارغ',
              '${(loading?['emptyWeight'] ?? 0).toStringAsFixed(1)} كجم',
              Icons.remove_circle_outline,
              Colors.orange,
            ),
            _buildDetailRow(
              'الوزن الصافي',
              '${(loading?['netWeight'] ?? 0).toStringAsFixed(1)} كجم',
              Icons.scale_outlined,
              Colors.green,
            ),
            _buildDetailRow(
              'إجمالي التحميل',
              '${(loading?['totalLoading'] ?? 0).toStringAsFixed(2)} ج.م',
              Icons.attach_money,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierCard() {
    final supplier = loading?['supplier'];
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات المورد',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (supplier != null) ...[
              _buildDetailRow(
                'اسم المورد',
                supplier['name'] ?? 'غير معروف',
                Icons.business,
                Colors.blue,
              ),
              if (supplier['phone'] != null)
                _buildDetailRow(
                  'الهاتف',
                  supplier['phone'],
                  Icons.phone,
                  Colors.green,
                ),
              if (supplier['address'] != null)
                _buildDetailRow(
                  'العنوان',
                  supplier['address'],
                  Icons.location_on,
                  Colors.orange,
                ),
            ] else
              const Text('معلومات المورد غير متوفرة'),
          ],
        ),
      ),
    );
  }

  Widget _buildChickenTypeCard() {
    final chickenType = loading?['chickenType'];
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نوع الدجاج',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (chickenType != null) ...[
              _buildDetailRow(
                'النوع',
                chickenType['name'] ?? 'غير معروف',
                Icons.pets,
                Colors.brown,
              ),
              if (chickenType['description'] != null)
                _buildDetailRow(
                  'الوصف',
                  chickenType['description'],
                  Icons.description,
                  Colors.grey,
                ),
            ] else
              const Text('نوع الدجاج غير محدد'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'غير معروف';
    try {
      final dt = DateTime.parse(dateTime).toLocal();
      final two = (int v) => v.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return 'تاريخ غير صحيح';
    }
  }
}
