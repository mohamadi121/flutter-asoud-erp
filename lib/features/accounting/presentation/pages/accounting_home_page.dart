import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import 'chart_of_accounts_page.dart';

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
            ...actions.map((action) => Card(
                  elevation: 0,
                  color: Colors.white,
                  child: ListTile(
                    leading: AsoudIconBox(icon: action.$2, color: action.$3),
                    title: Text(action.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: action.$1 == 'سرفصل حساب‌ها'
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const ChartOfAccountsPage()))
                        : null,
                  ),
                )),
          ])),
    );
  }
}
