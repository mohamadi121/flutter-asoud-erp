part of 'organization_page.dart';

@visibleForTesting
Map<String, dynamic> templateOrganizationPayload(OrganizationTemplate template,
    {List<Map<String, dynamic>> existingUnits = const []}) {
  // A template unit whose title already exists as a unit is matched to it by
  // its real id instead of being created again.
  final existing = <String, String>{
    for (final u in existingUnits)
      if (u['disabled'] != 1) '${u['department_name']}': '${u['name']}'
  };
  final departments = template.positions
      .map((p) => p.department)
      .where((d) => d.isNotEmpty)
      .toSet()
      .toList();
  final ids = {
    for (var i = 0; i < departments.length; i++) departments[i]: 'UNIT-${i + 1}'
  };
  return {
    'template': true,
    'template_title': template.title,
    'units': [
      for (final title in departments)
        {
          'code': ids[title],
          'title': title,
          'parent': '',
          if (existing.containsKey(title)) 'name': existing[title]
        }
    ],
    'rows': [
      for (final p in template.positions)
        p.copyWith(
            departmentId: ids[p.department] ?? '', occupants: []).toJson()
    ],
  };
}

class _OrganizationImportReview extends StatefulWidget {
  const _OrganizationImportReview({required this.payload, this.unitLabels = const {}});
  final Map<String, dynamic> payload;
  final Map<String, String> unitLabels;
  @override
  State<_OrganizationImportReview> createState() =>
      _OrganizationImportReviewState();
}

class _OrganizationImportReviewState extends State<_OrganizationImportReview> {
  Map<String, dynamic>? preview;
  String? error;
  bool busy = false;
  bool expandedUnits = false;
  @override
  void initState() {
    super.initState();
    _preview();
  }

  Future<void> _preview() async {
    setState(() {
      busy = true;
      error = null;
      preview = null;
    });
    try {
      final c = context.read<OrganizationCubit>();
      if (c.state.snapshot.pending) {
        throw const FormatException(
            'ابتدا پیش‌نویس چارت را همگام یا با نسخه سرور مقایسه کنید.');
      }
      final result =
          await c.repository.previewImport(c.company, widget.payload);
      if (mounted) setState(() => preview = result);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException
            ? e.message
            : e is FormatException && e.message.isNotEmpty
                ? e.message
                : 'پیش‌نمایش ورود آماده نشد؛ دوباره تلاش کنید.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _apply() async {
    if (busy || preview == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final c = context.read<OrganizationCubit>();
      await c.repository.applyImport(
          c.company, widget.payload, (preview!['revision'] as num).toInt());
      await c.load();
      if (mounted) {
        setState(() => busy = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException
            ? e.message
            : 'نتیجه ورود تأیید نشد؛ نسخه سرور را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: Scaffold(
          appBar: const AsoudHeader(title: 'پیش‌نمایش ساختار سازمانی'),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Text(error!, style: const TextStyle(color: AsoudColors.danger)),
            const Text(
                'واحد موجود فقط با شناسه صریح تطبیق می‌یابد؛ اطلاعات قبلی بازنویسی نمی‌شود. ثبت همه ردیف‌ها یک تراکنش است.'),
            if (preview != null) ...[
              if (widget.payload['template'] == true) ...[
                Text('${widget.payload['template_title']}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(formatCount(
                    (preview!['additions'] as List).length, 'جایگاه پیشنهادی')),
                const SizedBox(height: 16),
                const Center(
                    child: AsoudIconBox(
                        icon: Icons.person_outline,
                        color: AsoudColors.primary,
                        size: 52)),
                const Center(child: Text('مدیرعامل')),
                const Center(
                    child: Text('│\nواحدهای سازمانی\n│',
                        textAlign: TextAlign.center)),
                GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.8,
                    children: [
                      for (final unit in (preview!['units'] as List)
                          .take(expandedUnits ? 500 : 4))
                        Card(
                            color: _unitColor('${unit['name']}')
                                .withValues(alpha: .1),
                            child: Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(organizationLabel('${unit['title']}'),
                                        textAlign: TextAlign.center)))),
                    ]),
                TextButton(
                    onPressed: () =>
                        setState(() => expandedUnits = !expandedUnits),
                    child: Text(
                        expandedUnits ? 'نمایش کمتر' : 'نمایش همه واحدها')),
                const Text(
                    'این نمایش خلاصه واحدهاست؛ فهرست کامل جایگاه‌ها در پایین آمده است.'),
              ],
              Text('${formatCount((preview!["units"] as List).length, "واحد بررسی‌شده")} · ${formatCount((preview!["additions"] as List).length, "جایگاه جدید")}'),
              for (final unit in preview!['units'] as List)
                ListTile(
                    title: Text(organizationLabel('${unit['title']}')),
                    subtitle: Text('${unit['action'] == 'match' ? 'واحد موجود' : 'واحد جدید'} · بالادستی: ${_unitLabel('${unit['parent'] ?? ''}')}')),
              for (final row in preview!['additions'] as List)
                ListTile(
                    title: Text(organizationLabel('${row['title']}')),
                    subtitle: Text(
                        'بالادست: ${_positionLabel('${row['parent'] ?? ''}')}\nواحد: ${row['department'] == '' || row['department'] == null ? 'بدون واحد' : organizationLabel('${row['department']}')} · ظرفیت: ${toPersianDigits('${row['capacity'] ?? 1}')}')),
            ],
            TextButton(
                onPressed: busy ? null : _preview,
                child: const Text('بازخوانی پیش‌نمایش')),
            FilledButton(
                onPressed:
                    busy || preview == null || error != null ? null : _apply,
                child: const Text('تأیید و ایجاد ساختار')),
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('بازگشت و ویرایش')),
          ])));

  String _unitLabel(String id) => id.isEmpty
      ? 'بدون بالادستی / واحد اصلی'
      : (preview?['units'] as List? ?? [])
              .where((u) => u['name'] == id)
              .map((u) => organizationLabel('${u['title']}')).firstOrNull ??
          (widget.unitLabels[id] == null ? 'واحد موجود (نام در دسترس نیست)' : organizationLabel(widget.unitLabels[id]));

  String _positionLabel(String code) => code.isEmpty
      ? 'بدون جایگاه بالادستی'
      : (preview?['rows'] as List? ?? [])
              .where((p) => p['code'] == code)
              .map((p) => organizationLabel('${p['title']}')).firstOrNull ?? 'جایگاه در دسترس نیست';
}

