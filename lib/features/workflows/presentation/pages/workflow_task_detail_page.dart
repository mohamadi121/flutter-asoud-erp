import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import '../cubit/workflow_task_detail_cubit.dart';

class WorkflowTaskDetailPage extends StatelessWidget {
  const WorkflowTaskDetailPage({required this.task, super.key});
  final String task;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => WorkflowTaskDetailCubit(
            context.read<WorkflowTaskRepository>(), task)
          ..load(),
        child: const _TaskDetailView(),
      );
}

class _TaskDetailView extends StatelessWidget {
  const _TaskDetailView();

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<WorkflowTaskDetailCubit, WorkflowTaskDetailState>(
        listenWhen: (old, current) =>
            old.message != current.message && current.message != null,
        listener: (context, state) => ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.message!))),
        builder: (context, state) {
          final detail = state.detail;
          return Scaffold(
            appBar: AsoudHeader(
              title: detail?.task.title ?? 'جزئیات کار',
              subtitle: detail?.task.instance,
            ),
            body: detail == null
                ? state.status == WorkflowTaskDetailStatus.failure
                    ? Center(
                        child: OutlinedButton.icon(
                          onPressed:
                              context.read<WorkflowTaskDetailCubit>().load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('تلاش دوباره'),
                        ),
                      )
                    : const Center(child: CircularProgressIndicator())
                : Column(children: [
                    if (state.offline) const AsoudOfflinePreviewBanner(),
                    if (state.offline) const _LocalNotice(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        children: [
                          for (final field in detail.fields) ...[
                            _DynamicField(field: field),
                            const SizedBox(height: 12),
                          ],
                          if (detail.activities.isNotEmpty) ...[
                            const Text('تاریخچه اقدامات',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 8),
                            for (final activity in detail.activities)
                              ListTile(
                                leading:
                                    const Icon(Icons.history_rounded, size: 20),
                                title: Text(activity.action),
                                subtitle: Text(activity.actor),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ]),
            bottomNavigationBar: detail == null
                ? null
                : SafeArea(
                    minimum: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              state.status == WorkflowTaskDetailStatus.saving
                                  ? null
                                  : () async {
                                      final done = await context
                                          .read<WorkflowTaskDetailCubit>()
                                          .submit(detail.stageType == 'Approval'
                                              ? 'Approve'
                                              : 'Complete');
                                      if (done && context.mounted) {
                                        Navigator.pop(context, true);
                                      }
                                    },
                          child: Text(detail.stageType == 'Approval'
                              ? 'تأیید و ارسال'
                              : 'ثبت و ارسال'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: state.status ==
                                WorkflowTaskDetailStatus.saving
                            ? null
                            : context.read<WorkflowTaskDetailCubit>().saveDraft,
                        child: const Text('ذخیره پیش‌نویس'),
                      ),
                      if (detail.allowReject || detail.allowReturn) ...[
                        const SizedBox(width: 6),
                        PopupMenuButton<String>(
                          enabled:
                              state.status != WorkflowTaskDetailStatus.saving,
                          tooltip: 'اقدامات بیشتر',
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (action) => context
                              .read<WorkflowTaskDetailCubit>()
                              .submit(action),
                          itemBuilder: (_) => [
                            if (detail.allowReturn)
                              const PopupMenuItem(
                                  value: 'Return',
                                  child: Text('بازگشت برای اصلاح')),
                            if (detail.allowReject)
                              const PopupMenuItem(
                                  value: 'Reject', child: Text('رد درخواست')),
                          ],
                        ),
                      ],
                    ]),
                  ),
          );
        },
      );
}

class _DynamicField extends StatelessWidget {
  const _DynamicField({required this.field});
  final WorkflowFormFieldDefinition field;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkflowTaskDetailCubit>();
    final value = context.select(
        (WorkflowTaskDetailCubit cubit) => cubit.state.values[field.key]);
    final label = '${field.label}${field.required ? ' *' : ''}';
    if (field.type == 'Checkbox') {
      return CheckboxListTile(
        value: value == true,
        title: Text(label),
        onChanged: (next) => cubit.setValue(field.key, next == true),
      );
    }
    if (field.type == 'Choice') {
      return DropdownButtonFormField<String>(
        initialValue: field.options.contains(value) ? value?.toString() : null,
        decoration: InputDecoration(labelText: label),
        items: field.options
            .map((option) => DropdownMenuItem(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis)))
            .toList(growable: false),
        onChanged: (next) => cubit.setValue(field.key, next),
      );
    }
    if (field.type == 'Attachment') {
      return OutlinedButton.icon(
        onPressed: () async {
          final file = await openFile(
            acceptedTypeGroups: const [
              XTypeGroup(
                label: 'اسناد مجاز',
                extensions: ['pdf', 'png', 'jpg', 'jpeg', 'xlsx', 'docx'],
              ),
            ],
          );
          if (file != null && context.mounted) {
            await cubit.setAttachment(
                field.key, file.name, await file.readAsBytes());
          }
        },
        icon: const Icon(Icons.attach_file_rounded),
        label: Text(value == null
            ? label
            : 'فایل انتخاب شد: ${value.toString().split('/').last}'),
      );
    }
    return TextFormField(
      initialValue: value?.toString() ?? '',
      minLines: field.type == 'Long Text' ? 3 : 1,
      maxLines: field.type == 'Long Text' ? 5 : 1,
      keyboardType: {'Number', 'Currency'}.contains(field.type)
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      onChanged: (next) => cubit.setValue(field.key, next),
    );
  }
}

class _LocalNotice extends StatelessWidget {
  const _LocalNotice();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AsoudColors.warning.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'این اطلاعات فقط داخل گوشی ذخیره می‌شود و هنوز در ERPNext ثبت نشده است.',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
}
