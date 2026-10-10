import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/auth/capabilities.dart';
import '../../../../core/offline/local_database_store.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../auth/data/unsent_offline_count.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../base_setup/presentation/pages/base_accounting_setup_page.dart';
import '../../../base_setup/presentation/pages/roles_setup_page.dart';
import '../../../hr/presentation/pages/hr_home_page.dart';
import '../../../hr/presentation/pages/organization_page.dart';
import '../../../office_setup/presentation/pages/offices_page.dart';
import '../../../request_types/presentation/pages/request_types_page.dart';
import '../../../roles/presentation/roles_page.dart';
import '../../../workflows/presentation/pages/generic_request_page.dart';
import '../../../workflows/presentation/pages/workflow_list_page.dart';
import '../../../workflows/presentation/pages/workflow_notifications_page.dart';
import '../../../workflows/presentation/pages/workflow_tasks_page.dart';
import 'sync_queue_page.dart';
import 'sync_status_indicator.dart';
import '../../data/demo/dashboard_demo_data.dart';

/// Administrative entry points. Unavailable telemetry is never presented as live.
class SettingsDashboardContent extends StatefulWidget {
  const SettingsDashboardContent(
      {this.company,
      this.offlinePreview = false,
      this.offlineStore,
      super.key});
  final String? company;
  final bool offlinePreview;

  /// Injected for tests; defaults to the on-device offline store.
  final LocalRecordStore? offlineStore;

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

  void _openLogin() {
    final client = context.read<FrappeApiClient>();
    final serverUrl = client is FrappeClient ? client.serverIdentity : null;
    _open(LoginPage(initialServerUrl: serverUrl));
  }