Future<String?> _pickOrganizationEmployee(
    BuildContext context, List<OrganizationEmployee> people) {
  var query = '';
  return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
          builder: (c, update) => Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                  child: Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(c).bottom),
                      child: SizedBox(
                          height: MediaQuery.sizeOf(c).height * .6,
                          child: Column(children: [
                            const Text('جست‌وجوی پرسنل'),
                            Padding(
                                padding: const EdgeInsets.all(12),
                                child: TextField(
                                    onChanged: (v) =>
                                        update(() => query = v.trim()),
                                    decoration: const InputDecoration(
                                        hintText:
                                            'نام، نام خانوادگی یا کد پرسنلی...',
                                        prefixIcon: Icon(Icons.search)))),
                            Expanded(
                                child: ListView(children: [
                              ListTile(
                                  title: const Text('جایگاه خالی'),
                                  onTap: () => Navigator.pop(c, '')),
                              for (final p in people.where((p) =>
                                  '${p.displayName} ${p.personnelCode} ${p.id}'
                                      .contains(query)))
                                ListTile(
                                    title: Text(p.displayName),
                                    subtitle: Text(p.personnelCode.isEmpty
                                        ? p.id.replaceFirst('employee:', '')
                                        : p.personnelCode),
                                    onTap: () => Navigator.pop(c, p.id)),
                            ])),
                          ])))))));
}

Future<T?> _orgSheet<T>(BuildContext context, Widget child) {
  if (child is _UnitDetails || child is _UnitForm) {
    return _openOrganizationPage<T>(context, _OrgSheetTheme(child: child));
  }
  final cubit = context.read<OrganizationCubit>();
  return showModalBottomSheet<T>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _orgCanvas,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      clipBehavior: Clip.antiAlias,
      builder: (c) => BlocProvider.value(
          value: cubit,
          child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(c).bottom),
                  child: SizedBox(
                          height: MediaQuery.sizeOf(c).height * .85,
                          child: _OrgSheetTheme(child: child))))));
}

