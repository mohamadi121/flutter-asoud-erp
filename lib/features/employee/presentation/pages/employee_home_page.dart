import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../hr/data/personnel_file_repository.dart';
import '../../../workflows/presentation/widgets/home_inbox_summary.dart';
import '../../../calendar/calendar_page.dart';
import '../../../dashboard/presentation/pages/sync_status_indicator.dart';
import '../../../dashboard/presentation/pages/sync_queue_page.dart';
import '../../../hr/domain/personnel_file.dart';
import 'my_info_page.dart';
import '../widgets/employee_photo.dart';
import '../../../workflows/domain/entities/workflow_notification.dart';
import '../../../workflows/domain/repositories/workflow_notification_repository.dart';
import '../../../workflows/presentation/pages/workflow_notifications_page.dart';
import '../../data/demo/employee_demo_data.dart';
import '../../data/self_service_repository.dart';

String _errorText(Object error) =>
    error is ApiException ? error.message : 'دریافت اطلاعات ممکن نشد.';

/// Shared personal home: profile, existing inbox and calendar.
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
  late final PersonnelFileRepository files = widget.files ??
      context.read<PersonnelFileRepository?>() ??
      PersonnelFileRepository(context.read<FrappeApiClient>());
  Future<EmployeeHome> _loadHome() async =>
      widget.demoPreview ? demoEmployeeHome() : await files.myHome();
  late Future<EmployeeHome> future = _loadHome();
  late final WorkflowNotificationRepository? notifications =
      widget.notifications ?? context.read<WorkflowNotificationRepository?>();
  late Future<List<WorkflowNotification>> notices =
      notifications?.getNotifications() ?? Future.value([]);
  int refreshVersion = 0;

  Future<void> _reload() async {
    final next = _loadHome();
    setState(() {
      future = next;
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

  void _profile() => _push(MyInfoPage(repository: files));

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ColoredBox(color: const Color(0xFFF6F8FC),
      child: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: FutureBuilder<List<WorkflowNotification>>(
            future: notices,
            builder: (context, alerts) => _TopBar(
              company: widget.company, now: widget.now ?? DateTime.now(),
              unread: alerts.data?.where((n) => !n.isRead).length ?? 0,
              onProfile: _profile,
              onNotifications: () => _push(const WorkflowNotificationsPage())))),
        Expanded(child: RefreshIndicator(onRefresh: _reload,
          child: ListView(physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              if (syncServiceOf(context) case final service?)
                SyncStatusIndicator(service: service, hideWhenClear: true,
                  onOpen: () => openSyncQueue(context, service)),
              if (widget.statusBanner != null) ...[
                widget.statusBanner!, const SizedBox(height: 10)],
              FutureBuilder<EmployeeHome>(future: future,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return _Greeting(home: snapshot.data!, onTap: _profile);
                  }
                  return Card(margin: EdgeInsets.zero, color: Colors.white,
                    child: ListTile(leading: const Icon(Icons.person_outline),
                      title: const Text('پرونده من'), onTap: _profile,
                      subtitle: Text(snapshot.hasError
                        ? _errorText(snapshot.error!) : 'دریافت اطلاعات پرونده…'),
                      trailing: snapshot.hasError
                        ? IconButton(tooltip: 'تلاش دوباره', onPressed: _reload,
                            icon: const Icon(Icons.refresh))
                        : const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))));
                }),
              if (widget.demoPreview)
                const Text('پیش‌نمایش آفلاین · اطلاعات شخصی نمونه است',
                  style: TextStyle(fontSize: 12, color: Color(0xFF2878DE))),
              const SizedBox(height: 10),
              HomeInboxSummary(
                key: ValueKey('inbox:${widget.company}:$refreshVersion'),
                company: widget.company, now: widget.now),
              const SizedBox(height: 10),
              AsoudCalendar(key: ValueKey('calendar:${widget.company}:$refreshVersion'),
                company: widget.company, compact: true, now: widget.now),
            ]))),
      ]))),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.company,
      required this.now,
      required this.unread,
      required this.onNotifications,
      required this.onProfile});
  final int unread;
  final String company;
  final DateTime now;
  final VoidCallback onNotifications, onProfile;
  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('دفتر کار فعال',
            style: TextStyle(fontSize: 12, color: AsoudColors.muted)),
          Text(company, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w700)),
        ])),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
        child: Column(children: [
          Text('آسود', style: TextStyle(fontSize: 18,
            color: Color(0xFF2878DE), fontWeight: FontWeight.w800)),
          Text('ERP', style: TextStyle(fontSize: 10, color: Color(0xFF2878DE))),
        ])),
      IconButton(tooltip: 'اعلان‌ها', onPressed: onNotifications,
        icon: Badge(isLabelVisible: unread > 0,
          label: Text(toPersianDigits(unread)),
          child: const Icon(Icons.notifications_none_rounded))),
      IconButton(tooltip: 'پرونده من', onPressed: onProfile,
        icon: const Icon(Icons.account_circle_outlined)),
    ]),
    const SizedBox(height: 12),
    Row(children: [
      const Expanded(child: Text('خانه من',
        style: TextStyle(fontSize: 22, color: Color(0xFF172B50),
          fontWeight: FontWeight.w800))),
      Flexible(child: Text(formatJalaliLong(now), textAlign: TextAlign.end,
        style: const TextStyle(fontSize: 12, color: AsoudColors.muted))),
    ]),
  ]);
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.home, required this.onTap});
  final EmployeeHome home;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: EmployeePhoto(name: home.name, recordId: home.photoRecord),
          title: const Text('پرونده من',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          subtitle: Text(
              [home.name, home.designation, home.departmentName]
                  .where((v) => v.isNotEmpty)
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AsoudColors.muted)),
          trailing: const Icon(Icons.chevron_left_rounded)));
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
