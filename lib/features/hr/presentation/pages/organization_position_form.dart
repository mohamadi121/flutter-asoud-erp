part of 'organization_page.dart';

class _OrganizationPositionForm extends StatefulWidget {
  const _OrganizationPositionForm({this.item, this.parent});
  final OrgPosition? item, parent;
  @override
  State<_OrganizationPositionForm> createState() =>
      _OrganizationPositionFormState();
}

class _OrganizationPositionFormState extends State<_OrganizationPositionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _department;
  late String _employee;
  List<OrganizationEmployee> _people = [];
  bool _loadingPeople = false;
  bool _saving = false;
  OrgPosition? _savedDraft;
  String? get _editingCode => _savedDraft?.code ?? widget.item?.code;
  String? _peopleError, _error;

  String get _parentCode => widget.item?.parent ?? widget.parent?.code ?? '';

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.item?.code ?? '');
    _title = TextEditingController(text: widget.item?.title ?? '');
    _department = TextEditingController(
        text: widget.item?.department ?? widget.parent?.department ?? '');
    _employee = widget.item?.employee ?? '';
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
      if (!mounted) return;
      setState(() => _people = people);
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
          final assigned = state.snapshot.rows
              .where((row) => row.code != _editingCode)
              .map((row) => row.employee)
              .where((id) => id.isNotEmpty)
              .toSet();
          final available = _people
              .where((person) =>
                  !assigned.contains(person.id) || person.id == _employee)
              .toList();
          return PopScope(
            canPop: !_saving,
            child: Scaffold(
              appBar: AsoudHeader(
                  title: widget.item == null
                      ? 'افزودن جایگاه سازمانی'
                      : 'ویرایش جایگاه سازمانی',
                  subtitle: _parentCode.isEmpty
                      ? 'اطلاعات جایگاه اصلی'
                      : 'زیرمجموعه $parentTitle'),
              body: SafeArea(
                  child: Form(
                key: _formKey,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  const _OrganizationStatus(),
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
                              TextFormField(
                                controller: _title,
                                enabled: !busy,
                                decoration: const InputDecoration(
                                    labelText: 'عنوان جایگاه *',
                                    prefixIcon: Icon(Icons.badge_outlined)),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'عنوان جایگاه را وارد کنید.'
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _code,
                                enabled: !busy && widget.item == null,
                                textDirection: TextDirection.ltr,
                                decoration: const InputDecoration(
                                    labelText: 'کد جایگاه *',
                                    prefixIcon: Icon(Icons.tag)),
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
                              TextFormField(
                                controller: _department,
                                enabled: !busy,
                                decoration: const InputDecoration(
                                    labelText: 'واحد سازمانی',
                                    prefixIcon: Icon(Icons.business_outlined)),
                              ),
                              const SizedBox(height: 16),
                              _OrgNotice(
                                  icon: Icons.account_tree_outlined,
                                  color: AsoudColors.primary,
                                  text: 'بالادست: $parentTitle'),
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
                                  'اختیاری؛ هر پرسنل فقط یک جایگاه دارد. مدیر مستقیم از پرسنل بالادست خوانده می‌شود؛ بالادست خالی یعنی بدون مدیر مستقیم. ذخیره، این رابطه را در پرونده پرسنل نیز به‌روز می‌کند.',
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
                              DropdownButtonFormField<String>(
                                key: ValueKey('org-employee-$_employee'),
                                initialValue: _employee,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'پرسنل',
                                    prefixIcon: Icon(Icons.person_outline)),
                                items: [
                                  const DropdownMenuItem(
                                      value: '', child: Text('جایگاه خالی')),
                                  if (_employee.isNotEmpty &&
                                      !available.any(
                                          (person) => person.id == _employee))
                                    DropdownMenuItem(
                                        value: _employee,
                                        child: Text(_employee,
                                            overflow: TextOverflow.ellipsis)),
                                  ...available.map((person) => DropdownMenuItem(
                                      value: person.id,
                                      child: Text(person.displayName,
                                          overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: busy || _loadingPeople
                                    ? null
                                    : (value) =>
                                        setState(() => _employee = value ?? ''),
                              ),
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
                onSecondary: busy ? null : () => Navigator.pop(context),
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
      final matchesOriginal = latest.title == original.title &&
          latest.parent == original.parent &&
          latest.department == original.department &&
          latest.employee == original.employee;
      final matchesDraft = latest.title == _title.text.trim() &&
          latest.parent == _parentCode &&
          latest.department == _department.text.trim() &&
          latest.employee == _employee;
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
        employee: _employee);
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