Future<bool> _confirmOrgDiscard(BuildContext context) async =>
    await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('انصراف از تغییرات؟'),
                content: const Text('تغییرات ذخیره‌نشده از بین می‌روند.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('ادامه ویرایش')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('انصراف'))
                ])) ==
    true;

Color _unitColor(String key) {
  const colors = [
    AsoudColors.primary,
    AsoudColors.success,
    AsoudColors.warning,
    Color(0xff805ad5),
    Color(0xffd97770)
  ];
  return colors[key.codeUnits.fold<int>(0, (a, b) => a + b) % colors.length];
}

class _OrganizationWorkspace extends StatelessWidget {
  const _OrganizationWorkspace({required this.canManage});
  final bool canManage;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: _orgCanvas,
      appBar: const _OrganizationReferenceHeader(
          title: 'مدیریت ساختار سازمانی', compact: true, form: true),
      body: _OrganizationUnits(canManage: canManage, hierarchy: true));
}

class _PositionList extends StatefulWidget {
  const _PositionList({required this.canManage});
  final bool canManage;
  @override
  State<_PositionList> createState() => _PositionListState();
}

class _PositionListState extends State<_PositionList> {
  String query = '';
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OrganizationCubit, OrganizationState>(
          builder: (context, state) {
        return ListView(padding: const EdgeInsets.all(16), children: [
          _OrgTabHeading(
              title: 'جایگاه‌های سازمانی',
              action: 'جایگاه جدید',
              canManage: widget.canManage,
              onCreate: state.busy
                  ? null
                  : () => _openOrganizationPage<bool>(
                      context, const _OrganizationCreateForm(position: true))),
          OutlinedButton.icon(
              onPressed: () => _openOrganizationPage<void>(
                  context,
                  _OrganizationVisualReport(canManage: widget.canManage)),
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('گزارش تصویری چارت')),
          const SizedBox(height: 16),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _orgTints[0], borderRadius: BorderRadius.circular(18)),
              child: const Text(
                  'جایگاه شغلی مستقل از حساب کاربری و نقش دسترسی است. انتساب پرسنل در مراحل مربوط به منابع انسانی انجام می‌شود.',
                  style: TextStyle(
                      fontSize: 12, height: 1.9, color: Color(0xff697587)))),
          const SizedBox(height: 16),
          _OrganizationTree(
              rows: state.snapshot.rows,
              query: query,
              cardStyle: true,
              canManage: widget.canManage,
              onClearSearch: () => setState(() => query = '')),
          const _OrgTabFooter(),
        ]);
      });
}

class _PositionDetails extends StatelessWidget {
  const _PositionDetails({required this.code, required this.canManage});
  final String code;
  final bool canManage;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OrganizationCubit, OrganizationState>(
          builder: (context, state) {
        final row =
            state.snapshot.rows.where((r) => r.code == code).firstOrNull;
        if (row == null) {
          return const _OrgDetailPage(
              title: 'جزئیات جایگاه',
              children: [Text('جایگاه در دسترس نیست.')]);
        }
        return _OrgDetailPage(title: 'جزئیات جایگاه', children: [
          _OrgDetailIdentity(
              title: row.displayTitle,
              position: true,
              subtitle:
                  'واحد: ${row.displayDepartment}\nبالادست: ${state.snapshot.rows.where((r) => r.code == row.parent).map((r) => r.displayTitle).firstOrNull ?? 'بدون بالادست'}'),
          Text(
              'ظرفیت: ${row.capacity} · ظرفیت خالی: ${row.capacity - row.activeEmployees.length}'),
          if (row.duties.isNotEmpty) Text(row.duties),
          if (canManage)
            OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: state.busy
                    ? null
                    : () => _orgSheet<bool>(
                        context,
                        _OrganizationPositionForm(
                            item: row,
                            unitId: row.departmentId,
                            unitTitle: row.department)),
                label: const Text('ویرایش مشخصات جایگاه')),
          FilledButton.icon(
              onPressed: () => _orgSheet<void>(context,
                  _OrganizationAssignments(code: code, canManage: canManage)),
              icon: const Icon(Icons.people_outline),
              label: const Text('انتساب پرسنل و سوابق')),
          const SizedBox(height: 16),
          DefaultTabController(
              length: 2,
              child: Column(children: [
                const TabBar(
                    tabs: [Tab(text: 'پرسنل فعلی'), Tab(text: 'سوابق انتساب')]),
                SizedBox(
                    height: 300,
                    child: TabBarView(children: [
                      _Occupants(ids: row.activeEmployees),
                      _AssignmentHistory(history: row.history),
                    ])),
              ])),
          const _OrgDetailSection(title: 'جایگاه‌های زیرمجموعه'),
          if (!state.snapshot.rows.any((r) => r.parent == code))
            const Text('هنوز زیرمجموعه‌ای تعریف نشده است.'),
          for (final child
              in state.snapshot.rows.where((r) => r.parent == code))
            _OrgDetailRow(
                title: child.displayTitle,
                position: true,
                onTap: () => _orgSheet<void>(context,
                    _PositionDetails(code: child.code, canManage: canManage))),
        ]);
      });
}

