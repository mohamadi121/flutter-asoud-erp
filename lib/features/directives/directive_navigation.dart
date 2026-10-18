import 'package:flutter/material.dart';

import '../../core/widgets/asoud_bottom_bar.dart';
import '../../core/widgets/asoud_ui.dart';
import '../calendar/calendar_navigation.dart';
import '../dashboard/presentation/pages/dashboard_page.dart';
import '../dashboard/presentation/pages/settings_dashboard_content.dart';
import '../workflows/presentation/pages/cartable_page.dart';

/// Uses the application's five destinations, without changing the user's role.
/// Pushed routes keep the current form alive when the user comes back.
class DirectiveBottomBar extends StatelessWidget {
  const DirectiveBottomBar(
      {required this.company,
      this.selectedIndex = 3,
      this.enabled = true,
      super.key});

  final String company;
  final int selectedIndex;
  final bool enabled;

  @override
  Widget build(BuildContext context) => AsoudBottomBar(
        selectedIndex: selectedIndex,
        items: const [
          AsoudBottomBarItem(icon: Icons.home_outlined, label: 'خانه'),
          AsoudBottomBarItem(icon: Icons.grid_view_outlined, label: 'عملیات'),
          AsoudBottomBarItem(icon: Icons.add_circle, label: 'ایجاد'),
          AsoudBottomBarItem(icon: Icons.inbox_outlined, label: 'کارتابل'),
          AsoudBottomBarItem(icon: Icons.more_horiz, label: 'بیشتر'),
        ],
        onSelected: (index) {
          if (!enabled) return;
          if (index == 2) {
            showAsoudCreateMenu(context, company);
            return;
          }
          final Widget page = switch (index) {
            0 => const DashboardLandingPage(),
            1 => DashboardPage(officeName: company, operationsOnly: true),
            3 => CartablePage(company: company),
            _ => Scaffold(
                appBar: const AsoudHeader(title: 'بیشتر'),
                body: SettingsDashboardContent(company: company),
              ),
          };
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => page));
        },
      );
}
