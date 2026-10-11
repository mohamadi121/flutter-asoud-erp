import 'package:flutter/material.dart';

import '../../../../core/auth/capabilities.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import 'ledger_page.dart';
import 'trial_balance_page.dart';

/// Lists the financial reports the signed-in role may open.
///
/// Only reports that have a real page are listed; a report the backend exposes
/// but the app cannot render yet stays out of the hub instead of being a dead
/// card (bug #11).
class ReportsHubPage extends StatelessWidget {
  const ReportsHubPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
            title: 'گزارش‌ها', subtitle: 'گزارش‌های مالی دفتر'),
        body: SafeArea(
          child: FutureBuilder<Capabilities>(
            future: capabilitiesOf(context),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.data!.canSeeAccounting) {
                return const EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'دسترسی به گزارش‌ها',
                  description:
                      'برای این حساب دسترسی به گزارش‌های مالی تعریف نشده است.',
                );
              }
              final reports = <(String, String, IconData, Color, Widget)>[
                (
                  'دفتر کل',
                  'گردش یک حساب با مانده افتتاحیه و اختتامیه',
                  Icons.menu_book_rounded,
                  const Color(0xFF42A5F5),
                  const LedgerPage(title: 'دفتر کل'),
                ),
                (
                  'تراز آزمایشی',
                  'مانده بدهکار و بستانکار همه حساب‌ها در یک دوره',
                  Icons.balance_rounded,
                  const Color(0xFF26A69A),
                  const TrialBalancePage(),
                ),
              ];
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  for (final report in reports)
                    _ReportCard(
                      title: report.$1,
                      description: report.$2,
                      icon: report.$3,
                      color: report.$4,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => report.$5),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        child: ListTile(
          onTap: onTap,
          leading: AsoudIconBox(icon: icon, color: color),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AsoudColors.muted)),
          trailing: const Icon(Icons.chevron_left_rounded),
        ),
      );
}
