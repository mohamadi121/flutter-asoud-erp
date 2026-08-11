import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_repository.dart';
import '../cubit/workflow_designer_cubit.dart';
import '../widgets/workflow_graph_canvas.dart';
import 'workflow_stage_settings_page.dart';

class WorkflowDesignerPage extends StatelessWidget {
  const WorkflowDesignerPage({required this.definition, super.key});
  final String definition;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => WorkflowDesignerCubit(
          repository: context.read<WorkflowRepository>(),
          definition: definition,
        )..load(),
        child: const _DesignerView(),
      );
}

class _DesignerView extends StatelessWidget {
  const _DesignerView();

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<WorkflowDesignerCubit, WorkflowDesignerState>(
        listenWhen: (previous, current) =>
            previous.message != current.message && current.message != null,
        listener: (context, state) => ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.message!))),
        builder: (context, state) {
          final design = state.design;
          if (design == null) {
            return Scaffold(
              appBar: const AsoudHeader(title: 'طراحی فرایند'),
              body: state.status == WorkflowDesignerStatus.failure
                  ? _Failure(
                      onRetry: context.read<WorkflowDesignerCubit>().load)
                  : const Center(child: CircularProgressIndicator()),
            );
          }
          final stages = [...design.stages]
            ..sort((a, b) => a.sequence.compareTo(b.sequence));
          final canAdd = stages.isNotEmpty;
          return Scaffold(
            appBar: AsoudHeader(
              title: 'طراحی فرایند',
              subtitle: design.workflow.title,
              action: IconButton(
                tooltip: 'تنظیمات فرایند',
                onPressed: () {},
                icon: const Icon(Icons.settings_outlined),
              ),
            ),
            body: Column(children: [
              if (state.offlinePreview) const AsoudOfflinePreviewBanner(),
              _DraftBanner(
                  workflow: design.workflow,
                  saving: state.status == WorkflowDesignerStatus.saving),
              Expanded(
                child: WorkflowGraphCanvas(
                  design: design,
                  onOpenStage: (stage) =>
                      _openStage(context, stage, state.options),
                  onMoveStage: context.read<WorkflowDesignerCubit>().moveStage,
                  onMoveEnd:
                      context.read<WorkflowDesignerCubit>().savePositions,
                  onInsertOnTransition: (edge) => _insertStage(context, edge),
                  onCreateTransition: (stage) =>
                      _connectStage(context, stage, design),
                ),
              ),
            ]),
            floatingActionButton: canAdd
                ? SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => _showStagePicker(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('افزودن مرحله'),
                    ),
                  )
                : null,
          );
        },
      );

  Future<void> _openStage(BuildContext context, WorkflowStage stage,
      WorkflowFormOptions? options) async {
    if (stage.type == WorkflowStageType.start) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<WorkflowDesignerCubit>(),
          child: StartSettingsPage(
              stage: stage, roles: options?.roles ?? const []),
        ),
      ));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: context.read<WorkflowDesignerCubit>(),
        child: WorkflowStageSettingsPage(
          stage: stage,
          roles: options?.roles ?? const [],
          departments: options?.departments ?? const [],
          employees: options?.employees ?? const [],
        ),
      ),
    ));
  }

  Future<void> _showStagePicker(BuildContext context) async {
    final cubit = context.read<WorkflowDesignerCubit>();
    final type = await showModalBottomSheet<WorkflowStageType>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _StagePickerSheet(),
    );
    if (type != null) await cubit.addStage(type);
  }

  Future<void> _insertStage(
      BuildContext context, WorkflowTransition transition) async {
    final type = await showModalBottomSheet<WorkflowStageType>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _StagePickerSheet(),
    );
    if (type != null && context.mounted) {
      await context
          .read<WorkflowDesignerCubit>()
          .insertStage(transition.id, type);
    }
  }

  Future<void> _connectStage(
      BuildContext context, WorkflowStage from, WorkflowDesign design) async {
    final candidates = design.stages
        .where((stage) => stage.id != from.id)
        .toList(growable: false);
    if (candidates.isEmpty) return;
    final result = await showModalBottomSheet<({String target, String action})>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _ConnectSheet(stages: candidates),
    );
    if (result != null && context.mounted) {
      await context.read<WorkflowDesignerCubit>().connectStages(
            fromStage: from.id,
            toStage: result.target,
            action: result.action,
          );
    }
  }
}

class _ConnectSheet extends StatefulWidget {
  const _ConnectSheet({required this.stages});
  final List<WorkflowStage> stages;

