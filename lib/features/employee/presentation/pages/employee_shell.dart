import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../hr/data/personnel_file_repository.dart';
import '../../../hr/presentation/pages/hr_home_page.dart';
import 'my_info_page.dart';
import '../../../workflows/presentation/pages/generic_request_page.dart';
import '../../../workflows/presentation/pages/workflow_notifications_page.dart';
import '../../../workflows/presentation/pages/workflow_tasks_page.dart';
import '../../data/demo/employee_demo_data.dart';
import '../../data/self_service_repository.dart';
import 'employee_home_page.dart';
import 'my_attendance_page.dart';

/// The employee's own panel: خانه · درخواست‌ها · مکاتبات · بیشتر.
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

  bool _previewFiles() {
    if (widget.files != null) return false;
    try {
      return AppConfig.offlineDemoMode &&
          !context.read<FrappeApiClient>().isAuthenticated;
    } catch (_) {
      return false;
    }
  }

  Widget _body() => switch (tab) {
        1 => const WorkflowTasksPage(),
        2 => GenericRequestsPage(company: widget.company),
        3 => HrCommunicationsPage(company: widget.company),
        4 => _MoreTab(
            company: widget.company,
            files: files,
            selfService: selfService,
            previewDemo: _previewFiles()),
        _ => EmployeeHomePage(
            company: widget.company,
            files: files,
            selfService: selfService,
            demoPreview: _previewFiles(),
            onOpenTab: _open),
      };

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: _body(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab == 1 ? 3 : const [0, 2, 3, 4].indexOf(tab),
            onDestinationSelected: (index) => _open(const [0, 2, 3, 4][index]),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'خانه'),
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
      {required this.company,
      required this.files,
      required this.selfService,
      this.previewDemo = false});
  final String company;
  final PersonnelFileRepository files;
  final SelfServiceRepository selfService;
  final bool previewDemo;

  @override
  Widget build(BuildContext context) {
    void push(Widget page) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    final items = <(String, IconData, Color, VoidCallback)>[
      (
        'کارتابل',
        Icons.assignment_ind_outlined,
        AsoudColors.primary,
        () => push(const WorkflowTasksPage())
      ),
      (
        'اطلاعات من',
        Icons.badge_outlined,
        AsoudColors.cyan,
        () => push(MyInfoPage(repository: files))
      ),
      (
        'مدارک من',
        Icons.folder_outlined,
        AsoudColors.danger,
        () => push(MyInfoPage(repository: files, showDocuments: true))
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
        () => push(AnnouncementsPage(
            repository: files,
            demoItems: previewDemo ? demoAnnouncements() : null))
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
