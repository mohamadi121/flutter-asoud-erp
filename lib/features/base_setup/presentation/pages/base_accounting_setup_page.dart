import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../domain/entities/accounting_setup.dart';
import '../../domain/repositories/base_setup_repository.dart';
import '../bloc/base_setup_cubit.dart';
import 'roles_setup_page.dart';
import 'fiscal_years_page.dart';
import '../../../accounting/presentation/pages/chart_setup_page.dart';
import '../../../accounting/presentation/pages/detail_groups_page.dart';
import '../../../parties/presentation/pages/party_management_page.dart';
import '../../../parties/domain/entities/party_profile.dart';
import '../../../hr/presentation/pages/hr_home_page.dart';
import '../../../workflows/presentation/pages/workflow_list_page.dart';
import '../../../purchase/presentation/pages/purchase_requests_page.dart';
import '../../../office_setup/domain/entities/office.dart';
import '../../../office_setup/domain/repositories/office_repository.dart';

class BaseAccountingSetupPage extends StatefulWidget {
  const BaseAccountingSetupPage(
      {this.officeName, this.offlinePreview = false, super.key});

  final String? officeName;
  final bool offlinePreview;

  @override
  State<BaseAccountingSetupPage> createState() =>
      _BaseAccountingSetupPageState();
}

class _BaseAccountingSetupPageState extends State<BaseAccountingSetupPage> {
  late Future<Office?> _setupStatus;

  @override
  void initState() {
    super.initState();
    _setupStatus = _loadSetupStatus();
  }

  Future<Office?> _loadSetupStatus() => widget.offlinePreview
      ? Future<Office?>.value(null)
      : context.read<OfficeRepository>().getDefaultOffice();