  /// Signs out without deleting queued rows: they are owner-scoped and
  /// replay when the same user signs in again.
  Future<void> _confirmLogout() async {
    final unsent = await countUnsentOfflineRows(store: widget.offlineStore);
    if (!mounted) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('خروج از حساب'),
        content: Text(unsent > 0
            ? '${toPersianDigits(unsent)} مورد هنوز به سرور ارسال نشده؛ با خروج، این موارد تا ورود دوباره همین کاربر ارسال نمی‌شوند'
            : 'از حساب سازمانی خارج می‌شوید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    final client = context.read<FrappeApiClient>();
    final serverUrl = client is FrappeClient ? client.serverIdentity : null;
    await context.read<AuthRepository>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
          builder: (_) => LoginPage(initialServerUrl: serverUrl)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.company;
    final hasOffice = company?.trim().isNotEmpty == true;
    final demo = widget.offlinePreview;
    final now = DateTime.now();
    final sync = syncServiceOf(context);
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
            if (sync != null) ...[
              const SizedBox(height: 12),
              SyncStatusIndicator(
                  service: sync, onOpen: () => openSyncQueue(context, sync)),
            ],
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
                                  : formatUserGreetingRoles(profile.roles),
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
            // Live telemetry is not connected yet: only the offline preview
            // shows these cards, so no «—»/«داده موجود نیست» placeholder is
            // presented as real data (bug #10).
            if (demo) ...[
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
                            AsoudColors.primary,
                            value:
                                demo ? demoSystemStatus('کاربران فعال') : null,
                            demo: demo),
                        _StatusCard('کاربران آنلاین',
                            Icons.desktop_windows_outlined, AsoudColors.success,
                            value: demo
                                ? demoSystemStatus('کاربران آنلاین')
                                : null,
                            demo: demo),
                        _StatusCard('فضای ذخیره‌سازی', Icons.storage_outlined,
                            AsoudColors.primary,
                            value: demo
                                ? demoSystemStatus('فضای ذخیره‌سازی')
                                : null,
                            demo: demo),
                        _StatusCard('درخواست‌های در انتظار',
                            Icons.pending_actions, AsoudColors.warning,
                            value: demo
                                ? demoSystemStatus('درخواست‌های در انتظار')
                                : null,
                            demo: demo,
                            onTap: hasOffice
                                ? () => _open(const WorkflowTasksPage())
                                : null),
                        _StatusCard('خطاهای سیستم', Icons.bug_report_outlined,
                            AsoudColors.purple,
                            value:
                                demo ? demoSystemStatus('خطاهای سیستم') : null,
                            demo: demo),
                        _StatusCard(
                            'وضعیت همگام‌سازی', Icons.sync, AsoudColors.success,
                            value: demo
                                ? demoSystemStatus('وضعیت همگام‌سازی')
                                : null,
                            demo: demo,
                            note: sync == null ? null : 'صف ارسال به سرور',
                            onTap: sync == null
                                ? null
                                : () => openSyncQueue(context, sync)),
                      ],
                    )),
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: const Text(
                    'آمار نمایشی برای پیش‌نمایش آفلاین است و روی سرور ذخیره نمی‌شود.',
                    style: TextStyle(
                        fontSize: 11, color: AsoudColors.muted))),
            ],
            const SizedBox(height: 18),
            const Text('عملیات سریع',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            if (!hasOffice)
              const Text(
                  'برای بخش‌های وابسته به دفتر، ابتدا دفتر را انتخاب یا ایجاد کنید.'),
            const SizedBox(height: 10),
            FutureBuilder<FrappeUserContext?>(
                future: user,
                builder: (context, snapshot) {
                  final capabilities = Capabilities.fromRoles(
                    snapshot.data?.roles ?? const [],
                    offlinePreview: widget.offlinePreview,
                  );
                  return LayoutBuilder(
                      builder: (context, constraints) => GridView.count(
                            crossAxisCount: constraints.maxWidth < 300 ? 3 : 4,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            mainAxisExtent: 96,
                            children: [
                              if (capabilities.canManageUserAccess)
                                _ActionCard('مدیریت کاربران',
                                    Icons.person_outline, AsoudColors.primary,
                                    onTap: widget.offlinePreview
                                        ? null
                                        : () => _open(UserAccessPage(
                                            repository: UserAccessRepository(
                                                context
                                                    .read<FrappeApiClient>())))),
                              if (capabilities.canManageOrganization)
                                _ActionCard(
                                    'ساختار سازمانی',
                                    Icons.account_tree_outlined,
                                    AsoudColors.purple,
                                    onTap: hasOffice
                                        ? () => _open(
                                            OrganizationPage(company: company!))
                                        : null),
                              if (capabilities.canSeeSettingsAdmin)
                                _ActionCard(
                                    'ماژول‌ها',
                                    Icons.view_module_outlined,
                                    AsoudColors.primary,
                                    onTap: hasOffice
                                        ? () => _open(BaseAccountingSetupPage(
                                            officeName: company,
                                            offlinePreview:
                                                widget.offlinePreview))
                                        : null),
                              if (capabilities.canManageRequestTypes)
                                _ActionCard(
                                    'انواع درخواست',
                                    Icons.description_outlined,
                                    AsoudColors.warning,
                                    onTap: hasOffice
                                        ? () => _open(
                                            RequestTypesPage(company: company!))
                                        : null),
                              _ActionCard('دفترها', Icons.business_outlined,
                                  AsoudColors.purple,
                                  onTap: () => _open(const OfficesPage())),
                              const _ActionCard('گزارش‌های سیستم',
                                  Icons.bar_chart, AsoudColors.primary),
                              if (capabilities.canManageRoles)
                                _ActionCard('مدیریت نقش‌ها',
                                    Icons.shield_outlined, AsoudColors.primary,
                                    note: 'الگو و ایجاد دستی',
                                    onTap: () => _open(RolesSetupPage(
                                        officeName: company,
                                        offlinePreview:
                                            widget.offlinePreview))),
                              if (capabilities.canManageWorkflows)
                                _ActionCard('گردش کار', Icons.alt_route_rounded,
                                    AsoudColors.success,
                                    onTap: hasOffice
                                        ? () => _open(
                                            WorkflowListPage(company: company))
                                        : null),
                              _ActionCard('منابع انسانی', Icons.badge_outlined,
                                  AsoudColors.warning,
                                  onTap: hasOffice
                                      ? () =>
                                          _open(HrHomePage(company: company!))
                                      : null),
                              _ActionCard('ثبت درخواست‌ها',
                                  Icons.note_add_outlined, AsoudColors.primary,
                                  onTap: hasOffice
                                      ? () => _open(GenericRequestsPage(
                                          company: company!))
                                      : null),
                              _ActionCard(
                                  'کارتابل',
                                  Icons.assignment_ind_outlined,
                                  AsoudColors.purple,
                                  onTap: hasOffice
                                      ? () => _open(const WorkflowTasksPage())
                                      : null),
                            ],
                          ));
                }),
            const SizedBox(height: 18),
            const Text('حساب کاربری',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (widget.offlinePreview)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openLogin,
                  icon: const Icon(Icons.business_rounded),
                  label: const Text('ورود به حساب سازمانی'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('خروج از حساب'),
                ),
              ),
          ]),
        ));
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard(this.title, this.icon, this.color,
      {this.onTap, this.note, this.value, this.demo = false});
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? note;

  /// Demo figure for the offline preview; null keeps the «—» placeholder.
  final String? value;
  final bool demo;
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
                    Text(value ?? '—',
                        style: const TextStyle(
                            fontSize: 18,
                            height: 1.1,
                            fontWeight: FontWeight.w800)),
                    Text(
                        note ??
                            (onTap == null
                                ? (demo ? 'نمایشی' : 'داده موجود نیست')
                                : (demo
                                    ? 'نمایشی · مشاهده کارتابل'
                                    : 'مشاهده کارتابل')),
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
      color: color.withValues(alpha: onTap == null ? .03 : .06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
            opacity: onTap == null ? .55 : 1,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon,
                          size: 24,
                          color: onTap == null ? AsoudColors.muted : color),
                      const SizedBox(height: 5),
                      Text(title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              height: 1.25,
                              fontWeight: FontWeight.w700)),
                      if (onTap == null || note != null)
                        Text(note ?? 'به‌زودی',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 9,
                                height: 1.3,
                                color: AsoudColors.muted)),
                    ]))),
      ));
}
