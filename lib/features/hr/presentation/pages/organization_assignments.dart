part of 'organization_page.dart';

class _OrganizationAssignments extends StatefulWidget {
  const _OrganizationAssignments({super.key, required this.code, required this.canManage,
    this.embedded = false, this.onClose, this.onBusy});
  final String code;
  final bool canManage;
  final bool embedded;
  final VoidCallback? onClose;
  final ValueChanged<bool>? onBusy;
  @override
  State<_OrganizationAssignments> createState() =>
      _OrganizationAssignmentsState();
}

class _OrganizationAssignmentsState extends State<_OrganizationAssignments> {
  late String code = widget.code;
  late Future<List<OrganizationEmployee>> people;
  bool history = false;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  void _loadPeople() {
    final c = context.read<OrganizationCubit>();
    people = c.repository.employees(c.company);
    people.ignore();
  }

  Future<void> _change(OrgPosition original, List<String> occupants) async {
    final c = context.read<OrganizationCubit>();
    if (saving || c.state.busy || !widget.canManage) return;
    final latest =
        c.state.snapshot.rows.where((r) => r.code == original.code).firstOrNull;
    if (latest == null ||
        jsonEncode(latest.toJson()) != jsonEncode(original.toJson())) {
      _orgMessage(context, 'اطلاعات جایگاه تغییر کرده؛ دوباره بررسی کنید.');
      return;
    }
    final rows = [
      for (final r in c.state.snapshot.rows)
        if (r.code == original.code) r.copyWith(occupants: occupants) else r
    ];
    try {
      validateOrganization(rows);
    } on FormatException catch (e) {
      _orgMessage(context, e.message);
      return;
    }
    setState(() => saving = true);
    widget.onBusy?.call(true);
    final saved = await c.save(rows);
    widget.onBusy?.call(false);
    if (!mounted) return;
    setState(() => saving = false);
    _orgMessage(
        context,
        saved
            ? (c.state.snapshot.pending
                ? 'تغییرات محلی است و هنوز با سرور همگام نشده.'
                : 'تغییرات انتساب ثبت شد.')
            : (c.state.error ?? 'ثبت تغییرات تأیید نشد.'));
  }

