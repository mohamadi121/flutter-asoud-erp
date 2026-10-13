import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import '../pages/workflow_task_detail_page.dart';
import '../pages/workflow_tasks_page.dart';

/// A read-only window onto the real inbox; no second task store or action engine.
class HomeInboxSummary extends StatefulWidget {
  const HomeInboxSummary({this.repository, this.now, super.key});
  final WorkflowTaskRepository? repository;
  final DateTime? now;
  @override
  State<HomeInboxSummary> createState() => _HomeInboxSummaryState();
}

class _HomeInboxSummaryState extends State<HomeInboxSummary> {
  late final repository =
      widget.repository ?? context.read<WorkflowTaskRepository?>();
  late Future<List<WorkflowTask>> future = _load();
  Future<List<WorkflowTask>> _load() async {
    if (repository == null) {
      throw StateError('کارتابل در این محیط در دسترس نیست.');
    }
    return repository!.getMyTasks();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => future = next);
    await next.catchError((Object _) => <WorkflowTask>[]);
  }

  Future<void> _open([WorkflowTask? task]) async {
    if (repository == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => RepositoryProvider<WorkflowTaskRepository>.value(
                value: repository!,
                child: task == null
                    ? const WorkflowTasksPage()
                    : WorkflowTaskDetailPage(task: task.id))));
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const AsoudIconBox(
                  icon: Icons.assignment_late_outlined,
                  color: AsoudColors.warning,
                  size: 34),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('نیازمند اقدام من',
                      style: TextStyle(fontWeight: FontWeight.w800))),
              TextButton(
                  onPressed: repository == null ? null : () => _open(),
                  child: const Text('مشاهده همه'))
            ]),
            FutureBuilder<List<WorkflowTask>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return TextButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: Text(repository == null
                            ? 'کارتابل در این محیط در دسترس نیست.'
                            : failureMessage(snapshot.error!)));
                  }
                  final rows = (snapshot.data ?? [])
                      .where((t) => t.status == 'Open')
                      .toList();
                  final now = widget.now ?? DateTime.now();
                  final overdue =
                      rows.where((t) => t.dueOn?.isBefore(now) == true).length;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (repository!.isOfflinePreview)
                          const Text('پیش‌نمایش آفلاین · داده نمونه/محلی',
                              style: TextStyle(
                                  fontSize: 11, color: AsoudColors.warning)),
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          Chip(
                              label: Text(
                                  'باز: ${toPersianDigits(rows.length)}${rows.length >= 200 ? '+' : ''}')),
                          Chip(
                              backgroundColor: AsoudColors.dangerSurface,
                              label: Text('معوق: ${toPersianDigits(overdue)}')),
                          const Tooltip(
                              message:
                                  'API فعلی کارتابل اولویت را ارائه نمی‌کند.',
                              child: Chip(label: Text('فوری: —'))),
                        ]),
                        if (rows.length >= 200)
                          const Text('خلاصه بر اساس موارد دریافت‌شده است.',
                              style: TextStyle(fontSize: 11)),
                        if (rows.isEmpty)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                  'در حال حاضر اقدام بازی در کارتابل شما نیست.')),
                        // Preserve the inbox's server order instead of inventing a ranking.
                        for (final task in rows.take(3))
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              onTap: () => _open(task),
                              leading: AsoudIconBox(
                                  icon: task.dueOn?.isBefore(now) == true
                                      ? Icons.warning_amber_rounded
                                      : Icons.task_alt,
                                  color: task.dueOn?.isBefore(now) == true
                                      ? AsoudColors.danger
                                      : AsoudColors.primary,
                                  size: 34),
                              title: Text(task.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  task.dueOn == null
                                      ? 'باز · بدون مهلت'
                                      : '${task.dueOn!.isBefore(now) ? 'معوق' : 'مهلت'}: ${formatJalaliDateTimeIso(task.dueOn!.toIso8601String())}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: task.dueOn?.isBefore(now) == true
                                          ? AsoudColors.danger
                                          : AsoudColors.muted)),
                              trailing:
                                  const Icon(Icons.chevron_left, size: 18)),
                      ]);
                }),
          ])));
}
