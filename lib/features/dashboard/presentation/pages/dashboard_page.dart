import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../accounting/presentation/pages/accounting_home_page.dart';
import '../../../base_setup/presentation/pages/base_accounting_setup_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage(
      {this.officeName, this.offlinePreview = false, super.key});

  final String? officeName;
  final bool offlinePreview;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            _Header(officeName: officeName),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _ConnectionBanner(offline: offlinePreview),
                  const SizedBox(height: 10),
                  const _MetricsGrid(),
                  const SizedBox(height: 10),
                  _SetupProgress(
                    offline: offlinePreview,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BaseAccountingSetupPage(
                          officeName: officeName,
                          offlinePreview: offlinePreview,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _InfoCards(),
                  const SizedBox(height: 14),
                  const Text('عملیات سریع',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  _QuickActions(
                    onAccounting: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AccountingHomePage(
                          company: officeName,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (index) {
            if (index != 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('این بخش هنوز به Backend متصل نشده است.'),
              ));
            }
          },
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'خانه'),
            NavigationDestination(
                icon: Icon(Icons.grid_view_outlined), label: 'عملیات'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart_rounded), label: 'گزارش‌ها'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
          ],
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.officeName});
  final String? officeName;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.business_outlined, size: 17),
            label: const Text('تغییر دفتر'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('دفتر کار',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            Text(officeName ?? 'دفتر فعال',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AsoudColors.muted)),
          ])),
        ]),
      );
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.offline});
  final bool offline;
  @override
  Widget build(BuildContext context) {
    final color = offline ? AsoudColors.warning : AsoudColors.success;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        border: Border.all(color: color.withValues(alpha: .55), width: 1.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: color,
          child: Icon(offline ? Icons.cloud_off_rounded : Icons.check_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(offline ? 'حالت موقت آفلاین' : 'همگام‌سازی با ERPNext موفق بود',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          Text(
              offline
                  ? 'داده‌ها هنوز در سرور ذخیره نشده‌اند.'
                  : 'اطلاعات دفتر به‌روز است.',
              style: const TextStyle(fontSize: 9, color: AsoudColors.muted)),
        ])),
      ]),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid();
  static const items = [
    ('دریافتی امروز', Icons.payments_outlined, AsoudColors.success),
    ('فروش امروز', Icons.bar_chart_rounded, AsoudColors.primary),
    ('موجودی بانک', Icons.account_balance_outlined, AsoudColors.purple),
    ('اسناد باز', Icons.description_outlined, AsoudColors.warning),
  ];
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.55,
        children: items
            .map((item) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(item.$1,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700))),
                            AsoudIconBox(
                                icon: item.$2, color: item.$3, size: 30)
                          ]),
                          const Text('—',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w900)),
                          const Text('پس از اتصال سرور',
                              style: TextStyle(
                                  fontSize: 8, color: AsoudColors.muted)),
                        ]),
                  ),
                ))
            .toList(),
      );
}

class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.offline, required this.onTap});
  final bool offline;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: const Color(0xFFFFFAF0),
            border: Border.all(color: const Color(0xFFF4B43C)),
            borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Row(children: [
            const AsoudIconBox(
                icon: Icons.priority_high_rounded,
                color: AsoudColors.warning,
                size: 32),
            const SizedBox(width: 9),
            const Expanded(
                child: Text('راه‌اندازی دفتر هنوز کامل نیست',
                    style: TextStyle(
                        color: Color(0xFFC26A00),
                        fontSize: 11,
                        fontWeight: FontWeight.w800))),
          ]),
          const Divider(height: 18),
          Row(children: [
            Expanded(
                child: Text(
                    offline
                        ? '۱ مورد از ۳ مورد تکمیل شده است'
                        : 'وضعیت از سرور دریافت می‌شود',
                    style: const TextStyle(
                        fontSize: 9, color: AsoudColors.muted))),
            FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: const Text('تکمیل تنظیمات پایه',
                    style: TextStyle(fontSize: 9))),
          ]),
        ]),
      );
}

class _InfoCards extends StatelessWidget {
  const _InfoCards();
  @override
  Widget build(BuildContext context) => const Row(children: [
        Expanded(
            child: _InfoCard(
                title: 'سال مالی', value: '۱۴۰۳', subtitle: 'فعال پیش‌فرض')),
        SizedBox(width: 8),
        Expanded(
            child: _InfoCard(
                title: 'سرفصل‌ها',
                value: 'تعریف نشده',
                subtitle: 'نیازمند تنظیم')),
      ]);
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.title, required this.value, required this.subtitle});
  final String title, value, subtitle;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(11),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(fontSize: 9, color: AsoudColors.muted)),
            const SizedBox(height: 5),
            Text(value,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            Text(subtitle,
                style: const TextStyle(fontSize: 8, color: AsoudColors.muted))
          ])));
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onAccounting});
  final VoidCallback onAccounting;
  @override
  Widget build(BuildContext context) {
    final items = <(String, String, IconData, Color, VoidCallback?)>[
      (
        'دریافت و پرداخت',
        'Payment',
        Icons.payments_outlined,
        AsoudColors.success,
        null
      ),
      (
        'فاکتور فروش',
        'Sale Invoice',
        Icons.description_outlined,
        AsoudColors.primary,
        null
      ),
      (
        'کالا و خدمات',
        'Items',
        Icons.inventory_2_outlined,
        AsoudColors.warning,
        null
      ),
      (
        'ثبت حسابداری',
        'Journal Entry',
        Icons.receipt_long_outlined,
        AsoudColors.purple,
        onAccounting
      ),
      (
        'گزارش‌ها',
        'Reports',
        Icons.bar_chart_rounded,
        AsoudColors.danger,
        null
      ),
      (
        'طرف حساب‌ها',
        'Customer/Supplier',
        Icons.people_outline_rounded,
        AsoudColors.cyan,
        null
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.15,
      children: items
          .map((item) => Card(
                child: InkWell(
                  onTap: item.$5,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Row(children: [
                      AsoudIconBox(icon: item.$3, color: item.$4, size: 34),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$1,
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w800)),
                            Text(item.$2,
                                style: const TextStyle(
                                    fontSize: 7, color: AsoudColors.muted)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
