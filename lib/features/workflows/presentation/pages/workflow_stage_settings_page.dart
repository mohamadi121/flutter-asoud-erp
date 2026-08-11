import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_definition.dart';
import '../cubit/workflow_designer_cubit.dart';

class WorkflowStageSettingsPage extends StatefulWidget {
  const WorkflowStageSettingsPage({
    required this.stage,
    required this.roles,
    this.departments = const [],
    this.employees = const [],
    super.key,
  });

  final WorkflowStage stage;
  final List<String> roles;
  final List<WorkflowTargetOption> departments, employees;

  @override
  State<WorkflowStageSettingsPage> createState() =>
      _WorkflowStageSettingsPageState();
}

class _WorkflowStageSettingsPageState extends State<WorkflowStageSettingsPage> {
  late final TextEditingController title;
  late final TextEditingController details;
  late final TextEditingController value;
  String function = 'Review';
  String assignmentType = 'Role';
  String accessMode = 'Read Only';
  String secondary = '';
  bool allowReject = true;
  bool allowReturn = true;
  bool commentRequired = false;
  Set<String> selected = {};
  List<WorkflowFieldOption> fields = const [];
  bool loadingFields = false;

  Map<String, dynamic> get config => widget.stage.config;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.stage.title);
    details = TextEditingController(
      text: (config['instructions'] ??
              config['message'] ??
              config['result_label'] ??
              '')
          .toString(),
    );
    value = TextEditingController(
      text: (config['compare_value'] ?? config['wait_value'] ?? '').toString(),
    );
    assignmentType = config['assignment_type']?.toString() ?? 'Role';
    accessMode = config['document_access']?.toString() ?? 'Read Only';
    allowReject = config['allow_reject'] != false;
    allowReturn = config['allow_return'] != false;
    commentRequired = config['comment_required'] == true;
    _initializeType();
    _loadSelected();
    if (widget.stage.type == WorkflowStageType.condition) _loadFields();
  }

  void _initializeType() {
    switch (widget.stage.type) {
      case WorkflowStageType.userTask:
        function = config['activity_type']?.toString() ?? 'Review';
      case WorkflowStageType.approval:
        function = config['approval_mode']?.toString() ?? 'Any';
      case WorkflowStageType.condition:
        function = config['source_field']?.toString() ?? '';
        secondary = config['operator']?.toString() ?? 'Equals';
      case WorkflowStageType.systemAction:
        assignmentType = 'Role';
        function = config['action_type']?.toString() ?? 'Send Notification';
      case WorkflowStageType.wait:
        function = config['wait_type']?.toString() ?? 'Duration';
        secondary = config['wait_unit']?.toString() ?? 'Day';
      case WorkflowStageType.end:
        function = config['outcome']?.toString() ?? 'Completed';
      case WorkflowStageType.start:
        break;
    }
  }

  void _loadSelected() {
    final prefix = widget.stage.type == WorkflowStageType.approval
        ? 'approver'
        : widget.stage.type == WorkflowStageType.systemAction
            ? 'target'
            : 'assignee';
    final key = assignmentType == 'Department'
        ? '${prefix}_departments'
        : assignmentType == 'Employee'
            ? '${prefix}_employees'
            : '${prefix}_roles';
    selected = ((config[key] as List?) ?? const [])
        .map((item) => item.toString())
        .toSet();
  }

  Future<void> _loadFields() async {
    setState(() => loadingFields = true);
    try {
      fields = await context.read<WorkflowDesignerCubit>().conditionFields();
      if (function.isEmpty && fields.isNotEmpty) function = fields.first.name;
    } finally {
      if (mounted) setState(() => loadingFields = false);
    }
  }

  @override
  void dispose() {
    title.dispose();
    details.dispose();
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AsoudHeader(
          title: 'تنظیمات مرحله',
          subtitle: 'عملکرد، مسئول و تصمیم‌های این مرحله را مشخص کنید',
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 116),
          children: [
            const _Notice(
              text:
                  'اطلاعات در سند اصلی ثبت می‌شوند؛ اینجا فقط نحوه گردش آن تعیین می‌شود.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'عنوان مرحله *',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 14),
            ..._fieldsForType(),
          ],
        ),
        bottomNavigationBar: AsoudBottomActions(
          primaryLabel: 'ذخیره مرحله',
          onPrimary: _save,
          secondaryLabel: 'انصراف',
          onSecondary: () => Navigator.pop(context),
        ),
      );

  List<Widget> _fieldsForType() => switch (widget.stage.type) {
        WorkflowStageType.userTask => [
            _dropdown(
                'عملکرد این مرحله',
                function,
                const {
                  'Review': 'بررسی و تصمیم‌گیری',
                  'Correction': 'اصلاح درخواست',
                  'Task': 'انجام یا پیگیری کار',
                },
                (next) => function = next),
            const SizedBox(height: 14),
            _ownerFields('مسئول مرحله'),
            const SizedBox(height: 14),
            _accessFields(),
            const SizedBox(height: 10),
            _actionSwitches(),
            const SizedBox(height: 10),
            _detailsField('راهنمای کوتاه برای مسئول'),
          ],
        WorkflowStageType.approval => [
            _ownerFields('مسئول تأیید'),
            const SizedBox(height: 14),
            _accessFields(),
            const SizedBox(height: 14),
            AsoudSegmentedControl<String>(
              value: function,
              options: const [
                AsoudSegmentedOption(
                    value: 'Any', label: 'اقدام یک نفر کافی است'),
                AsoudSegmentedOption(value: 'All', label: 'اقدام همه لازم است'),
              ],
              onChanged: (next) => setState(() => function = next),
            ),
            const SizedBox(height: 10),
            _actionSwitches(),
          ],
        WorkflowStageType.condition => [
            if (loadingFields) const LinearProgressIndicator(),
            _conditionField(),
            const SizedBox(height: 10),
            _dropdown(
                'نوع مقایسه',
                secondary,
                const {
                  'Equals': 'برابر باشد',
                  'Not Equals': 'برابر نباشد',
                  'Greater Than': 'بزرگ‌تر باشد',
                  'Less Than': 'کوچک‌تر باشد',
                  'Contains': 'شامل باشد',
                  'Is Set': 'مقدار داشته باشد',
                },
                (next) => secondary = next),
            if (secondary != 'Is Set') ...[
              const SizedBox(height: 10),
              TextField(
                controller: value,
                decoration: const InputDecoration(labelText: 'مقدار مقایسه *'),
              ),
            ],
            const SizedBox(height: 10),
            const _Notice(
              text:
                  'مسیر «بله» و «خیر» را روی صفحه طراحی به مقصدهای موردنظر وصل کنید.',
            ),
          ],
        WorkflowStageType.systemAction => [
            _dropdown(
                'عملکرد خودکار',
                function,
                const {
                  'Send Notification': 'ارسال اعلان',
                  'Assign Role': 'ارجاع به یک نقش',
                },
                (next) => function = next),
            const SizedBox(height: 14),
            _roleTargetFields('گیرنده عملیات'),
            const SizedBox(height: 14),
            _detailsField('متن اعلان یا توضیح کوتاه'),
          ],
        WorkflowStageType.wait => [
            _dropdown(
                'نوع انتظار',
                function,
                const {
                  'Duration': 'مدت مشخص',
                  'Date': 'تا تاریخ مشخص',
                  'Event': 'تا وقوع رویداد',
                },
                (next) => function = next),
            const SizedBox(height: 10),
            TextField(
              controller: value,
              keyboardType: function == 'Duration'
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: function == 'Duration'
                    ? 'مدت انتظار *'
                    : 'تاریخ یا نام رویداد *',
              ),
            ),
            if (function == 'Duration') ...[
              const SizedBox(height: 10),
              _dropdown(
                  'واحد زمان',
                  secondary,
                  const {
                    'Minute': 'دقیقه',
                    'Hour': 'ساعت',
                    'Day': 'روز',
                  },
                  (next) => secondary = next),
            ],
          ],
        WorkflowStageType.end => [
            _dropdown(
                'نتیجه نهایی',
                function,
                const {
                  'Completed': 'تکمیل موفق',
                  'Rejected': 'ردشده',
                  'Cancelled': 'لغوشده',
                  'Stopped': 'متوقف‌شده',
                },
                (next) => function = next),
            const SizedBox(height: 14),
            _detailsField('پیام نتیجه نهایی'),
          ],
        WorkflowStageType.start => const [],
      };

  Widget _ownerFields(String title) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        AsoudSegmentedControl<String>(
          value: assignmentType,
          options: const [
            AsoudSegmentedOption(value: 'Role', label: 'نقش'),
            AsoudSegmentedOption(value: 'Department', label: 'واحد کاری'),
            AsoudSegmentedOption(value: 'Employee', label: 'پرسنل'),
            AsoudSegmentedOption(value: 'Initiator', label: 'درخواست‌کننده'),
          ],
          onChanged: (next) => setState(() {
            assignmentType = next;
            selected.clear();
          }),
        ),
        const SizedBox(height: 9),
        if (assignmentType == 'Initiator')
          const _Notice(
            text:
                'این مرحله به شخصی ارجاع می‌شود که گردش‌کار را شروع کرده است.',
          )
        else if (_targets.isEmpty)
          const Text('گزینه‌ای از سرور دریافت نشده است.',
              style: TextStyle(fontSize: 10, color: AsoudColors.warning))
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _targets
                .map((item) => FilterChip(
                      selected: selected.contains(item.id),
                      label: Text(item.label),
                      onSelected: (checked) => setState(() {
                        checked
                            ? selected.add(item.id)
                            : selected.remove(item.id);
                      }),
                    ))
                .toList(growable: false),
          ),
      ]);

  Widget _roleTargetFields(String title) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (widget.roles.isEmpty)
          const Text('نقشی از سرور دریافت نشده است.',
              style: TextStyle(fontSize: 10, color: AsoudColors.warning))
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: widget.roles
                .map((role) => FilterChip(
                      selected: selected.contains(role),
                      label: Text(role),
                      onSelected: (checked) => setState(() {
                        checked ? selected.add(role) : selected.remove(role);
                      }),
                    ))
                .toList(growable: false),
          ),
      ]);

  List<WorkflowTargetOption> get _targets => switch (assignmentType) {
        'Department' => widget.departments,
        'Employee' => widget.employees,
        'Initiator' => const [],
        _ => widget.roles
            .map((role) => WorkflowTargetOption(id: role, label: role))
            .toList(growable: false),
      };

  Widget _accessFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('دسترسی به سند اصلی',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          AsoudSegmentedControl<String>(
            value: accessMode,
            options: const [
              AsoudSegmentedOption(value: 'Read Only', label: 'فقط مشاهده'),
              AsoudSegmentedOption(value: 'Edit', label: 'مشاهده و ویرایش'),
              AsoudSegmentedOption(
                  value: 'Limited Edit', label: 'ویرایش محدود'),
            ],
            onChanged: (next) => setState(() => accessMode = next),
          ),
          if (accessMode == 'Limited Edit') ...[
            const SizedBox(height: 8),
            const _Notice(
              text:
                  'انتخاب فیلدهای مجاز پس از اتصال متادیتای ERPNext v15 فعال می‌شود.',
            ),
          ],
        ],
      );

  Widget _actionSwitches() => Column(children: [
        SwitchListTile(
          title: const Text('امکان رد'),
          value: allowReject,
          onChanged: (next) => setState(() => allowReject = next),
        ),
        SwitchListTile(
          title: const Text('امکان بازگشت برای اصلاح'),
          value: allowReturn,
          onChanged: (next) => setState(() => allowReturn = next),
        ),
        SwitchListTile(
          title: const Text('توضیح تصمیم اجباری باشد'),
          value: commentRequired,
          onChanged: (next) => setState(() => commentRequired = next),
        ),
      ]);

  Widget _dropdown(String label, String current, Map<String, String> options,
          ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue:
            options.containsKey(current) ? current : options.keys.first,
        decoration: InputDecoration(labelText: label),
        items: options.entries
            .map((item) => DropdownMenuItem(
                  value: item.key,
                  child: Text(item.value, overflow: TextOverflow.ellipsis),
                ))
            .toList(growable: false),
        onChanged: (next) {
          if (next != null) setState(() => onChanged(next));
        },
      );

  Widget _conditionField() => DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue:
            fields.any((field) => field.name == function) ? function : null,
        decoration: const InputDecoration(labelText: 'فیلد سند اصلی *'),
        items: fields
            .map((field) => DropdownMenuItem(
                  value: field.name,
                  child: Text(field.label, overflow: TextOverflow.ellipsis),
                ))
            .toList(growable: false),
        onChanged: (next) => setState(() => function = next ?? function),
      );

  Widget _detailsField(String label) => TextField(
        controller: details,
        minLines: 2,
        maxLines: 3,
        decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
      );

  Map<String, dynamic> _assignment(String prefix) => {
        'assignment_type': assignmentType,
        '${prefix}_roles': assignmentType == 'Role' ? selected.toList() : [],
        '${prefix}_departments':
            assignmentType == 'Department' ? selected.toList() : [],
        '${prefix}_employees':
            assignmentType == 'Employee' ? selected.toList() : [],
      };

  Future<void> _save() async {
    final output = <String, dynamic>{'title': title.text.trim()};
    switch (widget.stage.type) {
      case WorkflowStageType.userTask:
        output.addAll({
          'activity_type': function,
          ..._assignment('assignee'),
          'document_access': accessMode,
          'instructions': details.text.trim(),
          'form_fields': const [],
          'allow_reject': allowReject,
          'allow_return': allowReturn,
          'comment_required': commentRequired,
        });
      case WorkflowStageType.approval:
        output.addAll({
          ..._assignment('approver'),
          'approval_mode': function,
          'document_access': accessMode,
          'allow_reject': allowReject,
          'allow_return': allowReturn,
          'comment_required': commentRequired,
        });
      case WorkflowStageType.condition:
        output.addAll({
          'source_kind': 'Document',
          'source_field': function,
          'operator': secondary,
          'compare_value': value.text.trim(),
        });
      case WorkflowStageType.systemAction:
        output.addAll({
          'action_type': function,
          'target_roles': selected.toList(),
          'message': details.text.trim(),
        });
      case WorkflowStageType.wait:
        output.addAll({
          'wait_type': function,
          'wait_value': value.text.trim(),
          'wait_unit': secondary,
        });
      case WorkflowStageType.end:
        output.addAll({
          'outcome': function,
          'result_label': details.text.trim(),
        });
      case WorkflowStageType.start:
        return;
    }
    final saved = await context
        .read<WorkflowDesignerCubit>()
        .saveStage(widget.stage, output);
    if (saved && mounted) Navigator.pop(context);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AsoudColors.primary.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: AsoudColors.primary, size: 18),
          const SizedBox(width: 7),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 9))),
        ]),
      );
}
