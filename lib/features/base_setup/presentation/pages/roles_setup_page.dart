import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

class RolesSetupPage extends StatefulWidget {
  const RolesSetupPage(
      {this.officeName, this.offlinePreview = false, super.key});

  final String? officeName;
  final bool offlinePreview;

  @override
  State<RolesSetupPage> createState() => _RolesSetupPageState();
}

class _RolesSetupPageState extends State<RolesSetupPage> {
  final selected = <String>{'مدیر سیستم', 'مدیر مالی'};
  static const roles = [
    ('مدیر سیستم', Icons.admin_panel_settings_rounded, Color(0xFF5C6BC0)),
    ('مدیر مالی', Icons.account_balance_rounded, Color(0xFFFFB547)),
    ('حسابدار', Icons.calculate_rounded, Color(0xFF26A69A)),
    ('انباردار', Icons.inventory_2_rounded, Color(0xFFEF6C5B)),
    ('کارشناس فروش', Icons.storefront_rounded, Color(0xFF42A5F5)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AsoudHeader(
          title: 'نقش‌های اولیه', subtitle: 'دسترسی‌های اولیه دفتر'),
      body: SafeArea(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
            const Text('نقش‌های موردنیاز دفتر را انتخاب کنید',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('بعداً از بخش کاربران قابل تغییر است.',
                style: TextStyle(color: AsoudColors.muted)),
            const SizedBox(height: 20),
            ...roles.map((role) => Card(
                  elevation: 0,
                  color: Colors.white,
                  child: CheckboxListTile(
                    value: selected.contains(role.$1),
                    secondary: Icon(role.$2, color: role.$3),
                    title: Text(role.$1),
                    onChanged: role.$1 == 'مدیر سیستم'
                        ? null
                        : (value) => setState(() {
                              value == true
                                  ? selected.add(role.$1)
                                  : selected.remove(role.$1);
                            }),
                  ),
                )),
            const SizedBox(height: 24),
          ])),
      bottomNavigationBar: AsoudBottomActions(
          primaryLabel: 'تکمیل تنظیمات پایه',
          onPrimary: () {
            if (!widget.offlinePreview) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'ذخیره نقش‌ها نیازمند اتصال و پاسخ موفق ERPNext است.',
                  ),
                ),
              );
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'پیش‌نمایش آفلاین؛ تنظیمات روی سرور ذخیره نشده است.',
                ),
                backgroundColor: AsoudColors.warning,
              ),
            );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => DashboardPage(
                  officeName: widget.officeName,
                  offlinePreview: true,
                ),
              ),
              (route) => false,
            );
          }),
    );
  }
}
