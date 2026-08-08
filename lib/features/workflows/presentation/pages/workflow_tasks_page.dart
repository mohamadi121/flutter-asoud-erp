import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import '../cubit/workflow_tasks_cubit.dart';
import 'workflow_task_detail_page.dart';

class WorkflowTasksPage extends StatelessWidget {
  const WorkflowTasksPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            WorkflowTasksCubit(context.read<WorkflowTaskRepository>())..load(),
        child: const _WorkflowTasksView(),
      );
}

class _WorkflowTasksView extends StatelessWidget {
  const _WorkflowTasksView();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
          title: 'کارتابل من',
          subtitle: 'کارهای ارجاع‌شده به شما',
        ),
        body: BlocBuilder<WorkflowTasksCubit, WorkflowTasksState>(
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
              Expanded(
                child: state.tasks.isEmpty
                    ? const _EmptyTasks()
                    : RefreshIndicator(
                        onRefresh: context.read<WorkflowTasksCubit>().load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.tasks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) => _TaskCard(
                            task: state.tasks[index],
                            saving: state.status == WorkflowTasksStatus.saving,
                            onTap: () async {
                              final changed =
                                  await Navigator.of(context).push<bool>(
                                MaterialPageRoute<bool>(
                                  builder: (_) => WorkflowTaskDetailPage(
                                      task: state.tasks[index].id),
                                ),
                              );
                              if (changed == true && context.mounted) {
                                await context.read<WorkflowTasksCubit>().load();
                              }
                            },
                          ),
                        ),
                      ),
              ),
            ]);
          },
        ),
      );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard(
      {required this.task, required this.saving, required this.onTap});
  final WorkflowTask task;
  final bool saving;
  final VoidCallback onTap;

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
          const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('بازکردن فرم',
                style: TextStyle(
                    color: AsoudColors.primary, fontWeight: FontWeight.w700)),
            SizedBox(width: 4),
            Icon(Icons.chevron_left_rounded, color: AsoudColors.primary),
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
          Text('کار بازی در کارتابل شما نیست.',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
