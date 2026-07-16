import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../accounting/presentation/pages/accounting_home_page.dart';
import '../../domain/entities/erp_module.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const modules = [
    ErpModule(title: 'حسابداری', icon: Icons.account_balance_rounded, color: Color(0xFFFFB547)),
    ErpModule(title: 'خرید', icon: Icons.shopping_cart_checkout_rounded, color: Color(0xFF7E57C2)),
    ErpModule(title: 'فروش', icon: Icons.point_of_sale_rounded, color: Color(0xFF42A5F5)),
    ErpModule(title: 'انبار', icon: Icons.inventory_2_rounded, color: Color(0xFFEF6C5B)),
    ErpModule(title: 'دارایی ثابت', icon: Icons.domain_rounded, color: Color(0xFF26A69A)),
    ErpModule(title: 'خزانه', icon: Icons.account_balance_wallet_rounded, color: Color(0xFF5C6BC0)),
    ErpModule(title: 'فروش مویرگی', icon: Icons.route_rounded, color: Color(0xFFEC407A)),
    ErpModule(title: 'مکاتبات داخلی', icon: Icons.mark_email_read_rounded, color: Color(0xFF78909C)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('آسود ERP'),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('سلام، خوش آمدید', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text('دفتر فعال: ${AppConfig.companyName}', style: const TextStyle(color: AsoudColors.muted)),
            const SizedBox(height: 22),
            const _SummaryCard(),
            const SizedBox(height: 24),
            const Text('ماژول‌ها', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.55,
              ),
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];
                return _ModuleCard(
                  module: module,
                  onTap: module.title == 'حسابداری'
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const AccountingHomePage()),
                          )
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('ماژول ${module.title} در مرحله بعد تکمیل می‌شود.')),
                          ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline_rounded), label: 'ثبت سریع'),
          NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'بیشتر'),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AsoudColors.primary, AsoudColors.primaryDark]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('وضعیت امروز', style: TextStyle(color: Colors.white70)),
          SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _SummaryValue(label: 'اسناد پیش‌نویس', value: '۰'),
            _SummaryValue(label: 'مطالبات سررسید', value: '۰'),
            _SummaryValue(label: 'پرداخت‌های امروز', value: '۰'),
          ]),
        ]),
      );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]);
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onTap});
  final ErpModule module;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border.all(color: AsoudColors.border), borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: module.color.withValues(alpha: .13), borderRadius: BorderRadius.circular(13)), child: Icon(module.icon, color: module.color)),
              const SizedBox(width: 10),
              Expanded(child: Text(module.title, style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      );
}

