import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_definition.dart';
import '../cubit/workflow_designer_cubit.dart';
import '../widgets/workflow_form_builder.dart';

class WorkflowStageSettingsPage extends StatefulWidget {
  const WorkflowStageSettingsPage(
      {required this.stage, required this.options, super.key});
  final WorkflowStage stage;
  final WorkflowFormOptions options;

  @override
  State<WorkflowStageSettingsPage> createState() =>
      _WorkflowStageSettingsPageState();
}

class _WorkflowStageSettingsPageState extends State<WorkflowStageSettingsPage> {
  late final TextEditingController title;
  late final TextEditingController details;
  late final TextEditingController value;
  late Set<String> selectedRoles;
  String assignmentType = 'Role';
  String? selectedDepartment;
  String? selectedEmployee;
  String primary = '';
  String secondary = '';
  String conditionSource = 'Document';
  bool optionA = true;
  bool optionB = true;
  bool optionC = false;
  List<WorkflowFieldOption> fields = const [];
  bool loadingFields = false;
  late List<WorkflowFormFieldDefinition> formFields;

  @override
  void initState() {
    super.initState();
    final config = widget.stage.config;
    title = TextEditingController(text: widget.stage.title);
    details = TextEditingController(
      text: (config['instructions'] ??
              config['message'] ??
              config['result_label'] ??
              '')
          .toString(),
    );
    value = TextEditingController(
        text:
            (config['compare_value'] ?? config['wait_value'] ?? '').toString());
    selectedRoles = ((config[_roleKey] as List?) ?? const [])
        .map((item) => item.toString())
        .toSet();
    assignmentType = config['assignment_type']?.toString() ?? 'Role';
    final prefix = _assignmentPrefix;
    selectedDepartment =
        ((config['${prefix}_departments'] as List?) ?? const [])
            .map((item) => item.toString())
            .firstOrNull;
    selectedEmployee = ((config['${prefix}_employees'] as List?) ?? const [])
        .map((item) => item.toString())
        .firstOrNull;
    formFields = ((config['form_fields'] as List?) ?? const [])
        .whereType<Map>()
        .map(WorkflowFormFieldDefinition.fromMap)
        .toList();
    _initializeSelections(config);
    if (widget.stage.type == WorkflowStageType.condition) _loadFields();
  }

  String get _roleKey => switch (widget.stage.type) {
        WorkflowStageType.userTask => 'assignee_roles',
        WorkflowStageType.approval => 'approver_roles',
        WorkflowStageType.systemAction => 'target_roles',
        _ => '',
      };

  String get _assignmentPrefix =>
      widget.stage.type == WorkflowStageType.approval ? 'approver' : 'assignee';

  void _initializeSelections(Map<String, dynamic> config) {
    switch (widget.stage.type) {
      case WorkflowStageType.userTask:
        primary = config['activity_type']?.toString() ?? 'Task';
        optionA = config['allow_reject'] == true;
        optionB = config['allow_return'] == true;
        optionC = config['comment_required'] == true;
        break;
      case WorkflowStageType.approval:
        primary = config['approval_mode']?.toString() ?? 'Any';
        optionA = config['allow_reject'] != false;
        optionB = config['allow_return'] != false;
        optionC = config['comment_required'] == true;
        break;
      case WorkflowStageType.condition:
        primary = config['source_field']?.toString() ?? '';
        conditionSource = config['source_kind']?.toString() ?? 'Document';
        secondary = config['operator']?.toString() ?? 'Equals';
        break;
      case WorkflowStageType.systemAction:
        primary = config['action_type']?.toString() ?? 'Send Notification';
        break;
      case WorkflowStageType.wait:
        primary = config['wait_type']?.toString() ?? 'Duration';
        secondary = config['wait_unit']?.toString() ?? 'Day';
        break;
      case WorkflowStageType.end:
        primary = config['outcome']?.toString() ?? 'Completed';
        break;
      case WorkflowStageType.start:
        break;
    }
  }

