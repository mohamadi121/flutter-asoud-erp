import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/entities/workflow_task.dart';
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
                          _TaskTypeCard(detail: detail),
                          if (detail.documentValues.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _ReferencedDocumentCard(detail: detail),
                          ],
                          if (detail.previousData.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const AsoudSectionTitle(
                                title: 'اطلاعات ثبت‌شده مراحل قبل'),
                            for (final section in detail.previousData) ...[
                              _PreviousDataCard(section: section),
                              const SizedBox(height: 10),
                            ],
                          ],
                          if (detail.fields.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            const AsoudSectionTitle(title: 'اطلاعات این مرحله'),
                          ],
                          for (final field in detail.fields) ...[
                            _DynamicField(
                              field: field,
                              enabled: detail.task.status == 'Open',
                            ),
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
                                subtitle: Text([
                                  activity.actor,
                                  if (activity.comment.isNotEmpty)
                                    activity.comment,
                                ].join('\n')),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ]),
            bottomNavigationBar: detail == null || detail.task.status != 'Open'
                ? null
                : SafeArea(
                    minimum: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: state.status ==
                                  WorkflowTaskDetailStatus.saving
                              ? null
                              : () async {
                                  final action = detail.stageType == 'Approval'
                                      ? 'Approve'
                                      : 'Complete';
                                  final done = await _submitAction(
                                      context, detail, action);
                                  if (done && context.mounted) {
                                    Navigator.pop(context, true);
                                  }
                                },
                          child: Text(detail.stageType == 'Approval'
                              ? 'تأیید و ارسال'
                              : detail.activityType == 'Review'
                                  ? 'تأیید بررسی و ارسال'
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
                          onSelected: (action) =>
                              _submitAction(context, detail, action),
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

  Future<bool> _submitAction(
      BuildContext context, WorkflowTaskDetail detail, String action) async {
    final needsComment = action == 'Return' ||
        action == 'Reject' ||
        (action == 'Approve' && detail.commentRequired);
    String? comment;
    if (needsComment) {
      comment = await showDialog<String>(
        context: context,
        builder: (_) => _DecisionDialog(
          action: action,
          isRequired: action == 'Return' || detail.commentRequired,
        ),
      );
      if (comment == null || !context.mounted) return false;
    }
    return context
        .read<WorkflowTaskDetailCubit>()
        .submit(action, comment: comment);
  }
}

class _ReferencedDocumentCard extends StatelessWidget {
  const _ReferencedDocumentCard({required this.detail});
  final WorkflowTaskDetail detail;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AsoudColors.primary.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const AsoudIconBox(
              icon: Icons.description_outlined,
              color: AsoudColors.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اطلاعات درخواست اصلی',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  Text('${detail.referenceDoctype} • ${detail.referenceName}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 9, color: AsoudColors.muted)),
                ],
              ),
            ),
          ]),
          const Divider(height: 22),
          for (final value in detail.documentValues)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(value.label,
                        style: const TextStyle(
                            fontSize: 10, color: AsoudColors.muted)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(value.value?.toString() ?? '—',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
        ]),
      );
}

class _TaskTypeCard extends StatelessWidget {
  const _TaskTypeCard({required this.detail});
  final WorkflowTaskDetail detail;

  @override
  Widget build(BuildContext context) {
    final approval = detail.stageType == 'Approval';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (approval ? AsoudColors.purple : AsoudColors.primary)
            .withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AsoudColors.border),
      ),
      child: Row(children: [
        AsoudIconBox(
          icon: approval ? Icons.approval_outlined : Icons.fact_check_outlined,
          color: approval ? AsoudColors.purple : AsoudColors.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(approval ? 'مرحله تأیید' : 'مرحله بررسی و انجام کار',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(
                approval
                    ? 'اطلاعات مراحل قبل را بررسی و تصمیم خود را ثبت کنید.'
                    : 'اطلاعات ثبت‌شده را بررسی و موارد این مرحله را تکمیل کنید.',
                style: const TextStyle(fontSize: 10, color: AsoudColors.muted),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _PreviousDataCard extends StatelessWidget {
  const _PreviousDataCard({required this.section});
  final WorkflowTaskDataSection section;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(section.title,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          const Divider(height: 18),
          for (final item in section.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Text(item.label,
                        style: const TextStyle(
                            fontSize: 10, color: AsoudColors.muted))),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(_displayValue(item.value),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800))),
              ]),
            ),
        ]),
      );
}

class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog({required this.action, required this.isRequired});
  final String action;
  final bool isRequired;

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final controller = TextEditingController();
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final returning = widget.action == 'Return';
    final rejecting = widget.action == 'Reject';
    return AlertDialog(
      title: Text(returning
          ? 'بازگشت برای اصلاح'
          : rejecting
              ? 'رد درخواست'
              : 'ثبت تأیید'),
      content: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 5,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.isRequired ? 'توضیحات *' : 'توضیحات',
          hintText: returning ? 'مواردی که باید اصلاح شوند را بنویسید.' : null,
          errorText: error,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف')),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (widget.isRequired && value.isEmpty) {
              setState(() => error = 'ثبت توضیحات الزامی است.');
              return;
            }
            Navigator.pop(context, value);
          },
          child: const Text('ثبت تصمیم'),
        ),
      ],
    );
  }
}

String _displayValue(dynamic value) {
  if (value == null || value == '') return '—';
  if (value == true) return 'بله';
  if (value == false) return 'خیر';
  return value.toString();
}

class _DynamicField extends StatelessWidget {
  const _DynamicField({required this.field, required this.enabled});
  final WorkflowFormFieldDefinition field;
  final bool enabled;

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
        onChanged:
            enabled ? (next) => cubit.setValue(field.key, next == true) : null,
      );
    }
    if (field.type == 'Choice') {
      return DropdownButtonFormField<String>(
        initialValue: field.options.contains(value) ? value?.toString() : null,
        decoration: InputDecoration(labelText: label),
        disabledHint: Text(value?.toString() ?? ''),
        items: field.options
            .map((option) => DropdownMenuItem(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis)))
            .toList(growable: false),
        onChanged: enabled ? (next) => cubit.setValue(field.key, next) : null,
      );
    }
    if (field.type == 'Attachment') {
      return OutlinedButton.icon(
        onPressed: enabled
            ? () async {
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
              }
            : null,
        icon: const Icon(Icons.attach_file_rounded),
        label: Text(value == null
            ? label
            : 'فایل انتخاب شد: ${value.toString().split('/').last}'),
      );
    }
    return TextFormField(
      enabled: enabled,
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
          'این اطلاعات فقط داخل گوشی ذخیره شده و هنوز در ASOUD ERP همگام نشده است.',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
}
