import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../hr/data/personnel_file_repository.dart';
import '../../../hr/domain/personnel_file.dart';
import '../../../hr/presentation/pages/hr_home_page.dart';
import 'my_info_page.dart';
import '../widgets/employee_photo.dart';
import '../../../workflows/presentation/pages/generic_request_page.dart';
import '../../../workflows/domain/entities/workflow_notification.dart';
import '../../../workflows/domain/repositories/workflow_notification_repository.dart';
import '../../../workflows/presentation/pages/workflow_notifications_page.dart';
import '../../data/self_service_repository.dart';
import 'my_attendance_page.dart';

String _errorText(Object error) =>
    error is ApiException ? error.message : 'دریافت اطلاعات ممکن نشد.';

/// «خانه» of the employee panel: greeting, today's date, quick actions and
/// company announcements.
class EmployeeHomePage extends StatefulWidget {
  const EmployeeHomePage({
    required this.company,
    this.files,
    this.selfService,
    this.onOpenTab,
    this.notifications,
    this.now,
    super.key,
  });

  final String company;
  final WorkflowNotificationRepository? notifications;
  final DateTime? now;
  final PersonnelFileRepository? files;
  final SelfServiceRepository? selfService;

  /// Switches the shell tab (1 کارتابل, 2 درخواست‌ها, 3 مکاتبات).
  final ValueChanged<int>? onOpenTab;

  @override
  State<EmployeeHomePage> createState() => _EmployeeHomePageState();
}

class _EmployeeHomePageState extends State<EmployeeHomePage> {
  late final PersonnelFileRepository files =
      widget.files ?? PersonnelFileRepository(context.read<FrappeApiClient>());
  late Future<EmployeeHome> future = files.myHome();
  late final WorkflowNotificationRepository? notifications =
      widget.notifications ?? _notificationsFromContext();
  late Future<List<WorkflowNotification>> notices =
      notifications?.getNotifications() ?? Future.value([]);
  WorkflowNotificationRepository? _notificationsFromContext() =>
      context.read<WorkflowNotificationRepository?>();

