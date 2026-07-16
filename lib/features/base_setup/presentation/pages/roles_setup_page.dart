import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

class RolesSetupPage extends StatefulWidget {
  const RolesSetupPage({super.key});

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
      appBar: AppBar(title: const Text('نقش‌های اولیه')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('نقش‌های موردنیاز دفتر را انتخاب کنید', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('بعداً از بخش کاربران قابل تغییر است.', style: TextStyle(color: AsoudColors.muted)),
        const SizedBox(height: 20),
        ...roles.map((role) => Card(
          elevation: 0,
          color: Colors.white,
          child: CheckboxListTile(
            value: selected.contains(role.$1),
            secondary: Icon(role.$2, color: role.$3),
            title: Text(role.$1),
            onChanged: role.$1 == 'مدیر سیستم' ? null : (value) => setState(() { value == true ? selected.add(role.$1) : selected.remove(role.$1); }),
          ),
        )),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تنظیمات پایه ذخیره شد.'), backgroundColor: AsoudColors.success),
            );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const DashboardPage()),
              (route) => false,
            );
          },
          child: const Text('تکمیل تنظیمات پایه'),
        ),
      ])),
    );
  }
}