  @override
  State<_ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends State<_ConnectSheet> {
  late String target = widget.stages.first.id;
  String action = 'تأیید';

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('ایجاد مسیر جدید',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: target,
              decoration: const InputDecoration(labelText: 'مرحله مقصد'),
              items: widget.stages
                  .map((stage) => DropdownMenuItem(
                        value: stage.id,
                        child: Text(stage.title),
                      ))
                  .toList(growable: false),
              onChanged: (value) => setState(() => target = value ?? target),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: action,
              decoration: const InputDecoration(labelText: 'عملیات مسیر'),
              items: const [
                'تأیید',
                'رد',
                'بازگشت برای اصلاح',
                'ارجاع',
                'ادامه'
              ]
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(growable: false),
              onChanged: (value) => setState(() => action = value ?? action),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.pop(context, (target: target, action: action)),
                child: const Text('ثبت مسیر'),
              ),
            ),
          ]),
        ),
      );
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner({required this.workflow, required this.saving});
  final WorkflowDefinition workflow;
  final bool saving;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AsoudColors.primary.withValues(alpha: .06),
          border: Border.all(color: AsoudColors.primary.withValues(alpha: .2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(saving ? Icons.sync_rounded : Icons.cloud_done_outlined,
              color: AsoudColors.primary, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                saving
                    ? 'در حال ذخیره تغییرات...'
                    : 'تغییرات این پیش‌نویس روی سرور ذخیره شده است.',
                style:
                    const TextStyle(fontSize: 9, color: AsoudColors.primary)),
          ),
          Text(workflow.code,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 9, color: AsoudColors.muted)),
        ]),
      );
}

// Kept temporarily to preserve the locked linear preview implementation.
// ignore: unused_element
class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage, required this.onTap});
  final WorkflowStage stage;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final visual = _stageVisual(stage.type);
    final roles = stage.config['initiator_roles'];
    final subtitle = stage.type == WorkflowStageType.start
        ? _triggerLabel(stage.config['trigger_type']?.toString())
        : stage.configurationComplete
            ? 'تنظیمات تکمیل شده'
            : 'برای تکمیل تنظیمات لمس کنید';
    return Align(
      child: SizedBox(
        width: 250,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side:
                BorderSide(color: visual.$2.withValues(alpha: .7), width: 1.4),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: visual.$2.withValues(alpha: .12),
                  child: Icon(visual.$1, color: visual.$2),
                ),
                const SizedBox(height: 9),
                Text(stage.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 9, color: AsoudColors.muted)),
                if (roles is List && roles.isNotEmpty) ...[
                  const Divider(height: 20),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: roles
                        .map((role) => Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(role.toString(),
                                  style: const TextStyle(fontSize: 8)),
                            ))
                        .toList(growable: false),
                  ),
                ],
                if (!stage.configurationComplete &&
                    stage.type != WorkflowStageType.end) ...[
                  const SizedBox(height: 8),
                  Text('نیازمند تنظیم',
                      style: TextStyle(
                          fontSize: 8,
                          color: AsoudColors.warning,
                          fontWeight: FontWeight.w800)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _Connector extends StatelessWidget {
  const _Connector();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 2,
          height: 34,
          color: AsoudColors.primary.withValues(alpha: .35),
        ),
      );
}

// ignore: unused_element
class _AddStageTarget extends StatelessWidget {
  const _AddStageTarget({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Align(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 250,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .85),
              border: Border.all(
                  color: AsoudColors.border, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Column(children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: Color(0xFFF0F3FA),
                child: Icon(Icons.add_rounded, color: AsoudColors.muted),
              ),
              SizedBox(height: 7),
              Text('مرحله بعدی را اضافه کنید',
                  style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
            ]),
          ),
        ),
      );
}

