import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../base_setup/presentation/pages/base_accounting_setup_page.dart';
import '../../../base_setup/presentation/pages/roles_setup_page.dart';
import '../../../hr/presentation/pages/hr_home_page.dart';
import '../../../hr/presentation/pages/organization_page.dart';
import '../../../office_setup/presentation/pages/offices_page.dart';
import '../../../request_types/presentation/pages/request_types_page.dart';
import '../../../workflows/presentation/pages/generic_request_page.dart';
import '../../../workflows/presentation/pages/workflow_form_page.dart';
import '../../../workflows/presentation/pages/workflow_notifications_page.dart';
import '../../../workflows/presentation/pages/workflow_tasks_page.dart';

/// Administrative entry points. Unavailable telemetry is never presented as live.
class SettingsDashboardContent extends StatefulWidget {
  const SettingsDashboardContent(
      {this.company, this.offlinePreview = false, super.key});
  final String? company;
  final bool offlinePreview;

  @override
  State<SettingsDashboardContent> createState() =>
      _SettingsDashboardContentState();
}

class _SettingsDashboardContentState extends State<SettingsDashboardContent> {
  Future<FrappeUserContext?>? user;

  @override
  void initState() {
    super.initState();
    user = _loadUser();
  }

  Future<FrappeUserContext?> _loadUser() async {
    try {
      final client = context.read<FrappeApiClient>();
      if (!client.isAuthenticated) return null;
      return await client.getCurrentUser().timeout(const Duration(seconds: 8));
    } catch (_) {
      // Profile failure must not block the navigation hub or imply admin access.
      return null;
    }
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final company = widget.company;
    final hasOffice = company?.trim().isNotEmpty == true;
    final now = DateTime.now();
    return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Flexible(
                  child: OutlinedButton.icon(
                onPressed: () => _open(const OfficesPage()),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 10)),
                icon: const Icon(Icons.business_rounded, size: 20),
                label: Text(company ?? 'انتخاب دفتر',
                    overflow: TextOverflow.ellipsis),
              )),
              const Expanded(
                  child: Text('ASOUD ERP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AsoudColors.primary,
                          fontWeight: FontWeight.w900))),
              IconButton(
                  tooltip: 'اعلان‌ها',
                  onPressed: hasOffice
                      ? () => _open(const WorkflowNotificationsPage())
                      : null,
                  icon: const Icon(Icons.notifications_outlined)),
            ]),
            const SizedBox(height: 16),
            FutureBuilder<FrappeUserContext?>(
                future: user,
                builder: (context, snapshot) {
                  final profile = snapshot.data;
                  return Row(children: [
                    const CircleAvatar(
                        radius: 34,
                        child: Icon(Icons.person_outline_rounded, size: 38)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              profile == null
                                  ? 'سلام، خوش آمدید!'
                                  : 'سلام ${profile.fullName}!',
                              style: const TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          const Text('مدیریت و تنظیمات دفتر'),
                          Text(
                              profile == null
                                  ? 'اطلاعات دسترسی دریافت نشده است'
                                  : profile.roles.join('، '),
                              style: const TextStyle(
                                  fontSize: 11, color: AsoudColors.muted)),
                        ])),
                  ]);
                }),
            const SizedBox(height: 16),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: AsoudColors.primary.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(formatJalaliLong(now),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        const Text('دسترسی سریع به بخش‌های موجود آسود',
                            style: TextStyle(
                                color: AsoudColors.muted, fontSize: 11)),
                      ])),
                  const SizedBox(width: 12),
                  const AsoudIconBox(
                      icon: Icons.calendar_month_outlined,
                      color: AsoudColors.primary,
                      size: 44),
                ])),
            const SizedBox(height: 18),
            const Text('خلاصه وضعیت سیستم',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            LayoutBuilder(
                builder: (context, constraints) => GridView.count(
                      crossAxisCount: constraints.maxWidth < 300 ? 2 : 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      mainAxisExtent: 126,
                      children: [
                        _StatusCard('کاربران فعال', Icons.people_outline,
                            AsoudColors.primary),
                        _StatusCard(
                            'کاربران آنلاین',
                            Icons.desktop_windows_outlined,
                            AsoudColors.success),
                        _StatusCard('فضای ذخیره‌سازی', Icons.storage_outlined,
                            AsoudColors.primary),
                        _StatusCard('درخواست‌های در انتظار',
                            Icons.pending_actions, AsoudColors.warning,
                            onTap: hasOffice
                                ? () => _open(const WorkflowTasksPage())
                                : null),
                        _StatusCard('خطاهای سیستم', Icons.bug_report_outlined,
                            AsoudColors.purple),
                        _StatusCard('وضعیت همگام‌سازی', Icons.sync,
                            AsoudColors.success),
                      ],
                    )),
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'آمار سیستم هنوز به منبع داده متصل نیست؛ خط تیره به معنی صفر نیست.',
                    style: TextStyle(fontSize: 11, color: AsoudColors.muted))),
            const SizedBox(height: 18),
            const Text('عملیات سریع',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            if (!hasOffice)
              const Text(
                  'برای بخش‌های وابسته به دفتر، ابتدا دفتر را انتخاب یا ایجاد کنید.'),
            const SizedBox(height: 10),
            LayoutBuilder(
                builder: (context, constraints) => GridView.count(
                      crossAxisCount: constraints.maxWidth < 300 ? 3 : 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      mainAxisExtent: 96,
                      children: [
                        const _ActionCard('مدیریت کاربران',
                            Icons.person_outline, AsoudColors.primary),
                        _ActionCard('ساختار سازمانی',
                            Icons.account_tree_outlined, AsoudColors.purple,
                            onTap: hasOffice
                                ? () =>
                                    _open(OrganizationPage(company: company!))
                                : null),
                        _ActionCard('ماژول‌ها', Icons.view_module_outlined,
                            AsoudColors.primary,
                            onTap: hasOffice
                                ? () => _open(BaseAccountingSetupPage(
                                    officeName: company,
                                    offlinePreview: widget.offlinePreview))
                                : null),
                        _ActionCard('انواع درخواست', Icons.description_outlined,
                            AsoudColors.warning,
                            onTap: hasOffice
                                ? () =>
                                    _open(RequestTypesPage(company: company!))
                                : null),
                        _ActionCard('دفترها', Icons.business_outlined,
                            AsoudColors.purple,
                            onTap: () => _open(const OfficesPage())),
                        _ActionCard('نقش‌ها و دسترسی‌ها', Icons.shield_outlined,
                            AsoudColors.success,
                            note: 'تنظیمات اولیه',
                            onTap: hasOffice
                                ? () => _open(RolesSetupPage(
                                    officeName: company,
                                    offlinePreview: widget.offlinePreview))
                                : null),
                        const _ActionCard('گزارش‌های سیستم', Icons.bar_chart,
                            AsoudColors.primary),
                        _ActionCard('تنظیمات پایه', Icons.settings_outlined,
                            AsoudColors.primary,
                            onTap: hasOffice
                                ? () => _open(BaseAccountingSetupPage(
                                    officeName: company,
                                    offlinePreview: widget.offlinePreview))
                                : null),
                        _ActionCard('گردش کار', Icons.alt_route_rounded,
                            AsoudColors.success,
                            onTap: hasOffice
                                ? () => _open(const WorkflowFormPage())
                                : null),
                        _ActionCard('منابع انسانی', Icons.badge_outlined,
                            AsoudColors.warning,
                            onTap: hasOffice
                                ? () => _open(HrHomePage(company: company!))
                                : null),
                        _ActionCard('ثبت درخواست‌ها', Icons.note_add_outlined,
                            AsoudColors.primary,
                            onTap: hasOffice
                                ? () => _open(
                                    GenericRequestsPage(company: company!))
                                : null),
                        _ActionCard('کارتابل', Icons.assignment_ind_outlined,
                            AsoudColors.purple,
                            onTap: hasOffice
                                ? () => _open(const WorkflowTasksPage())
                                : null),
                      ],
                    )),
          ]),
        ));
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard(this.title, this.icon, this.color, {this.onTap});
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AsoudIconBox(icon: icon, color: color, size: 32),
                    const SizedBox(height: 6),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    const Text('—',
                        style: TextStyle(
                            fontSize: 18,
                            height: 1.1,
                            fontWeight: FontWeight.w800)),
                    Text(onTap == null ? 'داده موجود نیست' : 'مشاهده کارتابل',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 9,
                            height: 1.3,
                            color: AsoudColors.muted)),
                  ]))));
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(this.title, this.icon, this.color, {this.onTap, this.note});
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? note;
  @override
  Widget build(BuildContext context) => Card(
      color: color.withValues(alpha: .06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon,
                  size: 24, color: onTap == null ? AsoudColors.muted : color),
              const SizedBox(height: 5),
              Text(title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, height: 1.25, fontWeight: FontWeight.w700)),
              if (onTap == null || note != null)
                Text(note ?? 'هنوز فعال نیست',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 9, height: 1.3, color: AsoudColors.muted)),
            ])),
      ));
}
