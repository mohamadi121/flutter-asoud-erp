import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../form_builder/form_repository.dart';
import '../../../form_builder/form_runtime/form_fields_view.dart';
import '../../data/workflow_action_repository.dart';
import '../../domain/entities/workflow_task.dart';
import '../cubit/workflow_task_detail_cubit.dart';
import 'user_action_reassignment_picker.dart';

class UserActionExecution extends StatefulWidget {
  const UserActionExecution({required this.detail, super.key});
  final WorkflowTaskDetail detail;
  @override
  State<UserActionExecution> createState() => _UserActionExecutionState();
}

class _UserActionExecutionState extends State<UserActionExecution> {
  final keyForm = GlobalKey<FormState>();
  bool uploading = false;
  late final repository = WorkflowActionRepository(
      context.read<FrappeApiClient>(),
      widget.detail.actionCompany,
      widget.detail.task.id,
      uploads: widget.detail.allowAddAttachments, onUploadChanged: (value) {
    if (mounted) setState(() => uploading = value);
  });
  Future<void> submit(String action) async {
    if (action != 'Claim' && keyForm.currentState?.validate() != true) return;
    final cubit = context.read<WorkflowTaskDetailCubit>();
    if ({'Follow Up', 'Blocked'}.contains(action) &&
        '${cubit.state.values['action_note'] ?? ''}'.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('علت پیگیری یا مانع انجام را وارد کنید.')));
      return;
    }
    final done = await cubit.performAction(action);
    if (done && action == 'Complete' && mounted) Navigator.pop(context, true);
  }

  Future<void> reassign() async {
    final user = await showModalBottomSheet<String>(context: context,
        isScrollControlled: true, useSafeArea: true, showDragHandle: true,
        builder: (_) => UserActionReassignmentPicker(repository: repository));
    if (user == null || !mounted) return;
    final done = await context.read<WorkflowTaskDetailCubit>().reassign(user);
    if (done && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<WorkflowTaskDetailCubit, WorkflowTaskDetailState>(
          builder: (_, state) {
        final detail = widget.detail;
        final open = detail.task.status == 'Open';
        final saving =
            state.status == WorkflowTaskDetailStatus.saving || uploading;
        final outcome = '${state.values['action_result'] ?? 'done'}';
        final schema = copyForm(detail.actionSchema);
        final hasOutcome = formMaps(schema['sections']).any((section) =>
            formMaps(section['fields']).any((field) => field['key'] == 'action_result'));
        if (detail.actionMode == 'Simple' && hasOutcome) {
          // Requiredness is also enforced independently by the server.
          schema['sections'] = [
            for (final section in formMaps(schema['sections']))
              {
                ...section,
                'fields': [
                  for (final field in formMaps(section['fields']))
                    {
                      ...field,
                      if (field['key'] == 'action_note')
                        'required': outcome != 'done'
                    }
                ]
              }
          ];
        }
        final action = detail.actionMode != 'Simple' || !hasOutcome || outcome == 'done'
            ? 'Complete'
            : outcome == 'follow_up'
                ? 'Follow Up'
                : 'Blocked';
        return Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('ثبت نتیجه اقدام',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      if (detail.requiresClaim) ...[
                        const Text(
                            'این اقدام در صف مشترک است. برای ثبت نتیجه، ابتدا آن را دریافت کنید.'),
                        FilledButton.icon(
                            onPressed: saving ? null : () => submit('Claim'),
                            icon: const Icon(Icons.touch_app_outlined),
                            label: Text(
                                saving ? 'در حال دریافت…' : 'دریافت اقدام')),
                      ] else ...[
                        Form(
                            key: keyForm,
                            child: FormFieldsView(
                                schema: schema,
                                values: state.values,
                                enabled: open && !saving,
                                snapshot: !open,
                                onChanged: context
                                    .read<WorkflowTaskDetailCubit>()
                                    .setValues,
                                repository: repository,
                                formName: detail.actionForm)),
                        if (open) ...[
                          FilledButton(
                              onPressed: saving ? null : () => submit(action),
                              child: Text(saving
                                  ? 'در حال ثبت…'
                                  : switch (action) {
                                      'Follow Up' => 'ثبت وضعیت اقدام',
                                      'Blocked' => 'ثبت مانع انجام',
                                      _ => 'ثبت و تکمیل وظیفه'
                                    })),
                          if (detail.allowDraft)
                            OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : context
                                        .read<WorkflowTaskDetailCubit>()
                                        .saveDraft,
                                child: const Text('ذخیره پیش‌نویس')),
                          if (detail.allowReassign)
                            TextButton.icon(onPressed: saving ? null : reassign,
                                icon: const Icon(Icons.person_add_alt_outlined),
                                label: const Text('واگذاری مجدد')),
                        ],
                      ],
                    ])));
      });
}