class _AssignmentHistory extends StatefulWidget {
  const _AssignmentHistory({required this.history});
  final List<Map<String, dynamic>> history;
  @override
  State<_AssignmentHistory> createState() => _AssignmentHistoryState();
}

class _AssignmentHistoryState extends State<_AssignmentHistory> {
  late Future<List<OrganizationEmployee>> people;
  @override
  void initState() {
    super.initState();
    final cubit = context.read<OrganizationCubit>();
    people = cubit.repository.employees(cubit.company);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<OrganizationEmployee>>(
          future: people,
          builder: (context, snap) => ListView(children: [
                if (widget.history.isEmpty)
                  const ListTile(title: Text('سابقه‌ای ثبت نشده است.')),
                for (final entry in widget.history)
                  ListTile(
                      title: Text(snap.data
                              ?.where((p) => p.id == entry['employee'])
                              .map((p) => p.displayName)
                              .firstOrNull ??
                          'پرسنل منتسب'),
                      subtitle: Text(
                          'شروع: ${_assignmentDate(entry['started_at'])}\nپایان: ${entry['ended_at'] == null ? 'فعال' : _assignmentDate(entry['ended_at'])}')),
              ]));
}

class _Occupants extends StatefulWidget {
  const _Occupants({required this.ids});
  final List<String> ids;
  @override
  State<_Occupants> createState() => _OccupantsState();
}

class _OccupantsState extends State<_Occupants> {
  late Future<List<OrganizationEmployee>> people;
  @override
  void initState() {
    super.initState();
    final cubit = context.read<OrganizationCubit>();
    people = cubit.repository.employees(cubit.company);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<OrganizationEmployee>>(
          future: people,
          builder: (context, snap) => ListView(children: [
                if (widget.ids.isEmpty)
                  const ListTile(title: Text('بدون متصدی')),
                if (snap.hasError)
                  const ListTile(title: Text('مشخصات پرسنل قابل دریافت نیست.')),
                for (final id in widget.ids)
                  ListTile(
                      leading: _OrganizationAvatar(employee: id),
                      title: Text(snap.data
                              ?.where((p) => p.id == id)
                              .map((p) => p.displayName)
                              .firstOrNull ??
                          'پرسنل منتسب'),
                      subtitle: Text(id.replaceFirst('employee:', ''))),
              ]));
}

class _OrganizationUnits extends StatefulWidget {
  const _OrganizationUnits({required this.canManage, this.hierarchy = false});
  final bool canManage;
  final bool hierarchy;
  @override
  State<_OrganizationUnits> createState() => _OrganizationUnitsState();
}

class _OrganizationUnitsState extends State<_OrganizationUnits> {
  late Future<Map<String, dynamic>> data;
  String query = '';
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final c = context.read<OrganizationCubit>();
    data = c.repository.units(c.company);
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<OrganizationCubit, OrganizationState>(
          listenWhen: (before, after) =>
              before.busy && !after.busy && after.error == null,
          listener: (context, state) => setState(_reload),
          child: FutureBuilder<Map<String, dynamic>>(
              future: data,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  if (widget.hierarchy) {
                    return _OrganizationFocus(units: const [], canManage: false,
                        initialError: failureMessage(snapshot.error));
                  }
                  return Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(failureMessage(snapshot.error),
                                    key: const ValueKey('organization-units-error'),
                                    textAlign: TextAlign.center),
                                TextButton(
                                    onPressed: () => setState(_reload),
                                    child: const Text(
                                        'دریافت واحدها ناموفق بود؛ تلاش دوباره')),
                              ])));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final units = (snapshot.data!['units'] as List)
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
                final manage =
                    widget.canManage && snapshot.data!['can_manage'] == true;
                if (widget.hierarchy) {
                  return _OrgSheetTheme(child: _OrganizationFocus(
                      units: units, canManage: manage));
                }
                return _OrganizationUnitList(
                    units: units,
                    canManage: manage,
                    onOpen: (unit) async {
                      await _orgSheet<void>(
                          context,
                          _UnitDetails(
                              unit: unit, units: units, canManage: manage));
                      if (mounted) setState(_reload);
                    });
              }));
}

