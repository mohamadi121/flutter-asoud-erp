import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../hr/data/personnel_file_repository.dart';
import '../../../hr/presentation/pages/hr_home_page.dart';
import '../../../hr/presentation/pages/personnel_page.dart';
import '../../../workflows/presentation/pages/generic_request_page.dart';
import '../../../workflows/presentation/pages/workflow_notifications_page.dart';
import '../../../workflows/presentation/pages/workflow_tasks_page.dart';
import '../../data/self_service_repository.dart';
import 'employee_home_page.dart';
import 'my_attendance_page.dart';

/// The employee's own panel: خانه · کارتابل · درخواست‌ها · مکاتبات · بیشتر.
class EmployeeShell extends StatefulWidget {
  const EmployeeShell({
    required this.company,
    this.files,
    this.selfService,
    this.initialTab = 0,
    super.key,
  });

  final String company;
  final PersonnelFileRepository? files;
  final SelfServiceRepository? selfService;
  final int initialTab;

  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  late int tab = widget.initialTab;
  late final PersonnelFileRepository files =
      widget.files ?? PersonnelFileRepository(context.read<FrappeApiClient>());
  late final SelfServiceRepository selfService = widget.selfService ??
      SelfServiceRepository(context.read<FrappeApiClient>());

  void _open(int index) => setState(() => tab = index);

  Widget _body() => switch (tab) {
        1 => const WorkflowTasksPage(),
        2 => GenericRequestsPage(company: widget.company),
        3 => HrCommunicationsPage(company: widget.company),
        4 => _MoreTab(
            company: widget.company, files: files, selfService: selfService),
        _ => EmployeeHomePage(
            company: widget.company,
            files: files,
            selfService: selfService,
            onOpenTab: _open),
      };

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: _body(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: _open,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'خانه'),
              NavigationDestination(
                  icon: Icon(Icons.assignment_ind_outlined), label: 'کارتابل'),
              NavigationDestination(
                  icon: Icon(Icons.description_outlined), label: 'درخواست‌ها'),
              NavigationDestination(
                  icon: Icon(Icons.mail_outline_rounded), label: 'مکاتبات'),
              NavigationDestination(
                  icon: Icon(Icons.more_horiz_rounded), label: 'بیشتر'),
            ],
          ),
        ),
      );
}

class _MoreTab extends StatelessWidget {
  const _MoreTab(
      {required this.company, required this.files, required this.selfService});
  final String company;
  final PersonnelFileRepository files;
  final SelfServiceRepository selfService;

  @override
  Widget build(BuildContext context) {
    void push(Widget page) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    final items = <(String, IconData, Color, VoidCallback)>[
      (
        'اطلاعات من',
        Icons.badge_outlined,
        AsoudColors.cyan,
        () => push(PersonnelFilePage.mine(repository: files))
      ),
      (
        'مدارک من',
        Icons.folder_outlined,
        AsoudColors.danger,
        () => push(PersonnelFilePage.mine(repository: files, initialTab: 2))
      ),
      (
        'حضور و غیاب',
        Icons.schedule_rounded,
        AsoudColors.success,
        () => push(MyAttendancePage(repository: selfService))
      ),
      (
        'گزارش کار',
        Icons.fact_check_outlined,
        AsoudColors.warning,
        () => push(WorkReportsPage(company: company))
      ),
      (
        'اعلان‌ها',
        Icons.notifications_none_rounded,
        AsoudColors.primary,
        () => push(const WorkflowNotificationsPage())
      ),
      (
        'اطلاعیه‌ها',
        Icons.campaign_outlined,
        AsoudColors.purple,
        () => push(AnnouncementsPage(repository: files))
      ),
    ];
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('بیشتر',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        for (final (label, icon, color, onTap) in items)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: AsoudIconBox(icon: icon, color: color, size: 38),
              title: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: onTap,
            ),
          ),
      ]),
    );
  }
}
