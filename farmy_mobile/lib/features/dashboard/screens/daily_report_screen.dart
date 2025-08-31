import 'package:flutter/material.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  // الشرائح: 0 التحصيل - 1 التوزيع
  int selectedTab = 0;

  // التحصيل (يدخلها الموظف)
  final totalCtrl = TextEditingController();
  final discountCtrl = TextEditingController();
  final paidCtrl = TextEditingController();
  final remainingCtrl = TextEditingController();

  // التوزيع (يدخلها الموظف)
  final oldCtrl = TextEditingController();
  final countCtrl = TextEditingController();
  final grossWeightCtrl = TextEditingController();
  final netWeightCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final dailyAccountCtrl = TextEditingController();
  final totalDistCtrl = TextEditingController();

  String distType = 'تسمين';
  final List<String> distTypes = const ['تسمين', 'بلدي', 'احمر', 'ساسو', 'بط'];

  @override
  void dispose() {
    totalCtrl.dispose();
    discountCtrl.dispose();
    paidCtrl.dispose();
    remainingCtrl.dispose();
    oldCtrl.dispose();
    countCtrl.dispose();
    grossWeightCtrl.dispose();
    netWeightCtrl.dispose();
    priceCtrl.dispose();
    dailyAccountCtrl.dispose();
    totalDistCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            // خلفية متدرّجة مع حافة سفلية دائرية
            Container(
              height: size.height * 0.34,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF6ECD8), // cream
                    Color(0xFFFFFFFF),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
            ),

            // المحتوى
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const _HeaderBar(),
                    const SizedBox(height: 18),

                    

                    // الشرائح (التحصيل - التوزيع)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _SegmentChip(
                            label: 'التحصيل',
                            selected: selectedTab == 0,
                            onTap: () => setState(() => selectedTab = 0),
                          ),
                          const SizedBox(width: 10),
                          _SegmentChip(
                            label: 'التوزيع',
                            selected: selectedTab == 1,
                            onTap: () => setState(() => selectedTab = 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // الكروت الملوّنة
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: const [
                          Expanded(
                            child: _StatCard(
                              titleTop: 'الطلبات',
                              value: '0',
                              color: Color(0xFFF37B2A), // برتقالي
                              icon: Icons.shopping_bag_rounded,
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: _StatCard(
                              titleTop: 'قيد التنفيذ',
                              value: '0',
                              color: Color(0xFF0EA57A), // أخضر
                              icon: Icons.timelapse_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // نموذج ديناميكي حسب الشريحة
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SectionCard(
                        title: selectedTab == 0 ? 'بيانات التحصيل' : 'بيانات التوزيع',
                        child: selectedTab == 0
                            ? _CollectionForm(
                                totalCtrl: totalCtrl,
                                discountCtrl: discountCtrl,
                                paidCtrl: paidCtrl,
                                remainingCtrl: remainingCtrl,
                              )
                            : _DistributionForm(
                                oldCtrl: oldCtrl,
                                distType: distType,
                                onTypeChanged: (v) => setState(() => distType = v),
                                types: distTypes,
                                countCtrl: countCtrl,
                                grossWeightCtrl: grossWeightCtrl,
                                netWeightCtrl: netWeightCtrl,
                                priceCtrl: priceCtrl,
                                dailyAccountCtrl: dailyAccountCtrl,
                                totalDistCtrl: totalDistCtrl,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // نظرة عامة (ثابتة تُحدّث من الباك)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _SectionCard(
                        title: 'نظرة عامة',
                        child: _OverviewGrid(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // زر حفظ
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حفظ التقرير بنجاح ✅')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA57A),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'حفظ التقرير',
                            style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===================== Header =====================
class _HeaderBar extends StatelessWidget {
  const _HeaderBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          // صورة/أفاتار
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFEFEFEF),
            child: Icon(Icons.person, color: Colors.grey.shade700, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'مرحباً، موظف',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              Text(
                _formatToday(),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.1),
              ),
            ],
          ),
          const Spacer(),
          _RoundIconButton(icon: Icons.notifications_none_rounded, onTap: () {}),
          const SizedBox(width: 8),
          const _RoundIconButton(icon: Icons.star_rounded, onTap: null, filled: true),
        ],
      ),
    );
  }

  static String _formatToday() {
    final now = DateTime.now();
    const months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}';
    // Ex: 28 أغسطس 2025
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? const Color(0xFFF37B2A) : Colors.white;
    final fg = filled ? Colors.white : Colors.black87;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: filled ? 2 : 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}

/// ===================== Chips =====================
class _SegmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// ===================== Stat Cards =====================
class _StatCard extends StatelessWidget {
  final String titleTop;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.titleTop,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -8,
            top: -8,
            child: Icon(icon, size: 80, color: Colors.black.withValues(alpha: 0.06)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SmallBadge(icon: icon),
                const Spacer(),
                Text(
                  titleTop,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final IconData icon;
  const _SmallBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(6),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}

/// ===================== Section Card Wrapper =====================
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// ===================== Forms =====================
/// التحصيل
class _CollectionForm extends StatelessWidget {
  final TextEditingController totalCtrl;
  final TextEditingController discountCtrl;
  final TextEditingController paidCtrl;
  final TextEditingController remainingCtrl;

  const _CollectionForm({
    required this.totalCtrl,
    required this.discountCtrl,
    required this.paidCtrl,
    required this.remainingCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _NumField(label: 'الإجمالي', controller: totalCtrl),
        const SizedBox(height: 10),
        _NumField(label: 'خصم', controller: discountCtrl),
        const SizedBox(height: 10),
        _NumField(label: 'دفع', controller: paidCtrl),
        const SizedBox(height: 10),
        _NumField(label: 'باقي', controller: remainingCtrl),
      ],
    );
  }
}

/// التوزيع
class _DistributionForm extends StatelessWidget {
  final TextEditingController oldCtrl;
  final String distType;
  final List<String> types;
  final ValueChanged<String> onTypeChanged;
  final TextEditingController countCtrl;
  final TextEditingController grossWeightCtrl;
  final TextEditingController netWeightCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController dailyAccountCtrl;
  final TextEditingController totalDistCtrl;

  const _DistributionForm({
    required this.oldCtrl,
    required this.distType,
    required this.types,
    required this.onTypeChanged,
    required this.countCtrl,
    required this.grossWeightCtrl,
    required this.netWeightCtrl,
    required this.priceCtrl,
    required this.dailyAccountCtrl,
    required this.totalDistCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _NumField(label: 'قديم', controller: oldCtrl),
        const SizedBox(height: 10),
        _DropdownField(
          label: 'نوع',
          value: distType,
          items: types,
          onChanged: (v) {
            if (v != null) onTypeChanged(v);
          },
        ),
        const SizedBox(height: 10),
        _NumField(label: 'عدد', controller: countCtrl),
        const SizedBox(height: 10),
        _NumField(label: 'وزن القايم', controller: grossWeightCtrl),
        const SizedBox(height: 10),
        _NumField(label: 'وزن الصافي', controller: netWeightCtrl),
        const SizedBox(height: 10),
        _NumField(label: 'السعر', controller: priceCtrl),
        const SizedBox(height: 10),
        _NumField(label: 'حساب اليوم', controller: dailyAccountCtrl),
        const SizedBox(height: 10),
        _NumField(label: 'الإجمالي', controller: totalDistCtrl),
      ],
    );
  }
}

/// ===================== Overview Grid =====================
class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid();

  @override
  Widget build(BuildContext context) {
    // قيم Placeholder (ثابتة للعرض فقط – تُستبدل من الباك لاحقاً)
    final items = const [
      ['الطلبات المسلَّمة', '0'],
      ['الإيصالات المُعطاة', '0'],
      ['الأموال المحصلة', '0 ج.م'],
      ['الديون القديمة المحصلة', '0 ج.م'],
      ['المصروفات', '0 ج.م'],
      ['الرصيد النهائي', '0 ج.م'],
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // شبكة 2×3
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.9,
      ),
      itemBuilder: (context, i) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(items[i][0], style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                items[i][1],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ===================== Inputs (styled) =====================
class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _NumField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.right,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map((e) => DropdownMenuItem<String>(
                value: e,
                child: Text(e),
              ))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

