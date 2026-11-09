part of 'stage_settings_page.dart';

/// Reference styling over existing approval settings, without a second engine.
extension _ApprovalSettings on _StageSettingsPageState {
  Widget _existingApprovalOwners() {
    if (approvalOwnerFingerprint != initialApprovalOwner) return const SizedBox.shrink();
    final byRole = config['assignment_type'] == 'Role';
    final values = config[byRole ? 'approver_roles' : 'approver_departments'];
    if (values is! List || values.length < 2) return const SizedBox.shrink();
    final names = values.map((id) => byRole ? roleLabel('$id') :
        departments.where((item) => item.id == id).firstOrNull?.label ?? 'واحد ثبت‌شده').join('، ');
    return Padding(padding: const EdgeInsets.only(top: 8),
      child: Text('مسئولان ثبت‌شده: $names',
        style: const TextStyle(fontSize: 11, color: AsoudColors.muted)));
  }

  Future<void> _pickApprovalRoute(String action, {String? emptyLabel}) async {
    if (saving) return;
    final result = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _StageRouteSheet(stages: _destinations,
          selected: routes[action] ?? '', emptyLabel: emptyLabel,
          returning: action == 'Return'));
    if (result != null && mounted) _updateAction(() => routes[action] = result);
  }

  Future<void> _openApprovalDestination(WorkflowStage stage) async {
    if (saving || stage.id == widget.stage.id) return;
    final cubit = context.read<WorkflowDesignerCubit>();
    final design = cubit.state.design ?? widget.design;
    final page = switch (stage.type) {
      WorkflowStageType.end => WorkflowEndSettingsPage(stage: stage),
      WorkflowStageType.condition || WorkflowStageType.wait => WorkflowStageSettingsPage(
          stage: stage, roles: roles, departments: departments, employees: employees),
      _ => StageSettingsPage(stage: stage, design: design,
          options: widget.options, automation: automation),
    };
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) =>
        BlocProvider.value(value: cubit, child: page)));
    if (mounted) _updateAction(() {});
  }

  Widget _approvalDiagram() => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: ExpansionTile(
      key: const ValueKey('approval-diagram-expand'),
      title: const Text('پیش‌نمایش نمودار گردش کار',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      children: [ValueListenableBuilder<TextEditingValue>(
        valueListenable: title,
        builder: (context, value, _) => _ApprovalDiagram(
          key: const ValueKey('approval-diagram-preview'),
          stage: widget.stage.copyWith(title: value.text),
          stages: (context.read<WorkflowDesignerCubit>().state.design ?? widget.design).stages,
          routes: routes,
          actions: ['Approve', if (allowReject) 'Reject', if (allowReturn) 'Return'],
          onOpen: (stage) => _openApprovalDestination(stage).ignore(),
          onPick: (action) => _pickApprovalRoute(action,
            emptyLabel: action == 'Reject' ? 'پایان فرایند (رد درخواست)' :
                action == 'Return' ? 'آخرین مرحله قابل اصلاح' : null).ignore(),
        )),
        const SizedBox(height: 8),
        const Text('انتخاب‌ها تا ذخیرهٔ فرم پیش‌نویس‌اند؛ لمس مقصد، تنظیمات همان مرحله را باز می‌کند.',
            style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
      ]));

  Widget _approvalPanel(List<Widget> children) => Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children)));

  FormMap? get _approvalSource => widget.design.stages
      .where((stage) => stage.type == WorkflowStageType.start)
      .map((stage) => stage.config['submission_source'])
      .whereType<Map>()
      .map(formMap)
      .firstOrNull;

  Widget _approvalInformation() {
    final source = _approvalSource;
    return _approvalPanel([
      _label('اطلاعات موردنیاز برای تأیید'),
      const Text(
          'درخواست اصلی از تنظیمات شروع دریافت می‌شود؛ انتخاب دوباره لازم نیست.',
          style:
              TextStyle(fontSize: 11, height: 1.7, color: AsoudColors.muted)),
      const SizedBox(height: 10),
      Material(
          color: const Color(0xfff5f7fc),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const AsoudIconBox(
                icon: Icons.description_outlined,
                color: AsoudColors.primary,
                size: 34),
            title: Text(source?['title']?.toString() ?? 'فرم اصلی درخواست',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            subtitle: Text(
                source == null
                    ? 'فرم قابل پیش‌نمایش در شروع انتخاب نشده است.'
                    : 'نمایش اطلاعات اصلی؛ فقط مشاهده',
                style: const TextStyle(
                    fontSize: 10, height: 1.7, color: AsoudColors.muted)),
          )),
      if (source != null)
        TextButton.icon(
            key: const ValueKey('approval-source-preview'),
            onPressed: saving || previewingApprovalSource
                ? null
                : () => _previewApprovalSource().ignore(),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            label: Text(previewingApprovalSource
                ? 'در حال دریافت…'
                : 'پیش‌نمایش فرم درخواست')),
      const Divider(height: 24),
      _label('فرم تکمیلی تأیید (اختیاری)'),
      // A bound stage form shows its title; a legacy inline form keeps its
      // old «N فیلد» label so old stages render unchanged.
      PickerField(
          value: supplementaryForm != null
              ? _boundFormTitle
              : (formFields.isEmpty
                  ? ''
                  : 'فرم تکمیلی · ${formatCount(formFields.length, 'فیلد')}'),
          placeholder: 'انتخاب یا ویرایش فرم مرحله',
          icon: Icons.description_outlined,
          onTap: saving ? null : _pickForm),
      if (supplementaryForm != null) ...[
        TextButton.icon(
            onPressed: saving ? null : _previewBoundForm,
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('پیش‌نمایش')),
        TextButton(
            onPressed: saving ? null : _pickForm,
            child: const Text('تغییر فرم')),
        TextButton(
            onPressed: saving ? null : _removeBoundForm,
            child: const Text('برداشتن فرم')),
      ],
      if (supplementaryForm == null && formFields.isNotEmpty)
        Row(children: [
          Expanded(
              child: TextButton.icon(
                  onPressed: saving ? null : _editForm,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('ویرایش فرم'))),
          TextButton(
              onPressed: saving ? null : _removeApprovalForm,
              child: const Text('حذف فرم')),
        ]),
      const SizedBox(height: 8),
      const Text(
          'نبود فرم تکمیلی مانع تصمیم‌گیری نیست؛ اطلاعات آن جدا از درخواست اصلی ثبت می‌شود.',
          style:
              TextStyle(fontSize: 10, height: 1.7, color: AsoudColors.muted)),
    ]);
  }

  Future<void> _previewApprovalSource() async {
    final source = _approvalSource;
    if (source == null || previewingApprovalSource || saving) return;
    _updateAction(() => previewingApprovalSource = true);
    try {
      final repository = FormRepository(automation.client, company ?? '');
      final record = formMap(await repository.call('get_form', {
        'name': source['form'],
        'revision_name': source['revision'],
        'manage': 1,
      }));
      final schema = formMap(record['schema']);
      if (schema.isEmpty) throw StateError('فرم قابل پیش‌نمایش دریافت نشد.');
      if (!mounted) return;
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .8,
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                                'پیش‌نمایش فرم اصلی؛ بدون اطلاعات اجرایی',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 16),
                            FormFieldsView(
                                schema: schema,
                                values: const {},
                                enabled: false,
                                snapshot: true,
                                onChanged: (_) {},
                                repository: repository,
                                formName: source['form']?.toString()),
                          ])))));
    } catch (failure) {
      if (mounted) {
        _message(failure is ApiException
            ? failure.message
            : 'پیش‌نمایش فرم درخواست در دسترس نیست؛ اتصال و مجوز را بررسی کنید.');
      }
    } finally {
      if (mounted) _updateAction(() => previewingApprovalSource = false);
    }
  }

  // --- bound stage form (kind 'Stage') -----------------------------------------------------

  /// Opens the pinned revision of the bound form in the shared preview page.
  Future<void> _previewBoundForm() async {
    final binding = supplementaryForm;
    if (binding == null || saving) return;
    final repository = FormRepository(automation.client, company ?? '');
    try {
      final record = formMap(await repository.call('get_form', {
        'name': binding['form'],
        'revision_name': binding['revision'],
        'manage': 1,
      }));
      final schema = formMap(record['schema']);
      if (schema.isEmpty) throw StateError('فرم قابل پیش‌نمایش دریافت نشد.');
      if (!mounted) return;
      await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
              builder: (_) => FormPreviewPage(
                  schema: schema,
                  repository: repository,
                  record: record,
                  initialValues: const {})));
    } catch (failure) {
      if (mounted) {
        _message(failure is ApiException
            ? failure.message
            : 'پیش‌نمایش فرم تکمیلی در دسترس نیست؛ اتصال و مجوز را بررسی کنید.');
      }
    }
  }

  /// Removes the binding only; the form and its revisions are never deleted.
  Future<void> _removeBoundForm() async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('برداشتن فرم تکمیلی'),
        content: const Text(
            'فرم تکمیلی از این مرحله برداشته شود؟ خود فرم و سوابق آن حذف نمی‌شود.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('برداشتن فرم')),
        ],
      ),
    );
    if (remove == true && mounted) {
      _updateAction(() => supplementaryForm = null);
    }
  }

  Future<void> _setApprovalDecision(String action, bool enabled) async {
    if (saving || changingApprovalDecision) return;
    _updateAction(() => changingApprovalDecision = true);
    try {
      if (!enabled && (routes[action] ?? '').isNotEmpty) {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
                    title: const Text('غیرفعال‌کردن تصمیم'),
                    content: const Text(
                        'این تصمیم مسیر خروجی دارد. با ذخیرهٔ فرم، اتصال آن حذف می‌شود؛ خود مرحلهٔ مقصد حذف نخواهد شد. ادامه می‌دهید؟'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('انصراف')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('تأیید غیرفعال‌سازی')),
                    ]));
        if (confirmed != true || !mounted) return;
      }
      if (!mounted) return;
      _updateAction(() {
        if (action == 'Reject') {
          allowReject = enabled;
        } else {
          allowReturn = enabled;
        }
        if (enabled) {
          confirmedDisabledApprovalRoutes.remove(action);
        } else {
          confirmedDisabledApprovalRoutes.add(action);
        }
      });
    } finally {
      if (mounted) _updateAction(() => changingApprovalDecision = false);
    }
  }
}

