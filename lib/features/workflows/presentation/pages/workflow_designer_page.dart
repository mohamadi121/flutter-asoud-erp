import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../data/workflow_path_repository.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_repository.dart';
import '../cubit/workflow_designer_cubit.dart';
import '../widgets/workflow_check_sheet.dart';
import '../widgets/workflow_dry_run_sheet.dart';
import '../widgets/workflow_graph_canvas.dart';
import '../widgets/workflow_system_copy_dialog.dart';
import 'stage_settings_page.dart';
import 'workflow_stage_settings_page.dart';
import 'workflow_form_page.dart';
import 'workflow_end_settings_page.dart';

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

class _DesignerView extends StatefulWidget {
  const _DesignerView();

  @override
  State<_DesignerView> createState() => _DesignerViewState();
}

class _DesignerViewState extends State<_DesignerView> {
  bool editingPath = false;
  WorkflowPathRepository paths(BuildContext context) => WorkflowPathRepository(context.read<FrappeApiClient>());

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<WorkflowDesignerCubit, WorkflowDesignerState>(
        listenWhen: (previous, current) =>
            previous.message != current.message && current.message != null,
        listener: (context, state) => _onMessage(context, state),
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
                onPressed: () => _showWorkflowMenu(context, design,
                    state.offlinePreview),
                icon: const Icon(Icons.settings_outlined),
              ),
            ),
            body: Column(children: [
              if (state.offlinePreview) const AsoudOfflinePreviewBanner(),
              if (design.workflow.isSystemTemplate)
                _SystemWorkflowBanner(workflow: design.workflow),
              _DraftBanner(
                  workflow: design.workflow,
                  saving: state.status == WorkflowDesignerStatus.saving,
                  failed: state.status == WorkflowDesignerStatus.failure,
                  failureMessage: state.message,
                  offlinePreview: state.offlinePreview),
              Expanded(
                child: WorkflowGraphCanvas(
                  design: design,
                  onOpenStage: (stage) =>
                      _openStage(context, stage, state.options),
                  onMoveStage: context.read<WorkflowDesignerCubit>().moveStage,
                  onMoveEnd:
                      context.read<WorkflowDesignerCubit>().savePositions,
                  onInsertOnTransition: (edge) => _insertStage(context, edge),
                  onRemoveTransition: (edge) => _removePath(context, edge),
                ),
              ),
            ]),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
            floatingActionButton: canAdd
                ? SizedBox(
                    width: MediaQuery.sizeOf(context).width - 32,
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

  void _onMessage(BuildContext context, WorkflowDesignerState state) {
    final message = state.message!;
    final workflow = state.design?.workflow;
    final messenger = ScaffoldMessenger.of(context);
    if (message.contains('ابتدا یک کپی مستقل') &&
        workflow != null &&
        workflow.isSystemTemplate) {
      messenger.showSnackBar(SnackBar(
          content: Text(message),
          action: SnackBarAction(
              label: 'ایجاد کپی مستقل',
              onPressed: () => _copySystem(context, workflow).ignore())));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copySystem(BuildContext context, WorkflowDefinition workflow) async {
    final created = await showDialog<WorkflowDefinition>(
        context: context,
        barrierDismissible: false,
        builder: (_) => WorkflowSystemCopyDialog(
            source: workflow, client: context.read<FrappeApiClient>()));
    if (created == null || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => WorkflowDesignerPage(definition: created.id)));
  }

  Future<void> _openStage(BuildContext context, WorkflowStage stage,
      WorkflowFormOptions? options, {WorkflowDesignerCubit? editor, VoidCallback? onCommitted}) async {
    final current = editor ?? context.read<WorkflowDesignerCubit>();
    if (stage.type == WorkflowStageType.start) {
      await _editWorkflow(context);
      return;
    }
    if (stage.type == WorkflowStageType.end) {
      final cubit = current;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: WorkflowEndSettingsPage(stage: stage, onCommitted: onCommitted),
        ),
      ));
      return;
    }
    final design = current.state.design;
    if (design != null &&
        const {
          WorkflowStageType.userTask,
          WorkflowStageType.approval,
          WorkflowStageType.systemAction,
        }.contains(stage.type)) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: current,
          child:
              StageSettingsPage(stage: stage, design: design, options: options, onCommitted: onCommitted),
        ),
      ));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: current,
        child: WorkflowStageSettingsPage(
          stage: stage,
          roles: options?.roles ?? const [],
          departments: options?.departments ?? const [],
          employees: options?.employees ?? const [],
          onCommitted: onCommitted,
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
    if (type == null) return;
    final stage = await cubit.addStage(type);
    if (stage != null && type == WorkflowStageType.userTask && context.mounted) {
      await _openStage(context, stage, cubit.state.options);
    }
  }

  Future<void> _editWorkflow(BuildContext context) async {
    final cubit = context.read<WorkflowDesignerCubit>();
    final workflow = cubit.state.design?.workflow;
    if (workflow == null) {
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => WorkflowFormPage(existing: workflow),
    ));
    if (!cubit.isClosed) {
      await cubit.load();
    }
  }

  Future<void> _showWorkflowMenu(
      BuildContext context, WorkflowDesign design, bool offlinePreview) async {
    final client = context.read<FrappeApiClient>();
    final choice = await showModalBottomSheet<_WorkflowMenuChoice>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _WorkflowMenuSheet(),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _WorkflowMenuChoice.edit:
        await _editWorkflow(context);
      case _WorkflowMenuChoice.validate:
        await _openCheckSheet(context, design, offlinePreview, client);
      case _WorkflowMenuChoice.dryRun:
        await _openDryRunSheet(context, design, offlinePreview, client);
    }
  }

  Future<void> _openCheckSheet(BuildContext context, WorkflowDesign design,
      bool offlinePreview, FrappeApiClient client) async {
    if (offlinePreview) {
      await _showServerOnlySheet(context, 'بررسی اعتبار گردش کار');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WorkflowCheckSheet(
          definition: design.workflow.id, design: design, client: client),
    );
  }

  Future<void> _openDryRunSheet(BuildContext context, WorkflowDesign design,
      bool offlinePreview, FrappeApiClient client) async {
    if (offlinePreview) {
      await _showServerOnlySheet(context, 'اجرای آزمایشی فرایند');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WorkflowDryRunSheet(
          definition: design.workflow.id, design: design, client: client),
    );
  }

  Future<void> _showServerOnlySheet(
      BuildContext context, String title) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text(
              'این قابلیت برای بررسی نسخهٔ ذخیره‌شده به سرور نیاز دارد و در پیش‌نمایش آفلاین در دسترس نیست.',
              style: TextStyle(fontSize: 11, height: 1.6),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _insertStage(
      BuildContext context, WorkflowTransition transition) async {
    if (editingPath) return;
    editingPath = true;
    final parent = context.read<WorkflowDesignerCubit>();
    WorkflowDesignerCubit? editor;
    String? created, ticket;
    bool committed = false;
    try {
    final type = await showModalBottomSheet<WorkflowStageType>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _StagePickerSheet(),
    );
    if (type != null && context.mounted) {
      final before = parent.state.design!.stages.map((stage) => stage.id).toSet();
      final reply = await paths(context).insert(parent.definition, transition.id, type);
      ticket = reply['insertion_token'] as String;
      created = (reply['stages'] as List).cast<Map>().where((row) => !before.contains(row['name'])).single['name'] as String;
      editor = WorkflowDesignerCubit(repository: parent.repository, definition: parent.definition);
      await editor.load();
      final node = editor.state.design?.stages.where((stage) => stage.id == created).single;
      if (node == null) throw StateError('مرحلهٔ جدید از سرور دریافت نشد.');
      created = node.id;
      if (context.mounted) {
        await _openStage(context, node, editor.state.options,
            editor: editor, onCommitted: () => committed = true);
      }
    }
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureMessage(error))));
    } finally {
      if (!committed && created != null && ticket != null && context.mounted) {
        try { await paths(context).discard(parent.definition, created, ticket); }
        catch (error) { if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('بازگردانی مرحله انجام نشد؛ نمودار را تازه کنید. ${failureMessage(error)}')));
        } }
      }
      await editor?.close();
      if (!parent.isClosed) await parent.load();
      editingPath = false;
    }
  }

  Future<void> _removePath(BuildContext context, WorkflowTransition transition) async {
    if (editingPath) return;
    editingPath = true;
    final cubit = context.read<WorkflowDesignerCubit>();
    try {
      final review = await paths(context).preview(cubit.definition, transition.id);
      if (!context.mounted) return;
      final names = (review['stage_labels'] as List).join('، ');
      final accepted = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
        title: const Text('حذف مسیر'),
        content: SingleChildScrollView(child: Text('این مسیر حذف می‌شود.\n'
          '${names.isEmpty ? 'هیچ مرحلهٔ مشترکی حذف نمی‌شود.' : 'مراحل اختصاصی قابل حذف: $names'}\n'
          'مراحل مشترک و شاخه‌های دیگر حفظ می‌شوند.')),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('تأیید حذف'))]));
      if (accepted == true && context.mounted) {
        await paths(context).remove(cubit.definition, transition.id, review['version'] as Object);
        await cubit.load();
      }
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureMessage(error))));
    } finally { editingPath = false; }
  }

}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner({
    required this.workflow,
    required this.saving,
    required this.failed,
    this.failureMessage,
    this.offlinePreview = false,
  });
  final WorkflowDefinition workflow;
  final bool saving;
  final bool failed;
  final String? failureMessage;
  final bool offlinePreview;
  @override
  Widget build(BuildContext context) {
    final color = failed ? AsoudColors.warning : AsoudColors.primary;
    return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .06),
          border: Border.all(color: color.withValues(alpha: .2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(
            saving
                ? Icons.sync_rounded
                : failed
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              saving
                  ? 'در حال ذخیره تغییرات...'
                  : failed
                      ? failureMessage ??
                          'ذخیره تغییرات ناموفق بود؛ تغییرات را دوباره ذخیره کنید.'
                      : offlinePreview
                          ? 'تغییرات این پیش‌نویس روی دستگاه ذخیره شد؛ همگام‌سازی با سرور تأیید نشده است.'
                          : 'تغییرات این پیش‌نویس روی سرور ذخیره شده است.',
              style: TextStyle(fontSize: 9, color: color),
            ),
          ),
          Text(workflow.code,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 9, color: AsoudColors.muted)),
        ]),
      );
  }
}

