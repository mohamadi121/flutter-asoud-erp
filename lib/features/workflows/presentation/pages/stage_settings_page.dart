import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/workflow_automation_repository.dart';
import '../../domain/entities/workflow_definition.dart';
import '../cubit/workflow_designer_cubit.dart';
import '../widgets/document_template_visuals.dart';
import '../widgets/stage_pickers.dart';
import '../widgets/workflow_form_builder.dart';
import 'create_document_settings_page.dart';

/// Decision routes by stage type; the first one is the main route.
const _routeActions = {
  WorkflowStageType.userTask: ['Complete', 'Reject', 'Return'],
  WorkflowStageType.approval: ['Approve', 'Reject', 'Return'],
  WorkflowStageType.systemAction: ['Success', 'Error'],
};
const _labelActions = {
  'تأیید': 'Approve',
  'رد': 'Reject',
  'بازگشت برای اصلاح': 'Return',
  'ادامه': 'Complete',
  'موفقیت': 'Success',
  'خطا': 'Error',
};

/// Current exit routes of [stage]: action -> destination stage id.
Map<String, String> stageRoutes(WorkflowDesign design, WorkflowStage stage) {
  final actions = _routeActions[stage.type] ?? const <String>[];
  final routes = <String, String>{};
  for (final edge in design.transitions.where((e) => e.fromStage == stage.id)) {
    var action = edge.condition['action']?.toString() ?? '';
    if (action.isEmpty) action = _labelActions[edge.label] ?? '';
    if (action.isEmpty && actions.isNotEmpty) action = actions.first;
    routes.putIfAbsent(action, () => edge.toStage);
  }
  return routes;
}

/// Settings of a user task, approval or automatic stage, laid out per type.
class StageSettingsPage extends StatefulWidget {
  const StageSettingsPage({
    required this.stage,
    required this.design,
    this.options,
    this.automation,
    super.key,
  });
  final WorkflowStage stage;
  final WorkflowDesign design;
  final WorkflowFormOptions? options;
  final WorkflowAutomationRepository? automation;

  @override
  State<StageSettingsPage> createState() => _StageSettingsPageState();
}

class _StageSettingsPageState extends State<StageSettingsPage> {
  late final WorkflowAutomationRepository automation = widget.automation ??
      WorkflowAutomationRepository(context.read<FrappeApiClient>());
  Map<String, dynamic> get config => widget.stage.config;
  WorkflowStageType get type => widget.stage.type;
  String get prefix =>
      type == WorkflowStageType.approval ? 'approver' : 'assignee';
  String? get company => widget.design.workflow.company;
  List<WorkflowTargetOption> get departments =>
      widget.options?.departments ?? const [];
  List<WorkflowTargetOption> get employees =>
      widget.options?.employees ?? const [];
  List<String> get roles => widget.options?.roles ?? const [];

  late final title = TextEditingController(text: widget.stage.title);
  late final description = TextEditingController(
      text: (config['description'] ?? config['instructions'] ?? '').toString());
  late final deadline = TextEditingController(
      text: ((config['deadline_value'] as num?) ?? 0) == 0
          ? ''
          : config['deadline_value'].toString());
  late final message =
      TextEditingController(text: (config['message'] ?? '').toString());
  late final status =
      TextEditingController(text: (config['request_status'] ?? '').toString());
  late String deadlineUnit = config['deadline_unit']?.toString() ?? 'Day';

  // Responsible person.
  String ownerMode = 'role';
  String role = directManagerRole;
  OrgUnitChoice? unit;
  bool specificPerson = false;
  OrgUnitChoice? person;

  // Decisions and extra settings.
  late bool allowReject =
      config['allow_reject'] ?? (type == WorkflowStageType.approval);
  late bool allowReturn =
      config['allow_return'] ?? (type == WorkflowStageType.approval);
  late bool rejectComment = config['reject_comment_required'] == true;
  late bool commentRequired = config['comment_required'] == true;
  late bool allowDraft = config['allow_draft'] != false;
  late bool requireAll = config['require_all_fields'] == true;
  late bool editAfterSubmit = config['allow_edit_after_submit'] == true;
  late String approvalMode = config['approval_mode']?.toString() ?? 'Any';
  late String access = config['document_access']?.toString() ?? 'Read Only';
  late List<WorkflowFormFieldDefinition> formFields =
      ((config['form_fields'] as List?) ?? const [])
          .whereType<Map>()
          .map(WorkflowFormFieldDefinition.fromMap)
          .toList();

