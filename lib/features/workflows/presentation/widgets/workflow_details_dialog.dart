import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../domain/entities/workflow_definition.dart';

/// Read-only saved-design details. Returning true opens the existing stage page.
class WorkflowDetailsDialog extends StatefulWidget {
  const WorkflowDetailsDialog({required this.load, super.key});
  final Future<WorkflowDesign> Function() load;

  @override
  State<WorkflowDetailsDialog> createState() => _WorkflowDetailsDialogState();
}

class _WorkflowDetailsDialogState extends State<WorkflowDetailsDialog> {
  late Future<WorkflowDesign> _future;

  @override
  void initState() {
    super.initState();
    _future = Future.sync(widget.load);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    key: const ValueKey('workflow-details-dialog'),
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
    backgroundColor: AsoudColors.background,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: AsoudColors.border)),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 500, maxHeight: MediaQuery.sizeOf(context).height * .9),
      child: Padding(padding: const EdgeInsets.all(8), child: Card(
        margin: EdgeInsets.zero,
        color: AsoudColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: FutureBuilder<WorkflowDesign>(future: _future, builder: (context, snapshot) {
          final design = snapshot.data;
          final summary = design?.detailsSummary;
          final incomplete = design?.workflow.status == WorkflowDefinitionStatus.inactive &&
              (summary?.needsCompletion ?? design?.workflow.isLocked ?? false);
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 8), child: Row(textDirection: TextDirection.ltr, children: [
              const Expanded(child: Text('جزئیات گردش‌کار',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AsoudColors.text))),
              IconButton(tooltip: 'بستن', onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFF4F5F7)),
                  icon: const Icon(Icons.close_rounded, color: AsoudColors.muted)),
            ])),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 14),
              child: snapshot.hasError
                  ? ErrorState(failure: snapshot.error!, onRetry: () => setState(() {
                      _future = Future.sync(widget.load);
                    }))
                  : design == null
                      ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
                      : _DetailsBody(design: design),
            )),
            Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (design != null) ...[
                  FilledButton.icon(onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF171717),
                        foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46),
                        shape: const StadiumBorder()),
                    icon: const Icon(Icons.account_tree_outlined, size: 20),
                    label: Text(incomplete ? 'طراحی مراحل' : 'مشاهده مراحل')),
                  const SizedBox(height: 8),
                ],
                OutlinedButton(onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44),
                        foregroundColor: AsoudColors.muted,
                        side: const BorderSide(color: AsoudColors.border), shape: const StadiumBorder()),
                    child: const Text('بستن')),
              ],
            )),
          ]);
        }),
      )),
    ),
  );
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.design});
  final WorkflowDesign design;

  String _relatedTitle() {
    for (final stage in design.stages) {
      final source = stage.config['submission_source'];
      if (source is Map && source['title'] is String && (source['title'] as String).trim().isNotEmpty) {
        return source['title'] as String;
      }
    }
    final label = persianDoctypeLabel(design.workflow.targetDoctype);
    return RegExp(r'[\u0600-\u06ff]').hasMatch(label) ? label : 'عنوان فارسی نوع سند در دسترس نیست';
  }

  String _requirement(String value) {
    if (value == 'تنظیمات یا مسیر خروج یکی از مراحل کامل و معتبر نیست.') {
      final summary = design.detailsSummary!;
      if (summary.routesComplete) return 'تکمیل تنظیمات مراحل گردش‌کار';
      if (summary.stagesComplete) return 'تعیین مسیرهای خروجی مراحل';
      return 'تکمیل تنظیمات مراحل و مسیرهای خروجی';
    }
    final label = persianServerMessage(value);
    if (RegExp(r'Frappe|ERPNext|ASOUD|Traceback', caseSensitive: false).hasMatch(label) ||
        !RegExp(r'[\u0600-\u06ff]').hasMatch(label)) {
      return 'برای تکمیل این مورد، تنظیمات مراحل را بررسی کنید.';
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final workflow = design.workflow;
    final summary = design.detailsSummary;
    final pending = workflow.status == WorkflowDefinitionStatus.inactive &&
        (summary?.needsCompletion ?? workflow.isLocked);
    final (label, color, surface) = pending
        ? (summary == null ? 'نیازمند بررسی' : 'نیازمند تکمیل', AsoudColors.warning, AsoudColors.warningSurface)
        : switch (workflow.status) {
            WorkflowDefinitionStatus.active => ('فعال', AsoudColors.success, AsoudColors.successSurface),
            WorkflowDefinitionStatus.inactive => ('غیرفعال', AsoudColors.muted, AsoudColors.border),
            WorkflowDefinitionStatus.archived => ('آرشیو', AsoudColors.purple, const Color(0xFFF1E8FD)),
          };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 14),
      Row(textDirection: TextDirection.ltr, crossAxisAlignment: CrossAxisAlignment.start, children: [
        AsoudIconBox(icon: pending ? Icons.pending_actions_outlined : Icons.account_tree_outlined,
            color: color, size: 54),
        const SizedBox(width: 12),
        Expanded(child: Column(textDirection: TextDirection.ltr, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(workflow.title, textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(workflow.code, key: const ValueKey('workflow-details-code'),
              textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12, color: AsoudColors.muted)),
        ])),
      ]),
      Align(alignment: Alignment.centerLeft, child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
        child: Text(label, key: const ValueKey('workflow-details-status'),
            style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      )),
      const Divider(color: AsoudColors.border),
      _row('نسخه', toPersianDigits(workflow.version)),
      _row('درخواست / سند مرتبط', _relatedTitle()),
      _row('تعداد مراحل', toPersianDigits(summary?.stepsCount ?? design.stages.where(
          (stage) => stage.type != WorkflowStageType.start).length)),
      _row('مراحل گردش‌کار', summary == null ? 'بررسی نشده' : summary.stagesComplete ? 'تکمیل شده' : 'تکمیل نشده'),
      _row('مسیرهای خروجی', summary == null ? 'بررسی نشده' : summary.routesComplete ? 'تکمیل شده' : 'تکمیل نشده'),
      if (summary == null)
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text(
            'گزارش بررسی مراحل و مسیرها از سرور دریافت نشد؛ کامل یا ناقص بودن آن‌ها تأیید نشده است.',
            style: TextStyle(color: AsoudColors.muted, height: 1.7))),
      if (summary != null && summary.requirements.isNotEmpty) Container(
        margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AsoudColors.warningSurface.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(textDirection: TextDirection.ltr, children: [Icon(Icons.error_outline_rounded, color: AsoudColors.warning, size: 22),
            SizedBox(width: 8), Expanded(child: Text('موارد نیازمند تکمیل',
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AsoudColors.warning)))]),
          for (final requirement in summary.requirements.map(_requirement).toSet())
            Padding(padding: const EdgeInsets.only(top: 10), child: Row(textDirection: TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [const Padding(padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle, size: 10, color: AsoudColors.warning)), const SizedBox(width: 8),
                Expanded(child: Text(requirement, textAlign: TextAlign.left, style: const TextStyle(height: 1.7)))])),
        ]),
      ),
    ]);
  }

  Widget _row(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AsoudColors.border))),
    child: Row(textDirection: TextDirection.ltr, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(label, textAlign: TextAlign.left,
          style: const TextStyle(fontSize: 12, color: AsoudColors.text))),
      const SizedBox(width: 12),
      Expanded(child: Text(value, textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, color: AsoudColors.muted))),
    ]),
  );
}
