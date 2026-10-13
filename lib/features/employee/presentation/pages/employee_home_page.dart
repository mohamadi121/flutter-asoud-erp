import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../hr/data/personnel_file_repository.dart';
import '../../../../core/auth/capabilities.dart';
import '../../../reports/presentation/pages/reports_hub_page.dart';
import '../../../workflows/presentation/widgets/home_inbox_summary.dart';
import '../../../workflows/presentation/pages/workflow_tasks_page.dart';
import '../../../calendar/calendar_page.dart';
import '../../../dashboard/presentation/pages/sync_status_indicator.dart';
import '../../../dashboard/presentation/pages/sync_queue_page.dart';
import '../../../hr/domain/personnel_file.dart';
import '../../../hr/presentation/pages/hr_home_page.dart';
import 'my_info_page.dart';
import '../widgets/employee_photo.dart';
import '../../../request_templates/request_templates.dart';
import '../../../workflows/presentation/pages/generic_request_page.dart';
import '../../../workflows/domain/entities/workflow_notification.dart';
import '../../../workflows/domain/repositories/workflow_notification_repository.dart';
import '../../../workflows/presentation/pages/workflow_notifications_page.dart';
import '../../data/demo/employee_demo_data.dart';
import '../../data/self_service_repository.dart';
import 'my_attendance_page.dart';

String _errorText(Object error) =>
    error is ApiException ? error.message : 'دریافت اطلاعات ممکن نشد.';

/// Shared personal home: profile, existing calendar, inbox and quick actions.
class EmployeeHomePage extends StatefulWidget {
  const EmployeeHomePage({
    required this.company,
    this.files,
    this.selfService,
    this.onOpenTab,
    this.notifications,
    this.now,
    this.demoPreview = false,
    this.onOperations,
    this.statusBanner,
    super.key,
  });

  final String company;
  final Widget? statusBanner;
  final VoidCallback? onOperations;
  final WorkflowNotificationRepository? notifications;
  final DateTime? now;
  final PersonnelFileRepository? files;
  final SelfServiceRepository? selfService;

  /// Shows the offline-preview demo rows instead of calling the repository.
  final bool demoPreview;

  /// Switches the shell tab (1 کارتابل, 2 درخواست‌ها, 3 مکاتبات).
  final ValueChanged<int>? onOpenTab;

  @override
  State<EmployeeHomePage> createState() => _EmployeeHomePageState();
}

class _EmployeeHomePageState extends State<EmployeeHomePage> {
  late final PersonnelFileRepository files =
      widget.files ?? PersonnelFileRepository(context.read<FrappeApiClient>());
  Future<EmployeeHome> _loadHome() async =>
      widget.demoPreview ? demoEmployeeHome() : await files.myHome();
  late Future<EmployeeHome> future = _loadHome();
  late Future<Capabilities> capabilities =
      capabilitiesOf(context, offlinePreview: widget.demoPreview);
  late final WorkflowNotificationRepository? notifications =
      widget.notifications ?? context.read<WorkflowNotificationRepository?>();
  late Future<List<WorkflowNotification>> notices =
      notifications?.getNotifications() ?? Future.value([]);
  int refreshVersion = 0;

  Future<void> _reload() async {
    final next = _loadHome();
    setState(() {
      future = next;
      capabilities =
          capabilitiesOf(context, offlinePreview: widget.demoPreview);
      notices = notifications?.getNotifications() ?? Future.value([]);
      refreshVersion++;
    });
    await next.catchError((_) => EmployeeHome.fromJson(const {}));
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _reload();
  }

  SelfServiceRepository get _selfService =>
      widget.selfService ??
      SelfServiceRepository(context.read<FrappeApiClient>());
  void _profile() => _push(MyInfoPage(repository: files));