  // Automatic action.
  late String action = switch (config['action_type']?.toString()) {
    'Send Notification' => 'Send Notification',
    'Change Status' => 'Change Status',
    _ => 'Create Document',
  };
  CreateDocumentConfig document = const CreateDocumentConfig();
  late Set<String> targetRoles =
      ((config['target_roles'] as List?) ?? const []).map((e) => '$e').toSet();
  late bool notifyInitiator = config['notify_initiator'] == true;

  late Map<String, String> routes = stageRoutes(widget.design, widget.stage);
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _initOwner();
    document = CreateDocumentConfig(
        transferValues: config['transfer_values'] != false,
        remark: (config['document_remark'] ?? '').toString());
    final template = config['document_template']?.toString() ?? '';
    if (type == WorkflowStageType.systemAction && template.isNotEmpty) {
      _loadTemplate(template);
    }
  }

  void _initOwner() {
    final kind = config['assignment_type']?.toString() ??
        (type == WorkflowStageType.approval ? 'Direct Manager' : 'Initiator');
    List<String> values(String suffix) =>
        ((config['${prefix}_$suffix'] as List?) ?? const [])
            .map((e) => '$e')
            .toList();
    String label(List<WorkflowTargetOption> list, String id) =>
        list.where((item) => item.id == id).firstOrNull?.label ?? id;
    switch (kind) {
      case 'Direct Manager':
        role = directManagerRole;
      case 'Initiator':
        role = initiatorRole;
      case 'Role':
        role = values('roles').firstOrNull ?? directManagerRole;
      case 'Initiator Department':
        ownerMode = 'unit';
        unit = const OrgUnitChoice.initiatorDepartment();
      case 'Department':
        ownerMode = 'unit';
        final id = values('departments').firstOrNull ?? '';
        unit = id.isEmpty
            ? null
            : OrgUnitChoice.department(id, label(departments, id));
      case 'Employee':
        ownerMode = 'unit';
        specificPerson = true;
        final id = values('employees').firstOrNull ?? '';
        if (id.isNotEmpty) {
          person = OrgUnitChoice.employee(id, label(employees, id));
          final department =
              employees.where((item) => item.id == id).firstOrNull?.department;
          if (department != null) {
            unit = OrgUnitChoice.department(
                department, label(departments, department));
          }
        }
    }
  }

  Future<void> _loadTemplate(String name) async {
    try {
      final template = await automation.template(name);
      if (!mounted) return;
      setState(() => document = CreateDocumentConfig(
          template: template,
          module: template.module,
          documentType: template.documentType,
          transferValues: document.transferValues,
          remark: document.remark));
    } catch (_) {
      // The stage keeps its template name; picking again reloads it.
    }
  }

  @override
  void dispose() {
    for (final controller in [title, description, deadline, message, status]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Map<String, dynamic> _assignment() {
    if (ownerMode == 'role') {
      return switch (role) {
        directManagerRole => {'assignment_type': 'Direct Manager'},
        initiatorRole => {'assignment_type': 'Initiator'},
        _ => {
            'assignment_type': 'Role',
            '${prefix}_roles': [role]
          },
      };
    }
    if (specificPerson && person != null) {
      return {
        'assignment_type': 'Employee',
        '${prefix}_employees': [person!.id]
      };
    }
    if (unit?.kind == 'initiator') {
      return {'assignment_type': 'Initiator Department'};
    }
    return {
      'assignment_type': 'Department',
      '${prefix}_departments': [unit!.id]
    };
  }

  Map<String, dynamic> _deadline() => {
        'deadline_value': int.tryParse(deadline.text.trim()) ?? 0,
        'deadline_unit': deadlineUnit,
        'reminder_before_minutes': config['reminder_before_minutes'] ?? 0,
        'escalation_roles': config['escalation_roles'] ?? const [],
        'reassign_on_overdue': config['reassign_on_overdue'] == true,
      };

  String? _validate() {
    if (title.text.trim().length < 2) return 'عنوان مرحله را وارد کنید.';
    if (type != WorkflowStageType.systemAction && ownerMode == 'unit') {
      if (unit == null) return 'واحد سازمانی مسئول را انتخاب کنید.';
      if (specificPerson && person == null) return 'فرد مسئول را انتخاب کنید.';
    }
    if (type == WorkflowStageType.systemAction) {
      if (action == 'Create Document' && document.template == null) {
        return 'الگوی سند را انتخاب کنید.';
      }
      if (action == 'Change Status' && status.text.trim().length < 2) {
        return 'عنوان وضعیت را وارد کنید.';
      }
      if (action == 'Send Notification' &&
          (message.text.trim().isEmpty ||
              (targetRoles.isEmpty && !notifyInitiator))) {
        return 'گیرنده و متن اعلان را مشخص کنید.';
      }
    }
    final main = _routeActions[type]!.first;
    if ((routes[main] ?? '').isEmpty) return 'مسیر خروجی اصلی را انتخاب کنید.';
    return null;
  }

  Map<String, dynamic> _config() {
    final text = description.text.trim();
    switch (type) {
      case WorkflowStageType.userTask:
        return {
          'title': title.text.trim(),
          'description': text,
          'instructions': text,
          'activity_type': config['activity_type'] ?? 'Data Entry',
          ..._assignment(),
          'document_access': access,
          'form_fields': formFields.map((field) => field.toMap()).toList(),
          'allow_reject': allowReject,
          'allow_return': allowReturn,
          'comment_required': commentRequired,
          'reject_comment_required': rejectComment,
          'allow_draft': allowDraft,
          'require_all_fields': requireAll,
          'allow_edit_after_submit': editAfterSubmit,
          ..._deadline(),
        };
      case WorkflowStageType.approval:
        return {
          'title': title.text.trim(),
          'description': text,
          ..._assignment(),
          'approval_mode': approvalMode,
          'document_access': access,
          'allow_reject': allowReject,
          'allow_return': allowReturn,
          'comment_required': commentRequired,
          'reject_comment_required': rejectComment,
          ..._deadline(),
        };
      default:
        return {
          'title': title.text.trim(),
          'description': text,
          'action_type': action,
          if (action == 'Create Document') ...{
            'document_template': document.template!.name,
            'transfer_values': document.transferValues,
            'document_remark': document.remark,
          },
          if (action == 'Change Status') 'request_status': status.text.trim(),
          if (action == 'Send Notification') ...{
            'target_roles': targetRoles.toList(),
            'notify_initiator': notifyInitiator,
            'message': message.text.trim(),
          },
        };
    }
  }

  Future<void> save() async {
    final problem = _validate();
    if (problem != null) return _message(problem);
    final cubit = context.read<WorkflowDesignerCubit>();
    setState(() => saving = true);
    final saved = await cubit.saveStage(widget.stage, _config());
    if (!saved || !mounted) {
      if (mounted) setState(() => saving = false);
      return;
    }
    final current = stageRoutes(widget.design, widget.stage);
    final wanted = {
      for (final action in _routeActions[type]!)
        action: switch (action) {
          'Reject' when !allowReject => '',
          'Return' when !allowReturn => '',
          _ => routes[action] ?? '',
        },
    };
    final changed = {
      for (final entry in wanted.entries)
        if ((current[entry.key] ?? '') != entry.value) entry.key: entry.value
    };
    try {
      if (changed.isNotEmpty) {
        await automation.saveStageRoutes(
            definition: widget.design.workflow.id,
            stage: widget.stage.id,
            routes: changed);
        await cubit.load();
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      _message(e is ApiException
          ? e.message
          : 'تنظیمات ذخیره شد اما مسیرهای خروجی ذخیره نشد.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(84),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(children: [
                IconButton(
                    tooltip: 'بستن',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded)),
                Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('تنظیمات مرحله',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900)),
                    Text(_typeInfo.$1,
                        style: const TextStyle(
                            fontSize: 11, color: AsoudColors.muted)),
                  ]),
                ),
                FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(72, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14)),
                    onPressed: saving ? null : save,
                    child: Text(saving ? '...' : 'ذخیره')),
              ]),
            ),
          ),
        ),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _typeCard(),
              const SizedBox(height: 14),
              _label('عنوان مرحله', required: true),
              TextField(
                  controller: title,
                  decoration: const InputDecoration(
                      hintText: 'مثلاً: تأیید مدیر مستقیم')),
              const SizedBox(height: 14),
              _label('توضیحات'),
              TextField(
                controller: description,
                minLines: 3,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                    hintText: 'شرح کوتاهی از کار این مرحله...'),
              ),
              ...switch (type) {
                WorkflowStageType.userTask => _userTask(),
                WorkflowStageType.approval => _approval(),
                _ => _systemAction(),
              },
            ]),
      );

  (String, String, IconData, Color) get _typeInfo => switch (type) {
        WorkflowStageType.userTask => (
            'وظیفه کاربر',
            'انجام کار توسط کاربر یا تکمیل فرم',
            Icons.assignment_ind_outlined,
            AsoudColors.primary
          ),
        WorkflowStageType.approval => (
            'تأیید / رد',
            'بررسی و تصمیم‌گیری توسط کاربر',
            Icons.approval_outlined,
            AsoudColors.danger
          ),
        _ => (
            'اقدام خودکار',
            'اجرای عملیات سیستمی بدون نیاز به دخالت کاربر',
            Icons.settings_suggest_outlined,
            AsoudColors.success
          ),
      };

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: text,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          if (required)
            const TextSpan(
                text: ' *', style: TextStyle(color: AsoudColors.danger)),
        ])),
      );

  Widget _typeCard() {
    final info = _typeInfo;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label('نوع مرحله', required: true),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AsoudColors.border),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          AsoudIconBox(icon: info.$3, color: info.$4, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(info.$1,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900)),
              Text(info.$2,
                  style:
                      const TextStyle(fontSize: 11, color: AsoudColors.muted)),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _notice(String text, {Color color = AsoudColors.primary}) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(11)),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 11, height: 1.6))),
        ]),
      );

  // --- responsible person -------------------------------------------------------------

  List<Widget> _owner() => [
        const SizedBox(height: 6),
        _label('مسئول انجام', required: true),
        AsoudSegmentedControl<String>(
          value: ownerMode,
          options: const [
            AsoudSegmentedOption(value: 'role', label: 'نقش'),
            AsoudSegmentedOption(value: 'unit', label: 'واحد سازمانی'),
          ],
          onChanged: (next) => setState(() => ownerMode = next),
        ),
        const SizedBox(height: 10),
        if (ownerMode == 'role')
          PickerField(
            value: roleLabel(role),
            icon: roleVisual(role).icon,
            iconColor: roleVisual(role).color,
            onTap: () async {
              final choice = await pickRole(context,
                  roles: roles,
                  selected: role,
                  initiator: type == WorkflowStageType.userTask);
              if (choice != null) setState(() => role = choice);
            },
          )
        else ...[
          PickerField(
            label: 'انتخاب واحد سازمانی',
            value: unit?.label ?? '',
            placeholder: 'انتخاب واحد',
            icon: Icons.apartment_rounded,
            onTap: () async {
              final choice = await pickOrgUnit(context,
                  departments: departments, selected: unit);
              if (choice != null) {
                setState(() {
                  unit = choice;
                  person = null;
                  if (choice.kind == 'initiator') specificPerson = false;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          _label('انتخاب افراد'),
          RadioGroup<bool>(
            groupValue: specificPerson,
            onChanged: (value) => setState(() => specificPerson = value!),
            child: Column(children: [
              const RadioListTile<bool>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: false,
                  title: Text('همه افراد واحد')),
              RadioListTile<bool>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  enabled: unit != null && unit!.kind != 'initiator',
                  title: const Text('یک فرد مشخص')),
            ]),
          ),
          if (specificPerson)
            PickerField(
              value: person?.label ?? '',
              placeholder: 'انتخاب فرد',
              icon: Icons.person_outline_rounded,
              onTap: () async {
                final unitOption = departments
                    .where((item) => item.id == unit?.id)
                    .firstOrNull;
                if (unitOption == null) return;
                final choice = await Navigator.push<OrgUnitChoice>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => OrgUnitPickerPage(
                            departments: departments,
                            employees: employees,
                            parent: unitOption,
                            selected: person,
                            initiatorDepartment: false,
                            members: true)));
                if (choice?.kind == 'employee') {
                  setState(() => person = choice);
                }
              },
            )
          else
            _notice(
                'این مرحله برای تمامی افراد واحد انتخاب‌شده قابل انجام خواهد بود.',
                color: AsoudColors.success),
        ],
      ];

  Widget _deadlineRow() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          _label('مهلت انجام'),
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: deadline,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    hintText: 'بدون مهلت',
                    prefixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: deadlineUnit,
                items: const [
                  DropdownMenuItem(value: 'Day', child: Text('روز')),
                  DropdownMenuItem(value: 'Hour', child: Text('ساعت')),
                  DropdownMenuItem(value: 'Minute', child: Text('دقیقه')),
                ],
                onChanged: (value) =>
                    setState(() => deadlineUnit = value ?? 'Day'),
              ),
            ),
          ]),
        ],
      );

  Widget _switch(String title, bool value, ValueChanged<bool>? onChanged,
          {String? subtitle}) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontSize: 13)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: const TextStyle(fontSize: 11)),
        value: value,
        onChanged: onChanged,
      );

  Widget _accessControl() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _label('دسترسی به سند اصلی'),
          AsoudSegmentedControl<String>(
            value: access,
            options: const [
              AsoudSegmentedOption(value: 'Read Only', label: 'فقط مشاهده'),
              AsoudSegmentedOption(value: 'Edit', label: 'ویرایش'),
              AsoudSegmentedOption(value: 'Limited Edit', label: 'محدود'),
            ],
            onChanged: (next) => setState(() => access = next),
          ),
        ],
      );

  Widget _extra(List<Widget> children) => Card(
        margin: const EdgeInsets.only(top: 16),
        child: ExpansionTile(
          leading: const Icon(Icons.tune_rounded, color: AsoudColors.primary),
          title: const Text('تنظیمات اضافی (اختیاری)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: children,
        ),
      );

  // --- routes --------------------------------------------------------------------------

  List<WorkflowStage> get _destinations => [
        ...widget.design.stages.where((stage) =>
            stage.id != widget.stage.id &&
            stage.type != WorkflowStageType.start),
      ]..sort((a, b) => a.sequence.compareTo(b.sequence));

  Widget _route(String action, String label, IconData icon, Color color,
      {String? emptyLabel}) {
    final value = routes[action] ?? '';
    final stages = _destinations;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        AsoudPickerIcon(icon: icon, color: color),
        const SizedBox(width: 8),
        Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700))),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: stages.any((stage) => stage.id == value) ||
                    (value.isEmpty && emptyLabel != null)
                ? value
                : null,
            hint: const Text('انتخاب مرحله', style: TextStyle(fontSize: 12)),
            items: [
              if (emptyLabel != null)
                DropdownMenuItem(
                    value: '',
                    child: Text(emptyLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12))),
              for (final stage in stages)
                DropdownMenuItem(
                    value: stage.id,
                    child: Text(stage.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12))),
            ],
            onChanged: (next) => setState(() => routes[action] = next ?? ''),
          ),
        ),
      ]),
    );
  }

  // --- user task --------------------------------------------------------------------------

  List<Widget> _userTask() => [
        _label('فرم مرحله'),
        PickerField(
          value: formFields.isEmpty
              ? 'بدون فرم'
              : 'فرم مرحله · ${formFields.length} فیلد',
          icon: Icons.dynamic_form_outlined,
          trailing: const Icon(Icons.add_rounded, color: AsoudColors.primary),
          onTap: () async {
            final fields =
                await Navigator.push<List<WorkflowFormFieldDefinition>>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _StageFormPage(fields: formFields)));
            if (fields != null) setState(() => formFields = fields);
          },
        ),
        ..._owner(),
        _deadlineRow(),
        const SizedBox(height: 6),
        _switch('الزام به تکمیل', true, null,
            subtitle:
                'کاربر نمی‌تواند بدون تکمیل این مرحله به مرحله بعد برود.'),
        _extra([
          _switch('امکان ویرایش بعد از ارسال', editAfterSubmit,
              (value) => setState(() => editAfterSubmit = value)),
          _switch('الزام تکمیل تمام فیلدهای فرم', requireAll,
              (value) => setState(() => requireAll = value)),
          _switch('امکان ذخیره پیش‌نویس', allowDraft,
              (value) => setState(() => allowDraft = value)),
          _switch('امکان رد', allowReject,
              (value) => setState(() => allowReject = value)),
          _switch('امکان بازگشت برای اصلاح', allowReturn,
              (value) => setState(() => allowReturn = value)),
          _accessControl(),
        ]),
        const SizedBox(height: 16),
        _label('مسیرهای خروجی', required: true),
        _route('Complete', 'پس از تکمیل', Icons.check_rounded,
            AsoudColors.success),
        if (allowReject)
          _route(
              'Reject', 'در صورت رد', Icons.close_rounded, AsoudColors.danger,
              emptyLabel: 'پایان فرایند (رد درخواست)'),
      ];

  // --- approval ---------------------------------------------------------------------------

  List<Widget> _approval() => [
        ..._owner(),
        _deadlineRow(),
        const SizedBox(height: 16),
        _label('تصمیم‌های قابل انجام'),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: true,
            onChanged: (_) {},
            title: const Text('امکان تأیید', style: TextStyle(fontSize: 13))),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: allowReject,
            onChanged: (value) => setState(() => allowReject = value ?? false),
            title: const Text('امکان رد', style: TextStyle(fontSize: 13))),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: allowReturn,
            onChanged: (value) => setState(() => allowReturn = value ?? false),
            title: const Text('امکان بازگشت برای اصلاح',
                style: TextStyle(fontSize: 13))),
        _switch(
            'الزام ثبت توضیح هنگام رد',
            rejectComment,
            allowReject
                ? (value) => setState(() => rejectComment = value)
                : null),
        _switch('الزام ثبت توضیح هنگام بازگشت', true, null),
        const SizedBox(height: 12),
        _label('مسیرهای خروجی', required: true),
        _route('Approve', 'در صورت تأیید', Icons.check_rounded,
            AsoudColors.success),
        if (allowReject)
          _route(
              'Reject', 'در صورت رد', Icons.close_rounded, AsoudColors.danger,
              emptyLabel: 'پایان فرایند (رد درخواست)'),
        if (allowReturn)
          _route('Return', 'در صورت بازگشت برای اصلاح', Icons.undo_rounded,
              AsoudColors.primary,
              emptyLabel: 'آخرین مرحله قابل اصلاح'),
        _extra([
          const SizedBox(height: 4),
          AsoudSegmentedControl<String>(
            value: approvalMode,
            options: const [
              AsoudSegmentedOption(
                  value: 'Any', label: 'تأیید یک نفر کافی است'),
              AsoudSegmentedOption(value: 'All', label: 'تأیید همه لازم است'),
            ],
            onChanged: (next) => setState(() => approvalMode = next),
          ),
          _switch('توضیح برای همه تصمیم‌ها الزامی باشد', commentRequired,
              (value) => setState(() => commentRequired = value)),
          _accessControl(),
        ]),
      ];

  // --- automatic action ----------------------------------------------------------------

  List<Widget> _systemAction() => [
        _notice(
            'این مرحله به صورت خودکار توسط سیستم اجرا می‌شود و نیازی به تعیین مسئول ندارد.'),
        const SizedBox(height: 16),
        _label('عملیات خودکار', required: true),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 6,
          childAspectRatio: .95,
          children: [
            _actionTile(
                'Create Document', 'ایجاد سند', Icons.description_outlined),
            _actionTile('Change Status', 'تغییر وضعیت', Icons.sync_rounded),
            _actionTile('Send Notification', 'ارسال اعلان',
                Icons.notifications_none_rounded),
            _actionTile('API', 'اجرای API', Icons.link_rounded, enabled: false),
          ],
        ),
        const SizedBox(height: 14),
        ...switch (action) {
          'Create Document' => _createDocument(),
          'Change Status' => _changeStatus(),
          _ => _notification(),
        },
        const SizedBox(height: 16),
        _label('مسیرهای خروجی', required: true),
        _route('Success', 'در صورت موفقیت', Icons.check_rounded,
            AsoudColors.success),
        _route('Error', 'در صورت خطا', Icons.close_rounded, AsoudColors.danger,
            emptyLabel: 'اطلاع به مدیر سیستم'),
        _extra([
          _notice(
              'نتیجه هر اجرا در سوابق فرایند ثبت می‌شود و در صورت خطا تغییرات برگشت داده می‌شوند.'),
        ]),
      ];

  Widget _actionTile(String key, String label, IconData icon,
      {bool enabled = true}) {
    final active = action == key;
    return InkWell(
      onTap: enabled ? () => setState(() => action = key) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: active ? AsoudColors.primary : Colors.white,
            border: Border.all(
                color: active ? AsoudColors.primary : AsoudColors.border),
            borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: active
                  ? Colors.white
                  : enabled
                      ? AsoudColors.text
                      : AsoudColors.border),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? Colors.white
                      : enabled
                          ? AsoudColors.text
                          : AsoudColors.muted)),
          if (!enabled)
            const Text('به‌زودی',
                style: TextStyle(fontSize: 8, color: AsoudColors.muted)),
        ]),
      ),
    );
  }

  List<Widget> _createDocument() {
    final template = document.template;
    Future<void> edit() async {
      final value = company;
      if (value == null || value.isEmpty) {
        return _message('شرکت این گردش کار مشخص نیست.');
      }
      final result = await Navigator.push<CreateDocumentConfig>(
          context,
          MaterialPageRoute(
              builder: (_) => CreateDocumentSettingsPage(
                  company: value,
                  repository: automation,
                  initial: document,
                  sourceWorkflow: widget.design.workflow.targetDoctype ==
                          'ASOUD Workflow Request'
                      ? widget.design.workflow.id
                      : null)));
      if (result != null) setState(() => document = result);
    }

    final rows = [
      ('ماژول مقصد', template == null ? '' : _moduleLabel(template.module)),
      ('نوع سند', template == null ? '' : _typeLabel(template.documentType)),
      ('الگوی سند', template?.title ?? ''),
    ];
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              const Expanded(
                  child: Text('تنظیمات ایجاد سند',
                      style: TextStyle(fontWeight: FontWeight.w900))),
              AsoudPickerIcon(
                  icon: Icons.description_outlined, color: AsoudColors.primary),
            ]),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                      flex: 2,
                      child:
                          Text(row.$1, style: const TextStyle(fontSize: 12))),
                  Expanded(
                    flex: 3,
                    child: PickerField(
                        value: row.$2, placeholder: 'انتخاب', onTap: edit),
                  ),
                ]),
              ),
            _switch('انتقال اطلاعات', document.transferValues, (value) {
              setState(() => document = CreateDocumentConfig(
                  template: document.template,
                  module: document.module,
                  documentType: document.documentType,
                  transferValues: value,
                  remark: document.remark));
            },
                subtitle:
                    'مقادیر مورد نیاز از فرم مرحله قبل به صورت خودکار منتقل می‌شود.'),
            if (document.remark.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('توضیحات سند: ${document.remark}',
                    style: const TextStyle(
                        fontSize: 11, color: AsoudColors.muted)),
              ),
          ]),
        ),
      ),
    ];
  }

  String _typeLabel(String key) => switch (key) {
        'Journal Entry' => 'سند حسابداری',
        'Material Request' => 'درخواست خرید کالا',
        _ => key,
      };

  String _moduleLabel(String key) => switch (key) {
        'Finance' => 'مالی',
        'Purchase' => 'خرید',
        _ => key,
      };

  List<Widget> _changeStatus() => [
        _label('وضعیت جدید درخواست', required: true),
        TextField(
          controller: status,
          decoration: const InputDecoration(hintText: 'مثلاً: تأیید شده'),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final label in const [
            'تأیید شده',
            'در حال بررسی',
            'در حال تأمین',
            'تکمیل شده'
          ])
            ActionChip(
                label: Text(label),
                onPressed: () => setState(() => status.text = label)),
        ]),
      ];

  List<Widget> _notification() => [
        _label('گیرندگان', required: true),
        _switch('ارسال به درخواست‌کننده', notifyInitiator,
            (value) => setState(() => notifyInitiator = value)),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final item in roles.where((item) => item != 'Administrator'))
            FilterChip(
              label: Text(roleLabel(item)),
              selected: targetRoles.contains(item),
              onSelected: (checked) => setState(() =>
                  checked ? targetRoles.add(item) : targetRoles.remove(item)),
            ),
        ]),
        const SizedBox(height: 12),
        _label('متن اعلان', required: true),
        TextField(
          controller: message,
          minLines: 2,
          maxLines: 4,
          decoration:
              const InputDecoration(hintText: 'درخواست {{RequestNo}} ثبت شد.'),
        ),
      ];
}

/// Edits the form fields of a user task.
class _StageFormPage extends StatefulWidget {
  const _StageFormPage({required this.fields});
  final List<WorkflowFormFieldDefinition> fields;
  @override
  State<_StageFormPage> createState() => _StageFormPageState();
}

class _StageFormPageState extends State<_StageFormPage> {
  late List<WorkflowFormFieldDefinition> fields = [...widget.fields];
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(title: 'فرم مرحله'),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          WorkflowFormBuilder(
              fields: fields,
              onChanged: (value) => setState(() => fields = value)),
        ]),
        bottomNavigationBar: AsoudBottomActions(
          primaryLabel: 'تأیید فرم',
          onPrimary: () => Navigator.pop(context, fields),
          secondaryLabel: 'انصراف',
          onSecondary: () => Navigator.pop(context),
        ),
      );
}
