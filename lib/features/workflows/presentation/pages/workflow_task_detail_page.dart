import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import '../cubit/workflow_task_detail_cubit.dart';
import '../widgets/request_custom_table.dart';
import '../widgets/request_link_fields.dart';
import '../widgets/workflow_activity_timeline.dart';

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
              title: detail?.task.title.isNotEmpty == true
                  ? persianWorkflowStageTitle(detail!.task.title)
                  : 'جزئیات کار',
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
                          _TaskSummaryCard(rows: _summaryRows(detail)),
                          if (detail.previousData.isNotEmpty) ...[
                            const SizedBox(height: 16),
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
                          if (_technicalValues(detail).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _TechnicalDetailsSection(
                                values: _technicalValues(detail)),
                          ],
                          if (detail.activities.isNotEmpty ||
                              detail.task.status == 'Open') ...[
                            const SizedBox(height: 16),
                            const AsoudSectionTitle(title: 'تاریخچه اقدامات'),
                            WorkflowActivityTimeline(
                              activities: detail.activities,
                              pending: detail.task.status == 'Open',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ]),
            bottomNavigationBar: detail == null || detail.task.status != 'Open'
                ? null
                : _DecisionBar(detail: detail),
          );
        },
      );
}

/// The sticky decision bar. Approve is the primary action; Reject and Return
/// are always visible (never hidden behind a menu) and stay disabled until the
/// user writes the reason they require.
class _DecisionBar extends StatefulWidget {
  const _DecisionBar({required this.detail});
  final WorkflowTaskDetail detail;

  @override
  State<_DecisionBar> createState() => _DecisionBarState();
}

class _DecisionBarState extends State<_DecisionBar> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _hasReason => _reason.text.trim().isNotEmpty;

  Future<void> _decide(String action) async {
    final comment = action == 'Approve' ? null : _reason.text.trim();
    final done = await context
        .read<WorkflowTaskDetailCubit>()
        .submit(action, comment: comment);
    if (done && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.select((WorkflowTaskDetailCubit cubit) =>
        cubit.state.status == WorkflowTaskDetailStatus.saving);
    final detail = widget.detail;
    final approveAction =
        detail.stageType == 'Approval' ? 'Approve' : 'Complete';
    final approveLabel = detail.stageType == 'Approval'
        ? 'تأیید'
        : detail.activityType == 'Review'
            ? 'تأیید بررسی'
            : 'ثبت';

    final buttons = <Widget>[
      FilledButton(
        onPressed: saving || (detail.commentRequired && !_hasReason)
            ? null
            : () => _decide(approveAction),
        child: Text(approveLabel),
      ),
      if (detail.allowReject)
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: AsoudColors.danger,
              foregroundColor: Colors.white),
          onPressed: saving || !_hasReason ? null : () => _decide('Reject'),
          child: const Text('رد'),
        ),
      if (detail.allowReturn)
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: AsoudColors.warning,
              foregroundColor: Colors.white),
          onPressed: saving || !_hasReason ? null : () => _decide('Return'),
          child: const Text('بازگشت'),
        ),
    ];

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _reason,
          enabled: !saving,
          minLines: 1,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'دلیل / توضیح',
            helperText: 'برای رد یا بازگشت، نوشتن دلیل الزامی است.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final sized = [
            for (final button in buttons)
              SizedBox(height: 56, child: button),
          ];
          if (constraints.maxWidth < 360) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < sized.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                sized[i],
              ],
            ]);
          }
          return Row(children: [
            for (var i = 0; i < sized.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: sized[i]),
            ],
          ]);
        }),
        const SizedBox(height: 4),
        TextButton(
          onPressed: saving
              ? null
              : context.read<WorkflowTaskDetailCubit>().saveDraft,
          child: const Text('ذخیره پیش‌نویس'),
        ),
      ]),
    );
  }
}

class _SummaryRow {
  const _SummaryRow(this.label, this.value);
  final String label, value;
}

