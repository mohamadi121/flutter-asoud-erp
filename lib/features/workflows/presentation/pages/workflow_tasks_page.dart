import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import '../cubit/workflow_tasks_cubit.dart';
import '../cubit/workflow_instances_cubit.dart';
import 'workflow_instance_detail_page.dart';
import 'workflow_task_detail_page.dart';

class WorkflowTasksPage extends StatelessWidget {
  const WorkflowTasksPage({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                WorkflowTasksCubit(context.read<WorkflowTaskRepository>())
                  ..load(),
          ),
          BlocProvider(
            create: (_) =>
                WorkflowInstancesCubit(context.read<WorkflowTaskRepository>())
                  ..load(),
          ),
        ],
        child: const _WorkflowTasksView(),
      );
}

class _WorkflowTasksView extends StatefulWidget {
  const _WorkflowTasksView();

  @override
  State<_WorkflowTasksView> createState() => _WorkflowTasksViewState();
}

class _WorkflowTasksViewState extends State<_WorkflowTasksView> {
  String mode = 'inbox';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
          title: 'کارتابل من',
          subtitle: 'کارهای ارجاع‌شده به شما',
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
            child: AsoudSegmentedControl<String>(
              value: mode,
              options: const [
                AsoudSegmentedOption(value: 'inbox', label: 'دریافتی من'),
                AsoudSegmentedOption(value: 'sent', label: 'ارسال‌شده‌های من'),
              ],
              onChanged: (value) => setState(() => mode = value),
            ),
          ),
          Expanded(
            child: mode == 'sent'
                ? const _SentInstances()
                : BlocBuilder<WorkflowTasksCubit, WorkflowTasksState>(
                    builder: (context, state) {
                      if (state.status == WorkflowTasksStatus.loading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state.status == WorkflowTasksStatus.failure &&
                          state.tasks.isEmpty) {
                        return Center(
                          child: OutlinedButton.icon(
                            onPressed: context.read<WorkflowTasksCubit>().load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('تلاش دوباره'),
                          ),
                        );
                      }
                      return Column(children: [
                        if (state.offline) const AsoudOfflinePreviewBanner(),
                        _TaskFilters(
                          selected: state.filter,
                          onChanged: context.read<WorkflowTasksCubit>().load,
                        ),
                        Expanded(
                          child: state.tasks.isEmpty
                              ? const _EmptyTasks()
                              : RefreshIndicator(
                                  onRefresh:
                                      context.read<WorkflowTasksCubit>().load,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: state.tasks.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, index) => _TaskCard(
                                      task: state.tasks[index],
                                      saving: state.status ==
                                          WorkflowTasksStatus.saving,
                                      onTap: () async {
                                        final changed =
                                            await Navigator.of(context)
                                                .push<bool>(
                                          MaterialPageRoute<bool>(
                                            builder: (_) =>
                                                WorkflowTaskDetailPage(
                                                    task:
                                                        state.tasks[index].id),
                                          ),
                                        );
                                        if (changed == true &&
                                            context.mounted) {
                                          await context
                                              .read<WorkflowTasksCubit>()
                                              .load();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                        ),
                      ]);
                    },
                  ),
          ),
        ]),
      );
}

class _SentInstances extends StatelessWidget {
  const _SentInstances();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<WorkflowInstancesCubit, WorkflowInstancesState>(
        builder: (context, state) {
          if (state.status == WorkflowInstancesStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == WorkflowInstancesStatus.failure) {
            return Center(
              child: OutlinedButton.icon(
                onPressed: context.read<WorkflowInstancesCubit>().load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تلاش دوباره'),
              ),
            );
          }
          if (state.instances.isEmpty) {
            return const Center(child: Text('هنوز درخواستی ارسال نکرده‌اید.'));
          }
          return Column(children: [
            if (state.offline) const AsoudOfflinePreviewBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: context.read<WorkflowInstancesCubit>().load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.instances.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (_, index) =>
                      _InstanceCard(item: state.instances[index]),
                ),
              ),
            ),
          ]);
        },
      );
}