/// A system workflow cannot be edited in place; the only path is an
/// independent copy, so the designer offers it directly.
class _SystemWorkflowBanner extends StatelessWidget {
  const _SystemWorkflowBanner({required this.workflow});
  final WorkflowDefinition workflow;

  Future<void> _copy(BuildContext context) async {
    final created = await showDialog<WorkflowDefinition>(
        context: context,
        barrierDismissible: false,
        builder: (_) => WorkflowSystemCopyDialog(
            source: workflow, client: context.read<FrappeApiClient>()));
    if (created == null || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => WorkflowDesignerPage(definition: created.id)));
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AsoudColors.warning.withValues(alpha: .06),
          border: Border.all(color: AsoudColors.warning.withValues(alpha: .2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.lock_outline_rounded,
              color: AsoudColors.warning, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'این الگوی سیستمی است و ویرایش مستقیم ندارد؛ برای تغییر، کپی مستقل بسازید.',
              style: TextStyle(fontSize: 9, color: AsoudColors.warning),
            ),
          ),
          TextButton(
              onPressed: () => _copy(context).ignore(),
              style: TextButton.styleFrom(
                  foregroundColor: AsoudColors.warning,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('ایجاد کپی مستقل')),
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
        'اقدام کاربر',
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

enum _WorkflowMenuChoice { edit, validate, dryRun }

class _WorkflowMenuSheet extends StatelessWidget {
  const _WorkflowMenuSheet();
  @override
  Widget build(BuildContext context) {
    const items = [
      (_WorkflowMenuChoice.edit, Icons.edit_outlined,
          'ویرایش تنظیمات گردش کار', 'محرک شروع، نقش‌ها و مشخصات فرایند'),
      (_WorkflowMenuChoice.validate, Icons.verified_user_outlined,
          'بررسی اعتبار گردش کار', 'یافتن خطاها و هشدارها قبل از فعال‌سازی'),
      (_WorkflowMenuChoice.dryRun, Icons.play_circle_outline_rounded,
          'اجرای آزمایشی فرایند', 'پیمایش مرحله‌به‌مرحله بدون اثر واقعی'),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('تنظیمات فرایند',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          for (final item in items)
            InkWell(
              onTap: () => Navigator.pop(context, item.$1),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AsoudColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  AsoudIconBox(icon: item.$2, color: AsoudColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$3,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(item.$4,
                            style: const TextStyle(
                                fontSize: 9, color: AsoudColors.muted)),
                      ])),
                ]),
              ),
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
            const _StartSaveErrorBanner(),
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
            final saved = await context.read<WorkflowDesignerCubit>().saveStart(
                  triggerType: triggerType,
                  initiatorRoles: selectedRoles.toList(growable: false),
                  subjectSource: 'Referenced Document',
                  passMode: 'Direct',
                );
            if (saved && context.mounted) Navigator.pop(context);
          },
          secondaryLabel: 'انصراف',
          onSecondary: () => Navigator.pop(context),
        ),
      );
}

class _StartSaveErrorBanner extends StatelessWidget {
  const _StartSaveErrorBanner();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<WorkflowDesignerCubit, WorkflowDesignerState>(
        builder: (context, state) {
          final message = state.status == WorkflowDesignerStatus.failure
              ? state.message
              : null;
          if (message == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AsoudColors.warningSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AsoudColors.warning),
              ),
              child: Text(
                message,
                style: const TextStyle(
                    fontSize: 11, color: AsoudColors.warning),
              ),
            ),
          );
        },
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