  Future<void> _end(OrgPosition row, String employee) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('پایان انتساب'),
                content: const Text(
                    'انتساب این پرسنل پایان یابد؟ پرونده پرسنل و سوابق حذف نمی‌شوند.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('تأیید پایان انتساب'))
                ]));
    if (yes == true && mounted) {
      await _change(
          row, row.activeEmployees.where((id) => id != employee).toList());
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OrganizationCubit, OrganizationState>(
          builder: (context, state) {
        final row =
            state.snapshot.rows.where((r) => r.code == code).firstOrNull;
        final body = row == null
                  ? Center(child: Text('جایگاه در دسترس نیست.'))
                  : FutureBuilder<List<OrganizationEmployee>>(
                      future: people,
                      builder: (context, snapshot) {
                        final employees = snapshot.data ?? [];
                        String name(String id) =>
                            employees
                                .where((p) => p.id == id)
                                .map((p) => p.displayName)
                                .firstOrNull ??
                            'پرسنل منتسب';
                        String personnelCode(String id) =>
                            employees
                                .where((p) => p.id == id)
                                .map((p) => p.personnelCode)
                                .firstOrNull ??
                            id.replaceFirst('employee:', '');
                        final blocked = saving ||
                            state.busy ||
                            state.snapshot.pending ||
                            state.snapshot.rejected;
                        return ListView(
                            shrinkWrap: widget.embedded,
                            physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
                            padding: const EdgeInsets.all(16),
                            children: [
                              Container(
                                  decoration: _orgWhiteCard(),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(children: [
                                    _OrgDetailIdentity(
                                        title: row.displayTitle,
                                        subtitle: row.displayDepartment,
                                        position: true),
                                    AppSelectField(
                                        label: 'جایگاه شغلی',
                                        value: code,
                                        displayValue: row.displayTitle,
                                        enabled: !saving && !widget.embedded,
                                        onPick: () => showAppOptionSheet(
                                                context,
                                                title: 'انتخاب جایگاه',
                                                current: code,
                                                options: [
                                                  for (final r
                                                      in state.snapshot.rows)
                                                    AppOption(r.code, r.displayTitle)
                                                ]),
                                        onChanged: (v) =>
                                            setState(() => code = v)),
                                    const SizedBox(height: 16),
                                    Row(children: [
                                      for (final item in [
                                        (row.capacity, 'ظرفیت کل', 0),
                                        (
                                          row.activeEmployees.length,
                                          'منتسب‌شده',
                                          2
                                        ),
                                        (
                                          row.capacity -
                                              row.activeEmployees.length,
                                          'ظرفیت خالی',
                                          3
                                        )
                                      ])
                                        Expanded(
                                            child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 3),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 14,
                                                        horizontal: 4),
                                                decoration: BoxDecoration(
                                                    color: _orgTints[item.$3],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14)),
                                                child: Column(children: [
                                                  Text(formatNumber(item.$1),
                                                      style: TextStyle(
                                                          fontSize: 21,
                                                          color: _orgAccents[
                                                              item.$3])),
                                                  const SizedBox(height: 8),
                                                  Text(item.$2,
                                                      style: const TextStyle(
                                                          fontSize: 10),
                                                      textAlign:
                                                          TextAlign.center)
                                                ]))),
                                    ]),
                                  ])),
                              const SizedBox(height: 14),
                              _OrgNotice(
                                  icon: Icons.verified_user_outlined,
                                  color: _orgAccents[0],
                                  text: widget.canManage
                                      ? 'دسترسی مدیریت منابع انسانی؛ تغییرات با مجوز واقعی حساب شما ثبت می‌شوند.'
                                      : 'فقط مشاهده؛ اجازه تغییر انتساب‌ها را ندارید.'),
                              const _OrganizationStatus(),
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting)
                                const LinearProgressIndicator(),
                              if (snapshot.hasError)
                                TextButton(
                                    onPressed: () => setState(_loadPeople),
                                    child: const Text(
                                        'دریافت پرسنل ناموفق بود؛ تلاش دوباره')),
                              const SizedBox(height: 12),
                              Row(children: [
                                for (final item in [
                                  (false, 'پرسنل فعلی'),
                                  (true, 'سوابق انتساب')
                                ])
                                  Expanded(
                                      child: TextButton(
                                          style: TextButton.styleFrom(
                                              backgroundColor:
                                                  history == item.$1
                                                      ? const Color(0xffeeeeef)
                                                      : Colors.transparent),
                                          onPressed: () =>
                                              setState(() => history = item.$1),
                                          child: Text(item.$2)))
                              ]),
                              const SizedBox(height: 12),
                              Container(
                                  decoration: _orgWhiteCard(),
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                            history
                                                ? 'سوابق انتساب'
                                                : 'پرسنل این جایگاه',
                                            style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 14),
                                        if (history && row.history.isEmpty)
                                          const Text('سابقه‌ای ثبت نشده است.'),
                                        if (!history &&
                                            row.activeEmployees.isEmpty)
                                          const Text(
                                              'هنوز پرسنلی به این جایگاه منتسب نشده است.'),
                                        if (history)
                                          for (final h in row.history)
                                            Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 12),
                                                padding:
                                                    const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                    color: _orgTints[1],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16)),
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                          name(
                                                              '${h['employee']}'),
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                      Text(
                                                          'کد پرسنلی: ${personnelCode('${h['employee']}')}'),
                                                      const SizedBox(
                                                          height: 12),
                                                      Text(
                                                          'شروع: ${_assignmentDate(h['started_at'])}'),
                                                      Text(
                                                          'پایان: ${h['ended_at'] == null ? 'فعال' : _assignmentDate(h['ended_at'])}'),
                                                    ])),
                                        if (!history) ...[
                                          for (final id in row.activeEmployees)
                                            Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 12),
                                                padding:
                                                    const EdgeInsets.all(14),
                                                decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xfff2f7fa),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16)),
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      ListTile(
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                          leading: AsoudIconBox(
                                                              icon: Icons
                                                                  .person_outline,
                                                              color:
                                                                  _orgAccents[
                                                                      0],
                                                              size: 40),
                                                          title: Text(name(id)),
                                                          subtitle: Text(
                                                              'کد پرسنلی: ${personnelCode(id)}')),
                                                      Text(
                                                          state.snapshot.pending
                                                              ? 'انتساب محلی؛ در انتظار تأیید سرور'
                                                              : 'انتساب فعال',
                                                          style: TextStyle(
                                                              color:
                                                                  _orgAccents[
                                                                      2],
                                                              fontSize: 12)),
                                                      if (widget.canManage)
                                                        OutlinedButton.icon(
                                                            onPressed: blocked
                                                                ? null
                                                                : () => _end(
                                                                    row, id),
                                                            icon: const Icon(
                                                                Icons
                                                                    .event_busy_outlined,
                                                                size: 18),
                                                            label: const Text(
                                                                'پایان انتساب')),
                                                    ])),
                                          if (widget.canManage)
                                            FilledButton.icon(
                                                onPressed: blocked ||
                                                        !snapshot.hasData ||
                                                        row.activeEmployees
                                                                .length >=
                                                            row.capacity
                                                    ? null
                                                    : () async {
                                                        final id = await _pickOrganizationEmployee(
                                                            context,
                                                            employees
                                                                .where((p) => !row
                                                                    .activeEmployees
                                                                    .contains(
                                                                        p.id))
                                                                .toList());
                                                        if (!mounted ||
                                                            id == null ||
                                                            id.isEmpty) {
                                                          return;
                                                        }
                                                        await _change(row, [
                                                          ...row
                                                              .activeEmployees,
                                                          id
                                                        ]);
                                                      },
                                                icon: const Icon(
                                                    Icons.person_add_alt_1,
                                                    size: 19),
                                                label: const Text(
                                                    'انتساب پرسنل جدید')),
                                          if (row.activeEmployees.length >=
                                              row.capacity)
                                            const Text(
                                                'ظرفیت جایگاه تکمیل است.',
                                                style: TextStyle(fontSize: 12)),
                                        ],
                                      ])),
                              if (widget.embedded) ...[
                                const Text('تاریخ شروع و پایان واقعی را سرور هنگام ثبت و پایان انتساب نگه می‌دارد؛ تعیین بازهٔ دلخواه در API فعلی پشتیبانی نمی‌شود.',
                                  style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
                                OutlinedButton(onPressed: saving ? null : widget.onClose, child: const Text('بستن انتساب')),
                              ] else const _OrgTabFooter(),
                            ]);
                      });
        if (widget.embedded) return body;
        return PopScope(canPop: !saving, child: _OrgSheetTheme(child: Scaffold(
          backgroundColor: _orgCanvas,
          appBar: const _OrganizationReferenceHeader(title: 'انتساب پرسنل', form: true),
          body: body)));
      });
}