  Future<void> _loadFields() async {
    setState(() => loadingFields = true);
    try {
      final result = await context
          .read<WorkflowDesignerCubit>()
          .conditionFields(widget.stage.id);
      if (!mounted) return;
      setState(() {
        fields = result;
        if (primary.isEmpty && fields.isNotEmpty) {
          primary = fields.first.name;
          conditionSource = fields.first.source;
        } else {
          final selected = fields.where((field) => field.name == primary);
          if (selected.isNotEmpty) conditionSource = selected.first.source;
        }
        loadingFields = false;
      });
    } catch (_) {
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
            title: 'تنظیمات ${widget.stage.title}',
            subtitle: _stageHelp(widget.stage.type)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 116),
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(
                  labelText: 'عنوان مرحله *',
                  prefixIcon: Icon(Icons.title_rounded)),
            ),
            const SizedBox(height: 14),
            ..._typeFields(),
          ],
        ),
        bottomNavigationBar: AsoudBottomActions(
          primaryLabel: 'ذخیره تنظیمات مرحله',
          onPrimary: _save,
          secondaryLabel: 'انصراف',
          onSecondary: () => Navigator.pop(context),
        ),
      );

  List<Widget> _typeFields() => switch (widget.stage.type) {
        WorkflowStageType.userTask => [
            _dropdown(
                'نوع فعالیت',
                primary,
                const {
                  'Data Entry': 'دریافت اطلاعات',
                  'Review': 'بررسی اطلاعات',
                  'Correction': 'اصلاح اطلاعات',
                  'Task': 'انجام کار مشخص',
                },
                (next) => primary = next),
            const SizedBox(height: 14),
            _assignmentTargets('مسئول مرحله *'),
            const SizedBox(height: 14),
            WorkflowFormBuilder(
              fields: formFields,
              onChanged: (next) => setState(() => formFields = next),
            ),
            if (primary == 'Review') ...[
              const SizedBox(height: 10),
              SwitchListTile(
                  title: const Text('امکان بازگشت برای اصلاح'),
                  value: optionB,
                  onChanged: (next) => setState(() => optionB = next)),
              SwitchListTile(
                  title: const Text('امکان رد درخواست'),
                  value: optionA,
                  onChanged: (next) => setState(() => optionA = next)),
              SwitchListTile(
                  title: const Text('توضیح تصمیم اجباری باشد'),
                  value: optionC,
                  onChanged: (next) => setState(() => optionC = next)),
            ],
            const SizedBox(height: 14),
            _detailsField('راهنمای انجام کار'),
          ],
        WorkflowStageType.approval => [
            _assignmentTargets('تأییدکننده *'),
            const SizedBox(height: 14),
            AsoudSegmentedControl<String>(
              value: primary,
              options: const [
                AsoudSegmentedOption(value: 'Any', label: 'تأیید یک نفر'),
                AsoudSegmentedOption(value: 'All', label: 'تأیید همه'),
              ],
              onChanged: (next) => setState(() => primary = next),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
                title: const Text('امکان رد'),
                value: optionA,
                onChanged: (next) => setState(() => optionA = next)),
            SwitchListTile(
                title: const Text('امکان بازگشت برای اصلاح'),
                value: optionB,
                onChanged: (next) => setState(() => optionB = next)),
            SwitchListTile(
                title: const Text('توضیح تصمیم اجباری باشد'),
                value: optionC,
                onChanged: (next) => setState(() => optionC = next)),
          ],
        WorkflowStageType.condition => [
            if (loadingFields) const LinearProgressIndicator(),
            _fieldDropdown(),
            const SizedBox(height: 10),
            _dropdown(
                'عملگر شرط',
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
                  decoration:
                      const InputDecoration(labelText: 'مقدار مقایسه *')),
            ],
            const SizedBox(height: 10),
            const _SafeNotice(
                text: 'شرط فقط روی فیلدهای مجاز سند مرجع اجرا می‌شود.'),
          ],
        WorkflowStageType.systemAction => [
            _dropdown(
                'نوع اقدام',
                primary,
                const {
                  'Send Notification': 'ارسال اعلان',
                  'Assign Role': 'تخصیص به نقش',
                },
                (next) => primary = next),
            const SizedBox(height: 14),
            _roles('نقش‌های مقصد *'),
            const SizedBox(height: 14),
            _detailsField('متن پیام یا توضیح اقدام'),
            const SizedBox(height: 10),
            const _SafeNotice(
                text:
                    'اجرای API دلخواه و کد سفارشی برای امنیت سیستم غیرفعال است.'),
          ],
        WorkflowStageType.wait => [
            _dropdown(
                'نوع انتظار',
                primary,
                const {
                  'Duration': 'مدت مشخص',
                  'Date': 'تا تاریخ مشخص',
                  'Event': 'تا وقوع رویداد',
                },
                (next) => primary = next),
            const SizedBox(height: 10),
            TextField(
              controller: value,
              keyboardType: primary == 'Duration'
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(
                  labelText: primary == 'Duration'
                      ? 'مدت انتظار *'
                      : 'تاریخ یا نام رویداد *'),
            ),
            if (primary == 'Duration') ...[
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
                primary,
                const {
                  'Completed': 'تکمیل موفق',
                  'Rejected': 'ردشده',
                  'Cancelled': 'لغوشده',
                  'Stopped': 'متوقف‌شده',
                },
                (next) => primary = next),
            const SizedBox(height: 14),
            _detailsField('پیام نتیجه نهایی'),
          ],
        WorkflowStageType.start => const [],
      };

  Widget _dropdown(String label, String current, Map<String, String> options,
          ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: current,
        decoration: InputDecoration(labelText: label),
        items: options.entries
            .map((item) => DropdownMenuItem(
                value: item.key,
                child: Text(item.value, overflow: TextOverflow.ellipsis)))
            .toList(growable: false),
        onChanged: (next) {
          if (next != null) setState(() => onChanged(next));
        },
      );

  Widget _fieldDropdown() {
    final selectedKey = '$conditionSource:$primary';
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue:
          fields.any((field) => '${field.source}:${field.name}' == selectedKey)
              ? selectedKey
              : null,
      decoration: const InputDecoration(labelText: 'فیلد مبنای شرط *'),
      items: fields
          .map((field) => DropdownMenuItem(
              value: '${field.source}:${field.name}',
              child: Text(
                  '${field.source == 'Form' ? 'فرم' : 'سند'} — ${field.label}',
                  overflow: TextOverflow.ellipsis)))
          .toList(growable: false),
      onChanged: (next) => setState(() {
        final selected =
            fields.where((field) => '${field.source}:${field.name}' == next);
        if (selected.isNotEmpty) {
          primary = selected.first.name;
          conditionSource = selected.first.source;
        }
      }),
    );
  }

  Widget _roles(String label) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        if (widget.options.roles.isEmpty)
          const Text('نقشی از سرور دریافت نشد.',
              style: TextStyle(color: AsoudColors.warning))
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: widget.options.roles
                .map((role) => FilterChip(
                      selected: selectedRoles.contains(role),
                      label: Text(role),
                      onSelected: (selected) => setState(() {
                        selected
                            ? selectedRoles.add(role)
                            : selectedRoles.remove(role);
                      }),
                    ))
                .toList(growable: false),
          ),
      ]);

  Widget _assignmentTargets(String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          AsoudSegmentedControl<String>(
            value: assignmentType,
            options: const [
              AsoudSegmentedOption(value: 'Role', label: 'نقش'),
              AsoudSegmentedOption(value: 'Department', label: 'واحد کاری'),
              AsoudSegmentedOption(value: 'Employee', label: 'پرسنل مشخص'),
            ],
            onChanged: (next) => setState(() => assignmentType = next),
          ),
          const SizedBox(height: 10),
          if (assignmentType == 'Role')
            _roles('نقش‌های مجاز')
          else
            _targetDropdown(),
        ],
      );

  Widget _targetDropdown() {
    final employeeMode = assignmentType == 'Employee';
    final values =
        employeeMode ? widget.options.employees : widget.options.departments;
    final current = employeeMode ? selectedEmployee : selectedDepartment;
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: values.any((item) => item.id == current) ? current : null,
      decoration: InputDecoration(
        labelText: employeeMode ? 'نام پرسنل *' : 'واحد کاری *',
        prefixIcon: Icon(
            employeeMode ? Icons.badge_outlined : Icons.account_tree_outlined),
      ),
      items: values
          .map((item) => DropdownMenuItem(
                value: item.id,
                child: Text(
                  employeeMode && item.department?.isNotEmpty == true
                      ? '${item.label} — ${item.department}'
                      : item.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(growable: false),
      onChanged: values.isEmpty
          ? null
          : (next) => setState(() {
                if (employeeMode) {
                  selectedEmployee = next;
                } else {
                  selectedDepartment = next;
                }
              }),
    );
  }

  Widget _detailsField(String label) => TextField(
        controller: details,
        minLines: 3,
        maxLines: 4,
        decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
      );

  Future<void> _save() async {
    final config = <String, dynamic>{'title': title.text.trim()};
    switch (widget.stage.type) {
      case WorkflowStageType.userTask:
        config.addAll({
          'activity_type': primary,
          'assignee_roles': selectedRoles.toList(),
          'assignment_type': assignmentType,
          'assignee_departments':
              selectedDepartment == null ? [] : [selectedDepartment],
          'assignee_employees':
              selectedEmployee == null ? [] : [selectedEmployee],
          'instructions': details.text.trim(),
          'form_fields': formFields.map((field) => field.toMap()).toList(),
          'allow_reject': primary == 'Review' && optionA,
          'allow_return': primary == 'Review' && optionB,
          'comment_required': primary == 'Review' && optionC,
        });
        break;
      case WorkflowStageType.approval:
        config.addAll({
          'approver_roles': selectedRoles.toList(),
          'assignment_type': assignmentType,
          'approver_departments':
              selectedDepartment == null ? [] : [selectedDepartment],
          'approver_employees':
              selectedEmployee == null ? [] : [selectedEmployee],
          'approval_mode': primary,
          'allow_reject': optionA,
          'allow_return': optionB,
          'comment_required': optionC
        });
        break;
      case WorkflowStageType.condition:
        config.addAll({
          'source_kind': conditionSource,
          'source_field': primary,
          'operator': secondary,
          'compare_value': value.text.trim()
        });
        break;
      case WorkflowStageType.systemAction:
        config.addAll({
          'action_type': primary,
          'target_roles': selectedRoles.toList(),
          'message': details.text.trim()
        });
        break;
      case WorkflowStageType.wait:
        config.addAll({
          'wait_type': primary,
          'wait_value': value.text.trim(),
          'wait_unit': secondary
        });
        break;
      case WorkflowStageType.end:
        config
            .addAll({'outcome': primary, 'result_label': details.text.trim()});
        break;
      case WorkflowStageType.start:
        return;
    }
    final saved = await context
        .read<WorkflowDesignerCubit>()
        .saveStage(widget.stage, config);
    if (saved && mounted) Navigator.pop(context);
  }
}

class _SafeNotice extends StatelessWidget {
  const _SafeNotice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AsoudColors.primary.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(children: [
          const Icon(Icons.verified_user_outlined,
              color: AsoudColors.primary, size: 18),
          const SizedBox(width: 7),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 9))),
        ]),
      );
}

String _stageHelp(WorkflowStageType type) => switch (type) {
      WorkflowStageType.userTask => 'مسئول و نوع فعالیت کاربر را تعیین کنید',
      WorkflowStageType.approval => 'تأییدکنندگان و قواعد تصمیم را مشخص کنید',
      WorkflowStageType.condition => 'شرط امن روی سند مرجع تعریف کنید',
      WorkflowStageType.systemAction => 'یک اقدام خودکار مجاز انتخاب کنید',
      WorkflowStageType.wait => 'زمان یا رویداد ادامه فرایند را مشخص کنید',
      WorkflowStageType.end => 'نتیجه نهایی این مسیر را تعیین کنید',
      WorkflowStageType.start => '',
    };