  void _retrySetupStatus() => setState(() {
        _setupStatus = _loadSetupStatus();
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
          title: 'تنظیمات پایه',
          subtitle: 'تنظیمات هر ماژول را جداگانه مدیریت کنید',
          action: AsoudIconBox(
              icon: Icons.tune_rounded, color: AsoudColors.primary),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              FutureBuilder<Office?>(
                future: _setupStatus,
                builder: (context, snapshot) => _SetupOverview(
                  officeName: widget.officeName,
                  offlinePreview: widget.offlinePreview,
                  status: snapshot.data,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                  loadFailed: snapshot.hasError,
                  onRetry: _retrySetupStatus,
                ),
              ),
              const SizedBox(height: 18),
              Card(
                  child: ListTile(
                leading: const AsoudIconBox(
                    icon: Icons.hub_outlined, color: AsoudColors.primary),
                title: const Text('طراح گردش‌کار و فرم درخواست'),
                subtitle: const Text('بررسی فرایندهای قبلی و طراحی مراحل'),
                trailing: const Icon(Icons.chevron_left),
                onTap: widget.officeName == null
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) =>
                              WorkflowListPage(company: widget.officeName),
                        )),
              )),
              Card(
                  child: ListTile(
                leading: const AsoudIconBox(
                    icon: Icons.assignment_outlined,
                    color: AsoudColors.warning),
                title: const Text('درخواست‌های خرید'),
                subtitle: const Text('ثبت و مشاهده درخواست‌های موجود'),
                trailing: const Icon(Icons.chevron_left),
                onTap: widget.officeName == null
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) =>
                              PurchaseRequestsPage(company: widget.officeName!),
                        )),
              )),
              const Text('ماژول‌های تنظیمات پایه',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisExtent: 195,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _ModuleGridTile(
                    title: 'حسابداری',
                    subtitle: 'کدینگ، سرفصل‌ها و تفصیلی',
                    icon: Icons.account_balance_rounded,
                    color: AsoudColors.primary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => AccountingBaseSetupPage(
                                officeName: widget.officeName,
                                offlinePreview: widget.offlinePreview,
                              )),
                    ),
                  ),
                  _ModuleGridTile(
                    title: 'مالی و خزانه',
                    subtitle: 'بانک، صندوق و پرداخت‌ها',
                    icon: Icons.account_balance_wallet_outlined,
                    color: AsoudColors.success,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const _UnavailableModulePage(title: 'مالی و خزانه'),
                      ),
                    ),
                  ),
                  _ModuleGridTile(
                    title: 'انبار و کالا',
                    subtitle: 'کالا، واحد سنجش و انبارها',
                    icon: Icons.inventory_2_outlined,
                    color: AsoudColors.purple,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const _UnavailableModulePage(title: 'انبار و کالا'),
                      ),
                    ),
                  ),
                  _ModuleGridTile(
                    title: 'منابع انسانی',
                    subtitle: 'پرسنل، نقش‌ها و ساختار سازمانی',
                    icon: Icons.badge_outlined,
                    color: const Color(0xFFEF6C5B),
                    onTap: widget.officeName == null
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      HrHomePage(company: widget.officeName!)),
                            ),
                  ),
                  _ModuleGridTile(
                    title: 'خرید و تدارکات',
                    subtitle: 'تأمین‌کنندگان و سفارش خرید',
                    icon: Icons.shopping_cart_checkout_rounded,
                    color: AsoudColors.warning,
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => PartyManagementPage(
                          company: widget.officeName,
                          initialRole: PartyRole.supplier),
                    )),
                  ),
                  _ModuleGridTile(
                    title: 'فروش و درآمد',
                    subtitle: 'مشتریان، قیمت‌گذاری و فروش',
                    icon: Icons.point_of_sale_rounded,
                    color: AsoudColors.success,
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => PartyManagementPage(
                          company: widget.officeName,
                          initialRole: PartyRole.customer),
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'ماژول‌های غیرفعال در مراحل بعد و پس از تکمیل جریان کاری مربوطه فعال می‌شوند.',
                style: TextStyle(fontSize: 9, color: AsoudColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class AccountingBaseSetupPage extends StatelessWidget {
  const AccountingBaseSetupPage(
      {this.officeName, this.offlinePreview = false, this.status, super.key});

  final String? officeName;
  final bool offlinePreview;
  final Office? status;

  @override
  Widget build(BuildContext context) {
    final statusFuture = status != null
        ? Future<Office?>.value(status)
        : (offlinePreview
            ? Future<Office?>.value(null)
            : context.read<OfficeRepository>().getDefaultOffice());

    return Scaffold(
      appBar: const AsoudHeader(
        title: 'تنظیمات پایه حسابداری',
        subtitle: 'راه‌اندازی و پیکربندی مالی دفتر',
        action:
            AsoudIconBox(icon: Icons.tune_rounded, color: AsoudColors.primary),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            FutureBuilder<Office?>(
              future: statusFuture,
              builder: (context, snapshot) => _SetupOverview(
                officeName: officeName,
                offlinePreview: offlinePreview,
                status: snapshot.data ?? status,
                loading: snapshot.connectionState == ConnectionState.waiting &&
                    status == null,
              ),
            ),
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
              title: 'مدیریت نقش‌ها',
              subtitle: 'دسترسی‌های مدیر، حسابدار و کاربران',
              status: 'الگوی آماده یا ایجاد دستی',
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
              icon: Icons.people_outline_rounded,
              color: AsoudColors.primary,
              title: 'اشخاص و شرکت‌ها',
              subtitle: 'تعریف اشخاص، شرکت‌ها و کد تفصیلی',
              status: 'اطلاعات پایه حسابداری',
              onTap: officeName == null
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                PartyManagementPage(company: officeName)),
                      ),
            ),
            const SizedBox(height: 9),
            _SetupTile(
              icon: Icons.hub_outlined,
              color: AsoudColors.cyan,
              title: 'گروه تفصیلی شناور',
              subtitle: 'مشتریان، تأمین‌کنندگان، پروژه‌ها و مراکز هزینه',
              status: 'مدیریت گروه‌های تفصیلی ASOUD ERP',
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
}

class _ModuleGridTile extends StatelessWidget {
  const _ModuleGridTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                AsoudIconBox(icon: icon, color: color, size: 42),
                Icon(
                    onTap == null
                        ? Icons.lock_outline_rounded
                        : Icons.chevron_left_rounded,
                    size: 18,
                    color: onTap == null ? AsoudColors.muted : color),
              ]),
              const Spacer(),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10.5, height: 1.6, color: AsoudColors.muted)),
            ]),
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
  const _SetupOverview({
    required this.officeName,
    required this.offlinePreview,
    this.status,
    this.loading = false,
    this.loadFailed = false,
    this.onRetry,
  });
  final String? officeName;
  final bool offlinePreview;
  final Office? status;
  final bool loading;
  final bool loadFailed;
  final VoidCallback? onRetry;

  double? get _progress {
    if (offlinePreview) return 1 / 3;
    if (loading) return null;
    if (loadFailed) return 0;
    return status?.setupComplete == true ? 1 : 1 / 3;
  }

  String get _statusText {
    if (offlinePreview) return 'پیش‌نمایش آفلاین • ۱ مورد از ۳ مورد';
    if (loading) return 'در حال دریافت وضعیت راه‌اندازی…';
    if (status?.setupComplete == true) return 'راه‌اندازی دفتر کامل شده است.';
    return 'راه‌اندازی دفتر هنوز کامل نیست.';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F7FF),
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('تنظیمات پایه دفتر',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            Container(
              width: 100,
              height: 96,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFE4EFFF), Color(0xFFF3F7FF)]),
                  borderRadius: BorderRadius.circular(20)),
              child: const Stack(alignment: Alignment.center, children: [
                Icon(Icons.assignment_turned_in_outlined,
                    color: AsoudColors.primary, size: 64),
                Positioned(
                    bottom: 2,
                    left: 4,
                    child: Icon(Icons.settings_rounded,
                        color: AsoudColors.warning, size: 32)),
                Positioned(
                    bottom: 4,
                    right: 0,
                    child: Icon(Icons.trending_up_rounded,
                        color: AsoudColors.primary, size: 36)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Text(status?.name ?? officeName ?? 'دفتر کار',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          if (loadFailed && !offlinePreview)
            Row(children: [
              const Expanded(
                child: Text(
                  'دریافت وضعیت راه‌اندازی ناموفق بود.',
                  style: TextStyle(color: AsoudColors.warning, fontSize: 10),
                ),
              ),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('تلاش دوباره'),
              ),
            ])
          else
            Text(
              _statusText,
              style: const TextStyle(color: AsoudColors.muted, fontSize: 10),
            ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: _progress, minHeight: 7),
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

class _UnavailableModulePage extends StatelessWidget {
  const _UnavailableModulePage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AsoudHeader(title: title),
        body: const ComingSoonState(
            description: 'این ماژول در نسخه‌های بعدی آسود فعال می‌شود.'),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              if (offlinePreview) ...[
                const _OfflineSetupBanner(),
                const SizedBox(height: 18),
              ],
              const _SectionTitle(
                  icon: Icons.account_balance_wallet_rounded,
                  color: AsoudColors.accounting,
                  title: 'مبنای حسابداری'),
              const _AccountingBasisCard(),
              const SizedBox(height: 24),
              const _SectionTitle(
                  icon: Icons.payments_rounded,
                  color: Color(0xFF26A69A),
                  title: 'واحد نمایش مبالغ'),
              _MoneyUnitSelector(value: state.moneyUnit),
              const SizedBox(height: 24),
              _FinancialNavigationCard(
                title: 'سال مالی و تاریخ شروع',
                subtitle:
                    'ابتدا سال را ایجاد و سپس روز و ماه شروع را انتخاب کنید',
                icon: Icons.calendar_month_rounded,
                onTap: officeName == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FiscalYearsPage(
                              company: officeName!,
                              repository: context.read<BaseSetupRepository>(),
                              offlinePreview: offlinePreview,
                            ),
                          ),
                        ),
              ),
              const SizedBox(height: 22),
              const _SectionTitle(
                icon: Icons.account_tree_outlined,
                color: AsoudColors.primary,
                title: 'الگوی کد سرفصل‌ها',
              ),
              _AccountCodeModeCard(
                value: state.autoGenerateAccountCode,
                onChanged: context.read<BaseSetupCubit>().setAutoAccountCode,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _DigitSelector(
                  label: 'گروه',
                  value: state.groupCodeDigits,
                  onChanged: context.read<BaseSetupCubit>().setGroupDigits,
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: _DigitSelector(
                  label: 'کل',
                  value: state.generalCodeDigits,
                  onChanged: context.read<BaseSetupCubit>().setGeneralDigits,
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: _DigitSelector(
                  label: 'معین',
                  value: state.ledgerCodeDigits,
                  onChanged: context.read<BaseSetupCubit>().setLedgerDigits,
                )),
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
          final saved = await context.read<BaseSetupCubit>().submit();
          if (!saved || !context.mounted) return;
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
              'حالت آفلاین؛ تنظیمات در دیتابیس گوشی ذخیره و بعداً همگام می‌شوند.',
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
  Widget build(BuildContext context) => AsoudSegmentedControl<MoneyUnit>(
        value: value,
        options: const [
          AsoudSegmentedOption(
              value: MoneyUnit.rial,
              label: 'ریال',
              icon: Icons.account_balance_wallet_outlined),
          AsoudSegmentedOption(
              value: MoneyUnit.toman,
              label: 'تومان',
              icon: Icons.payments_outlined),
        ],
        onChanged: context.read<BaseSetupCubit>().setMoneyUnit,
      );
}

class _FinancialNavigationCard extends StatelessWidget {
  const _FinancialNavigationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          leading: AsoudIconBox(icon: icon, color: AsoudColors.success),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 9)),
          trailing: const Icon(Icons.chevron_left_rounded),
        ),
      );
}

