part of 'organization_page.dart';

class _OrganizationInlineEditor extends StatefulWidget {
  const _OrganizationInlineEditor(
      {super.key,
      required this.action,
      required this.unit,
      required this.units,
      this.position,
      required this.onBusy,
      required this.onCancel,
      required this.onSaved});
  final _OrgEdit action;
  final Map<String, dynamic> unit;
  final List<Map<String, dynamic>> units;
  final OrgPosition? position;
  final ValueChanged<bool> onBusy;
  final Future<void> Function() onCancel;
  final Future<void> Function(String?, String?) onSaved;
  @override
  State<_OrganizationInlineEditor> createState() =>
      _OrganizationInlineEditorState();
}

class _OrganizationInlineEditorState extends State<_OrganizationInlineEditor> {
  final form = GlobalKey<FormState>();
  late final sourceUnit = Map<String, dynamic>.of(widget.unit);
  late final title = TextEditingController(
      text: widget.position?.displayTitle ??
          (widget.action == _OrgEdit.addUnit ||
                  widget.action == _OrgEdit.addPosition
              ? ''
              : organizationUnitLabel(sourceUnit)));
  late final capacity =
      TextEditingController(text: '${widget.position?.capacity ?? 1}');
  late final duties =
      TextEditingController(text: widget.position?.duties ?? '');
  late String parent = isPosition
      ? widget.position?.parent ?? ''
      : '${sourceUnit['parent_department'] ?? ''}';
  late String destination =
      widget.position?.departmentId ?? '${sourceUnit['name']}';
  late bool group = sourceUnit['is_group'] == 1;
  late final String initial = fingerprint;
  late final int revision = cubit.state.snapshot.revision;
  late final String code = widget.position?.code ??
      'POS-${List.generate(16, (_) => math.Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  bool saving = false;
  String? error;
  Future<Map<String, dynamic>>? review;
  bool get isPosition => widget.action.index >= _OrgEdit.addPosition.index;
  bool get deleting =>
      widget.action == _OrgEdit.deleteUnit ||
      widget.action == _OrgEdit.deletePosition;
  bool get moving =>
      widget.action == _OrgEdit.moveUnit ||
      widget.action == _OrgEdit.movePosition;
  bool get adding =>
      widget.action == _OrgEdit.addUnit ||
      widget.action == _OrgEdit.addPosition;
  String get fingerprint => jsonEncode(
      [title.text, capacity.text, duties.text, parent, destination, group]);
  bool get dirty => !deleting && fingerprint != initial;
  OrganizationCubit get cubit => context.read<OrganizationCubit>();
  OrganizationUnitNavigation get nav =>
      OrganizationUnitNavigation(widget.units);
  static const labels = {
    _OrgEdit.addUnit: 'زیرواحد جدید',
    _OrgEdit.editUnit: 'ویرایش مشخصات واحد',
    _OrgEdit.moveUnit: 'جابه‌جایی واحد',
    _OrgEdit.deleteUnit: 'حذف ایمن واحد',
    _OrgEdit.addPosition: 'جایگاه جدید',
    _OrgEdit.editPosition: 'ویرایش جایگاه شغلی',
    _OrgEdit.movePosition: 'جابه‌جایی جایگاه',
    _OrgEdit.deletePosition: 'حذف ایمن جایگاه',
  };
  @override
  void initState() {
    super.initState();
    initial;
    revision;
    code;
    if (deleting) review = _review();
  }

  Future<Map<String, dynamic>> _review() => isPosition
      ? cubit.repository.previewDeletePosition(cubit.company, code, revision)
      : cubit.repository.previewDeleteUnit(cubit.company,
          '${sourceUnit['name']}', '${sourceUnit['modified']}');

  @override
  void dispose() {
    title.dispose();
    capacity.dispose();
    duties.dispose();
    super.dispose();
  }

