import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';
import 'chart_of_accounts_page.dart';
import 'chart_excel_import_page.dart';
import 'chart_template_page.dart';

class ChartSetupPage extends StatelessWidget {
  const ChartSetupPage({required this.company, super.key});

  final String company;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
          title: 'سرفصل‌های حسابداری',
          subtitle: 'کدینگ حساب‌ها را انتخاب یا ایجاد کنید',
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const _WarningCard(),
              const SizedBox(height: 18),
              _TemplateCard(
                onTap: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => ChartTemplatePage(
                        company: company,
                        repository: context.read<ChartOfAccountsRepository>(),
                      ),
                    ),
                  );
                  if (created == true && context.mounted) _openChart(context);
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _ChoiceCard(
                    icon: Icons.add_rounded,
                    color: AsoudColors.success,
                    title: 'ایجاد دستی',
                    subtitle: 'برای حسابدار حرفه‌ای یا کدینگ اختصاصی',
                    action: 'ایجاد دستی',
                    onTap: () => _openChart(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChoiceCard(
                    icon: Icons.upload_file_rounded,
                    color: AsoudColors.warning,
                    title: 'ورود از اکسل',
                    subtitle: 'از کدینگ حساب‌ها فایل اکسل دارید؟',
                    action: 'انتخاب فایل اکسل',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                        builder: (_) => ChartExcelImportPage(
                          company: company,
                          repository: context.read<ChartOfAccountsRepository>(),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 28),
              const _PreviewHintCard(),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => _openChart(context),
            child: const Text('مشاهده و تکمیل سرفصل‌ها'),
          ),
        ),
      );

  void _openChart(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChartOfAccountsPage(
            company: company,
            repository: context.read<ChartOfAccountsRepository>(),
          ),
        ),
      );
}

class _WarningCard extends StatelessWidget {
  const _WarningCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF0),
          border: Border.all(color: AsoudColors.warning),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(children: [
          AsoudIconBox(
              icon: Icons.priority_high_rounded,
              color: AsoudColors.warning,
              size: 38),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('کدینگ حسابداری هنوز کامل نشده است',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('روش ساخت سرفصل‌ها را انتخاب و اطلاعات را تکمیل کنید.',
                    style: TextStyle(fontSize: 9, color: AsoudColors.muted)),
              ],
            ),
          ),
        ]),
      );
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const AsoudIconBox(
                  icon: Icons.check_rounded,
                  color: AsoudColors.primary,
                  size: 38),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('استفاده از قالب آماده',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('سرفصل پیشنهادی متناسب با الگوی استاندارد ایران',
                        style:
                            TextStyle(fontSize: 9, color: AsoudColors.muted)),
                  ],
                ),
              ),
              const Chip(label: Text('پیشنهادی')),
            ]),
          ),
        ),
      );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.action,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title, subtitle, action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              AsoudIconBox(icon: icon, color: color, size: 38),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 8, color: AsoudColors.muted)),
              const SizedBox(height: 9),
              Text(action,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8, color: color)),
            ]),
          ),
        ),
      );
}

class _PreviewHintCard extends StatelessWidget {
  const _PreviewHintCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AsoudColors.primary.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(children: [
          AsoudIconBox(
              icon: Icons.visibility_outlined,
              color: AsoudColors.primary,
              size: 36),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'برای دیدن ساختار واقعی قالب، «استفاده از قالب آماده» را انتخاب کنید. تا قبل از تأیید شما هیچ حسابی در ERPNext ایجاد نمی‌شود.',
              style: TextStyle(fontSize: 9, color: AsoudColors.muted),
            ),
          ),
        ]),
      );
}
