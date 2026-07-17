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
        appBar: AsoudHeader(
          title: 'دفتر کار',
          subtitle: officeName?.isNotEmpty == true ? officeName : 'دفتر فعال',
          action: const AsoudIconBox(
              icon: Icons.domain_rounded, color: AsoudColors.primary),
        ),
        body: SafeArea(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                if (offlinePreview) ...[
                  const _OfflineDashboardBanner(),
                  const SizedBox(height: 14),
                ],
                _ConnectionCard(),
                const SizedBox(height: 14),
                const _MetricsGrid(),
                const SizedBox(height: 14),
                _SetupWarning(
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => BaseAccountingSetupPage(
                                  offlinePreview: offlinePreview,
                                )))),
                const SizedBox(height: 18),
                const AsoudSectionTitle(title: 'عملیات سریع'),
                _QuickActions(
                    onAccounting: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const AccountingHomePage()))),
              ]),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (index) {
            if (index == 0) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('این بخش هنوز در محدوده فعلی پیاده‌سازی نشده است.')));
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

class _OfflineDashboardBanner extends StatelessWidget {
  const _OfflineDashboardBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E6),
          border: Border.all(color: AsoudColors.warning.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(children: [
          AsoudIconBox(
              icon: Icons.cloud_off_rounded,
              color: AsoudColors.warning,
              size: 36),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'حالت موقت آفلاین؛ اطلاعات این دفتر هنوز در ERPNext ذخیره نشده است.',
              style: TextStyle(fontSize: 10),
            ),
          ),
        ]),
      );
}

class _ConnectionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: const Color(0xFFF3F7FF),
            border: Border.all(color: AsoudColors.border),
            borderRadius: BorderRadius.circular(14)),
        child: const Row(children: [
          CircleAvatar(
              backgroundColor: AsoudColors.primary,
              radius: 17,
              child: Icon(Icons.sync_rounded, color: Colors.white, size: 20)),
          SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('وضعیت اتصال ERPNext',
                    style: TextStyle(
                        color: AsoudColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
                Text('پس از دریافت اطلاعات سرور نمایش داده می‌شود.',
                    style: TextStyle(color: AsoudColors.muted, fontSize: 10)),
              ])),
        ]),
      );
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid();
  static const items = [
    ('درآمد امروز', '—', 'ریال', Icons.payments_outlined, AsoudColors.success),
    ('فروش امروز', '—', 'ریال', Icons.trending_up_rounded, AsoudColors.primary),
    (
      'موجودی بانک',
      '—',
      'ریال',
      Icons.account_balance_outlined,
      AsoudColors.purple
    ),
    (
      'فاکتور باز',
      '—',
      'مورد',
      Icons.description_outlined,
      AsoudColors.warning
    ),
  ];
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: items
            .map((e) => Card(
                    child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.$1,
                                  style: const TextStyle(
                                      fontSize: 11, color: AsoudColors.muted)),
                              Icon(e.$4, color: e.$5, size: 20)
                            ]),
                        Text(e.$2,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                        Text(e.$3,
                            style: const TextStyle(
                                fontSize: 9, color: AsoudColors.muted)),
                      ]),
                )))
            .toList(),
      );
}

class _SetupWarning extends StatelessWidget {
  const _SetupWarning({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            border: Border.all(color: const Color(0xFFFAD78A)),
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const AsoudIconBox(
              icon: Icons.priority_high_rounded, color: AsoudColors.warning),
          const SizedBox(width: 10),
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('اطلاعات دفتر هنوز کامل نیست',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                Text('وضعیت تکمیل پس از دریافت اطلاعات سرور مشخص می‌شود.',
                    style: TextStyle(fontSize: 10, color: AsoudColors.muted))
              ])),
          TextButton(onPressed: onTap, child: const Text('تکمیل')),
        ]),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onAccounting});
  final VoidCallback onAccounting;
  @override
  Widget build(BuildContext context) {
    final items = <(String, IconData, Color, VoidCallback?)>[
      (
        'حسابداری',
        Icons.account_balance_outlined,
        AsoudColors.primary,
        onAccounting
      ),
      ('دریافت و پرداخت', Icons.credit_card_rounded, AsoudColors.success, null),
      (
        'اسناد حسابداری',
        Icons.receipt_long_outlined,
        AsoudColors.purple,
        onAccounting
      ),
      ('کالا و خدمات', Icons.inventory_2_outlined, AsoudColors.warning, null),
      ('گزارش‌ها', Icons.bar_chart_rounded, AsoudColors.danger, null),
      ('طرف حساب‌ها', Icons.people_outline_rounded, AsoudColors.cyan, null),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.3,
      children: items
          .map((e) => Card(
                  child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: e.$4,
                child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      AsoudIconBox(icon: e.$2, color: e.$3, size: 36),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(e.$1,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700)))
                    ])),
              )))
          .toList(),
    );
  }
}