  void _operations(EmployeeHome? home) {
    if (widget.onOperations != null) {
      widget.onOperations!();
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
            builder: (_) => Scaffold(
                  appBar: const AsoudHeader(title: 'عملیات'),
                  body: SafeArea(
                      child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                        if (home != null)
                          _DateCard(
                              home: home, now: widget.now ?? DateTime.now()),
                        const SizedBox(height: 12),
                        _QuickActions(actions: [
                          _Action('درخواست‌ها', Icons.description_outlined,
                              AsoudColors.primary,
                              badge: home?.counts.openRequests ?? 0,
                              onTap: () => widget.onOpenTab != null
                                  ? () {
                                      Navigator.pop(context);
                                      widget.onOpenTab!(2);
                                    }()
                                  : _push(GenericRequestsPage(
                                      company: widget.company))),
                          _Action('حضور و غیاب', Icons.schedule_rounded,
                              AsoudColors.success,
                              onTap: () => _push(
                                  MyAttendancePage(repository: _selfService))),
                          _Action('گزارش کار', Icons.fact_check_outlined,
                              AsoudColors.warning,
                              onTap: () => _push(
                                  WorkReportsPage(company: widget.company))),
                          _Action('مکاتبات', Icons.mail_outline_rounded,
                              AsoudColors.purple,
                              onTap: () => widget.onOpenTab != null
                                  ? () {
                                      Navigator.pop(context);
                                      widget.onOpenTab!(3);
                                    }()
                                  : _push(HrCommunicationsPage(
                                      company: widget.company))),
                          _Action('پرونده من', Icons.badge_outlined,
                              AsoudColors.cyan,
                              onTap: () =>
                                  _push(MyInfoPage(repository: files))),
                          _Action('مدارک', Icons.folder_outlined,
                              AsoudColors.danger,
                              onTap: () => _push(MyInfoPage(
                                  repository: files, showDocuments: true))),
                          _Action('مرخصی', Icons.beach_access_outlined,
                              AsoudColors.success,
                              onTap: () => _push(LeaveRequestsListPage(
                                  company: widget.company))),
                          _Action('درخواست خرید', Icons.shopping_cart_outlined,
                              AsoudColors.primary,
                              onTap: () => _push(PurchaseRequestsListPage(
                                  company: widget.company))),
                          _Action('تأمین کالا / خدمات',
                              Icons.inventory_2_outlined, AsoudColors.cyan,
                              onTap: () => _push(SupplyRequestsListPage(
                                  company: widget.company))),
                        ]),
                      ])),
                )))
        .then((_) {
      if (mounted) _reload();
    });
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
            child: FutureBuilder<EmployeeHome>(
                future: future,
                builder: (context, snapshot) {
                  final home = snapshot.data;
                  return RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            FutureBuilder<List<WorkflowNotification>>(
                                future: notices,
                                builder: (context, alerts) => _TopBar(
                                    company: widget.company,
                                    unread: notifications != null &&
                                            alerts.hasData
                                        ? alerts.data!
                                            .where((n) => !n.isRead)
                                            .length
                                        : home?.counts.unreadNotifications ?? 0,
                                    onProfile: _profile,
                                    onNotifications: () => _push(
                                        const WorkflowNotificationsPage()))),
                            const SizedBox(height: 10),
                            if (widget.statusBanner != null) ...[
                              widget.statusBanner!,
                              const SizedBox(height: 10),
                            ],
                            if (snapshot.connectionState !=
                                ConnectionState.done)
                              const LinearProgressIndicator()
                            else if (snapshot.hasError)
                              Card(
                                  child: ListTile(
                                      leading: const Icon(Icons.person_outline),
                                      title: const Text('پرونده من'),
                                      subtitle:
                                          Text(_errorText(snapshot.error!)),
                                      onTap: _profile,
                                      trailing: IconButton(
                                          tooltip: 'تلاش دوباره',
                                          onPressed: _reload,
                                          icon: const Icon(Icons.refresh))))
                            else if (home != null)
                              _Greeting(home: home, onTap: _profile),
                            if (widget.demoPreview)
                              const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                      'پیش‌نمایش آفلاین · اطلاعات شخصی نمونه است',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AsoudColors.warning))),
                            const SizedBox(height: 10),
                            AsoudCalendar(
                                key: ValueKey(widget.company),
                                company: widget.company,
                                compact: true,
                                now: widget.now),
                            const SizedBox(height: 10),
                            HomeInboxSummary(
                                key: ValueKey(
                                    'inbox:${widget.company}:$refreshVersion'),
                                now: widget.now),
                            const SizedBox(height: 14),
                            const Text('دسترسی سریع',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            FutureBuilder<Capabilities>(
                                future: capabilities,
                                builder: (context, access) {
                                  final actions =
                                      <(String, IconData, Color, VoidCallback)>[
                                    (
                                      'عملیات',
                                      Icons.apps_rounded,
                                      AsoudColors.primary,
                                      () => _operations(home)
                                    ),
                                    if (access.data?.canSeeAccounting == true)
                                      (
                                        'گزارش‌ها',
                                        Icons.bar_chart_rounded,
                                        AsoudColors.purple,
                                        () => _push(const ReportsHubPage())
                                      ),
                                    (
                                      'کارتابل',
                                      Icons.assignment_ind_outlined,
                                      AsoudColors.warning,
                                      () => _push(const WorkflowTasksPage())
                                    ),
                                    (
                                      'پرونده من',
                                      Icons.badge_outlined,
                                      AsoudColors.cyan,
                                      _profile
                                    ),
                                  ];
                                  return GridView.count(
                                      crossAxisCount: 2,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      mainAxisExtent: 90,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      children: [
                                        for (final action in actions)
                                          Card(
                                              margin: EdgeInsets.zero,
                                              child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  onTap: action.$4,
                                                  child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        AsoudIconBox(
                                                            icon: action.$2,
                                                            color: action.$3,
                                                            size: 34),
                                                        const SizedBox(
                                                            height: 6),
                                                        Text(action.$1,
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700)),
                                                      ]))),
                                      ]);
                                }),
                          ]));
                })),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.company,
      required this.unread,
      required this.onNotifications,
      required this.onProfile});
  final int unread;
  final String company;
  final VoidCallback onNotifications, onProfile;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: AsoudColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AsoudColors.border)),
      child: Column(children: [
        Row(children: [
          const AsoudIconBox(
              icon: Icons.hub_outlined, color: AsoudColors.primary, size: 36),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('آسود',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const Text('خانه من',
                    style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
                Text(company,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, color: AsoudColors.muted)),
              ])),
          IconButton(
              tooltip: 'اعلان‌ها',
              onPressed: onNotifications,
              icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(toPersianDigits(unread)),
                  child: const Icon(Icons.notifications_none_rounded))),
          IconButton(
              tooltip: 'پرونده من',
              onPressed: onProfile,
              icon: const Icon(Icons.account_circle_outlined)),
        ]),
        if (syncServiceOf(context) case final service?)
          SyncStatusIndicator(
              service: service, onOpen: () => openSyncQueue(context, service)),
      ]));
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.home, required this.onTap});
  final EmployeeHome home;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      margin: EdgeInsets.zero,
      child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: EmployeePhoto(name: home.name, recordId: home.photoRecord),
          title: Text(home.name,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          subtitle: Text(
              [home.designation, home.departmentName]
                  .where((v) => v.isNotEmpty)
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AsoudColors.muted)),
          trailing: const Icon(Icons.chevron_left_rounded)));
}

