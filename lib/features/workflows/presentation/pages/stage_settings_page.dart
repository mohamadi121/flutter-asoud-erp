import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/repositories/preview_fallback_workflow_repository.dart';
import '../../data/workflow_automation_repository.dart';
import '../../domain/entities/workflow_definition.dart';
import '../cubit/workflow_designer_cubit.dart';
import '../widgets/document_template_visuals.dart';
import '../widgets/stage_pickers.dart';
import '../widgets/stage_people_sheet.dart';
import '../widgets/workflow_form_builder.dart';
import 'create_document_settings_page.dart';
import 'automatic_action_page.dart';

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
  late bool modernAutomaticAction =
      widget.stage.config['schema_version'] == 2 ||
          !widget.stage.config.containsKey('action_type');
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
  Set<String> selectedPeople = {};
  late bool hasDeadline = ((config['deadline_value'] as num?) ?? 0) > 0;

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
  late String activityType =
      config['activity_type']?.toString() ?? 'Data Entry';
  late String taskPurpose = config['task_purpose']?.toString() ?? 'Existing';
  late String requestDefinition =
      config['request_definition']?.toString() ?? '';
  late String requestLabel = config['request_label']?.toString() ?? '';
  late List<WorkflowFormFieldDefinition> formFields =
      ((config['form_fields'] as List?) ?? const [])
          .whereType<Map>()
          .map(WorkflowFormFieldDefinition.fromMap)
          .toList();
  late List<Map<String, dynamic>> formLayout =
      ((config['form_layout'] as List?) ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
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
    if (template.isNotEmpty) {
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
        selectedPeople = values('employees').toSet();
        final id = values('employees').firstOrNull ?? '';
        if (id.isNotEmpty) {
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
    if (specificPerson && selectedPeople.isNotEmpty) {
      return {
        'assignment_type': 'Employee',
        '${prefix}_employees': selectedPeople.toList()
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
        'deadline_value': hasDeadline ? _deadlineValue : 0,
        'deadline_unit': deadlineUnit,
        'reminder_before_minutes': config['reminder_before_minutes'] ?? 0,
        'escalation_roles': config['escalation_roles'] ?? const [],
        'reassign_on_overdue': config['reassign_on_overdue'] == true,
      };

  int? get _deadlineValue {
    var value = deadline.text.trim();
    for (var i = 0; i < 10; i++) {
      value = value
          .replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i')
          .replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i');
    }
    return int.tryParse(value);
  }

  String? _validate() {
    if (type == WorkflowStageType.userTask) {
      if (taskPurpose == 'Create Request' && requestDefinition.isEmpty) {
        return 'نوع درخواست را انتخاب کنید.';
      }
      if (taskPurpose == 'Create Document' && document.template == null) {
        return 'نوع سند و الگوی سند را انتخاب کنید.';
      }
    }
    if (title.text.trim().length < 2) return 'عنوان مرحله را وارد کنید.';
    if (type != WorkflowStageType.systemAction && ownerMode == 'unit') {
      if (!specificPerson && unit == null) {
        return 'واحد سازمانی مسئول را انتخاب کنید.';
      }
      if (specificPerson && selectedPeople.isEmpty) {
        return 'افراد مسئول را انتخاب کنید.';
      }
    }
    if (type != WorkflowStageType.systemAction &&
        hasDeadline &&
        (_deadlineValue == null ||
            _deadlineValue! <= 0 ||
            _deadlineValue! > 3650)) {
      return 'مهلت انجام باید یک عدد صحیح بین ۱ تا ۳۶۵۰ باشد.';
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
          'activity_type': activityType,
          'task_purpose': taskPurpose,
          if (taskPurpose == 'Create Request') ...{
            'request_definition': requestDefinition,
            'request_label': requestLabel,
          },
          if (taskPurpose == 'Create Document') ...{
            'document_template': document.template!.name,
            'transfer_values': document.transferValues,
            'document_remark': document.remark,
          },
          ..._assignment(),
          'document_access': access,
          'form_fields': formFields.map((field) => field.toMap()).toList(),
          if (formLayout.isNotEmpty)
            'form_layout': [
              for (final item in formLayout)
                if (item['key'].toString().startsWith('base:') ||
                    formFields.any((field) => field.key == item['key']))
                  Map<String, dynamic>.from(item),
            ],
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
          'form_fields': formFields.map((field) => field.toMap()).toList(),
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
        final local = cubit.repository;
        if (automation.isLocal && local is PreviewFallbackWorkflowRepository) {
          await local.saveStageRoutesLocally(
              definition: widget.design.workflow.id,
              stage: widget.stage.id,
              routes: changed);
        } else {
          await automation.saveStageRoutes(
              definition: widget.design.workflow.id,
              stage: widget.stage.id,
              routes: changed);
        }
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
  Widget build(BuildContext context) => type ==
              WorkflowStageType.systemAction &&
          modernAutomaticAction
      ? AutomaticActionPage(
          stage: widget.stage,
          design: widget.design,
          repository: automation,
          initialRoutes: routes,
          onSaved: () => context.read<WorkflowDesignerCubit>().load())
      : Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AsoudColors.background,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(children: [
                    IconButton(
                        tooltip: 'بستن',
                        onPressed: saving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded)),
                    Expanded(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('تنظیمات مرحله',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w900)),
                        Text(_typeInfo.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AsoudColors.muted)),
                      ]),
                    ),
                    IconButton(
                        tooltip: 'بازگشت',
                        onPressed: saving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 18)),
                  ]),
                ),
              ),
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: AsoudBottomActions(
                primaryLabel: saving ? 'در حال ذخیره...' : 'ذخیره',
                onPrimary: saving ? null : save,
                secondaryLabel: 'انصراف',
                onSecondary: saving ? null : () => Navigator.pop(context),
              ),
            ),
            body: AbsorbPointer(
                absorbing: saving,
                child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
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
                    ])),
          ));

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
            AsoudColors.purple
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
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: info.$4.withValues(alpha: .06),
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

  Future<void> _pickPeople() async {
    if (unit == null && !specificPerson) {
      _message('ابتدا واحد سازمانی را انتخاب کنید.');
      return;
    }
    if (unit?.kind == 'initiator') {
      _message('افراد این واحد هنگام اجرا از واحد درخواست‌کننده مشخص می‌شوند.');
      return;
    }
    final candidates = <String, WorkflowTargetOption>{
      for (final item in employees)
        if (item.department == unit?.id || selectedPeople.contains(item.id))
          item.id: item,
      for (final id in selectedPeople)
        if (!employees.any((item) => item.id == id))
          id: WorkflowTargetOption(id: id, label: id),
    };
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => StagePeopleSheet(
        employees: candidates.values.toList(),
        selected: selectedPeople,
        allSelected: !specificPerson,
        allowAll: unit != null,
        unitLabel: unit?.label ?? 'واحد',
      ),
    );
    if (result != null && mounted) {
      setState(() {
        selectedPeople = result;
        specificPerson = result.isNotEmpty;
      });
    }
  }

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
              final choice = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (sheetContext) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: SizedBox(
                      height: MediaQuery.sizeOf(sheetContext).height * .7,
                      child: ChoiceListPage<String>(
                        title: 'انتخاب نقش مسئول',
                        searchHint: 'جستجوی نقش‌ها...',
                        items: [
                          directManagerRole,
                          initiatorRole,
                          ...roles.where((item) => item != 'Administrator')
                        ],
                        selected: role,
                        labelOf: roleLabel,
                        iconOf: roleVisual,
                      )),
                ),
              );
              if (choice != null && mounted) setState(() => role = choice);
            },
          )
        else ...[
          PickerField(
            label: 'انتخاب واحد سازمانی',
            value: unit?.label ?? '',
            placeholder: 'انتخاب واحد',
            icon: Icons.apartment_rounded,
            onTap: () async {
              final choice = await showModalBottomSheet<OrgUnitChoice>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (sheetContext) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: SizedBox(
                    height: MediaQuery.sizeOf(sheetContext).height * .75,
                    child: OrgUnitPickerPage(
                      departments: departments,
                      selected: unit,
                    ),
                  ),
                ),
              );
              if (choice != null && mounted) {
                setState(() {
                  unit = choice;
                  selectedPeople.clear();
                  specificPerson = false;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          _label('انتخاب افراد'),
          if (unit != null) ...[
            AsoudSegmentedControl<bool>(
              value: specificPerson,
              options: const [
                AsoudSegmentedOption(value: false, label: 'همه افراد واحد'),
                AsoudSegmentedOption(value: true, label: 'یک فرد مشخص'),
              ],
              onChanged: (value) => setState(() {
                specificPerson = value;
                if (!value) selectedPeople.clear();
              }),
            ),
            if (!specificPerson) ...[
              const SizedBox(height: 8),
              _notice(
                  'این مرحله برای تمامی افراد واحد انتخاب‌شده قابل انجام خواهد بود.'),
            ],
          ],
          if (specificPerson)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PickerField(
                value: selectedPeople
                    .map((id) =>
                        employees
                            .where((item) => item.id == id)
                            .firstOrNull
                            ?.label ??
                        id)
                    .join('، '),
                placeholder: 'انتخاب فرد',
                icon: Icons.people_outline_rounded,
                onTap: _pickPeople,
              ),
            ),
        ],
      ];

  Widget _deadlineRow() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          _label('مهلت انجام'),
          AsoudSegmentedControl<bool>(
            value: hasDeadline,
            options: const [
              AsoudSegmentedOption(value: true, label: 'مهلت دارد'),
              AsoudSegmentedOption(value: false, label: 'بدون مهلت'),
            ],
            onChanged: (value) => setState(() => hasDeadline = value),
          ),
          if (hasDeadline) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: deadline,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      hintText: 'مدت انجام',
                      prefixIcon:
                          Icon(Icons.calendar_today_outlined, size: 18)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: PickerField(
                  value: switch (deadlineUnit) {
                    'Day' => 'روز',
                    'Hour' => 'ساعت',
                    _ => 'دقیقه'
                  },
                  onTap: () async {
                    final value = await showModalBottomSheet<String>(
                      context: context,
                      showDragHandle: true,
                      useSafeArea: true,
                      builder: (context) => Directionality(
                          textDirection: TextDirection.rtl,
                          child: SafeArea(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('واحد زمان')),
                                for (final entry in const {
                                  'Day': 'روز',
                                  'Hour': 'ساعت',
                                  'Minute': 'دقیقه'
                                }.entries)
                                  ListTile(
                                      title: Text(entry.value),
                                      trailing: deadlineUnit == entry.key
                                          ? const Icon(Icons.check,
                                              color: AsoudColors.primary)
                                          : null,
                                      onTap: () =>
                                          Navigator.pop(context, entry.key)),
                              ]))),
                    );
                    if (value != null && mounted) {
                      setState(() => deadlineUnit = value);
                    }
                  },
                ),
              ),
            ]),
          ],
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
          const Text(
              'دسترسی مسئول در زمان انجام این مرحله به سند مرجع؛ نه مجوز پس از پایان. حالت محدود تابع فیلدهای مجاز سامانه است.',
              style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
          const SizedBox(height: 8),
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

  Widget _taskPurpose() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _label('نوع کار مرحله', required: true),
          DropdownButtonFormField<String>(
            initialValue: taskPurpose,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                  value: 'Create Request', child: Text('ایجاد درخواست جدید')),
              DropdownMenuItem(
                  value: 'Create Document', child: Text('ایجاد سند جدید')),
              DropdownMenuItem(
                  value: 'Existing', child: Text('تکمیل درخواست یا سند فعلی')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => taskPurpose = value);
            },
          ),
          const SizedBox(height: 8),
          _notice(switch (taskPurpose) {
            'Create Request' =>
              'پس از تکمیل این وظیفه، درخواست جدید از نوع انتخاب‌شده ثبت می‌شود.',
            'Create Document' =>
              'پس از تکمیل این وظیفه، سند طبق الگوی انتخاب‌شده و دسترسی کاربر ساخته می‌شود.',
            _ =>
              'ادامه کار روی درخواست یا سند فعلی؛ رکورد جدیدی ایجاد نمی‌شود.',
          }),
          if (taskPurpose == 'Create Request') ...[
            const SizedBox(height: 12),
            _label('نوع درخواست', required: true),
            PickerField(
                value: requestLabel.isEmpty ? requestDefinition : requestLabel,
                placeholder: 'انتخاب نوع درخواست',
                icon: Icons.description_outlined,
                onTap: _pickRequestType),
          ],
          if (taskPurpose == 'Create Document') ..._createDocument(),
        ]),
      );

  Future<void> _editForm() async {
    final fields = await Navigator.push<List<WorkflowFormFieldDefinition>>(
      context,
      MaterialPageRoute(builder: (_) => _StageFormPage(fields: formFields)),
    );
    if (fields != null && mounted) {
      setState(() => formFields = fields);
    }
  }

  Future<void> _pickRequestType() async {
    try {
      final choices = await automation.userTaskRequests(company ?? '');
      if (!mounted) return;
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * .7,
                child: ChoiceListPage<Map<String, dynamic>>(
                  title: 'انتخاب نوع درخواست',
                  searchHint: 'جستجو در درخواست‌ها...',
                  items: choices
                      .where(
                          (item) => item['name'] != widget.design.workflow.id)
                      .toList(),
                  labelOf: (item) =>
                      '${item['workflow_title'] ?? item['name']}',
                  iconOf: (_) => (
                    icon: Icons.description_outlined,
                    color: AsoudColors.primary
                  ),
                ))),
      );
      if (picked == null || !mounted) return;
      if (formFields.isNotEmpty) {
        final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('جایگزینی فرم مرحله'),
                  content: const Text(
                      'فرم مرحله با فیلدهای نوع درخواست انتخاب‌شده جایگزین شود؟'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('انصراف')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('جایگزینی'))
                  ],
                ));
        if (confirm != true || !mounted) return;
      }
      setState(() {
        requestDefinition = picked['name'].toString();
        requestLabel = '${picked['workflow_title'] ?? picked['name']}';
        formFields = ((picked['fields'] as List?) ?? const [])
            .whereType<Map>()
            .map(WorkflowFormFieldDefinition.fromMap)
            .toList();
        formLayout = [];
      });
    } catch (error) {
      if (mounted) {
        _message(error is ApiException
            ? error.message
            : 'دریافت انواع درخواست ممکن نشد؛ انتخاب قبلی حفظ شده است.');
      }
    }
  }

  Future<void> _pickForm() async {
    final available = widget.design.stages
        .where((stage) =>
            stage.id != widget.stage.id &&
            (stage.type == WorkflowStageType.userTask ||
                stage.type == WorkflowStageType.approval) &&
            ((stage.config['form_fields'] as List?) ?? const []).isNotEmpty)
        .toList();
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
            child: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
                child: SizedBox(
                  height: MediaQuery.sizeOf(sheetContext).height * .6,
                  child: _StageFormChoices(
                    stages: available,
                    hasForm: formFields.isNotEmpty,
                  ),
                ))),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == '__edit__') {
      await _editForm();
      return;
    }
    final source = available.where((stage) => stage.id == choice).firstOrNull;
    if (source == null) return;
    if (formFields.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('جایگزینی فرم مرحله'),
          content: const Text(
              'فیلدهای فعلی با یک نسخه از فرم انتخاب‌شده جایگزین شوند؟ فرم اصلی تغییر نمی‌کند.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('جایگزینی')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      formFields = (source.config['form_fields'] as List)
          .whereType<Map>()
          .map(WorkflowFormFieldDefinition.fromMap)
          .toList();
      formLayout = ((source.config['form_layout'] as List?) ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
    });
  }

  List<Widget> _userTask() => [
        _taskPurpose(),
        _label('فرم مرحله'),
        PickerField(
          value: formFields.isEmpty
              ? 'بدون فرم'
              : 'فرم مرحله · ${formFields.length} فیلد',
          icon: Icons.dynamic_form_outlined,
          onTap: _pickForm,
        ),
        if (formFields.isNotEmpty)
          Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                  onPressed: _editForm,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('ویرایش فرم مرحله'))),
        ..._owner(),
        _deadlineRow(),
        const SizedBox(height: 6),
        _switch('الزام به تکمیل', true, null,
            subtitle:
                'کاربر نمی‌تواند بدون تکمیل این مرحله به مرحله بعد برود.'),
        _extra([
          DropdownButtonFormField<String>(
            initialValue: activityType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'نوع فعالیت'),
            items: const [
              DropdownMenuItem(
                  value: 'Data Entry', child: Text('تکمیل اطلاعات')),
              DropdownMenuItem(value: 'Review', child: Text('بررسی')),
              DropdownMenuItem(value: 'Correction', child: Text('اصلاح')),
              DropdownMenuItem(value: 'Task', child: Text('انجام کار')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => activityType = value);
            },
          ),
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
        if (allowReturn)
          _route('Return', 'در صورت بازگشت برای اصلاح', Icons.undo_rounded,
              AsoudColors.primary,
              emptyLabel: 'آخرین مرحله قابل اصلاح'),
      ];

  // --- approval ---------------------------------------------------------------------------

  List<Widget> _approval() => [
        ..._owner(),
        _deadlineRow(),
        if (hasDeadline) ...[
          const SizedBox(height: 8),
          _notice('مهلت از زمان ارجاع کار در این مرحله محاسبه می‌شود.'),
        ],
        const SizedBox(height: 16),
        _label('تصمیم‌های قابل انجام'),
        _decision('امکان تأیید', true, AsoudColors.success, null),
        _decision('امکان رد', allowReject, AsoudColors.danger,
            (value) => setState(() => allowReject = value)),
        _decision('امکان بازگشت برای اصلاح', allowReturn, AsoudColors.warning,
            (value) => setState(() => allowReturn = value)),
        const SizedBox(height: 12),
        _approvalRoute('Approve', 'در صورت تأیید', Icons.check_circle_outline,
            AsoudColors.success),
        if (allowReject)
          _approvalRoute(
              'Reject', 'در صورت رد', Icons.cancel_outlined, AsoudColors.danger,
              emptyLabel: 'پایان فرایند (رد درخواست)'),
        if (allowReturn)
          _approvalRoute('Return', 'در صورت بازگشت برای اصلاح',
              Icons.undo_rounded, AsoudColors.warning,
              emptyLabel: 'آخرین مرحله قابل اصلاح'),
        _extra([
          _label('فرم تکمیلی تأیید (اختیاری)'),
          PickerField(
            value: formFields.isEmpty
                ? ''
                : 'فرم تکمیلی · ${formFields.length} فیلد',
            placeholder: 'انتخاب یا ساخت فرم تکمیلی',
            icon: Icons.description_outlined,
            onTap: _pickForm,
          ),
          if (formFields.isNotEmpty)
            Row(children: [
              Expanded(
                  child: TextButton.icon(
                      onPressed: _editForm,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('ویرایش فرم'))),
              TextButton(
                  onPressed: _removeApprovalForm, child: const Text('حذف فرم')),
            ]),
          _switch(
              'الزام توضیح هنگام رد',
              rejectComment,
              allowReject
                  ? (value) => setState(() => rejectComment = value)
                  : null),
          _switch('الزام توضیح هنگام برگشت برای اصلاح', true, null,
              subtitle:
                  'طبق قواعد فعلی سامانه، دلیل بازگشت همواره الزامی است.'),
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
        const SizedBox(height: 12),
        _notice(approvalMode == 'Any'
            ? 'تأیید یک نفر کافی است؛ پس از تأیید، کار سایر مسئولان این مرحله بسته می‌شود.'
            : 'تأیید همه مسئولان لازم است؛ تا تکمیل همه تأییدها، مرحله ادامه نمی‌یابد.'),
      ];

  Widget _decision(String label, bool value, Color color,
          ValueChanged<bool>? onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          fillColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? color : null),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          tileColor: color.withValues(alpha: .06),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          activeColor: color,
          value: value,
          onChanged: onChanged == null
              ? null
              : (checked) => onChanged(checked ?? false),
          title: Text(label, style: const TextStyle(fontSize: 13)),
        ),
      );

  Future<void> _removeApprovalForm() async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فرم تکمیلی'),
        content: const Text('فرم تکمیلی از تنظیمات این مرحله حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (remove == true && mounted) {
      setState(() {
        formFields = [];
        formLayout = [];
      });
    }
  }

  Widget _approvalRoute(String action, String label, IconData icon, Color color,
      {String? emptyLabel}) {
    final target = routes[action] ?? '';
    final selected =
        _destinations.where((stage) => stage.id == target).firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .05),
        border: Border.all(color: color.withValues(alpha: .15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(child: _label(label, required: true)),
        ]),
        const SizedBox(height: 6),
        PickerField(
          value:
              selected?.title ?? (target.isEmpty ? emptyLabel ?? '' : target),
          placeholder:
              action == 'Return' ? 'انتخاب مقصد برگشت' : 'انتخاب مرحله بعد',
          icon: action == 'Return'
              ? Icons.undo_rounded
              : Icons.account_tree_outlined,
          onTap: () async {
            final result = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              builder: (_) => _StageRouteSheet(
                stages: _destinations,
                selected: target,
                emptyLabel: emptyLabel,
                returning: action == 'Return',
              ),
            );
            if (result != null && mounted) {
              setState(() => routes[action] = result);
            }
          },
        ),
      ]),
    );
  }

  // --- automatic action ----------------------------------------------------------------

  List<Widget> _systemAction() => [
        OutlinedButton.icon(
          icon: const Icon(Icons.upgrade),
          label: const Text('ویرایش با فرم جدید اقدام خودکار'),
          onPressed: saving
              ? null
              : () async {
                  final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                            title: const Text('انتقال به فرم جدید'),
                            content: const Text(
                                'عنوان و مسیرها حفظ می‌شوند، اما تنظیمات اختصاصی عملیات باید دوباره تکمیل شوند. تا ذخیره، نسخه قبلی تغییر نمی‌کند.'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('انصراف')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('ادامه'))
                            ],
                          ));
                  if (confirmed == true && mounted) {
                    setState(() => modernAutomaticAction = true);
                  }
                },
        ),
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
      // The offline preview keeps templates on the device, without a company.
      final value = company ?? (automation.isLocal ? '' : null);
      if (value == null || (value.isEmpty && !automation.isLocal)) {
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

class _StageRouteSheet extends StatefulWidget {
  const _StageRouteSheet(
      {required this.stages,
      required this.selected,
      required this.returning,
      this.emptyLabel});
  final List<WorkflowStage> stages;
  final String selected;
  final bool returning;
  final String? emptyLabel;

  @override
  State<_StageRouteSheet> createState() => _StageRouteSheetState();
}

class _StageRouteSheetState extends State<_StageRouteSheet> {
  String query = '';
  WorkflowStageType? filter;

  (String, IconData, Color) _visual(WorkflowStageType type) => switch (type) {
        WorkflowStageType.userTask => (
            'وظیفه کاربر',
            Icons.person_outline,
            AsoudColors.primary
          ),
        WorkflowStageType.approval => (
            'تأیید',
            Icons.verified_user_outlined,
            AsoudColors.purple
          ),
        WorkflowStageType.systemAction => (
            'اقدام خودکار',
            Icons.settings_outlined,
            AsoudColors.success
          ),
        WorkflowStageType.end => (
            'پایان فرایند',
            Icons.stop_circle_outlined,
            AsoudColors.danger
          ),
        WorkflowStageType.condition => (
            'شرط',
            Icons.call_split_rounded,
            AsoudColors.warning
          ),
        WorkflowStageType.wait => (
            'انتظار',
            Icons.schedule_rounded,
            AsoudColors.cyan
          ),
        WorkflowStageType.start => (
            'شروع',
            Icons.play_circle_outline,
            AsoudColors.primary
          ),
      };

  @override
  Widget build(BuildContext context) {
    final visible = widget.stages.where((stage) =>
        (filter == null || stage.type == filter) &&
        stage.title.contains(query));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
          child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 12),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: Text(
                      widget.returning
                          ? 'انتخاب مقصد برگشت'
                          : filter == null
                              ? 'انتخاب نوع مرحله بعد'
                              : 'انتخاب مرحله بعد',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800))),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'بستن',
                  icon: const Icon(Icons.close_rounded)),
            ]),
            TextField(
                onChanged: (value) => setState(() => query = value.trim()),
                decoration: const InputDecoration(
                    hintText: 'جستجو در مراحل گردش کار...',
                    prefixIcon: Icon(Icons.search_rounded))),
            const SizedBox(height: 8),
            if (filter != null || widget.returning || query.isNotEmpty)
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    ChoiceChip(
                        label: const Text('همه'),
                        selected: filter == null,
                        onSelected: (_) => setState(() => filter = null)),
                    for (final type
                        in widget.stages.map((stage) => stage.type).toSet())
                      Padding(
                          padding: const EdgeInsetsDirectional.only(start: 6),
                          child: ChoiceChip(
                              label: Text(_visual(type).$1),
                              selected: filter == type,
                              onSelected: (_) =>
                                  setState(() => filter = type))),
                  ])),
            Expanded(
                child: ListView(children: [
              if (widget.emptyLabel != null && query.isEmpty && filter == null)
                ListTile(
                  title: Text(widget.emptyLabel!),
                  subtitle: widget.returning
                      ? const Text(
                          'آخرین مرحله قابل اصلاح از سابقه اجرا انتخاب می‌شود.')
                      : null,
                  leading: Icon(widget.returning
                      ? Icons.history_rounded
                      : Icons.stop_circle_outlined),
                  trailing: widget.selected.isEmpty
                      ? const Icon(Icons.check, color: AsoudColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, ''),
                ),
              if (visible.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'مرحله‌ای یافت نشد؛ مرحله مقصد را در طراح گردش کار ایجاد کنید.')),
              if (!widget.returning && filter == null && query.isEmpty)
                for (final type
                    in widget.stages.map((stage) => stage.type).toSet())
                  Card(
                      child: ListTile(
                    leading: Icon(_visual(type).$2, color: _visual(type).$3),
                    title: Text(_visual(type).$1),
                    subtitle: const Text('انتخاب از مراحل موجود گردش کار'),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => setState(() => filter = type),
                  )),
              if (widget.returning || filter != null || query.isNotEmpty)
                for (final stage in visible)
                  Card(
                      color: widget.selected == stage.id
                          ? AsoudColors.primary.withValues(alpha: .06)
                          : null,
                      child: ListTile(
                        leading: Icon(_visual(stage.type).$2,
                            color: _visual(stage.type).$3),
                        title: Text(stage.title),
                        subtitle: Text(_visual(stage.type).$1),
                        trailing: widget.selected == stage.id
                            ? const Icon(Icons.check,
                                color: AsoudColors.primary)
                            : null,
                        onTap: () => Navigator.pop(context, stage.id),
                      )),
            ])),
          ]),
        ),
      )),
    );
  }
}