// Projection of the existing stages and route selection only; it never creates
// a stage, transition or execution record. Geometry is shared with the Canvas.
class _ApprovalDiagram extends StatelessWidget {
  const _ApprovalDiagram({super.key, required this.stage, required this.stages,
    required this.routes, required this.actions, required this.onOpen, required this.onPick});
  final WorkflowStage stage;
  final List<WorkflowStage> stages;
  final Map<String, String> routes;
  final List<String> actions;
  final ValueChanged<WorkflowStage> onOpen;
  final ValueChanged<String> onPick;
  Color color(String action) => action == 'Approve' ? AsoudColors.success :
      action == 'Reject' ? AsoudColors.danger : AsoudColors.warning;
  @override
  Widget build(BuildContext context) => Column(children: [
    Center(child: _ApprovalShape(stage: stage)),
    LayoutBuilder(builder: (_, constraints) => CustomPaint(
      size: Size(constraints.maxWidth, 20), painter: _ApprovalBranches(actions.map(color).toList()))),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final action in actions) Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Builder(builder: (context) {
          final target = stages.where((s) => s.id == routes[action]).firstOrNull;
          return Column(children: [
            Text(action == 'Approve' ? 'تأیید' : action == 'Reject' ? 'رد' : 'اصلاح',
              style: TextStyle(fontSize: 11, color: color(action))),
            Container(width: 1, height: 16, color: color(action)),
            if (target != null) InkWell(
              key: ValueKey('approval-preview-target-$action-${target.id}'),
              onTap: () => onOpen(target),
              child: _ApprovalShape(stage: target))
            else OutlinedButton(
              key: ValueKey('approval-preview-unset-$action'),
              onPressed: () => onPick(action),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(8)),
              child: Text((routes[action] ?? '').isNotEmpty ? 'بازبینی مقصد' :
                action == 'Reject' ? 'پایان با نتیجه رد' : action == 'Return'
                    ? 'انتخاب از سابقه اجرا' : 'انتخاب مقصد',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
          ]);
        }))),
    ]),
  ]);
}

