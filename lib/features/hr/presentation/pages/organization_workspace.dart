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
  const _OrganizationImportReview({required this.payload});
  final Map<String, dynamic> payload;
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
      if (mounted) Navigator.pop(context, true);
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
                                    child: Text('${unit['title']}',
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
              for (final unit in preview!['units'] as List)
                ListTile(
                    title: Text('${unit['title']}'),
                    subtitle: Text(unit['action'] == 'match'
                        ? 'تطبیق با شناسه موجود'
                        : 'ایجاد واحد جدید')),
              for (final row in preview!['additions'] as List)
                ListTile(
                    title: Text('${row['title']}'),
                    subtitle: Text(
                        'کد: ${row['code']} · بالادست: ${row['parent']}\nواحد: ${row['department'] ?? ''}')),
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
                child: const Text('انصراف')),
          ])));
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
                  child: child is _UnitDetails
                      ? ConstrainedBox(
                          constraints: BoxConstraints(
                              maxHeight: MediaQuery.sizeOf(c).height * .85),
                          child: _OrgSheetTheme(child: child))
                      : SizedBox(
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
  Widget build(BuildContext context) => DefaultTabController(
      length: 3,
      child: Scaffold(
          backgroundColor: _orgCanvas,
          appBar: const _OrganizationReferenceHeader(),
          body: NestedScrollView(
              headerSliverBuilder: (context, innerScrolled) => [
                    const SliverToBoxAdapter(child: _OrganizationSummary()),
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: TabBar(
                                dividerColor: Colors.transparent,
                                indicatorSize: TabBarIndicatorSize.tab,
                                indicator: BoxDecoration(
                                    color: const Color(0xffeeeeef),
                                    borderRadius: BorderRadius.circular(28)),
                                labelColor: const Color(0xff24252b),
                                unselectedLabelColor: const Color(0xff777982),
                                labelPadding: EdgeInsets.zero,
                                tabs: const [
                                  Tab(text: 'چارت سازمانی'),
                                  Tab(text: 'واحدها'),
                                  Tab(text: 'جایگاه‌ها')
                                ]))),
                  ],
              body: TabBarView(children: [
                _OrganizationUnits(canManage: canManage, hierarchy: true),
                _OrganizationUnits(canManage: canManage),
                _PositionList(canManage: canManage),
              ]))));
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
              title: row.title,
              position: true,
              subtitle:
                  'واحد: ${row.department}\nبالادست: ${state.snapshot.rows.where((r) => r.code == row.parent).map((r) => r.title).firstOrNull ?? 'بدون بالادست'}'),
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
                title: child.title,
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

  Future<void> _edit(List<Map<String, dynamic>> units,
      {Map<String, dynamic>? unit, String parent = ''}) async {
    final saved = await _orgSheet<bool>(
        context, _UnitForm(units: units, unit: unit, parent: parent));
    if (saved == true && mounted) setState(_reload);
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
                  return _OrganizationHierarchyPanel(
                      units: units,
                      canManage: manage,
                      onCreateUnit: () => _edit(units),
                      onOpenUnit: (unit) async {
                        await _orgSheet<void>(
                            context,
                            _UnitDetails(
                                unit: unit, units: units, canManage: manage));
                        if (mounted) setState(_reload);
                      });
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
      this.unit,
      this.parent = '',
      this.moveOnly = false});
  final bool moveOnly;
  final List<Map<String, dynamic>> units;
  final Map<String, dynamic>? unit;
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
  Set<String> get _excludedParents {
    final ids = <String>{if (widget.unit != null) '${widget.unit!['name']}'};
    var changed = true;
    while (changed) {
      final before = ids.length;
      for (final u in widget.units) {
        if (ids.contains(u['parent_department'])) ids.add('${u['name']}');
      }
      changed = before != ids.length;
    }
    return ids;
  }

  String? error;
  bool get dirty =>
      title.text != (widget.unit?['department_name'] ?? '') ||
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
    title = TextEditingController(
        text: widget.unit?['department_name'] as String? ?? '');
    parent = widget.unit?['parent_department'] as String? ?? widget.parent;
    group = widget.unit == null || widget.unit!['is_group'] == 1;
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
        if (widget.unit != null) 'name': widget.unit!['name'],
        if (widget.unit != null) 'modified': widget.unit!['modified'],
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
              title: widget.moveOnly
                  ? 'جابه‌جایی واحد'
                  : widget.unit == null
                      ? (widget.parent.isEmpty
                          ? 'ایجاد واحد سازمانی'
                          : 'افزودن زیرواحد')
                      : 'ویرایش مشخصات واحد'),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (error != null)
              Text(error!, style: const TextStyle(color: AsoudColors.danger)),
            if (!widget.moveOnly)
              AppTextField(
                  controller: title,
                  label: 'عنوان واحد',
                  required: true,
                  enabled: !busy),
            const SizedBox(height: 16),
            AppSelectField(
                value: parent.isEmpty ? '__root__' : parent,
                label: 'واحد بالادستی',
                enabled: !busy && (widget.unit == null || widget.moveOnly),
                displayValue: widget.units
                        .where((u) => u['name'] == parent)
                        .map((u) => '${u['department_name']}')
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
                                  !_excludedParents.contains(u['name']) &&
                                  u['disabled'] != 1 &&
                                  u['is_group'] == 1)
                              .map((u) => AppOption(
                                  '${u['name']}', '${u['department_name']}'))
                        ]),
                onChanged: (v) => setState(() => parent = v)),
            if (!widget.moveOnly)
              SwitchListTile(
                  title: const Text('امکان ایجاد زیرواحد'),
                  subtitle: const Text(
                      'واحد گروهی در ERPNext؛ برای واحد دارای زیرواحد قابل غیرفعال‌کردن نیست.'),
                  value: group,
                  onChanged: busy ||
                          widget.units.any((u) =>
                              u['parent_department'] == widget.unit?['name'])
                      ? null
                      : (v) => setState(() => group = v)),
            if (widget.unit != null && !widget.moveOnly)
              const Text(
                  'برای تغییر واحد بالادستی از مدیریت واحد ← جابه‌جایی استفاده کنید.'),
            FilledButton(
                key: const ValueKey('organization-unit-submit'),
                onPressed: busy || (widget.moveOnly && parent == initialParent)
                    ? null
                    : _save,
                child: Text(busy
                    ? 'در حال ثبت…'
                    : widget.moveOnly
                        ? 'ثبت جابه‌جایی'
                        : widget.unit == null
                            ? 'افزودن واحد'
                            : 'ثبت تغییرات')),
            TextButton(
                onPressed: busy ? null : discard, child: const Text('انصراف')),
          ])));
}

