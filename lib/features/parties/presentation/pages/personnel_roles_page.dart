import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';

class PersonnelRolesPage extends StatefulWidget {
  const PersonnelRolesPage({this.initialValue = const {}, super.key});
  final Set<String> initialValue;

  @override
  State<PersonnelRolesPage> createState() => _PersonnelRolesPageState();
}

class _PersonnelRolesPageState extends State<PersonnelRolesPage> {
  late Set<String> selected;

  static const sections = [
    (
      'حالت پایه',
      'نقش اصلی پرسنل در عملیات روزمره',
      [
        (
          'تنخواه‌گردان',
          Icons.account_balance_wallet_outlined,
          AsoudColors.success
        ),
        ('صندوق', Icons.point_of_sale_outlined, AsoudColors.cyan),
        ('فروشنده', Icons.storefront_outlined, AsoudColors.purple),
        ('بازاریاب', Icons.campaign_outlined, AsoudColors.warning),
      ]
    ),
    (
      'حالت انتخاب دریافت‌کننده',
      'برای دریافت، پرداخت و تسویه اسناد',
      [
        ('دریافت‌کننده', Icons.payments_outlined, AsoudColors.success),
        ('تحویل‌گیرنده', Icons.inventory_2_outlined, AsoudColors.primary),
        ('مسئول وصول', Icons.receipt_long_outlined, AsoudColors.cyan),
        ('نماینده', Icons.badge_outlined, AsoudColors.warning),
      ]
    ),
    (
      'حالت انتخاب تأمین',
      'برای خرید و تأمین کالا یا خدمات',
      [
        ('خریدار', Icons.shopping_cart_outlined, AsoudColors.primary),
        ('تأمین‌کننده داخلی', Icons.factory_outlined, AsoudColors.success),
        ('مأمور خرید', Icons.assignment_ind_outlined, AsoudColors.cyan),
        ('واسطه خرید', Icons.handshake_outlined, AsoudColors.warning),
      ]
    ),
  ];

  @override
  void initState() {
    super.initState();
    selected = {...widget.initialValue};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
          title: 'تنظیمات نقش‌های پرسنلی',
          subtitle: 'ترکیب نقش‌ها و دسترسی‌های عملیاتی',
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 102),
                children: [
                  for (final section in sections)
                    _RoleSection(
                      title: section.$1,
                      subtitle: section.$2,
                      options: section.$3,
                      selected: selected,
                      onToggle: (value) => setState(() {
                        selected.contains(value)
                            ? selected.remove(value)
                            : selected.add(value);
                      }),
                    ),
                  _BalancePolicyCard(
                    selected: selected,
                    onToggle: (value) => setState(() {
                      selected.removeWhere(
                          (item) => item.startsWith('سیاست مانده:'));
                      selected.add('سیاست مانده:$value');
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: AsoudBottomActions(
          primaryLabel: 'تأیید ترکیب نقش‌ها',
          onPrimary: () => Navigator.pop(context, selected),
          secondaryLabel: 'انصراف',
          onSecondary: () => Navigator.pop(context),
        ),
      );
}

class _RoleSection extends StatelessWidget {
  const _RoleSection({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onToggle,
  });
  final String title, subtitle;
  final List<(String, IconData, Color)> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            Text(subtitle,
                style: const TextStyle(fontSize: 9, color: AsoudColors.muted)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.05,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final active = selected.contains(option.$1);
                return InkWell(
                  onTap: () => onToggle(option.$1),
                  borderRadius: BorderRadius.circular(11),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: active
                          ? option.$3.withValues(alpha: .09)
                          : Colors.white,
                      border: Border.all(
                          color: active ? option.$3 : AsoudColors.border),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(children: [
                      Icon(
                          active
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 18,
                          color: active ? option.$3 : AsoudColors.muted),
                      const SizedBox(width: 6),
                      Icon(option.$2, size: 17, color: option.$3),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(option.$1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ]),
        ),
      );
}

class _BalancePolicyCard extends StatelessWidget {
  const _BalancePolicyCard({required this.selected, required this.onToggle});
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final current = selected
        .where((item) => item.startsWith('سیاست مانده:'))
        .map((item) => item.split(':').last)
        .firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('سیاست مانده حساب',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final option in ['بدون محدودیت', 'بدهکار', 'بستانکار'])
            InkWell(
              onTap: () => onToggle(option),
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 46),
                child: Row(children: [
                  Icon(
                    current == option
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: current == option
                        ? AsoudColors.primary
                        : AsoudColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Text(option,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