class _DateCard extends StatelessWidget {
  const _DateCard({required this.home, required this.now});
  final EmployeeHome home;
  final DateTime now;
  String get status {
    final checkin = home.lastCheckin;
    final date = DateTime.tryParse(checkin?.time ?? '');
    if (date == null ||
        date.year != now.year ||
        date.month != now.month ||
        date.day != now.day) {
      return 'امروز هنوز ورودی ثبت نشده';
    }
    return "${checkin!.logType == 'OUT' ? 'خروج' : 'ورود'} امروز: ${toPersianDigits('${date.hour.toString().padLeft(2, "0")}:${date.minute.toString().padLeft(2, "0")}')}";
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AsoudColors.primary.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(formatJalaliLong(now),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(status, style: const TextStyle(fontSize: 12))
            ]),
          ),
          const AsoudIconBox(
              icon: Icons.calendar_month_outlined,
              color: AsoudColors.primary,
              size: 40),
        ]),
      );
}

class _Action {
  const _Action(this.label, this.icon, this.color,
      {required this.onTap, this.badge = 0});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badge;
  String get subtitle => const {
        'درخواست‌ها': 'ثبت و پیگیری درخواست',
        'مرخصی': 'روزانه و ساعتی',
        'درخواست خرید': 'خرید کالا',
        'تأمین کالا / خدمات': 'تأمین از انبار یا خرید',
        'حضور و غیاب': 'ثبت ورود و خروج',
        'گزارش کار': 'ثبت گزارش روزانه',
        'مکاتبات': 'دریافت و ارسال نامه',
        'پرونده من': 'مشاهده پرونده',
        'مدارک': 'مشاهده مدارک'
      }[label]!;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});
  final List<_Action> actions;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 112,
        children: [
          for (final action in actions)
            Material(
              color: action.color.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: action.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Badge(
                        isLabelVisible: action.badge > 0,
                        label: Text(toPersianDigits(action.badge)),
                        child: AsoudIconBox(
                            icon: action.icon, color: action.color, size: 38),
                      ),
                      const SizedBox(height: 6),
                      Text(action.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(action.subtitle,
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 10)))),
                    ]),
              ),
            ),
        ],
      );
}

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({required this.announcement, super.key});
  final Announcement announcement;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AsoudIconBox(
                icon: Icons.campaign_outlined,
                color: AsoudColors.warning,
                size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(announcement.title,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                    if (announcement.summary.isNotEmpty)
                      Text(announcement.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AsoudColors.muted,
                              height: 1.6)),
                    const SizedBox(height: 2),
                    Text(formatJalaliIso(announcement.date),
                        style: const TextStyle(
                            fontSize: 10, color: AsoudColors.muted)),
                  ]),
            ),
          ]),
        ),
      );
}

/// «اطلاعیه‌ها»: every public, unexpired announcement.
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage(
      {required this.repository, this.demoItems, super.key});
  final PersonnelFileRepository repository;

  /// Preview rows; when set, the repository is not called.
  final List<Announcement>? demoItems;

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  late Future<List<Announcement>> future = widget.demoItems != null
      ? Future.value(widget.demoItems)
      : widget.repository.announcements();

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: const AsoudHeader(title: 'اطلاعیه‌ها'),
          body: FutureBuilder<List<Announcement>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                      onPressed: () => setState(() {
                            future = widget.demoItems != null
                                ? Future.value(widget.demoItems)
                                : widget.repository.announcements();
                          }),
                      child:
                          Text('${_errorText(snapshot.error!)} تلاش دوباره')),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const Center(
                    child: Text('اطلاعیه‌ای وجود ندارد.',
                        style: TextStyle(color: AsoudColors.muted)));
              }
              return ListView(padding: const EdgeInsets.all(16), children: [
                for (final item in snapshot.data!)
                  AnnouncementCard(announcement: item),
              ]);
            },
          ),
        ),
      );
}