class _UnitPositions extends StatefulWidget {
  const _UnitPositions({required this.unit, required this.canManage});
  final Map<String, dynamic> unit;
  final bool canManage;
  @override
  State<_UnitPositions> createState() => _UnitPositionsState();
}

class _UnitPositionsState extends State<_UnitPositions> {
  final title = TextEditingController();
  bool adding = false, saving = false;
  bool allowClose = false;
  bool confirming = false;
  String? error;
  String? draftCode;
  Future<void> _discard({bool close = false}) async {
    if (saving || confirming) return;
    confirming = true;
    final discard =
        title.text.trim().isEmpty || await _confirmOrgDiscard(context);
    confirming = false;
    if (!mounted || !discard) return;
    setState(() {
      adding = false;
      title.clear();
      error = null;
      allowClose = close;
    });
    if (close) Navigator.pop(context);
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final c = context.read<OrganizationCubit>();
    if (saving ||
        c.state.busy ||
        title.text.trim().isEmpty ||
        !widget.canManage) {
      return;
    }
    draftCode ??=
        'POS-${List.generate(16, (_) => math.Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    final row = OrgPosition(
        code: draftCode!,
        title: title.text.trim(),
        departmentId: '${widget.unit['name']}',
        department: '${widget.unit['department_name']}',
        occupants: const []);
    final rows = [
      ...c.state.snapshot.rows.where((r) => r.code != draftCode),
      row
    ];
    try {
      validateOrganization(rows);
    } on FormatException catch (e) {
      setState(() => error = e.message);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final saved = await c.save(rows);
    if (!mounted) return;
    setState(() {
      saving = false;
      error = saved ? null : c.state.error;
      if (saved) {
        adding = false;
        title.clear();
        draftCode = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OrganizationCubit, OrganizationState>(
          builder: (context, state) {
        final rows = state.snapshot.rows
            .where((r) => r.departmentId == widget.unit['name']);
        return PopScope(
            canPop:
                !saving && (allowClose || !adding || title.text.trim().isEmpty),
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) _discard(close: true);
            },
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OrgDetailSection(
                      title: 'جایگاه‌های شغلی',
                      icon: Icons.work_outline,
                      color: _orgAccents[2],
                      addKey:
                          const ValueKey('organization-inline-position-open'),
                      onAdd: widget.canManage && !adding
                          ? () => setState(() => adding = true)
                          : null),
                  if (rows.isEmpty)
                    const _OrgNotice(
                        icon: Icons.work_outline,
                        color: AsoudColors.success,
                        text: 'هنوز جایگاه شغلی تعریف نشده است.'),
                  for (final row in rows)
                    _OrgDetailRow(
                        title: row.displayTitle,
                        position: true,
                        onTap: () => _orgSheet<void>(
                            context,
                            _PositionDetails(
                                code: row.code, canManage: widget.canManage))),
                  if (adding)
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xfff2faf7),
                            borderRadius: BorderRadius.circular(16)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppTextField(
                                  controller: title,
                                  label: 'عنوان جایگاه جدید',
                                  enabled: !saving,
                                  onChanged: (_) => setState(() {})),
                              if (error != null)
                                Text(error!,
                                    style: const TextStyle(
                                        color: AsoudColors.danger)),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                    child: FilledButton(
                                        key: const ValueKey(
                                            'organization-inline-position-save'),
                                        onPressed: saving ||
                                                state.busy ||
                                                title.text.trim().isEmpty
                                            ? null
                                            : save,
                                        child: Text(saving
                                            ? 'در حال ثبت…'
                                            : 'افزودن'))),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: OutlinedButton(
                                        onPressed: saving ? null : _discard,
                                        child: const Text('انصراف')))
                              ]),
                            ])),
                  if (state.snapshot.pending)
                    const Text('تغییرات محلی در انتظار تأیید سرور است.'),
                ]));
      });
}