class _StagePickerSheet extends StatelessWidget {
  const _StagePickerSheet();
  @override
  Widget build(BuildContext context) {
    const items = [
      (
        WorkflowStageType.userTask,
        'وظیفه کاربر',
        'دریافت، بررسی یا اصلاح اطلاعات'
      ),
      (WorkflowStageType.approval, 'تأیید یا رد', 'ثبت تصمیم رسمی'),
      (WorkflowStageType.condition, 'شرط و مسیر', 'انتخاب مسیر براساس شرط'),
      (
        WorkflowStageType.systemAction,
        'اقدام خودکار',
        'اعلان یا عملیات سیستمی'
      ),
      (WorkflowStageType.wait, 'انتظار و زمان‌بندی', 'توقف تا زمان یا رویداد'),
      (WorkflowStageType.end, 'پایان فرایند', 'نتیجه نهایی فرایند'),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('افزودن مرحله',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const Text('نوع مرحله بعدی را انتخاب کنید',
              style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: .95,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              final visual = _stageVisual(item.$1);
              return InkWell(
                onTap: () => Navigator.pop(context, item.$1),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AsoudColors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AsoudIconBox(
                            icon: visual.$1, color: visual.$2, size: 36),
                        const SizedBox(height: 7),
                        Text(item.$2,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(item.$3,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 7, color: AsoudColors.muted)),
                      ]),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}

class StartSettingsPage extends StatefulWidget {
  const StartSettingsPage(
      {required this.stage, required this.roles, super.key});
  final WorkflowStage stage;
  final List<String> roles;

  @override
  State<StartSettingsPage> createState() => _StartSettingsPageState();
}

class _StartSettingsPageState extends State<StartSettingsPage> {
  late String triggerType;
  late Set<String> selectedRoles;

  @override
  void initState() {
    super.initState();
    triggerType = widget.stage.config['trigger_type']?.toString() ?? 'Manual';
    selectedRoles =
        ((widget.stage.config['initiator_roles'] as List?) ?? const [])
            .map((value) => value.toString())
            .toSet();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
            title: 'تنظیمات شروع',
            subtitle: 'محرک و آغازکنندگان مجاز را مشخص کنید'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            const _StartNotice(),
            const SizedBox(height: 14),
            const AsoudSectionTitle(title: 'روش آغاز فرایند'),
            DropdownButtonFormField<String>(
              initialValue: triggerType,
              decoration: const InputDecoration(labelText: 'محرک شروع'),
              items: const [
                DropdownMenuItem(
                    value: 'Manual', child: Text('شروع دستی توسط کاربر')),
                DropdownMenuItem(
                    value: 'Document Event',
                    child: Text('رویداد یک سند موجود')),
                DropdownMenuItem(value: 'System', child: Text('رویداد سیستمی')),
                DropdownMenuItem(value: 'API', child: Text('فراخوانی API')),
              ],
              onChanged: (value) =>
                  setState(() => triggerType = value ?? triggerType),
            ),
            const SizedBox(height: 14),
            const AsoudSectionTitle(title: 'نقش‌های مجاز برای شروع'),
            if (widget.roles.isEmpty)
              const Text('نقش‌های قابل انتخاب از سرور دریافت نشد.',
                  style: TextStyle(fontSize: 10, color: AsoudColors.warning))
            else
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: widget.roles.map((role) {
                  final selected = selectedRoles.contains(role);
                  return FilterChip(
                    selected: selected,
                    label: Text(role),
                    onSelected: (value) => setState(() {
                      value
                          ? selectedRoles.add(role)
                          : selectedRoles.remove(role);
                    }),
                  );
                }).toList(growable: false),
              ),
          ],
        ),
        bottomNavigationBar: AsoudBottomActions(
          primaryLabel: 'ذخیره تنظیمات شروع',
          onPrimary: () async {
            await context.read<WorkflowDesignerCubit>().saveStart(
                  triggerType: triggerType,
                  initiatorRoles: selectedRoles.toList(growable: false),
                  subjectSource: 'Referenced Document',
                  passMode: 'Direct',
                );
            if (context.mounted) Navigator.pop(context);
          },
          secondaryLabel: 'انصراف',
          onSecondary: () => Navigator.pop(context),
        ),
      );
}

class _StartNotice extends StatelessWidget {
  const _StartNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AsoudColors.primary.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded,
              color: AsoudColors.primary, size: 19),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'گردش‌کار روی همان سند انتخاب‌شده اجرا می‌شود. اگر شروع مشروط لازم است، بعد از شروع یک گره شرط اضافه کنید.',
              style: TextStyle(fontSize: 9),
            ),
          ),
        ]),
      );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('تلاش دوباره'),
        ),
      );
}

// ignore: unused_element
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFDCE4F2);
    for (double x = 12; x < size.width; x += 18) {
      for (double y = 12; y < size.height; y += 18) {
        canvas.drawCircle(Offset(x, y), .8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

(IconData, Color) _stageVisual(WorkflowStageType type) => switch (type) {
      WorkflowStageType.start => (
          Icons.play_arrow_rounded,
          AsoudColors.success
        ),
      WorkflowStageType.userTask => (
          Icons.assignment_ind_outlined,
          AsoudColors.primary
        ),
      WorkflowStageType.approval => (
          Icons.approval_outlined,
          AsoudColors.purple
        ),
      WorkflowStageType.condition => (
          Icons.call_split_rounded,
          AsoudColors.warning
        ),
      WorkflowStageType.systemAction => (
          Icons.settings_suggest_outlined,
          AsoudColors.cyan
        ),
      WorkflowStageType.wait => (
          Icons.schedule_rounded,
          const Color(0xFF64748B)
        ),
      WorkflowStageType.end => (
          Icons.stop_circle_outlined,
          const Color(0xFFEF476F)
        ),
    };

String _triggerLabel(String? value) => switch (value) {
      'Document Event' => 'شروع با رویداد سند',
      'System' => 'شروع سیستمی',
      'API' => 'شروع از API',
      _ => 'شروع دستی',
    };
