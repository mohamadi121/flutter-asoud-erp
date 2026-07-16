import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import 'chart_of_accounts_page.dart';
import '../../../parties/presentation/pages/floating_details_page.dart';
import '../../../parties/presentation/pages/parties_page.dart';
import '../../../parties/presentation/pages/account_mapping_page.dart';

class AccountingHomePage extends StatelessWidget {
  const AccountingHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const actions = [
      ('سند حسابداری', Icons.receipt_long_rounded, Color(0xFFFFB547)),
      ('سرفصل حساب‌ها', Icons.account_tree_rounded, Color(0xFF5C6BC0)),
      ('تراز آزمایشی', Icons.balance_rounded, Color(0xFF26A69A)),
      ('دفتر کل', Icons.menu_book_rounded, Color(0xFF42A5F5)),
      ('مرور حساب‌ها', Icons.manage_search_rounded, Color(0xFFEF6C5B)),
      ('گزارش‌های مالی', Icons.analytics_rounded, Color(0xFF7E57C2)),
      ('تفصیلی‌های شناور', Icons.hub_rounded, Color(0xFF008291)),
      ('اشخاص و طرف‌حساب‌ها', Icons.groups_rounded, Color(0xFF690C36)),
      ('اتصال معین به تفصیلی', Icons.link_rounded, Color(0xFF1D5B79)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('حسابداری')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('حسابداری تعهدی', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const Text('مبتنی بر استانداردهای حسابداری ایران', style: TextStyle(color: AsoudColors.muted)),
        const SizedBox(height: 22),
        ...actions.map((action) => Card(
          elevation: 0,
          color: Colors.white,
          child: ListTile(
            leading: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: action.$3.withValues(alpha: .13), borderRadius: BorderRadius.circular(12)), child: Icon(action.$2, color: action.$3)),
            title: Text(action.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: switch (action.$1) {
              'سرفصل حساب‌ها' => () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ChartOfAccountsPage())),
              'تفصیلی‌های شناور' => () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FloatingDetailsPage())),
              'اشخاص و طرف‌حساب‌ها' => () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PartiesPage())),
              'اتصال معین به تفصیلی' => () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountMappingPage())),
              _ => null,
            },
          ),
        )),
      ])),
    );
  }
}
