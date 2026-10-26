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
      this.initialError,
      this.initialAction});
  final List<Map<String, dynamic>> units;
  final bool canManage;
  final String? initialUnit;
  final String? initialError;
  final _OrgEdit? initialAction;
  @override
  State<_OrganizationFocus> createState() => _OrganizationFocusState();
}

class _OrganizationFocusState extends State<_OrganizationFocus> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => action != null || assigningPosition != null;
  late List<Map<String, dynamic>> units = widget.units;
  late String? selected = widget.initialUnit;
  bool branchOpen = true;
  OrgPosition? assigningPosition;
  String? position;
  int page = 0, positionPage = 0, photoVersion = 0;
  bool busy = false, canPop = false;
  late bool canManage = widget.canManage;
  late _OrgEdit? action = widget.initialAction;
  OrgPosition? editingPosition;
  final editor = GlobalKey<_OrganizationInlineEditorState>();
  final rootEditor = GlobalKey<_OrganizationCreateFormState>();
  final actionAnchor = GlobalKey();
  late Future<List<OrganizationEmployee>> people;
  late String? loadError = widget.initialError;
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
    // Entry always starts at the real root. Selection survives refresh within
    // this mounted page by native ID, not by restoring another visit's branch.
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
    if (editor.currentState?.dirty != true && rootEditor.currentState?.dirty != true) return true;
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
    if (answer == 'save') {
      if (rootEditor.currentState != null) {
        await rootEditor.currentState!.save();
        return action == null;
      }
      return await editor.currentState?.submit() ?? false;
    }
    return answer == 'discard';
  }

  Future<void> selectUnit(String? id) async {
    if (!await leaveEditor() || !mounted) return;
    final same = selected == id;
    setState(() {
      selected = id;
      branchOpen = id != null && same ? !branchOpen : true;
      position = null;
      action = null;
      assigningPosition = null;
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
      assigningPosition = null;
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
          branchOpen = true;
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
    setState(() {
      action = null;
      assigningPosition = row;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && actionAnchor.currentContext != null) {
      await Scrollable.ensureVisible(actionAnchor.currentContext!,
          duration: const Duration(milliseconds: 180), alignment: .1);
    }
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
        final operations = <Widget>[
                if (assigningPosition != null)
                  Padding(key: actionAnchor, padding: const EdgeInsets.only(top: 12),
                    child: _OrgPanel(children: [_OrganizationAssignments(
                      key: ValueKey('inline-assignment-${assigningPosition!.code}'),
                      code: assigningPosition!.code, canManage: canManage, embedded: true,
                      onBusy: (value) { if (mounted) setState(() => busy = value); },
                      onClose: () => setState(() => assigningPosition = null))])),
                if (action != null && unit == null)
                  Padding(key: actionAnchor, padding: const EdgeInsets.only(top: 12),
                    child: _OrgPanel(children: [_OrganizationCreateForm(
                      key: rootEditor, embedded: true, position: action == _OrgEdit.addPosition,
                      onBusy: (value) { if (mounted) setState(() => busy = value); },
                      onCancel: () => setState(() => action = null),
                      onSaved: (id) async {
                        await refresh(newUnit: id);
                        if (mounted) setState(() => action = null);
                      })])),
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
        ];
        return PopScope(
          canPop: canPop || (!busy && action == null && assigningPosition == null),
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop || !await leaveEditor() || !mounted) return;
            setState(() {
              canPop = true;
              action = null;
              assigningPosition = null;
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
                    const Expanded(child: Text('ساختار فعلی سازمان',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                    Text(formatCount(units.length, 'واحد'),
                        style: const TextStyle(fontSize: 10, color: AsoudColors.muted)),
                    PopupMenuButton<String>(
                      tooltip: 'ابزارهای ساختار',
                      enabled: !locked,
                      icon: const Icon(Icons.more_horiz, size: 20),
                      onSelected: (value) async {
                        if (!await leaveEditor() || !context.mounted) return;
                        if (value == 'reload') { await reload(); return; }
                        await _openOrganizationPage<void>(context,
                          value == 'units'
                            ? _OrgDetailPage(title: 'واحدهای سازمانی', children: [
                                SizedBox(height: MediaQuery.sizeOf(context).height * .7,
                                  child: _OrganizationUnits(canManage: canManage))])
                            : value == 'positions'
                              ? _OrgDetailPage(title: 'جایگاه‌های سازمانی', children: [
                                  SizedBox(height: MediaQuery.sizeOf(context).height * .7,
                                    child: _PositionList(canManage: canManage))])
                              : value == 'summary'
                                ? const _OrgDetailPage(title: 'خلاصه ساختار', children: [_OrganizationSummary()])
                                : const _OrganizationSetup(returnToWorkspace: true));
                        if (mounted) await reload();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'reload', child: Text('بازخوانی ساختار')),
                        const PopupMenuItem(value: 'units', child: Text('واحدها')),
                        const PopupMenuItem(value: 'positions', child: Text('جایگاه‌ها')),
                        const PopupMenuItem(value: 'summary', child: Text('خلاصه ساختار')),
                        if (canManage) const PopupMenuItem(value: 'setup',
                          child: Text('انتخاب روش ایجاد: قالب، اکسل یا دستی')),
                      ]),
                  ]),
                  // Actual root positions only: never synthesize a Department.
                  for (final root in roots) ...[
                    Material(
                      color: const Color(0xff283f70),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        key: ValueKey('focus-root-${root.code}'),
                        onTap: locked ? null : () => selectUnit(null),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          child: Column(children: [
                            const Icon(Icons.person_outline, size: 19, color: Colors.white),
                            const SizedBox(height: 4),
                            Text(root.displayTitle, textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ])))),
                    _connector(),
                  ],
                  if (roots.isEmpty) const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('جایگاه ریشه در چارت ثبت نشده است؛ واحدها از ساختار واقعی نمایش داده می‌شوند.',
                      style: TextStyle(fontSize: 11, color: AsoudColors.muted))),
                  for (final ancestor in path) ...[
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _unitCard(ancestor, active: true,
                        current: ancestor['name'] == selected,
                        onTap: locked ? null : () => selectUnit('${ancestor['name']}'))),
                    _connector(),
                  ],
                  Center(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: _orgTints[0],
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(unit == null
                        ? 'زیرواحدهای مستقیم ${roots.length == 1 ? roots.single.displayTitle : 'ریشه سازمان'}'
                        : 'زیرواحدهای مستقیم ${organizationUnitLabel(unit!)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: _orgAccents[0])))),
                  _connector(height: 12),
                  if (branchOpen && children.isEmpty)
                    Container(width: double.infinity, padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _orgTints[0], borderRadius: BorderRadius.circular(12)),
                      child: const Text('هنوز زیرواحدی تعریف نشده است.', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12))),
                  if (branchOpen && children.isNotEmpty)
                    LayoutBuilder(builder: (context, bounds) {
                      final shown = nav.page(selected, page);
                      return Column(children: [
                        for (var offset = 0; offset < shown.length; offset += 2) ...[
                          CustomPaint(painter: _OrganizationChildConnector(
                              paired: offset + 1 < shown.length),
                            child: const SizedBox(width: double.infinity, height: 12)),
                          IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            for (var i = offset; i < math.min(offset + 2, shown.length); i++) ...[
                              if (i > offset) const SizedBox(width: 8),
                              Expanded(child: _unitCard(shown[i],
                                index: children.indexOf(shown[i]) + (selected == null ? 0 : 2),
                                onTap: locked ? null : () => selectUnit('${shown[i]['name']}'))),
                            ],
                            if (offset + 1 >= shown.length) ...[
                              const SizedBox(width: 8), const Expanded(child: SizedBox())],
                          ])),
                          if (offset + 2 < shown.length) _connector(height: 8),
                        ],
                      ]);
                    }),
                  if (branchOpen && children.length > 4)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(tooltip: 'صفحه قبل',
                        onPressed: locked || page == 0 ? null : () => setState(() => page--),
                        icon: const Icon(Icons.chevron_right)),
                      Text('${formatCount(page + 1)} از ${formatCount((children.length / 4).ceil())}'),
                      IconButton(tooltip: 'صفحه بعد',
                        onPressed: locked || (page + 1) * 4 >= children.length ? null : () => setState(() => page++),
                        icon: const Icon(Icons.chevron_left)),
                    ]),
                  if (!branchOpen) const Padding(padding: EdgeInsets.all(12),
                    child: Text('شاخه بسته است؛ برای بازکردن، کارت انتخاب‌شده را لمس کنید.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 11))),
                  if (canManage) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        key: const ValueKey('focus-add-unit'),
                        onPressed: locked ? null : () async {
                          if (unit != null) { await open(_OrgEdit.addUnit); return; }
                          await open(_OrgEdit.addUnit);
                        },
                        style: _slimButton().copyWith(backgroundColor: const WidgetStatePropertyAll(Color(0xff111111)), foregroundColor: const WidgetStatePropertyAll(Colors.white)),
                        icon: const Icon(Icons.add, size: 15), label: const Text('زیرواحد جدید'))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(
                        key: const ValueKey('focus-add-position'),
                        onPressed: locked ? null : () async {
                          if (unit != null) { await open(_OrgEdit.addPosition); return; }
                          await open(_OrgEdit.addPosition);
                        },
                        style: _slimButton(),
                        icon: const Icon(Icons.add, size: 15), label: const Text('جایگاه جدید'))),
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
                if (unit == null) ...operations,
                if (unit != null) ...[
                  const SizedBox(height: 12),
                  if (action == _OrgEdit.addPosition) ...operations,
                  if (action != _OrgEdit.addPosition) _OrgPanel(children: [
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
                                      color: const Color(0xfff4f6fb),
                                      borderRadius: BorderRadius.circular(14),
                                      child: ListTile(
                                        key: ValueKey(
                                            'focus-position-${row.code}'),
                                        leading: PopupMenuButton<String>(
                                          tooltip: 'عملیات ${row.displayTitle}', enabled: !locked && canManage,
                                          icon: const AsoudIconBox(icon: Icons.work_outline, color: AsoudColors.primary, size: 36),
                                          onSelected: (v) => v == 'assign' ? assign(row) : open(_OrgEdit.values.byName(v), row),
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(value: 'editPosition', child: Text('ویرایش جایگاه')),
                                            PopupMenuItem(value: 'movePosition', child: Text('جابه‌جایی جایگاه')),
                                            PopupMenuItem(value: 'assign', child: Text('مدیریت انتصاب پرسنل')),
                                            PopupMenuItem(value: 'deletePosition', child: Text('حذف ایمن جایگاه')),
                                          ]),
                                        title: Text(row.displayTitle,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: _orgInk)),
                                        subtitle: Text(
                                            'ظرفیت: ${formatCount(row.capacity)} نفر${row.activeEmployees.isEmpty ? '' : ' · ${_occupantLabel(row, snapshot.data ?? [])}'}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: const Color(0xff737e90))),
                                        trailing: canManage ? IconButton(
                                          tooltip: 'ویرایش ${row.displayTitle}',
                                          onPressed: locked ? null : () => open(_OrgEdit.editPosition, row),
                                          icon: const Icon(Icons.edit_outlined, size: 18)) : null,
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
                  if (action != _OrgEdit.addPosition) ...operations,
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
                    Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xfff4f6fb), borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        _detail('عنوان واحد', organizationUnitLabel(unit!)),
                        _detail('واحد بالادستی', _parentLabel(unit!)),
                        _detail('زیرواحدهای مستقیم', formatCount(children.length)),
                        _detail('جایگاه‌های مستقیم', formatCount(positions.length)),
                        if ('${unit!['description'] ?? ''}'.trim().isNotEmpty)
                          _detail('توضیحات', '${unit!['description']}'),
                      ])),
                  ]),
                  const SizedBox(height: 12),
                  if (selectedPosition != null) ...[
                    const SizedBox(height: 12),
                    _OrgPanel(children: [
                      Text('جزئیات جایگاه: ${selectedPosition.displayTitle}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      _detail('واحد سازمانی', organizationUnitLabel(unit!)),
                      _detail(
                          'جایگاه بالادستی',
                          state.snapshot.rows
                                  .where(
                                      (r) => r.code == selectedPosition.parent)
                                  .firstOrNull
                                  ?.displayTitle ??
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

  ButtonStyle _slimButton() => OutlinedButton.styleFrom(
      minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 6),
      foregroundColor: _orgInk, backgroundColor: Colors.white,
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12), shape: const StadiumBorder(),
      side: const BorderSide(color: Color(0xffe2e8f2)));

  Widget _connector({double height = 16}) => Center(child: Container(
      width: 1, height: height, color: const Color(0xffbdcde5)));

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

  String _parentLabel(Map<String, dynamic> row) {
    final parent = nav.byId(row['parent_department'] as String?);
    if (parent != null) return organizationUnitLabel(parent);
    // The same presentation root used above the top-level Department cards;
    // it is a real position, not a new/renamed native Department relationship.
    final roots = cubit.state.snapshot.rows.where((r) => r.parent.isEmpty).toList();
    if (roots.length == 1 && nav.children(null).any((u) => u['name'] == row['name'])) {
      return roots.single.displayTitle;
    }
    return (row['parent_department'] ?? '').toString().isEmpty ? 'ریشه سازمان' : 'واحد بالادستی خارج از فهرست';
  }
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
                constraints: BoxConstraints(minHeight: active ? 76 : 100),
                padding: const EdgeInsets.all(10),
                child: Column(children: [
                  CircleAvatar(
                      radius: active ? 10 : 14,
                      backgroundColor: Colors.transparent,
                      child: Icon(Icons.business_outlined,
                          size: active ? 18 : 22,
                          color: active
                              ? Colors.white
                              : _orgAccents[index % _orgAccents.length])),
                  const SizedBox(height: 6),
                  Text(organizationUnitLabel(row),
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
                  if (!active || current) Icon(
                    active && branchOpen ? Icons.expand_less : Icons.expand_more,
                    size: 16, color: active ? Colors.white70 : _orgAccents[index % _orgAccents.length]),
                ]))),
      );
}

class _OrganizationChildConnector extends CustomPainter {
  const _OrganizationChildConnector({required this.paired});
  final bool paired;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xffbdcde5)..strokeWidth = 1;
    final center = size.width / 2;
    final right = size.width * .75 + 2;
    canvas.drawLine(Offset(center, 0), Offset(center, 5), paint);
    canvas.drawLine(Offset(paired ? size.width * .25 - 2 : right, 5), Offset(right, 5), paint);
    canvas.drawLine(Offset(right, 5), Offset(right, size.height), paint);
    if (paired) canvas.drawLine(Offset(size.width * .25 - 2, 5), Offset(size.width * .25 - 2, size.height), paint);
  }
  @override
  bool shouldRepaint(covariant _OrganizationChildConnector oldDelegate) => oldDelegate.paired != paired;
}