class _InstanceCard extends StatelessWidget {
  const _InstanceCard({required this.item});
  final WorkflowInstanceSummary item;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => WorkflowInstanceDetailPage(instance: item.id),
          )),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const AsoudIconBox(
                  icon: Icons.outbox_outlined,
                  color: AsoudColors.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(item.subject,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                Text(_instanceStatus(item.status),
                    style: const TextStyle(
                        fontSize: 9,
                        color: AsoudColors.primary,
                        fontWeight: FontWeight.w800)),
              ]),
              const Divider(height: 20),
              Text(
                  'مرحله فعلی: ${item.currentStageTitle.isEmpty ? 'پایان‌یافته' : item.currentStageTitle}',
                  style: const TextStyle(fontSize: 10)),
              Text(
                'مسئول فعلی: ${item.currentAssignees.isEmpty ? 'بدون مسئول باز' : item.currentAssignees.join('، ')}',
                style: const TextStyle(fontSize: 9, color: AsoudColors.muted),
              ),
            ]),
          ),
        ),
      );
}

String _instanceStatus(String value) => switch (value) {
      'Running' => 'در حال گردش',
      'Completed' => 'تکمیل‌شده',
      'Rejected' => 'ردشده',
      'Cancelled' => 'لغوشده',
      _ => value,
    };

class _TaskFilters extends StatelessWidget {
  const _TaskFilters({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const filters = <(String, String)>[
      ('Open', 'در انتظار من'),
      ('Completed', 'انجام‌شده'),
      ('Rejected', 'ردشده'),
      ('Cancelled', 'لغوشده'),
    ];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final item = filters[index];
          final active = selected == item.$1;
          return ChoiceChip(
            selected: active,
            label: Text(item.$2),
            avatar: active ? const Icon(Icons.check_rounded, size: 16) : null,
            onSelected: (_) => onChanged(item.$1),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard(
      {required this.task, required this.saving, required this.onTap});
  final WorkflowTask task;
  final bool saving;
  final VoidCallback onTap;

  bool get overdue =>
      task.status == 'Open' &&
      task.dueOn != null &&
      task.dueOn!.isBefore(DateTime.now());

  @override
  Widget build(BuildContext context) => InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: saving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AsoudColors.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.assignment_ind_outlined,
                  color: AsoudColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(task.instance,
                      style: const TextStyle(
                          color: AsoudColors.muted, fontSize: 11)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (task.dueOn != null) ...[
            Row(children: [
              Icon(
                  overdue
                      ? Icons.warning_amber_rounded
                      : Icons.schedule_rounded,
                  size: 17,
                  color: overdue ? AsoudColors.danger : AsoudColors.warning),
              const SizedBox(width: 5),
              Text(
                overdue ? 'مهلت انجام گذشته است' : 'دارای مهلت انجام',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: overdue ? AsoudColors.danger : AsoudColors.warning,
                ),
              ),
              const Spacer(),
              Text(
                '${task.dueOn!.toLocal().year}/${task.dueOn!.toLocal().month.toString().padLeft(2, '0')}/${task.dueOn!.toLocal().day.toString().padLeft(2, '0')} '
                '${task.dueOn!.toLocal().hour.toString().padLeft(2, '0')}:${task.dueOn!.toLocal().minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 9, color: AsoudColors.muted),
              ),
            ]),
            const SizedBox(height: 10),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(task.status == 'Open' ? 'بررسی درخواست' : 'مشاهده جزئیات',
                style: TextStyle(
                    color: AsoudColors.primary, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left_rounded, color: AsoudColors.primary),
          ]),
        ]),
      ));
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.task_alt_rounded, size: 54, color: AsoudColors.success),
          SizedBox(height: 12),
          Text('کاری با این وضعیت در کارتابل شما نیست.',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
