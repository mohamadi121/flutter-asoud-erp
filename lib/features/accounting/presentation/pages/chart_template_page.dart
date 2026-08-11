import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';

class ChartTemplatePage extends StatefulWidget {
  const ChartTemplatePage(
      {required this.company, required this.repository, super.key});
  final String company;
  final ChartOfAccountsRepository repository;
  @override
  State<ChartTemplatePage> createState() => _ChartTemplatePageState();
}

class _ChartTemplatePageState extends State<ChartTemplatePage> {
  static const template = 'Iran Standard';
  late Future<List<ChartTemplateRow>> preview;
  bool saving = false;
  bool canApply = false;
  String? error;

  @override
  void initState() {
    super.initState();
    preview = loadPreview();
  }

  Future<List<ChartTemplateRow>> loadPreview() async {
    if (mounted) setState(() => canApply = false);
    final rows =
        await widget.repository.previewTemplate(widget.company, template);
    if (mounted) setState(() => canApply = rows.isNotEmpty);
    return rows;
  }

  Future<void> apply() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.applyTemplate(widget.company, template);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'ایجاد سرفصل‌ها در ERPNext انجام نشد و موفقیت ظاهری ثبت نشد.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
            title: 'قالب پیشنهادی سرفصل‌ها',
            subtitle: 'پیش‌نمایش فقط‌خواندنی پیش از ثبت در ERPNext'),
        body: SafeArea(
            child: FutureBuilder<List<ChartTemplateRow>>(
          future: preview,
          builder: (context, snapshot) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _InfoCard(),
              const SizedBox(height: 16),
              const Text('پیش‌نمایش ساختار',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text(
                  'این درخت هنوز ثبت نشده است. گروه، کل و معین را قبل از ایجاد بررسی کنید.',
                  style: TextStyle(fontSize: 9, color: AsoudColors.muted)),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                _ErrorCard(
                    onRetry: () => setState(() => preview = loadPreview()))
              else
                _TemplateTree(rows: snapshot.data ?? const []),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!,
                    style: const TextStyle(color: Colors.red, fontSize: 10)),
              ],
            ],
          ),
        )),
        bottomNavigationBar: AsoudBottomActions(
          primaryLabel: saving ? 'در حال ایجاد...' : 'ایجاد سرفصل‌های پیشنهادی',
          onPrimary: saving || !canApply ? null : apply,
          secondaryLabel: 'انصراف',
          onSecondary: () => Navigator.of(context).pop(),
        ),
      );
}

class _TemplateTree extends StatelessWidget {
  const _TemplateTree({required this.rows});
  final List<ChartTemplateRow> rows;
  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          for (final row in rows)
            Padding(
              padding: EdgeInsets.only(
                  right: row.level == 'Ledger'
                      ? 32
                      : row.level == 'General'
                          ? 16
                          : 0,
                  bottom: 7),
              child: Row(children: [
                Icon(
                    row.level == 'Group'
                        ? Icons.folder_rounded
                        : row.level == 'General'
                            ? Icons.folder_open_rounded
                            : Icons.description_outlined,
                    size: 18,
                    color: row.level == 'Group'
                        ? AsoudColors.primary
                        : AsoudColors.success),
                const SizedBox(width: 7),
                Expanded(child: Text(row.title)),
                Text(row.key,
                    style:
                        const TextStyle(fontSize: 9, color: AsoudColors.muted)),
              ]),
            ),
        ]),
      ));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
          child: ListTile(
        leading:
            const Icon(Icons.cloud_off_rounded, color: AsoudColors.warning),
        title: const Text('دریافت پیش‌نمایش از Backend انجام نشد.'),
        trailing:
            TextButton(onPressed: onRetry, child: const Text('تلاش مجدد')),
      ));
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AsoudColors.primary.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(14)),
        child: const Row(children: [
          AsoudIconBox(
              icon: Icons.visibility_outlined, color: AsoudColors.primary),
          SizedBox(width: 10),
          Expanded(
              child: Text(
                  'پیش‌نمایش ساختار یعنی نمایش فقط‌خواندنی درخت حساب‌ها؛ تا زمان تأیید شما هیچ حسابی ایجاد نمی‌شود.',
                  style: TextStyle(fontSize: 10))),
        ]),
      );
}