class _ApprovalShape extends StatelessWidget {
  const _ApprovalShape({required this.stage});
  final WorkflowStage stage;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ApprovalShapePainter(stage.type, workflowStageVisual(stage.type).color),
    child: SizedBox(height: 74, width: 140, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Center(child: Text(stage.title, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: workflowStageVisual(stage.type).color, fontWeight: FontWeight.w700))))));
}

class _ApprovalBranches extends CustomPainter {
  const _ApprovalBranches(this.colors);
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < colors.length; i++) {
      final x = size.width * (1 - (i + .5) / colors.length);
      final path = Path()..moveTo(size.width / 2, 0)
        ..lineTo(size.width / 2, size.height / 2)
        ..lineTo(x, size.height / 2)..lineTo(x, size.height);
      canvas.drawPath(path, Paint()..color = colors[i].withValues(alpha: .5)
        ..style = PaintingStyle.stroke..strokeWidth = 1);
    }
  }
  @override
  bool shouldRepaint(covariant _ApprovalBranches oldDelegate) =>
      oldDelegate.colors.length != colors.length ||
      List.generate(colors.length, (i) => oldDelegate.colors[i] != colors[i]).contains(true);
}

class _ApprovalShapePainter extends CustomPainter {
  const _ApprovalShapePainter(this.type, this.color);
  final WorkflowStageType type;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = WorkflowGraphGeometry.shape(type, size);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .08));
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1);
  }
  @override
  bool shouldRepaint(covariant _ApprovalShapePainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
