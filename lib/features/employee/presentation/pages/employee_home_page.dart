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
import '../../../hr/presentation/pages/personnel_page.dart';
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
    super.key,
  });

  final String company;
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

  Future<void> _reload() async {
    final next = files.myHome();
    setState(() {
      future = next;
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
                    const _DateCard(),
                    const SizedBox(height: 18),
                    const Text('دسترسی سریع',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    _QuickActions(actions: [
                      _Action('درخواست‌ها', Icons.description_outlined,
                          AsoudColors.primary,
                          badge: home.counts.openRequests,
                          onTap: () => widget.onOpenTab?.call(2)),
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
                          onTap: () => widget.onOpenTab?.call(3)),
                      _Action(
                          'اطلاعات من', Icons.badge_outlined, AsoudColors.cyan,
                          onTap: () =>
                              _push(PersonnelFilePage.mine(repository: files))),
                      _Action(
                          'مدارک', Icons.folder_outlined, AsoudColors.danger,
                          onTap: () => _push(PersonnelFilePage.mine(
                              repository: files, initialTab: 2))),
                    ]),
                    const SizedBox(height: 18),
                    Row(children: [
                      const Expanded(
                        child: Text('اعلان‌ها',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900)),
                      ),
                      TextButton(
                          onPressed: () =>
                              _push(AnnouncementsPage(repository: files)),
                          child: const Text('مشاهده همه')),
                    ]),
                    if (home.announcements.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('اطلاعیه‌ای وجود ندارد.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AsoudColors.muted)),
                      )
                    else
                      for (final item in home.announcements.take(5))
                        AnnouncementCard(announcement: item),
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
    final initials = home.name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join(' ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AsoudColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AsoudColors.border),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AsoudColors.primary.withValues(alpha: .12),
          child: Text(initials,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AsoudColors.primary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('سلام ${home.firstName}!',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
  const _DateCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AsoudColors.primary.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Expanded(
            child: Text(formatJalaliLong(DateTime.now()),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
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
        childAspectRatio: 1.15,
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
