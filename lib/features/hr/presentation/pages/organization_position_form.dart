part of 'organization_page.dart';

class _OrganizationPositionForm extends StatefulWidget {
  const _OrganizationPositionForm(
      {this.item, this.parent, this.unitId = '', this.unitTitle = ''});
  final OrgPosition? item, parent;
  final String unitId, unitTitle;
  @override
  State<_OrganizationPositionForm> createState() =>
      _OrganizationPositionFormState();
}

class _OrganizationPositionFormState extends State<_OrganizationPositionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _department;
  late final TextEditingController _capacity, _duties;
  late List<String> _occupants;
  late String _departmentId;
  List<Map<String, dynamic>> _units = [];
  late String _employee;
  List<OrganizationEmployee> _people = [];
  bool _loadingPeople = false;
  bool _saving = false;
  bool _allowClose = false;
  late String _selectedParent;
  OrgPosition? _savedDraft;
  String? get _editingCode => _savedDraft?.code ?? widget.item?.code;
  String? _peopleError, _error;

  String get _parentCode => _selectedParent;
  bool get _dirty =>
      _title.text != (widget.item?.title ?? '') ||
      _code.text != (widget.item?.code ?? '') ||
      _departmentId != (widget.item?.departmentId ?? widget.unitId) ||
      _duties.text != (widget.item?.duties ?? '') ||
      _capacity.text != '${widget.item?.capacity ?? 1}' ||
      _parentCode != (widget.item?.parent ?? widget.parent?.code ?? '') ||
      jsonEncode(_occupants) != jsonEncode(widget.item?.activeEmployees ?? []);

  Future<void> _discard() async {
    if (_saving) return;
    if (_dirty && !await _confirmOrgDiscard(context)) return;
    if (!mounted) return;
    setState(() => _allowClose = true);
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _selectedParent = widget.item?.parent ?? widget.parent?.code ?? '';
    _code = TextEditingController(text: widget.item?.code ?? '');
    _title = TextEditingController(text: widget.item?.title ?? '');
    _department = TextEditingController(
        text: widget.item?.department ??
            (widget.unitTitle.isNotEmpty
                ? widget.unitTitle
                : widget.parent?.department ?? ''));
    _departmentId = widget.item?.departmentId ??
        (widget.unitId.isNotEmpty
            ? widget.unitId
            : widget.parent?.departmentId ?? '');
    _capacity = TextEditingController(text: '${widget.item?.capacity ?? 1}');
    _duties = TextEditingController(text: widget.item?.duties ?? '');
    _occupants = [...?widget.item?.activeEmployees];
    _employee = '';
    for (final controller in [_title, _code, _department, _capacity, _duties]) {
      controller.addListener(() {
        if (mounted) setState(() {});
      });
    }
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    setState(() {
      _loadingPeople = true;
      _peopleError = null;
    });
    try {
      final cubit = context.read<OrganizationCubit>();
      final people = await cubit.repository.employees(cubit.company);
      final units = await cubit.repository.units(cubit.company);
      if (!mounted) return;
      setState(() {
        _people = people;
        _units = (units['units'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _peopleError =
            'فهرست پرسنل در دسترس نیست؛ می‌توانید جایگاه خالی بسازید یا انتصاب قبلی را نگه دارید.');
      }
    } finally {
      if (mounted) setState(() => _loadingPeople = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _department.dispose();
    _capacity.dispose();
    _duties.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OrganizationCubit, OrganizationState>(
        builder: (context, state) {
          final busy = _saving || state.busy;
          final parents =
              state.snapshot.rows.where((row) => row.code == _parentCode);
          final parentTitle = _parentCode.isEmpty
              ? 'جایگاه اصلی'
              : parents.isEmpty
                  ? _parentCode
                  : parents.first.title;
          final seatedElsewhere = {
            for (final row in state.snapshot.rows)
              if (row.code != _editingCode) ...row.activeEmployees
          };
          final available = _people
              .where((person) =>
                  !_occupants.contains(person.id) &&
                  !seatedElsewhere.contains(person.id))
              .toList();
          return PopScope(
            canPop: !_saving && (_allowClose || !_dirty),
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) _discard();
            },
            child: Scaffold(
              appBar: _OrganizationReferenceHeader(
                  form: true,
                  title: widget.item == null
                      ? 'افزودن جایگاه سازمانی'
                      : 'ویرایش جایگاه سازمانی'),
              body: SafeArea(
                  child: Form(
                key: _formKey,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  const _OrganizationStatus(),
                  _OrgDetailIdentity(
                      title: widget.item?.title ?? 'جایگاه جدید',
                      subtitle: _parentCode.isEmpty
                          ? 'اطلاعات جایگاه اصلی'
                          : 'زیرمجموعه $parentTitle',
                      position: true),
                  if (_error != null) ...[
                    _OrgNotice(
                        icon: Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                        text: _error!),
                    const SizedBox(height: 12),
                  ],
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('اطلاعات اصلی جایگاه',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 16),
                              AppTextField(
                                controller: _title,
                                label: 'عنوان جایگاه',
                                required: true,
                                enabled: !busy,
                                prefixIcon: const Icon(Icons.badge_outlined),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'عنوان جایگاه را وارد کنید.'
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                controller: _code,
                                label: 'کد جایگاه',
                                required: true,
                                ltr: true,
                                enabled: !busy && widget.item == null,
                                prefixIcon: const Icon(Icons.tag),
                                validator: (value) {
                                  final code =
                                      _normalizedOrgCode(value?.trim() ?? '');
                                  if (code.isEmpty) {
                                    return 'کد جایگاه را وارد کنید.';
                                  }
                                  if (state.snapshot.rows.any((row) =>
                                      row.code != _editingCode &&
                                      _normalizedOrgCode(row.code) == code)) {
                                    return 'این کد قبلاً ثبت شده است.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              AppSelectField(
                                value: _departmentId,
                                displayValue: _department.text.isEmpty
                                    ? 'انتخاب واحد'
                                    : _department.text,
                                label: 'واحد سازمانی',
                                enabled: !busy && !_loadingPeople,
                                onPick: () => showAppOptionSheet(context,
                                    title: 'واحد سازمانی',
                                    current: _departmentId,
                                    options: [
                                      const AppOption(
                                          '', 'بدون ارتباط با واحد'),
                                      ..._units
                                          .where((u) => u['disabled'] != 1)
                                          .map((u) => AppOption('${u['name']}',
                                              '${u['department_name']}')),
                                    ]),
                                onChanged: (value) => setState(() {
                                  _departmentId = value;
                                  _department.text = _units
                                          .where((u) => u['name'] == value)
                                          .map((u) => '${u['department_name']}')
                                          .firstOrNull ??
                                      '';
                                }),
                                prefixIcon: const Icon(Icons.business_outlined),
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                  controller: _capacity,
                                  label: 'ظرفیت',
                                  required: true,
                                  enabled: !busy,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    final count = int.tryParse(
                                        _normalizedOrgCode(v ?? ''));
                                    return count == null ||
                                            count < 1 ||
                                            count < _occupants.length
                                        ? 'ظرفیت مثبت و حداقل برابر تعداد پرسنل باشد.'
                                        : null;
                                  }),
                              const SizedBox(height: 12),
                              AppTextField(
                                  controller: _duties,
                                  label: 'شرح وظایف',
                                  enabled: !busy),
                              const SizedBox(height: 16),
                              AppSelectField(
                                  value: _parentCode,
                                  label: 'جایگاه بالادستی',
                                  displayValue: parentTitle,
                                  enabled: !busy,
                                  onPick: () => showAppOptionSheet(context,
                                          title: 'جایگاه بالادستی',
                                          current: _parentCode,
                                          options: [
                                            const AppOption('', 'جایگاه اصلی'),
                                            ...state.snapshot.rows
                                                .where((r) =>
                                                    r.code != _editingCode)
                                                .map((r) =>
                                                    AppOption(r.code, r.title))
                                          ]),
                                  onChanged: (v) =>
                                      setState(() => _selectedParent = v)),
                            ],
                          ))),
                  const SizedBox(height: 12),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('انتصاب پرسنل',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 8),
                              const Text(
                                  'انتخاب از پرسنل ثبت‌شده منابع انسانی است. مدیر مستقیم در پرونده پرسنلی جداگانه تعیین می‌شود؛ ذخیره یا تغییر جایگاه، مدیر مستقیم و دسترسی‌ها را تغییر نمی‌دهد.',
                                  style: TextStyle(
                                      fontSize: 11, color: AsoudColors.muted)),
                              const SizedBox(height: 16),
                              if (_loadingPeople)
                                const LinearProgressIndicator(),
                              if (_peopleError != null) ...[
                                Text(_peopleError!,
                                    style: const TextStyle(
                                        color: AsoudColors.muted,
                                        fontSize: 11)),
                                TextButton(
                                    onPressed: busy || _loadingPeople
                                        ? null
                                        : _loadPeople,
                                    child: const Text('تلاش دوباره')),
                              ],
                              AppSelectField(
                                key: ValueKey('org-employee-$_employee'),
                                label: 'پرسنل',
                                value: _employee,
                                displayValue: _employee.isEmpty
                                    ? 'انتساب پرسنل جدید'
                                    : available
                                            .where((person) =>
                                                person.id == _employee)
                                            .map((person) => person.displayName)
                                            .firstOrNull ??
                                        _employee,
                                hint: 'انتخاب از منابع انسانی',
                                prefixIcon: const Icon(Icons.person_outline),
                                enabled: !(busy || _loadingPeople),
                                onPick: () => _pickOrganizationEmployee(
                                    context, available),
                                onChanged: (value) => setState(() {
                                  _employee = '';
                                  if (value.isNotEmpty &&
                                      !_occupants.contains(value)) {
                                    _occupants.add(value);
                                  }
                                }),
                              ),
                              for (final id in _occupants)
                                ListTile(
                                    title: Text(_people
                                            .where((p) => p.id == id)
                                            .map((p) => p.displayName)
                                            .firstOrNull ??
                                        id),
                                    subtitle: Text(_people
                                            .where((p) =>
                                                p.id == id &&
                                                p.personnelCode.isNotEmpty)
                                            .map((p) => p.personnelCode)
                                            .firstOrNull ??
                                        id.replaceFirst('employee:', '')),
                                    trailing: IconButton(
                                        icon: const Icon(
                                            Icons.person_remove_outlined),
                                        tooltip: 'پایان انتساب پس از ذخیره',
                                        onPressed: busy
                                            ? null
                                            : () async {
                                                final yes = await showDialog<
                                                        bool>(
                                                    context: context,
                                                    builder: (c) => AlertDialog(
                                                            title: const Text(
                                                                'پایان انتساب'),
                                                            content: const Text(
                                                                'پس از ذخیره، انتساب پایان می‌یابد؛ پرونده پرسنل و سابقه حذف نمی‌شوند.'),
                                                            actions: [
                                                              TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          c,
                                                                          false),
                                                                  child: const Text(
                                                                      'انصراف')),
                                                              FilledButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          c,
                                                                          true),
                                                                  child: const Text(
                                                                      'تأیید'))
                                                            ]));
                                                if (yes == true && mounted) {
                                                  setState(() =>
                                                      _occupants.remove(id));
                                                }
                                              })),
                              if (widget.item?.history.isNotEmpty == true) ...[
                                const Text('سوابق انتساب'),
                                for (final h in widget.item!.history)
                                  ListTile(
                                      title: Text('${h['employee']}'),
                                      subtitle: Text(
                                          'شروع: ${_assignmentDate(h['started_at'])}\nپایان: ${h['ended_at'] == null ? 'فعال' : _assignmentDate(h['ended_at'])}')),
                              ],
                            ],
                          ))),
                  const SizedBox(height: 16),
                  const _OrgNotice(
                      icon: Icons.info_outline,
                      color: AsoudColors.primary,
                      text:
                          'بالادست سازمانی با نقش دسترسی متفاوت است؛ ثبت این جایگاه دسترسی کاربری ایجاد نمی‌کند.'),
                ]),
              )),
              bottomNavigationBar: AsoudBottomActions(
                primaryLabel: _saving ? 'در حال ذخیره…' : 'ذخیره جایگاه',
                onPrimary: busy ? null : _save,
                secondaryLabel: 'انصراف',
                onSecondary: busy ? null : _discard,
              ),
            ),
          );
        },
      );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cubit = context.read<OrganizationCubit>();
    if (cubit.state.busy || _saving) return;
    final rows = cubit.state.snapshot.rows;
    final matches = rows.where((row) => row.code == _editingCode);
    if (_editingCode != null && matches.isNotEmpty) {
      final latest = matches.first;
      final original = _savedDraft ?? widget.item!;
      final matchesOriginal =
          jsonEncode(latest.toJson()) == jsonEncode(original.toJson());
      final matchesDraft = latest.title == _title.text.trim() &&
          latest.parent == _parentCode &&
          latest.department == _department.text.trim() &&
          latest.departmentId == _departmentId &&
          latest.capacity == int.tryParse(_normalizedOrgCode(_capacity.text)) &&
          latest.duties == _duties.text.trim() &&
          jsonEncode(latest.activeEmployees) == jsonEncode(_occupants);
      if (!matchesOriginal && !matchesDraft) {
        setState(() => _error =
            'اطلاعات این جایگاه تغییر کرده؛ فرم را ببندید و از نسخه جدید دوباره باز کنید.');
        return;
      }
    }
    if (_editingCode != null && !rows.any((row) => row.code == _editingCode)) {
      setState(() => _error = 'این جایگاه دیگر وجود ندارد؛ به فهرست بازگردید.');
      return;
    }
    final position = OrgPosition(
        code: widget.item?.code ?? _normalizedOrgCode(_code.text.trim()),
        title: _title.text.trim(),
        parent: _parentCode,
        department: _department.text.trim(),
        departmentId: _departmentId,
        occupants: List.of(_occupants),
        capacity: int.parse(_normalizedOrgCode(_capacity.text.trim())),
        duties: _duties.text.trim(),
        history: widget.item?.history ?? const [],
        employee: '');
    final candidate = [
      ...rows.where((row) => row.code != _editingCode),
      position
    ];
    try {
      validateOrganization(candidate);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await cubit.save(candidate);
    if (!mounted) return;
    setState(() {
      if (!saved &&
          cubit.state.snapshot.pending &&
          cubit.state.snapshot.rows.any((row) =>
              row.code == position.code &&
              row.title == position.title &&
              row.parent == position.parent &&
              row.department == position.department &&
              row.employee == position.employee)) {
        _savedDraft = position;
      }
      _saving = false;
      _error = saved ? null : cubit.state.error;
    });
    if (saved) Navigator.pop(context, true);
  }
}