/// Searches existing forms without changing the source stage.
class _StageFormChoices extends StatefulWidget {
  const _StageFormChoices({required this.stages, required this.hasForm});
  final List<WorkflowStage> stages;
  final bool hasForm;

  @override
  State<_StageFormChoices> createState() => _StageFormChoicesState();
}

class _StageFormChoicesState extends State<_StageFormChoices> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final stages = widget.stages.where((stage) => stage.title.contains(query));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Row(children: [
          const Expanded(
              child: Text('انتخاب فرم',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          IconButton(
              onPressed: () => Navigator.pop(context),
              tooltip: 'بستن',
              icon: const Icon(Icons.close_rounded)),
        ]),
        TextField(
          decoration: const InputDecoration(
              hintText: 'جستجو در فرم‌های این گردش کار...',
              prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (value) => setState(() => query = value.trim()),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading:
              const Icon(Icons.edit_note_rounded, color: AsoudColors.primary),
          title: Text(widget.hasForm ? 'ویرایش فرم فعلی' : 'ساخت فرم اختصاصی'),
          onTap: () => Navigator.pop(context, '__edit__'),
        ),
        Expanded(
            child: ListView(children: [
          if (stages.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('فرم دیگری در این گردش کار یافت نشد.')),
          for (final stage in stages)
            ListTile(
              leading: const Icon(Icons.description_outlined,
                  color: AsoudColors.primary),
              title: Text(stage.title),
              subtitle: const Text('استفاده از یک نسخه مستقل از فیلدهای فرم'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.pop(context, stage.id),
            ),
        ])),
      ]),
    );
  }
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
