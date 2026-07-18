import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/accounting_setup.dart';
import '../../domain/repositories/base_setup_repository.dart';
import '../bloc/base_setup_cubit.dart';
import 'roles_setup_page.dart';
import '../../../accounting/presentation/pages/chart_setup_page.dart';
import '../../../accounting/presentation/pages/detail_groups_page.dart';

class BaseAccountingSetupPage extends StatelessWidget {
  const BaseAccountingSetupPage(
      {this.officeName, this.offlinePreview = false, super.key});

  final String? officeName;
  final bool offlinePreview;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
          title: 'تنظیمات پایه',
          subtitle: 'راه‌اندازی و پیکربندی دفتر',
          action: AsoudIconBox(
              icon: Icons.tune_rounded, color: AsoudColors.primary),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _SetupOverview(
                  officeName: officeName, offlinePreview: offlinePreview),
              const SizedBox(height: 16),
              const Text('مراحل راه‌اندازی',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 9),
              _SetupTile(
                icon: Icons.account_balance_rounded,
                color: AsoudColors.primary,
                title: 'تنظیمات مالی و کدینگ',
                subtitle: 'واحد پول، سال مالی و الگوی سرفصل‌ها',
                status: 'در انتظار تکمیل',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AccountingPreferencesPage(
                      officeName: officeName,
                      repository: context.read<BaseSetupRepository>(),
                      offlinePreview: offlinePreview,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              _SetupTile(
                icon: Icons.manage_accounts_rounded,
                color: AsoudColors.purple,
                title: 'نقش‌های اولیه',
                subtitle: 'دسترسی‌های مدیر، حسابدار و کاربران',
                status: 'در انتظار تکمیل',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RolesSetupPage(
                      officeName: officeName,
                      offlinePreview: offlinePreview,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              const _SetupTile(
                icon: Icons.calendar_month_rounded,
                color: AsoudColors.success,
                title: 'سال‌های مالی',
                subtitle: 'مدیریت دوره‌های مالی دفتر',
                status: 'نیازمند API سرور',
              ),
              const SizedBox(height: 9),
              _SetupTile(
                icon: Icons.account_tree_outlined,
                color: AsoudColors.warning,
                title: 'سرفصل‌های حسابداری',
                subtitle: 'ایجاد و مرور گروه، کل، معین و تفصیلی',
                status: officeName == null
                    ? 'ابتدا دفتر فعال را انتخاب کنید'
                    : 'انتخاب قالب یا ایجاد دستی',
                onTap: officeName == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChartSetupPage(
                              company: officeName!,
                            ),
                          ),
                        ),
              ),
              const SizedBox(height: 9),
              _SetupTile(
                icon: Icons.hub_outlined,
                color: AsoudColors.cyan,
                title: 'گروه تفصیلی شناور',
                subtitle: 'مشتریان، تأمین‌کنندگان، پروژه‌ها و مراکز هزینه',
                status: 'مدیریت گروه‌های تفصیلی ERPNext',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DetailGroupsPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class AccountingPreferencesPage extends StatelessWidget {
  const AccountingPreferencesPage(
      {this.officeName,
      this.repository,
      this.offlinePreview = false,
      super.key});

  final String? officeName;
  final BaseSetupRepository? repository;
  final bool offlinePreview;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
        create: (_) => BaseSetupCubit(
              repository: repository,
              company: officeName,
              offlinePreview: offlinePreview,
            )..load(),
        child: _BaseAccountingSetupView(
          officeName: officeName,
          offlinePreview: offlinePreview,
        ));
  }
}

class _SetupOverview extends StatelessWidget {
  const _SetupOverview(
      {required this.officeName, required this.offlinePreview});
  final String? officeName;
  final bool offlinePreview;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F7FF),
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(officeName ?? 'دفتر کار',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(
            offlinePreview
                ? 'پیش‌نمایش آفلاین • ۱ مورد از ۳ مورد'
                : 'وضعیت تکمیل از ERPNext دریافت می‌شود',
            style: const TextStyle(color: AsoudColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 10),
          const LinearProgressIndicator(value: 1 / 3, minHeight: 7),
        ]),
      );
}

class _SetupTile extends StatelessWidget {
  const _SetupTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title, subtitle, status;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(children: [
              AsoudIconBox(icon: icon, color: color, size: 42),
              const SizedBox(width: 11),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 9, color: AsoudColors.muted)),
                    const SizedBox(height: 6),
                    Text(status,
                        style: TextStyle(
                            fontSize: 8,
                            color: onTap == null
                                ? AsoudColors.warning
                                : AsoudColors.primary)),
                  ])),
              Icon(Icons.chevron_left_rounded,
                  color:
                      onTap == null ? AsoudColors.border : AsoudColors.primary),
            ]),
          ),
        ),
      );
}

class _BaseAccountingSetupView extends StatelessWidget {
  const _BaseAccountingSetupView(
      {required this.officeName, required this.offlinePreview});

