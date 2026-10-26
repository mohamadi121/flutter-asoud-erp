part of 'organization_page.dart';

enum _OrgEdit {
  addUnit,
  editUnit,
  moveUnit,
  deleteUnit,
  addPosition,
  editPosition,
  movePosition,
  deletePosition
}

class _OrganizationFocus extends StatefulWidget {
  const _OrganizationFocus(
      {required this.units,
      required this.canManage,
      this.initialUnit,
      this.initialAction});
  final List<Map<String, dynamic>> units;
  final bool canManage;
  final String? initialUnit;
  final _OrgEdit? initialAction;
  @override
  State<_OrganizationFocus> createState() => _OrganizationFocusState();
}

class _OrganizationFocusState extends State<_OrganizationFocus> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => action != null;
  late List<Map<String, dynamic>> units = widget.units;
  late String? selected = widget.initialUnit ??
      (nav.children(null).length == 1
          ? '${nav.children(null).single['name']}'
          : null);
  String? position;
  int page = 0, positionPage = 0, photoVersion = 0;
  bool busy = false, canPop = false;
  late bool canManage = widget.canManage;
  late _OrgEdit? action = widget.initialAction;
  OrgPosition? editingPosition;
  final editor = GlobalKey<_OrganizationInlineEditorState>();
  final actionAnchor = GlobalKey();
  late Future<List<OrganizationEmployee>> people;
  String? loadError;
  String? highlighted;
  Timer? highlightTimer;
  bool restored = false;
  OrganizationUnitNavigation get nav => OrganizationUnitNavigation(units);
  Map<String, dynamic>? get unit => nav.byId(selected);
  OrganizationCubit get cubit => context.read<OrganizationCubit>();

  Future<List<OrganizationEmployee>> loadPeople() {
    final future = Future<List<OrganizationEmployee>>.sync(() => cubit.repository.employees(cubit.company));
    // The list may be below the lazy viewport when this request finishes.
    // Keep its error for FutureBuilder, but attach a handler immediately.
    future.ignore();
    return future;
  }

  @override
  void initState() {
    super.initState();
    people = loadPeople();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (restored) return;
    restored = true;
    final saved = PageStorage.maybeOf(context)
        ?.readState(context, identifier: 'focus:${cubit.company}');
    if (widget.initialUnit == null &&
        saved is String &&
        nav.byId(saved) != null) {
      selected = saved;
    }
  }

  @override
  void dispose() {
    highlightTimer?.cancel();
    super.dispose();
  }

  void remember() => PageStorage.maybeOf(context)
      ?.writeState(context, selected, identifier: 'focus:${cubit.company}');

  Future<bool> leaveEditor() async {
    if (busy || editor.currentState?.saving == true) return false;
    if (editor.currentState?.dirty != true) return true;
    final answer = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: const Text('تغییرات ذخیره‌نشده'),
              content:
                  const Text('قبل از تغییر انتخاب، با ویرایش فعلی چه کنیم؟'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, 'cancel'),
                    child: const Text('ادامه ویرایش')),
                TextButton(
                    onPressed: () => Navigator.pop(dialog, 'discard'),
                    child: const Text('صرف‌نظر از تغییرات')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialog, 'save'),
                    child: const Text('ذخیره')),
              ],
            ));
    if (!mounted) return false;
    if (answer == 'save') return await editor.currentState?.submit() ?? false;
    return answer == 'discard';
  }

  Future<void> selectUnit(String? id) async {
    if (!await leaveEditor() || !mounted) return;
    setState(() {
      selected = id;
      position = null;
      action = null;
      page = 0;
      positionPage = 0;
      highlighted = null;
    });
    remember();
  }

  Future<void> open(_OrgEdit next, [OrgPosition? row]) async {
    if (!canManage || !await leaveEditor() || !mounted) return;
    setState(() {
      action = null;
    });
    // Replace the form state even when opening the same action for another row.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() {
      editingPosition = row;
      action = next;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && actionAnchor.currentContext != null) {
      await Scrollable.ensureVisible(actionAnchor.currentContext!,
          duration: const Duration(milliseconds: 200), alignment: .1);
    }
  }

  Future<void> refresh({String? newUnit, String? fallback}) async {
    try {
      final data = await cubit.repository.units(cubit.company);
      if (!mounted) return;
      setState(() {
        units = (data['units'] as List)
            .map((u) => Map<String, dynamic>.from(u as Map))
            .toList();
        canManage = widget.canManage && data['can_manage'] == true;
        loadError = null;
        if (selected != null && nav.byId(selected) == null) {
          selected = nav.byId(fallback) == null ? null : fallback;
        }
        if (newUnit != null) {
          final index =
              nav.children(selected).indexWhere((u) => u['name'] == newUnit);
          if (index >= 0) page = index ~/ 4;
          highlighted = newUnit;
        }
        final total = nav.children(selected).length;
        if (page * 4 >= total) page = 0;
      });
      remember();
      highlightTimer?.cancel();
      if (newUnit != null) {
        highlightTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => highlighted = null);
        });
      }
    } catch (e) {
      if (mounted) setState(() => loadError = failureMessage(e));
    }
  }

  Future<void> assign(OrgPosition row) async {
    if (!await leaveEditor() || !mounted) return;
    setState(() => action = null);
    await _openOrganizationPage<void>(context,
        _OrganizationAssignments(code: row.code, canManage: canManage));
    if (!mounted) return;
    cubit.repository.invalidateEmployeePhotos();
    setState(() {
      photoVersion++;
      people = loadPeople();
    });
  }

  Future<void> reload() async {
    if (!await leaveEditor() || !mounted) return;
    setState(() => action = null);
    await cubit.load();
    await refresh();
    if (!mounted) return;
    cubit.repository.invalidateEmployeePhotos();
    setState(() { photoVersion++; people = loadPeople(); });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _build(context);
  }

  Widget _build(BuildContext context) =>
      BlocBuilder<OrganizationCubit, OrganizationState>(
          builder: (context, state) {
        final children = nav.children(selected);
        final path = nav.path(selected);
        final positions = state.snapshot.rows
            .where((r) => selected != null && r.departmentId == selected)
            .toList();
        final selectedPosition =
            positions.where((p) => p.code == position).firstOrNull;
        final roots = state.snapshot.rows.where((p) => p.parent.isEmpty).toList();
        final visiblePositionPage = math.min(positionPage, math.max(0, (positions.length - 1) ~/ 10));
        final locked = busy || state.busy;
        return PopScope(
          canPop: canPop || (!busy && action == null),
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop || !await leaveEditor() || !mounted) return;
            setState(() {
              canPop = true;
              action = null;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pop(context);
            });
          },
          child: ListView(
              key: const PageStorageKey('organization-focused-scroll'),
              padding: const EdgeInsets.all(14),
              children: [
                _OrgPanel(children: [
                  Row(children: [
                    const Expanded(
                        child: Text('ساختار فعلی سازمان',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(tooltip: 'بازخوانی ساختار و تصاویر', onPressed: locked ? null : reload, icon: const Icon(Icons.refresh, size: 20)),
                    TextButton(
                        onPressed: locked ? null : () => selectUnit(null),
                        child: const Text('انتخاب ریشه'))
                  ]),
                  // Roots of the position graph are explicitly separate, not fake units.
                  for (final root in roots.take(4))
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: const Color(0xff283f70),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                              onTap: locked
                                  ? null
                                  : () async {
                                      if (!await leaveEditor() ||
                                          !context.mounted) {
                                        return;
                                      }
                                      await _openOrganizationPage<void>(
                                          context,
                                          _PositionDetails(
                                              code: root.code,
                                              canManage: canManage));
                                    },
                              child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      if (root.activeEmployees.isEmpty) const _OrganizationAvatar(),
                                      for (final employee in root.activeEmployees.take(2))
                                        _OrganizationAvatar(key: ValueKey('root:$employee:$photoVersion'), employee: employee),
                                    ]),
                                    Text(root.title,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    FutureBuilder<List<OrganizationEmployee>>(future: people,
                                      builder: (_, snapshot) => Text(_occupantLabel(root, snapshot.data ?? []),
                                        style: const TextStyle(color: Colors.white70, fontSize: 10))),
                                    const Text(
                                        'جایگاه ریشه · مستقل از سلسله‌مراتب واحدها',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10)),
                                  ]))),
                        )),
                  if (roots.length > 4) TextButton(onPressed: locked ? null : () async {
                    if (!await leaveEditor() || !context.mounted) return;
                    await _openOrganizationPage<void>(context, _OrganizationChart(canManage: canManage));
                  }, child: Text('مشاهده همه جایگاه‌های ریشه (${formatCount(roots.length)})')),
                  for (final ancestor in path) ...[
                    _unitCard(ancestor,
                        active: true,
                        current: ancestor['name'] == selected,
                        onTap: locked
                            ? null
                            : () => selectUnit('${ancestor['name']}')),
                    Center(
                        child: Container(
                            width: 2,
                            height: 18,
                            color: const Color(0xffbdcde5))),
                  ],
                  Text(
                      unit == null
                          ? 'واحدهای ریشه'
                          : 'زیرواحدهای مستقیم ${unit!['department_name']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xff6781a8))),
                  const SizedBox(height: 12),
                  if (children.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('زیرواحدی تعریف نشده است.',
                            textAlign: TextAlign.center)),
                  if (units.isEmpty) const Text('هنوز واحدی تعریف نشده است.'),
                  if (unit == null && canManage) Wrap(spacing: 8, children: [
                    FilledButton(onPressed: locked ? null : () async {
                      await _openOrganizationPage<bool>(context, const _OrganizationCreateForm(position: false));
                      if (mounted) await refresh();
                    }, child: const Text('افزودن واحد')),
                    OutlinedButton(onPressed: locked ? null : () async {
                      await _openOrganizationPage<bool>(context, const _OrganizationCreateForm(position: true));
                      if (mounted) await refresh();
                    }, child: const Text('افزودن جایگاه')),
                  ]),
                  LayoutBuilder(
                      builder: (context, bounds) =>
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final child in nav.page(selected, page))
                              SizedBox(
                                  width: (bounds.maxWidth - 8) / 2,
                                  child: _unitCard(child,
                                      index: children.indexOf(child),
                                      onTap: locked
                                          ? null
                                          : () =>
                                              selectUnit('${child['name']}'))),
                          ])),
                  if (children.length > 4)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(
                          tooltip: 'صفحه قبل',
                          onPressed: locked || page == 0
                              ? null
                              : () => setState(() => page--),
                          icon: const Icon(Icons.chevron_right)),
                      Text(
                          '${formatCount(page + 1)} از ${formatCount((children.length / 4).ceil())}'),
                      IconButton(
                          tooltip: 'صفحه بعد',
                          onPressed: locked || (page + 1) * 4 >= children.length
                              ? null
                              : () => setState(() => page++),
                          icon: const Icon(Icons.chevron_left)),
                    ]),
                  if (canManage && unit != null) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: FilledButton.icon(
                              onPressed:
                                  locked ? null : () => open(_OrgEdit.addUnit),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('زیرواحد جدید'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: OutlinedButton.icon(
                              onPressed: locked
                                  ? null
                                  : () => open(_OrgEdit.addPosition),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('جایگاه جدید'))),
                    ]),
                  ],
                ]),
                if (loadError != null)
                  _OrgPanel(children: [
                    Text(loadError!),
                    TextButton(
                        onPressed: () => refresh(),
                        child: const Text('تلاش دوباره'))
                  ]),
                if (action != null && unit != null)
                  Padding(
                      key: actionAnchor,
                      padding: const EdgeInsets.only(top: 12),
                      child: _OrganizationInlineEditor(
                        key: editor,
                        action: action!,
                        unit: Map.of(unit!),
                        units: units,
                        position: editingPosition,
                        onBusy: (v) {
                          if (mounted) setState(() => busy = v);
                        },
                        onCancel: () async {
                          if (await leaveEditor() && mounted) {
                            setState(() => action = null);
                          }
                        },
                        onSaved: (newId, fallback) async {
                          await refresh(newUnit: newId, fallback: fallback);
                          if (!mounted) return;
                          setState(() {
                            action = null;
                            editingPosition = null;
                          });
                        },
                      )),
                if (unit != null) ...[
                  const SizedBox(height: 12),
                  _OrgPanel(children: [
                    Row(children: [
                      const Expanded(
                          child: Text('جزئیات واحد انتخاب‌شده',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      if (canManage)
                        PopupMenuButton<_OrgEdit>(
                            tooltip: 'عملیات واحد',
                            enabled: !locked,
                            onSelected: (v) => open(v),
                            itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: _OrgEdit.editUnit,
                                      child: Text('ویرایش مشخصات')),
                                  PopupMenuItem(
                                      value: _OrgEdit.moveUnit,
                                      child: Text('جابه‌جایی واحد')),
                                  PopupMenuItem(
                                      value: _OrgEdit.deleteUnit,
                                      child: Text('حذف ایمن واحد')),
                                ]),
                    ]),
                    _detail('عنوان واحد', '${unit!['department_name']}'),
                    _detail('واحد بالادستی', _parentLabel(unit!)),
                    _detail('زیرواحدهای مستقیم', formatCount(children.length)),
                    _detail('جایگاه‌های مستقیم', formatCount(positions.length)),
                  ]),
                  const SizedBox(height: 12),
                  _OrgPanel(children: [
                    const Text('جایگاه‌های شغلی این واحد',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    if (positions.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('این واحد جایگاه ثبت‌شده ندارد.')),
                    FutureBuilder<List<OrganizationEmployee>>(
                        future: people,
                        builder: (context, snapshot) => Column(children: [
                              if (snapshot.hasError) ...[
                                const Text(
                                    'نام پرسنل دریافت نشد؛ اطلاعات جایگاه‌ها قابل مشاهده است.',
                                    style: TextStyle(fontSize: 11)),
                                TextButton(
                                    onPressed: () => setState(() => people =
                                        cubit.repository
                                            .employees(cubit.company)),
                                    child: const Text('بازخوانی پرسنل')),
                              ],
                              for (final row in positions.skip(visiblePositionPage * 10).take(10))
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Material(
                                      color: row.code == position
                                          ? const Color(0xff283f70)
                                          : const Color(0xfff4f6fb),
                                      borderRadius: BorderRadius.circular(14),
                                      child: ListTile(
                                        key: ValueKey(
                                            'focus-position-${row.code}'),
                                        leading: SizedBox(
                                            width:
                                                row.activeEmployees.length > 1
                                                    ? 56
                                                    : 36,
                                            height: 36,
                                            child: Stack(children: [
                                              if (row.activeEmployees.isEmpty)
                                                const _OrganizationAvatar(),
                                              for (var i = 0;
                                                  i <
                                                      math.min(
                                                          2,
                                                          row.activeEmployees
                                                              .length);
                                                  i++)
                                                PositionedDirectional(
                                                    start: i * 20.0,
                                                    child: _OrganizationAvatar(
                                                        key: ValueKey(
                                                            '${row.code}:${row.activeEmployees[i]}:$photoVersion'),
                                                        employee:
                                                            row.activeEmployees[
                                                                i])),
                                            ])),
                                        title: Text(row.title,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: row.code == position
                                                    ? Colors.white
                                                    : _orgInk)),
                                        subtitle: Text(
                                            '${_occupantLabel(row, snapshot.data ?? [])}\nظرفیت ${formatCount(row.capacity)} · خالی ${formatCount(row.capacity - row.activeEmployees.length)}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: row.code == position
                                                    ? Colors.white70
                                                    : const Color(0xff737e90))),
                                        trailing: canManage
                                            ? PopupMenuButton<String>(
                                                tooltip: 'عملیات ${row.title}',
                                                enabled: !locked,
                                                iconColor: row.code == position
                                                    ? Colors.white
                                                    : _orgInk,
                                                onSelected: (v) => v == 'assign'
                                                    ? assign(row)
                                                    : open(
                                                        _OrgEdit.values
                                                            .byName(v),
                                                        row),
                                                itemBuilder: (_) => const [
                                                      PopupMenuItem(
                                                          value: 'editPosition',
                                                          child: Text(
                                                              'ویرایش جایگاه')),
                                                      PopupMenuItem(
                                                          value: 'movePosition',
                                                          child: Text(
                                                              'جابه‌جایی جایگاه')),
                                                      PopupMenuItem(
                                                          value: 'assign',
                                                          child: Text(
                                                              'مدیریت انتصاب پرسنل')),
                                                      PopupMenuItem(
                                                          value:
                                                              'deletePosition',
                                                          child: Text(
                                                              'حذف ایمن جایگاه')),
                                                    ])
                                            : null,
                                        onTap: locked
                                            ? null
                                            : () => setState(
                                                () => position = row.code),
                                      ),
                                    )),
                              if (positions.length > 10) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                IconButton(tooltip: 'جایگاه‌های قبلی', onPressed: locked || visiblePositionPage == 0 ? null : () => setState(() => positionPage = visiblePositionPage - 1), icon: const Icon(Icons.chevron_right)),
                                Text('${formatCount(visiblePositionPage + 1)} از ${formatCount((positions.length / 10).ceil())}'),
                                IconButton(tooltip: 'جایگاه‌های بعدی', onPressed: locked || (visiblePositionPage + 1) * 10 >= positions.length ? null : () => setState(() => positionPage = visiblePositionPage + 1), icon: const Icon(Icons.chevron_left)),
                              ]),
                            ])),
                  ]),
                  if (selectedPosition != null) ...[
                    const SizedBox(height: 12),
                    _OrgPanel(children: [
                      Text('جزئیات جایگاه: ${selectedPosition.title}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      _detail('واحد سازمانی', '${unit!['department_name']}'),
                      _detail(
                          'جایگاه بالادستی',
                          state.snapshot.rows
                                  .where(
                                      (r) => r.code == selectedPosition.parent)
                                  .firstOrNull
                                  ?.title ??
                              (selectedPosition.parent.isEmpty
                                  ? 'بدون بالادست'
                                  : 'جایگاه در دسترس نیست')),
                      _detail('ظرفیت', formatCount(selectedPosition.capacity)),
                      _detail('متصدیان فعال',
                          formatCount(selectedPosition.activeEmployees.length)),
                      _detail(
                          'شرح وظایف',
                          selectedPosition.duties.isEmpty
                              ? 'ثبت نشده'
                              : selectedPosition.duties),
                      TextButton(
                          onPressed:
                              locked ? null : () => assign(selectedPosition),
                          child: const Text('مشاهده پرسنل و سوابق انتصاب')),
                    ]),
                  ],
                ],
                if (state.snapshot.pending)
                  const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                          'تغییرات محلی است؛ هنوز ثبت سرور تأیید نشده است.')),
                TextButton(
                    onPressed: locked
                        ? null
                        : () async {
                            if (!await leaveEditor() || !context.mounted) {
                              return;
                            }
                            await _openOrganizationPage<void>(context,
                                _OrganizationChart(canManage: canManage));
                          },
                    child: const Text('نمای روابط جایگاه‌ها')),
                TextButton(
                    onPressed: locked
                        ? null
                        : () async {
                            if (!await leaveEditor() || !context.mounted) {
                              return;
                            }
                            await _openOrganizationPage<void>(
                                context,
                                _OrganizationVisualReport(
                                    canManage: canManage));
                          },
                    child: const Text('گزارش تصویری چارت')),
                const _OrgTabFooter(),
              ]),
        );
      });

  String _occupantLabel(OrgPosition row, List<OrganizationEmployee> employees) {
    if (row.activeEmployees.isEmpty) return 'بدون متصدی';
    if (row.activeEmployees.length > 1) {
      return '${formatCount(row.activeEmployees.length)} متصدی · مشاهده در جزئیات';
    }
    return employees
            .where((p) => p.id == row.activeEmployees.single)
            .firstOrNull
            ?.displayName ??
        'پرسنل منتسب';
  }

  String _parentLabel(Map<String, dynamic> row) =>
      nav
          .byId(row['parent_department'] as String?)?['department_name']
          ?.toString() ??
      ((row['parent_department'] ?? '').toString().isEmpty
          ? 'ریشه سازمان'
          : 'ریشه بالادستی خارج از فهرست');
  Widget _detail(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xff7d8798)))),
        const SizedBox(width: 10),
        Flexible(
            child: Text(value,
                style: const TextStyle(fontSize: 13, color: _orgInk)))
      ]));
  Widget _unitCard(Map<String, dynamic> row,
          {bool active = false,
          bool current = false,
          int index = 0,
          VoidCallback? onTap}) =>
      Material(
        color: active
            ? const Color(0xff283f70)
            : _orgTints[index % _orgTints.length],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: current || highlighted == row['name']
                    ? const Color(0xff448fff)
                    : const Color(0xffe2e8f2))),
        child: InkWell(
            key: ValueKey('focus-unit-${row['name']}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 90),
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.transparent,
                      child: Icon(Icons.business_outlined,
                          size: 22,
                          color: active
                              ? Colors.white
                              : _orgAccents[index % _orgAccents.length])),
                  const SizedBox(height: 6),
                  Text('${row['department_name']}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: active ? Colors.white : _orgInk)),
                  const SizedBox(height: 4),
                  Text(
                      current
                          ? 'واحد انتخاب‌شده'
                          : formatCount(
                              nav.children('${row['name']}').length, 'زیرواحد'),
                      style: TextStyle(
                          fontSize: 10,
                          color: active
                              ? Colors.white70
                              : _orgAccents[index % _orgAccents.length])),
                ]))),
      );
}