/// Blocks a second delete flow while one is already checking or deleting.
bool _unitDeleteRunning = false;

class _UnitDetails extends StatelessWidget {
  const _UnitDetails(
      {required this.unit, required this.units, required this.canManage});
  final Map<String, dynamic> unit;
  final List<Map<String, dynamic>> units;
  final bool canManage;
  @override
  Widget build(BuildContext context) =>
      _OrgDetailPage(title: 'جزئیات واحد', grouped: true, children: [
        _OrgPanel(children: [
          _OrgDetailIdentity(
              title: '${unit['department_name']}',
              subtitle:
                  'زیرمجموعه: ${units.where((u) => u['name'] == unit['parent_department']).map((u) => u['department_name']).firstOrNull ?? unit['parent_department'] ?? 'ریشه ساختار'}'),
          if (canManage) ...[
            TextButton.icon(
                onPressed: () => _manage(context),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('مدیریت واحد')),
          ],
        ]),
        const SizedBox(height: 12),
        _OrgPanel(children: [
          _OrgDetailSection(
              title: 'زیرواحدها',
              addKey: const ValueKey('organization-subunit-add'),
              onAdd: !canManage || unit['is_group'] != 1
                  ? null
                  : () async {
                      final saved = await _orgSheet<bool>(context,
                          _UnitForm(units: units, parent: '${unit['name']}'));
                      if (saved == true && context.mounted) {
                        Navigator.pop(context);
                      }
                    }),
          if (!units.any((u) => u['parent_department'] == unit['name']))
            const _OrgNotice(
                icon: Icons.account_tree_outlined,
                color: Color(0xff8965af),
                text: 'برای این واحد هنوز زیرواحدی تعریف نشده است.'),
          for (final child
              in units.where((u) => u['parent_department'] == unit['name']))
            _OrgDetailRow(
                title: '${child['department_name']}',
                onTap: () => _orgSheet<void>(
                    context,
                    _UnitDetails(
                        unit: child, units: units, canManage: canManage))),
        ]),
        const SizedBox(height: 12),
        _OrgPanel(children: [_UnitPositions(unit: unit, canManage: canManage)]),
      ]);
  Future<void> _manage(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
        context: context,
        builder: (c) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  title: const Text('جابه‌جایی واحد'),
                  subtitle: const Text('تغییر واحد بالادستی بدون حذف اطلاعات'),
                  onTap: () => Navigator.pop(c, 'move')),
              ListTile(
                  title: const Text('حذف ایمن واحد'),
                  subtitle: const Text('بررسی وابستگی‌ها پیش از حذف'),
                  onTap: () => Navigator.pop(c, 'delete')),
            ])));
    if (!context.mounted || action == null) return;
    if (action == 'move') {
      final saved = await _orgSheet<bool>(
          context, _UnitForm(unit: unit, units: units, moveOnly: true));
      if (saved == true && context.mounted) Navigator.pop(context);
      return;
    }
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('بررسی امکان حذف واحد'),
                content: const Text(
                    'در صورت وجود زیرواحد، جایگاه یا سوابق مرتبط، سرور حذف را رد می‌کند.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('بررسی وابستگی‌ها'))
                ]));
    if (yes != true || !context.mounted || _unitDeleteRunning) return;
    _unitDeleteRunning = true;
    try {
      final c = context.read<OrganizationCubit>();
      final preview = await c.repository.previewDeleteUnit(
          c.company, '${unit['name']}', '${unit['modified']}');
      if (!context.mounted) return;
      if (preview['can_delete'] != true) {
        _orgMessage(context, (preview['blockers'] as List).join('\n'));
        return;
      }
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
                  title: const Text('تأیید حذف واحد'),
                  content: Text(
                      'واحد «${unit['department_name']}» حذف شود؟ وابستگی‌ها هنگام حذف دوباره بررسی می‌شوند.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const Text('انصراف')),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AsoudColors.danger),
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const Text('تأیید حذف واحد')),
                  ]));
      if (confirmed != true || !context.mounted) return;
      await c.repository
          .deleteUnit(c.company, '${unit['name']}', '${unit['modified']}');
      await c.load();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        _orgMessage(context, e is ApiException ? e.message : 'حذف تأیید نشد.');
      }
    } finally {
      _unitDeleteRunning = false;
    }
  }
}