const _priorityLabels = {
  'Normal': 'عادی',
  'High': 'مهم',
  'Urgent': 'فوری',
};

String _taskStatusLabel(String status) => switch (status) {
      'Open' => 'در انتظار اقدام',
      'Completed' => 'انجام‌شده',
      'Rejected' => 'ردشده',
      'Cancelled' => 'لغوشده',
      _ => status,
    };

String _textValue(dynamic value) {
  final text = _displayValue(value).trim();
  return text == '—' ? '' : text;
}

String? _lookupValue(WorkflowTaskDetail detail, List<String> keys) {
  for (final key in keys) {
    for (final section in detail.previousData) {
      for (final value in section.values) {
        if (value.key == key) {
          final text = _textValue(value.value);
          if (text.isNotEmpty) return text;
        }
      }
    }
  }
  for (final key in keys) {
    for (final value in detail.documentValues) {
      if (value.key == key) {
        final text = _textValue(value.value);
        if (text.isNotEmpty) return text;
      }
    }
  }
  return null;
}

/// The at-most-five summary rows shown at the top of the page. Identifiers,
/// JSON payloads and hashes are deliberately left out.
List<_SummaryRow> _summaryRows(WorkflowTaskDetail detail) {
  final rows = <_SummaryRow>[];
  void add(String label, String? value) {
    final text = value?.trim() ?? '';
    if (text.isNotEmpty) rows.add(_SummaryRow(label, text));
  }

  add(
      'نوع درخواست',
      _lookupValue(detail,
          const ['request_type', 'request_type_title', 'workflow_definition']));
  add(
      'درخواست‌کننده',
      _lookupValue(detail, const [
        'requester',
        'requester_name',
        'owner',
        'started_by',
        'initiator_name',
      ]));
  add('موضوع',
      _lookupValue(detail, const ['subject', 'request_title', 'title']) ??
          (detail.task.title.isEmpty ? null : detail.task.title));
  final assigned = detail.task.assignedOn;
  add('تاریخ', assigned == null ? null : formatDateTimeJalali(assigned));
  final priority = _lookupValue(detail, const ['priority']);
  add(
      'اولویت / وضعیت',
      [
        if (priority != null) _priorityLabels[priority] ?? priority,
        _taskStatusLabel(detail.task.status),
      ].where((value) => value.isNotEmpty).join(' • '));
  return rows.take(5).toList(growable: false);
}

/// Everything the user should not have to read first: the referenced
/// document, its identifiers, JSON payloads and hashes.
List<WorkflowTaskDataValue> _technicalValues(WorkflowTaskDetail detail) => [
      if (detail.referenceName.isNotEmpty)
        WorkflowTaskDataValue(
          key: 'reference',
          label: 'سند مرتبط',
          value:
              '${persianDoctypeLabel(detail.referenceDoctype)} • ${detail.referenceName}',
        ),
      if (detail.task.id.isNotEmpty)
        WorkflowTaskDataValue(
            key: 'task_id', label: 'شناسه کار', value: detail.task.id),
      if (detail.task.instance.isNotEmpty)
        WorkflowTaskDataValue(
            key: 'instance', label: 'شناسه درخواست', value: detail.task.instance),
      for (final value in detail.documentValues)
        if ((value.value?.toString().trim() ?? '').isNotEmpty) value,
    ];

class _TaskSummaryCard extends StatelessWidget {
  const _TaskSummaryCard({required this.rows});
  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AsoudColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 96,
              child: Text(rows[i].label,
                  style: const TextStyle(
                      fontSize: 12, color: AsoudColors.muted)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                rows[i].value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _TechnicalDetailsSection extends StatelessWidget {
  const _TechnicalDetailsSection({required this.values});
  final List<WorkflowTaskDataValue> values;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AsoudColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
            key: const PageStorageKey<String>('technical-details'),
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: const Icon(Icons.data_object_rounded,
                size: 22, color: AsoudColors.muted),
            title: const Text('جزئیات فنی',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('شناسه‌ها، کدها و مقادیر خام سرور',
                style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
            children: [
              for (final value in values) _TechnicalRow(value: value),
            ],
            ),
          ),
        ),
      );
}

