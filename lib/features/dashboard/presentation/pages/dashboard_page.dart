import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../accounting/presentation/pages/accounting_home_page.dart';
import '../../../base_setup/presentation/pages/base_accounting_setup_page.dart';
import '../../../office_setup/domain/entities/office.dart';
import '../../../office_setup/domain/repositories/office_repository.dart';
import '../../../office_setup/presentation/pages/office_type_page.dart';
import '../../../office_setup/presentation/pages/offices_page.dart';
import '../../../workflows/presentation/pages/workflow_list_page.dart';

class DashboardLandingPage extends StatefulWidget {
  const DashboardLandingPage({this.offlinePreview = false, super.key});

  final bool offlinePreview;

  @override
  State<DashboardLandingPage> createState() => _DashboardLandingPageState();
}

class _DashboardLandingPageState extends State<DashboardLandingPage> {
  late Future<Office?> _office;

  @override
  void initState() {
    super.initState();
    _office = context.read<OfficeRepository>().getDefaultOffice();
  }

  void _reload() => setState(
        () => _office = context.read<OfficeRepository>().getDefaultOffice(),
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<Office?>(
        future: _office,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return DashboardPage(
            office: snapshot.data,
            officeName: snapshot.data?.name,
            offlinePreview: widget.offlinePreview || snapshot.hasError,
            loadError: snapshot.hasError,
            onOfficeCreated: _reload,
          );
        },
      );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage(
      {this.officeName,
      this.office,
      this.offlinePreview = false,
      this.loadError = false,
      this.onOfficeCreated,
      super.key});

  final String? officeName;
  final Office? office;
  final bool offlinePreview;
  final bool loadError;
  final VoidCallback? onOfficeCreated;

  @override
  Widget build(BuildContext context) {
    final hasOffice = officeName?.trim().isNotEmpty == true;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _Header(officeName: officeName),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (!hasOffice)
                  _EmptyOfficeDashboard(
                    loadError: loadError,
                    onCreated: onOfficeCreated,
                  )
                else ...[
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
                  _InfoCards(office: office),
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
              ],
            ),
          ),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => WorkflowListPage(company: officeName),
            ));
          } else if (index != 0) {
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
              icon: Icon(Icons.hub_outlined), label: 'گردش‌کار'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_outlined), label: 'حسابداری'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded), label: 'گزارش‌ها'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
        ],
      ),
    );
  }
}

class _EmptyOfficeDashboard extends StatelessWidget {
  const _EmptyOfficeDashboard({required this.loadError, this.onCreated});

  final bool loadError;
  final VoidCallback? onCreated;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: loadError
                  ? AsoudColors.warning.withValues(alpha: .08)
                  : AsoudColors.primary.withValues(alpha: .06),
              border: Border.all(
                color: loadError
                    ? AsoudColors.warning.withValues(alpha: .45)
                    : AsoudColors.primary.withValues(alpha: .22),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              AsoudIconBox(
                icon: loadError
                    ? Icons.cloud_off_rounded
                    : Icons.business_center_outlined,
                color: loadError ? AsoudColors.warning : AsoudColors.primary,
                size: 52,
              ),
              const SizedBox(height: 12),
              Text(
                loadError
                    ? 'اطلاعات دفتر در دسترس نیست'
                    : 'هنوز دفتری ایجاد نشده است',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                loadError
                    ? 'پس از اتصال سرور دوباره تلاش کنید یا برای ادامه طراحی، یک دفتر موقت بسازید.'
                    : 'برای شروع، مشخصات دفتر حقیقی یا حقوقی خود را ثبت کنید.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: AsoudColors.muted),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OfficeTypePage(),
                      ),
                    );
                    onCreated?.call();
                  },
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('ایجاد دفتر کار'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          const _EmptyMetricsGrid(),
        ],
      );
}

class _EmptyMetricsGrid extends StatelessWidget {
  const _EmptyMetricsGrid();

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.8,
        children: const [
          _EmptyMetric(title: 'دریافتی امروز', icon: Icons.payments_outlined),
          _EmptyMetric(title: 'فروش امروز', icon: Icons.bar_chart_rounded),
          _EmptyMetric(
              title: 'موجودی بانک', icon: Icons.account_balance_outlined),
          _EmptyMetric(title: 'اسناد باز', icon: Icons.description_outlined),
        ],
      );
}

class _EmptyMetric extends StatelessWidget {
  const _EmptyMetric({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFBFCFE),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 10, color: AsoudColors.muted))),
                Icon(icon, size: 19, color: AsoudColors.border),
              ]),
              const Text('—',
                  style: TextStyle(
                      fontSize: 18,
                      color: AsoudColors.muted,
                      fontWeight: FontWeight.w800)),
            ],
          ),
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
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('دفتر کار',
                    style:
                        TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                Text(officeName ?? 'هنوز دفتری انتخاب نشده',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AsoudColors.muted)),
              ])),
          const SizedBox(width: 10),
          if (officeName?.trim().isNotEmpty == true)
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const OfficesPage()),
              ),
              icon: const Icon(Icons.business_outlined, size: 17),
              label: const Text('تغییر دفتر'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
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
  const _InfoCards({this.office});
  final Office? office;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: _InfoCard(
                title: 'سال مالی',
                value: office?.fiscalYear ?? 'تعریف نشده',
                subtitle: office?.fiscalYear == null
                    ? 'نیازمند تنظیم'
                    : 'فعال پیش‌فرض')),
        const SizedBox(width: 8),
        Expanded(
            child: _InfoCard(
                title: 'سرفصل‌ها',
                value: office?.chartTemplate ?? 'تعریف نشده',
                subtitle: office?.chartTemplate == null
                    ? 'نیازمند تنظیم'
                    : 'قالب انتخاب‌شده')),
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