class _UnitForm extends StatefulWidget {
  const _UnitForm(
      {required this.units,
      this.parent = ''});
  final List<Map<String, dynamic>> units;
  final String parent;
  @override
  State<_UnitForm> createState() => _UnitFormState();
}

class _UnitFormState extends State<_UnitForm> {
  late final TextEditingController title;
  late String parent;
  late bool group;
  bool busy = false;
  bool allowClose = false;
  late String initialParent;
  late bool initialGroup;
  String? error;
  bool get dirty =>
      title.text.isNotEmpty ||
      parent != initialParent ||
      group != initialGroup;
  Future<void> discard() async {
    if (busy) return;
    if (dirty && !await _confirmOrgDiscard(context)) return;
    if (!mounted) return;
    setState(() => allowClose = true);
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    title = TextEditingController();
    parent = widget.parent;
    group = true;
    initialParent = parent;
    initialGroup = group;
    title.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (busy) return;
    if (title.text.trim().isEmpty) {
      setState(() => error = 'عنوان واحد الزامی است.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final c = context.read<OrganizationCubit>();
      await c.repository.saveUnit(c.company, {
        'title': title.text.trim(),
        'parent': parent,
        'is_group': group
      });
      await c.load();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException
            ? e.message
            : 'ثبت واحد تأیید نشد؛ دوباره بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy && (allowClose || !dirty),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) discard();
      },
      child: Scaffold(
          appBar: _OrganizationReferenceHeader(
              form: true,
              title: widget.parent.isEmpty ? 'ایجاد واحد سازمانی' : 'افزودن زیرواحد'),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (error != null)
              Text(error!, style: const TextStyle(color: AsoudColors.danger)),
            AppTextField(
                  controller: title,
                  label: 'عنوان واحد',
                  required: true,
                  enabled: !busy),
            const SizedBox(height: 16),
            AppSelectField(
                value: parent.isEmpty ? '__root__' : parent,
                label: 'واحد بالادستی',
                enabled: !busy && widget.parent.isEmpty,
                displayValue: widget.units
                        .where((u) => u['name'] == parent)
                        .map((u) => organizationUnitLabel(u))
                        .firstOrNull ??
                    (parent.isEmpty
                        ? 'ریشه ساختار / بدون واحد بالادستی'
                        : parent),
                onPick: () => showAppOptionSheet(context,
                        title: 'واحد بالادستی',
                        current: parent,
                        options: [
                          const AppOption(
                              '', 'ریشه ساختار / بدون واحد بالادستی'),
                          ...widget.units
                              .where((u) =>
                                  u['disabled'] != 1 &&
                                  u['is_group'] == 1)
                              .map((u) => AppOption(
                                  '${u['name']}', organizationUnitLabel(u)))
                        ]),
                onChanged: (v) => setState(() => parent = v)),
            SwitchListTile(
                  title: const Text('امکان ایجاد زیرواحد'),
                  subtitle: const Text(
                      'واحد گروهی در ERPNext؛ برای واحد دارای زیرواحد قابل غیرفعال‌کردن نیست.'),
                  value: group,
                  onChanged: busy ? null
                      : (v) => setState(() => group = v)),
            FilledButton(
                key: const ValueKey('organization-unit-submit'),
                onPressed: busy ? null : _save,
                child: Text(busy
                    ? 'در حال ثبت…'
                    : 'افزودن واحد')),
            TextButton(
                onPressed: busy ? null : discard, child: const Text('انصراف')),
          ])));
}
