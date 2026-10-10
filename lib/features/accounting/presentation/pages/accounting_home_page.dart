import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import 'chart_setup_page.dart';
import 'detail_groups_page.dart';
import '../../../parties/presentation/pages/party_management_page.dart';

class AccountingHomePage extends StatelessWidget {
  const AccountingHomePage({this.company, super.key});
  final String? company;

  /// Rows whose feature is not implemented yet (bug #11). They are shown
  /// dimmed with a «به‌زودی» badge instead of an inert chevron.
  static const _comingSoon = {
    'سند حسابداری',
    'تراز آزمایشی',
    'دفتر کل',
    'مرور حساب‌ها',
    'گزارش‌های مالی',
  };

  @override
  Widget build(BuildContext context) {
    const actions = [
      ('سند حسابداری', Icons.receipt_long_rounded, Color(0xFFFFB547)),
      ('سرفصل حساب‌ها', Icons.account_tree_rounded, Color(0xFF5C6BC0)),
      ('تراز آزمایشی', Icons.balance_rounded, Color(0xFF26A69A)),
      ('دفتر کل', Icons.menu_book_rounded, Color(0xFF42A5F5)),
      ('مرور حساب‌ها', Icons.manage_search_rounded, Color(0xFFEF6C5B)),
      ('گزارش‌های مالی', Icons.analytics_rounded, Color(0xFF7E57C2)),
      ('گروه تفصیلی شناور', Icons.hub_outlined, Color(0xFF00ACC1)),
      ('مدیریت اشخاص', Icons.people_alt_outlined, Color(0xFF1769F6)),
    ];
    return Scaffold(
      appBar: const AsoudHeader(
          title: 'حسابداری', subtitle: 'عملیات و گزارش‌های مالی دفتر'),
      body: SafeArea(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
            const Text('حسابداری تعهدی',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const Text('مبتنی بر استانداردهای حسابداری ایران',
                style: TextStyle(color: AsoudColors.muted)),
            const SizedBox(height: 22),
            ...actions.map((action) {
              final comingSoon = _comingSoon.contains(action.$1);
              final VoidCallback? onTap = comingSoon
                  ? null
                  : action.$1 == 'سرفصل حساب‌ها' && company != null
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  ChartSetupPage(company: company!)))
                      : action.$1 == 'گروه تفصیلی شناور'
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const DetailGroupsPage(),
                                ),
                              )
                          : action.$1 == 'مدیریت اشخاص'
                              ? () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => PartyManagementPage(
                                        company: company,
                                      ),
                                    ),
                                  )
                              : null;
              final enabled = onTap != null;
              return Card(
                elevation: 0,
                color: Colors.white,
                child: ListTile(
                  enabled: enabled,
                  leading: AsoudIconBox(
                      icon: action.$2,
                      color: enabled ? action.$3 : AsoudColors.muted),
                  title: Text(action.$1,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: enabled ? null : AsoudColors.muted)),
                  trailing: comingSoon
                      ? const _ComingSoonBadge()
                      : enabled
                          ? const Icon(Icons.chevron_left_rounded)
                          : null,
                  onTap: onTap,
                ),
              );
            }),
          ])),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AsoudColors.warning.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('به‌زودی',
            style: TextStyle(
                fontSize: 10,
                color: AsoudColors.warning,
                fontWeight: FontWeight.w800)),
      );
}