  Future<bool> submit() async {
    if (saving || cubit.state.busy) return false;
    if (!deleting && !(form.currentState?.validate() ?? false)) return false;
    setState(() {
      saving = true;
      error = null;
    });
    widget.onBusy(true);
    try {
      if (deleting) {
        final result = await _review();
        if (!mounted) return false;
        if (result['can_delete'] != true) {
          throw FormatException(
              (result['blockers'] as List? ?? ['حذف مجاز نیست.']).join('\n'));
        }
        final yes = await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
                  title:
                      Text(isPosition ? 'تأیید حذف جایگاه' : 'تأیید حذف واحد'),
                  content: Text(
                      '«${widget.position?.displayTitle ?? organizationUnitLabel(sourceUnit)}» حذف شود؟ سوابق مرتبط حذف نمی‌شوند.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const Text('انصراف')),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AsoudColors.danger),
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const Text('تأیید حذف'))
                  ],
                ));
        if (yes != true || !mounted) return false;
      }
      String? newId;
      if (isPosition) {
        if (cubit.state.snapshot.revision != revision ||
            cubit.state.snapshot.server != null) {
          throw const FormatException(
              'ساختار تغییر کرده است؛ فرم را با اطلاعات تازه باز کنید.');
        }
        final rows = cubit.state.snapshot.rows;
        final existing = rows.where((r) => r.code == code).firstOrNull;
        if (!adding && existing == null) {
          throw const FormatException('این جایگاه دیگر در دسترس نیست.');
        }
        if (widget.position != null &&
            existing != null &&
            jsonEncode(existing.toJson()) !=
                jsonEncode(widget.position!.toJson()) &&
            !cubit.state.snapshot.rejected) {
          throw const FormatException(
              'جایگاه هم‌زمان تغییر کرده است؛ دوباره بررسی کنید.');
        }
        final base = widget.position ??
            OrgPosition(
                code: code,
                title: '',
                departmentId: '${sourceUnit['name']}',
                department: '${sourceUnit['department_name']}',
                occupants: const []);
        final updated = base.copyWith(
          title: organizationEditedTitle(title.text, widget.position?.title ?? ''),
          parent: parent,
          capacity: int.parse(toLatinDigits(capacity.text.trim())),
          duties: duties.text.trim(),
          departmentId: moving ? destination : base.departmentId,
          department: moving
              ? '${nav.byId(destination)?['department_name'] ?? ''}'
              : base.department,
          occupants: base.activeEmployees,
        );
        final next = [
          for (final row in rows)
            if (row.code != code) row else if (!deleting) updated,
          if (adding && existing == null) updated
        ];
        validateOrganization(next);
        if (!await cubit.save(next)) {
          throw FormatException(cubit.state.error ?? 'ذخیره تأیید نشد.');
        }
      } else if (deleting) {
        await cubit.repository.deleteUnit(cubit.company,
            '${sourceUnit['name']}', '${sourceUnit['modified']}');
      } else {
        final saved = await cubit.repository.saveUnit(cubit.company, {
          if (!adding) 'name': sourceUnit['name'],
          if (!adding) 'modified': sourceUnit['modified'],
          'title': organizationEditedTitle(title.text, adding ? '' : '${sourceUnit['department_name']}'),
          'parent': adding
              ? sourceUnit['name']
              : moving
                  ? parent
                  : sourceUnit['parent_department'] ?? '',
          'is_group': adding ? true : group,
        });
        if (adding) newId = saved['name']?.toString();
      }
      if (!isPosition) await cubit.load();
      if (!mounted) return true;
      _orgMessage(
          context,
          cubit.state.snapshot.pending
              ? 'تغییرات محلی ذخیره شد؛ تأیید سرور در انتظار است.'
              : 'تغییرات ذخیره شد.');
      await widget.onSaved(
          newId,
          deleting && !isPosition
              ? sourceUnit['parent_department'] as String?
              : null);
      return true;
    } catch (e) {
      if (mounted) {
        setState(
            () => error = e is FormatException ? e.message : failureMessage(e));
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
      widget.onBusy(false);
    }
  }

  Set<String> get excludedPositions {
    final result = <String>{code};
    var changed = true;
    while (changed) {
      final size = result.length;
      for (final row in cubit.state.snapshot.rows) {
        if (result.contains(row.parent)) result.add(row.code);
      }
      changed = result.length != size;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => _OrgPanel(children: [
        Row(children: [
          const Icon(Icons.edit_outlined, size: 20, color: Color(0xff448fff)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(labels[widget.action]!,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          IconButton(
              tooltip: 'بستن فرم',
              onPressed: saving ? null : widget.onCancel,
              icon: const Icon(Icons.close, size: 18)),
        ]),
        Text(widget.position?.displayTitle ?? organizationUnitLabel(sourceUnit),
            style: const TextStyle(fontSize: 12, color: Color(0xff7d8798))),
        const SizedBox(height: 14),
        if (deleting)
          FutureBuilder<Map<String, dynamic>>(
              future: review,
              builder: (context, snapshot) => Column(children: [
                    if (snapshot.connectionState != ConnectionState.done)
                      const LinearProgressIndicator(),
                    if (snapshot.hasError) ...[
                      Text(failureMessage(snapshot.error)),
                      TextButton(
                          onPressed: saving
                              ? null
                              : () => setState(() => review = _review()),
                          child: const Text('بررسی دوباره'))
                    ],
                    if (snapshot.hasData) ...[
                      Text(snapshot.data!['can_delete'] == true
                          ? 'وابستگی مسدودکننده پیدا نشد؛ هنگام حذف دوباره بررسی می‌شود.'
                          : (snapshot.data!['blockers'] as List? ?? [])
                              .join('\n')),
                      const SizedBox(height: 12),
                      FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AsoudColors.danger),
                          onPressed:
                              saving || snapshot.data!['can_delete'] != true
                                  ? null
                                  : submit,
                          child: const Text('حذف با تأیید نهایی')),
                    ],
                  ]))
        else
          Form(
              key: form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!moving) ...[
                      AppTextField(
                          key: const ValueKey('focus-editor-title'),
                          controller: title,
                          enabled: !saving,
                          label: isPosition ? 'عنوان جایگاه' : 'عنوان واحد',
                          required: true,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'عنوان الزامی است.'
                              : null),
                      const SizedBox(height: 14),
                    ],
                    if (isPosition) ...[
                      if (moving) ...[
                        _fixed('واحد مبدأ', organizationUnitLabel(sourceUnit)),
                        const SizedBox(height: 14),
                      ],
                      if (moving)
                        AppSelectField(
                            value: destination,
                            label: 'واحد مقصد',
                            displayValue: _nullableOrgUnitLabel(nav.byId(destination)) ??
                                'واحد در دسترس نیست',
                            enabled: !saving,
                            onPick: () => showAppOptionSheet(context,
                                title: 'واحد مقصد',
                                current: destination,
                                options: widget.units
                                    .where((u) => u['disabled'] != 1)
                                    .map((u) => AppOption(
                                        '${u['name']}',
                                        nav
                                            .path('${u['name']}')
                                            .map((v) => organizationUnitLabel(v))
                                            .join(' / ')))
                                    .toList()),
                            onChanged: (v) => setState(() => destination = v))
                      else
                        _fixed('واحد سازمانی مربوط',
                            organizationUnitLabel(sourceUnit)),
                      const SizedBox(height: 14),
                      AppSelectField(
                          value: parent,
                          label: 'جایگاه بالادستی',
                          enabled: !saving,
                          displayValue: cubit.state.snapshot.rows
                                  .where((r) => r.code == parent)
                                  .firstOrNull
                                  ?.displayTitle ??
                              (parent.isEmpty
                                  ? 'بدون بالادست'
                                  : 'جایگاه در دسترس نیست'),
                          onPick: () => showAppOptionSheet(context,
                                  title: 'جایگاه بالادستی',
                                  current: parent,
                                  options: [
                                    const AppOption('', 'بدون بالادست'),
                                    ...cubit.state.snapshot.rows
                                        .where((r) =>
                                            !excludedPositions.contains(r.code))
                                        .map((r) => AppOption(r.code,
                                            '${r.displayTitle} — ${r.department.isEmpty ? 'واحد تعیین نشده' : r.displayDepartment}')),
                                  ]),
                          onChanged: (v) => setState(() => parent = v)),
                      if (moving)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                                'انتساب‌ها و سوابق حفظ می‌شوند. بالادست جایگاه فقط طبق انتخاب همین فرم تغییر می‌کند؛ واحد جابه‌جا نمی‌شود.')),
                      if (!moving) ...[
                        const SizedBox(height: 14),
                        AppTextField(
                            key: const ValueKey('focus-editor-capacity'),
                            controller: capacity,
                            enabled: !saving,
                            keyboardType: TextInputType.number,
                            label: 'ظرفیت جایگاه',
                            required: true,
                            validator: (v) {
                              final n =
                                  int.tryParse(toLatinDigits(v?.trim() ?? ''));
                              return n == null || n < 1
                                  ? 'ظرفیت باید عدد صحیح مثبت باشد.'
                                  : n <
                                          (widget.position?.activeEmployees
                                                  .length ??
                                              0)
                                      ? 'ظرفیت کمتر از تعداد متصدیان فعال مجاز نیست.'
                                      : null;
                            }),
                        const SizedBox(height: 14),
                        AppTextField(
                            controller: duties,
                            enabled: !saving,
                            minLines: 3,
                            maxLines: 5,
                            label: 'شرح وظایف (اختیاری)'),
                      ],
                    ] else if (moving) ...[
                      _fixed(
                          'واحد بالادستی فعلی',
                          _nullableOrgUnitLabel(nav.byId(sourceUnit['parent_department']
                                      as String?)) ??
                              'ریشه بالادستی'),
                      const SizedBox(height: 14),
                      AppSelectField(
                          value: parent,
                          label: 'واحد بالادستی جدید',
                          enabled: !saving,
                          displayValue: _nullableOrgUnitLabel(nav.byId(parent)) ??
                              (parent.isEmpty
                                  ? 'سطح اصلی سازمان'
                                  : 'ریشه بالادستی'),
                          onPick: () => showAppOptionSheet(context,
                                  title: 'انتقال زیرشاخه به',
                                  current: parent,
                                  options: [
                                    const AppOption('', 'سطح اصلی سازمان'),
                                    ...widget.units
                                        .where((u) =>
                                            !nav
                                                .subtree(
                                                    '${sourceUnit['name']}')
                                                .contains(u['name']) &&
                                            u['disabled'] != 1 &&
                                            u['is_group'] == 1)
                                        .map((u) => AppOption(
                                            '${u['name']}',
                                            nav
                                                .path('${u['name']}')
                                                .map((v) => organizationUnitLabel(v))
                                                .join(' / '))),
                                  ]),
                          onChanged: (v) => setState(() => parent = v)),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                              'کل زیرشاخه همراه واحد منتقل می‌شود. جایگاه‌ها، انتساب‌ها و سوابق حفظ می‌شوند و روابط گزارش‌دهی جایگاه‌ها تغییر نمی‌کند.')),
                    ] else ...[
                      _fixed(
                          adding ? 'واحد بالادستی ثابت' : 'واحد بالادستی',
                          adding
                              ? organizationUnitLabel(sourceUnit)
                              : _nullableOrgUnitLabel(nav.byId(parent)) ??
                                  'ریشه بالادستی'),
                      if (!adding)
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: group,
                            title: const Text('پذیرش زیرواحد'),
                            onChanged: saving ||
                                    nav
                                        .children('${sourceUnit['name']}')
                                        .isNotEmpty
                                ? null
                                : (v) => setState(() => group = v)),
                      if (adding && sourceUnit['is_group'] != 1)
                        const Text(
                            'برای افزودن زیرواحد، ابتدا پذیرش زیرواحد را در مشخصات واحد بالادستی فعال کنید.'),
                    ],
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: FilledButton(
                              onPressed: saving ? null : submit,
                              child: Text(saving
                                  ? 'در حال ذخیره…'
                                  : adding
                                      ? 'ذخیره'
                                      : 'ذخیره تغییرات'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: OutlinedButton(
                              onPressed: saving ? null : widget.onCancel,
                              child: const Text('انصراف')))
                    ]),
                  ])),
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!,
                  style: const TextStyle(color: AsoudColors.danger))),
      ]);

  Widget _fixed(String label, String value) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xfff2f5fa),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xff7d8798))),
          const SizedBox(height: 6),
          Text(value)
        ])),
        const Icon(Icons.lock_outline, size: 16, color: Color(0xff9facbf))
      ]));
}