class _TechnicalRow extends StatelessWidget {
  const _TechnicalRow({required this.value});
  final WorkflowTaskDataValue value;

  @override
  Widget build(BuildContext context) {
    final text = _rawValue(value.value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(persianDocumentFieldLabel(value.label),
                style:
                    const TextStyle(fontSize: 10, color: AsoudColors.muted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              text,
              textAlign: TextAlign.end,
              textDirection:
                  RegExp(r'^[A-Za-z0-9_\-{}\[\]:".,/@ ]+$').hasMatch(text)
                      ? TextDirection.ltr
                      : null,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
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
          Text(persianWorkflowStageTitle(section.title),
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          const Divider(height: 18),
          for (final item in section.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Text(persianDocumentFieldLabel(item.label),
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

/// Raw server values for the technical section: identifiers, hashes and JSON
/// payloads are shown verbatim, never re-formatted or converted to Persian
/// digits.
String _rawValue(dynamic value) {
  if (value == null || value == '') return '—';
  if (value is DateTime) return formatDateTimeJalali(value);
  return value.toString();
}

String _displayValue(dynamic value) {
  if (value == null || value == '') return '—';
  if (value == true) return 'بله';
  if (value == false) return 'خیر';
  if (value is DateTime) {
    return formatDateTimeJalali(value);
  }
  if (value is num) {
    return formatNumber(value);
  }
  final str = value.toString().trim();
  if (RegExp(r'^\d{4}[-/]\d{2}[-/]\d{2}').hasMatch(str)) {
    final formatted = formatDateTimeJalali(str);
    if (formatted.isNotEmpty) return formatted;
  }
  if (RegExp(r'^[+-]?\d+(?:\.\d+)?$').hasMatch(str)) {
    return formatNumber(str, thousands: false);
  }
  return toPersianDigits(str);
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
    if (field.type == 'Table') {
      final rows = (value as List?)
              ?.whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList() ??
          const <Map<String, dynamic>>[];
      return RequestCustomTable(
          key: ValueKey(field.key),
          field: field,
          enabled: enabled,
          initialValue: rows,
          attachments: [
            for (final row in rows)
              for (final column in field.columns)
                if (column.type == 'Attachment' && row[column.key] is String)
                  row[column.key] as String,
          ],
          uploadAttachment: () async {
            final file = await openFile(acceptedTypeGroups: const [
              XTypeGroup(
                  label: 'اسناد مجاز',
                  extensions: ['pdf', 'png', 'jpg', 'jpeg', 'xlsx', 'docx']),
            ]);
            if (file == null || !context.mounted) return null;
            final bytes = await file.readAsBytes();
            if (!context.mounted || cubit.isClosed) return null;
            return cubit.uploadTableAttachment(file.name, bytes);
          },
          onChanged: (rows) => cubit.setValue(field.key, rows));
    }
    if (field.type == 'Checkbox') {
      return RequestBooleanField(
          label: label,
          initialValue: value is bool ? value : null,
          required: field.required,
          enabled: enabled,
          onChanged: (next) => cubit.setValue(field.key, next));
    }
    if (field.type == 'Date') {
      return AsoudFormDateValue(
          key: ValueKey(field.key),
          value: value?.toString() ?? '',
          label: label,
          enabled: enabled,
          required: field.required,
          onChanged: (next) => cubit.setValue(field.key, next));
    }
    if (field.type == 'Multi Choice') {
      return RequestMultiChoiceField(
          key: ValueKey(field.key),
          label: label,
          options: field.options,
          required: field.required,
          enabled: enabled,
          initialValue: (value as List?)?.cast<String>(),
          onChanged: (next) => cubit.setValue(field.key, next));
    }
    if (field.type == 'Choice') {
      return DropdownButtonFormField<String>(
        isExpanded: true,
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