  Future<void> _reload() async {
    final next = files.myHome();
    setState(() {
      future = next;
      notices = notifications?.getNotifications() ?? Future.value([]);
    });
    await next.catchError((_) => EmployeeHome.fromJson(const {}));
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  SelfServiceRepository get _selfService =>
      widget.selfService ??
      SelfServiceRepository(context.read<FrappeApiClient>());

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: FutureBuilder<EmployeeHome>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_errorText(snapshot.error!),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: _reload, child: const Text('تلاش دوباره')),
                    ]),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final home = snapshot.data!;
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _TopBar(
                      unread: home.counts.unreadNotifications,
                      onNotifications: () =>
                          _push(const WorkflowNotificationsPage()),
                    ),
                    const SizedBox(height: 12),
                    _Greeting(home: home),
                    const SizedBox(height: 12),
                    _DateCard(home: home, now: widget.now ?? DateTime.now()),
                    const SizedBox(height: 18),
                    const Text('دسترسی سریع',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    _QuickActions(actions: [
                      _Action('درخواست‌ها', Icons.description_outlined,
                          AsoudColors.primary,
                          badge: home.counts.openRequests,
                          onTap: () => widget.onOpenTab != null
                              ? widget.onOpenTab!(2)
                              : _push(GenericRequestsPage(
                                  company: widget.company))),
                      _Action('حضور و غیاب', Icons.schedule_rounded,
                          AsoudColors.success,
                          onTap: () => _push(
                              MyAttendancePage(repository: _selfService))),
                      _Action('گزارش کار', Icons.fact_check_outlined,
                          AsoudColors.warning,
                          onTap: () =>
                              _push(WorkReportsPage(company: widget.company))),
                      _Action('مکاتبات', Icons.mail_outline_rounded,
                          AsoudColors.purple,
                          onTap: () => widget.onOpenTab != null
                              ? widget.onOpenTab!(3)
                              : _push(HrCommunicationsPage(
                                  company: widget.company))),
                      _Action(
                          'اطلاعات من', Icons.badge_outlined, AsoudColors.cyan,
                          onTap: () => _push(MyInfoPage(repository: files))),
                      _Action(
                          'مدارک', Icons.folder_outlined, AsoudColors.danger,
                          onTap: () => _push(MyInfoPage(
                              repository: files, showDocuments: true))),
                    ]),
                    const SizedBox(height: 18),
                    Row(children: [
                      const Expanded(
                          child: Text('اعلان‌ها',
                              style: TextStyle(fontWeight: FontWeight.w900))),
                      TextButton(
                          onPressed: () =>
                              _push(const WorkflowNotificationsPage()),
                          child: const Text('مشاهده همه')),
                    ]),
                    FutureBuilder<List<WorkflowNotification>>(
                      future: notices,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return TextButton(
                              onPressed: () => setState(() {
                                    notices =
                                        notifications?.getNotifications() ??
                                            Future.value([]);
                                  }),
                              child: const Text(
                                  'دریافت اعلان‌ها ممکن نشد؛ تلاش دوباره'));
                        }
                        final items = [...?snapshot.data]..sort((a, b) =>
                            (b.createdAt ?? DateTime(1970))
                                .compareTo(a.createdAt ?? DateTime(1970)));
                        return Column(children: [
                          if (items.isEmpty)
                            const Text('اعلانی برای نمایش وجود ندارد.'),
                          for (final item in items.take(3))
                            Card(
                                child: ListTile(
                              onTap: () =>
                                  _push(const WorkflowNotificationsPage()),
                              title: Text(item.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.message,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(_relativeTime(item.createdAt,
                                        widget.now ?? DateTime.now()))
                                  ]),
                              trailing: item.isRead
                                  ? null
                                  : Container(
                                      key: ValueKey('unread-${item.id}'),
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                          color: AsoudColors.primary,
                                          shape: BoxShape.circle)),
                            )),
                        ]);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.unread, required this.onNotifications});
  final int unread;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) => Row(children: [
        const SizedBox(width: 48),
        const Expanded(
          child: Text('خانه',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ),
        IconButton(
          tooltip: 'اعلان‌ها',
          onPressed: onNotifications,
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(toPersianDigits(unread)),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ]);
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.home});
  final EmployeeHome home;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AsoudColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AsoudColors.border),
      ),
      child: Row(children: [
        EmployeePhoto(name: home.name, recordId: home.photoRecord),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                  child: Text('سلام ${home.firstName}!',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900))),
              const SizedBox(width: 6),
              const Icon(Icons.waving_hand_outlined,
                  size: 18, color: AsoudColors.warning)
            ]),
            const Text('روز خوبی داشته باشی'),
            Text(home.name),
            const SizedBox(height: 4),
            Text(
                [home.designation, home.departmentName]
                    .where((part) => part.isNotEmpty)
                    .join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AsoudColors.muted)),
          ]),
        ),
      ]),
    );
  }
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
        'حضور و غیاب': 'ثبت ورود و خروج',
        'گزارش کار': 'ثبت گزارش روزانه',
        'مکاتبات': 'دریافت و ارسال نامه',
        'اطلاعات من': 'مشاهده پرونده',
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
  const AnnouncementsPage({required this.repository, super.key});
  final PersonnelFileRepository repository;

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  late Future<List<Announcement>> future = widget.repository.announcements();

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
                            future = widget.repository.announcements();
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

String _relativeTime(DateTime? date, DateTime now) {
  if (date == null) return 'زمان ثبت نشده';
  final elapsed = now.difference(date);
  if (elapsed.inMinutes < 1) return 'همین حالا';
  if (elapsed.inHours < 1) {
    return '${toPersianDigits(elapsed.inMinutes)} دقیقه پیش';
  }
  if (elapsed.inDays < 1) return '${toPersianDigits(elapsed.inHours)} ساعت پیش';
  return '${toPersianDigits(elapsed.inDays)} روز پیش';
}