class _DigitSelector extends StatelessWidget {
  const _DigitSelector({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 6),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AsoudColors.muted,
                    fontWeight: FontWeight.w700)),
          ),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: value,
            decoration: const InputDecoration(isDense: true),
            items: List.generate(
              4,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text(formatCount(index + 1, 'رقم')),
              ),
            ),
            onChanged: (next) => next == null ? null : onChanged(next),
          ),
        ],
      );
}

class _AccountingBasisCard extends StatelessWidget {
  const _AccountingBasisCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(children: [
          AsoudIconBox(
              icon: Icons.check_circle_rounded,
              color: AsoudColors.success,
              size: 38),
          SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('حسابداری تعهدی',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text('ثبت هم‌زمان فاکتورها، بدهی‌ها و مطالبات',
                  style: TextStyle(fontSize: 9, color: AsoudColors.muted)),
            ]),
          ),
        ]),
      );
}

class _AccountCodeModeCard extends StatelessWidget {
  const _AccountCodeModeCard({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F7FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('تولید خودکار کد حساب',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              const Text('کد نهایی و یکتا توسط سرور تولید می‌شود.',
                  style: TextStyle(fontSize: 9, color: AsoudColors.muted)),
            ]),
          ),
          Switch(value: value, onChanged: onChanged),
        ]),
      );
}

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