  final String? officeName;
  final bool offlinePreview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AsoudHeader(
          title: 'تنظیمات مالی', subtitle: 'پیکربندی مالی و حسابداری دفتر'),
      body: SafeArea(child: BlocBuilder<BaseSetupCubit, BaseSetupState>(
          builder: (context, state) {
        return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (offlinePreview) ...[
                const _OfflineSetupBanner(),
                const SizedBox(height: 18),
              ],
              const _SectionTitle(
                  icon: Icons.account_balance_wallet_rounded,
                  color: AsoudColors.accounting,
                  title: 'مبنای حسابداری'),
              const Card(
                elevation: 0,
                color: Colors.white,
                child: ListTile(
                  leading: Icon(Icons.check_circle_rounded,
                      color: AsoudColors.success),
                  title: Text('حسابداری تعهدی',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      'فاکتورها، بدهی‌ها و مطالبات هنگام ایجاد معامله ثبت می‌شوند.'),
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle(
                  icon: Icons.payments_rounded,
                  color: Color(0xFF26A69A),
                  title: 'واحد نمایش مبالغ'),
              _MoneyUnitSelector(value: state.moneyUnit),
              const SizedBox(height: 24),
              Row(children: [
                const Expanded(
                  child: _SectionTitle(
                    icon: Icons.calendar_month_rounded,
                    color: AsoudColors.success,
                    title: 'شروع سال مالی',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'روز، ماه و سال را انتخاب کنید؛ ایجاد نهایی فقط پس از پاسخ موفق ERPNext انجام می‌شود.',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('ایجاد سال جدید'),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: state.fiscalYearStartDay,
                    decoration: const InputDecoration(labelText: 'روز'),
                    items: List.generate(
                        31,
                        (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1}'),
                            )),
                    onChanged: (value) {
                      if (value != null) {
                        context.read<BaseSetupCubit>().setFiscalDay(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: state.fiscalYearStartMonth,
                    decoration: const InputDecoration(labelText: 'ماه'),
                    items: List.generate(
                        12,
                        (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text(_persianMonths[index]),
                            )),
                    onChanged: (value) {
                      if (value != null) {
                        context.read<BaseSetupCubit>().setFiscalMonth(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: state.fiscalYear,
                    decoration: const InputDecoration(labelText: 'سال'),
                    items: List.generate(
                        6,
                        (index) => DropdownMenuItem(
                              value: 1403 + index,
                              child: Text('${1403 + index}'),
                            )),
                    onChanged: (value) {
                      if (value != null) {
                        context.read<BaseSetupCubit>().setFiscalYear(value);
                      }
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              DropdownButtonFormField<ChartTemplate>(
                isExpanded: true,
                initialValue: state.chartTemplate,
                decoration:
                    const InputDecoration(labelText: 'الگوی سرفصل حساب‌ها'),
                items: const [
                  DropdownMenuItem(
                      value: ChartTemplate.iranStandard,
                      child: Text('استاندارد حسابداری ایران')),
                  DropdownMenuItem(
                      value: ChartTemplate.service, child: Text('شرکت خدماتی')),
                  DropdownMenuItem(
                      value: ChartTemplate.commercial,
                      child: Text('شرکت بازرگانی')),
                  DropdownMenuItem(
                      value: ChartTemplate.manufacturing,
                      child: Text('شرکت تولیدی')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    context.read<BaseSetupCubit>().setChartTemplate(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: state.autoGenerateDetailCodes,
                title: const Text('تولید خودکار کد تفصیلی'),
                subtitle: const Text('جزئیات قابل ویرایش و حذف باقی می‌مانند.'),
                onChanged: context.read<BaseSetupCubit>().setAutoDetailCodes,
              ),
              const SizedBox(height: 24),
            ]);
      })),
      bottomNavigationBar: AsoudBottomActions(
        primaryLabel: 'ذخیره و ادامه',
        onPrimary: () async {
          if (!offlinePreview) {
            final saved = await context.read<BaseSetupCubit>().submit();
            if (!saved || !context.mounted) return;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('پیش‌نمایش آفلاین؛ تنظیمات روی سرور ذخیره نشده است.'),
            ));
          }
          if (!context.mounted) return;
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => RolesSetupPage(
              officeName: officeName,
              offlinePreview: offlinePreview,
            ),
          ));
        },
      ),
    );
  }
}

class _OfflineSetupBanner extends StatelessWidget {
  const _OfflineSetupBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E6),
          border: Border.all(color: AsoudColors.warning.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, color: AsoudColors.warning),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'پیش‌نمایش آفلاین؛ تنظیمات فقط در حافظه نگهداری می‌شوند.',
              style: TextStyle(fontSize: 10),
            ),
          ),
        ]),
      );
}

class _MoneyUnitSelector extends StatelessWidget {
  const _MoneyUnitSelector({required this.value});
  final MoneyUnit value;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          for (final unit in MoneyUnit.values)
            Expanded(
              child: InkWell(
                onTap: () => context.read<BaseSetupCubit>().setMoneyUnit(unit),
                borderRadius: BorderRadius.circular(9),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == unit ? AsoudColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    unit == MoneyUnit.rial ? 'ریال' : 'تومان',
                    style: TextStyle(
                      color: value == unit ? Colors.white : AsoudColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}

const _persianMonths = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند'
];

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
      {required this.icon, required this.color, required this.title});
  final IconData icon;
  final Color color;
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color)),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))
      ]));
}
