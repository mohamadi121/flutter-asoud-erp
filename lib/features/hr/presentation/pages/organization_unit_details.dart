part of 'organization_page.dart';

class _UnitDetails extends StatefulWidget {
  const _UnitDetails({required this.unit, required this.units, required this.canManage, this.onDeleted});
  final Map<String, dynamic> unit;
  final List<Map<String, dynamic>> units;
  final bool canManage;
  final ValueChanged<String?>? onDeleted;
  @override
  State<_UnitDetails> createState() => _UnitDetailsState();
}

class _UnitDetailsState extends State<_UnitDetails> {
  late String id = '${widget.unit['name']}';
  List<Map<String, dynamic>> units = [];
  bool loading = true, busy = false, permitted = false;
  String? error, assignment;
  bool assignmentHistory = false;
  _OrgEdit? action;
  OrgPosition? editingPosition;
  final editor = GlobalKey<_OrganizationInlineEditorState>();
  final scroll = ScrollController();
  OrganizationCubit get cubit => context.read<OrganizationCubit>();
  OrganizationUnitNavigation get nav => OrganizationUnitNavigation(units);
  Map<String, dynamic>? get unit => nav.byId(id);
  bool get locked => busy || loading || cubit.state.busy;
  bool get canManage => widget.canManage && permitted;
  @override
  void initState() { super.initState(); refresh().ignore(); }
  @override
  void dispose() { scroll.dispose(); super.dispose(); }

  Future<void> refresh() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await cubit.repository.units(cubit.company);
      if (!mounted) return;
      setState(() {
        units = (result['units'] as List).map((u) => Map<String, dynamic>.from(u as Map)).toList();
        permitted = result['can_manage'] == true; loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { loading = false; error = failureMessage(e); });
    }
  }
  Future<bool> leaveEditor() async {
    if (locked) return false;
    return editor.currentState?.dirty != true || await _confirmOrgDiscard(context);
  }
  Future<void> open(_OrgEdit next, [OrgPosition? row]) async {
    if (!canManage || !await leaveEditor() || !mounted) return;
    setState(() { action = null; assignment = null; });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() { action = next; editingPosition = row; });
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && editor.currentContext != null) {
      await Scrollable.ensureVisible(editor.currentContext!, alignment: .1,
          duration: const Duration(milliseconds: 180));
    }
  }
  Future<void> closeEditor() async {
    if (await leaveEditor() && mounted) setState(() { action = null; assignment = null; editingPosition = null; });
  }
  Future<void> assign(OrgPosition row, {bool history = false}) async {
    if (!await leaveEditor() || !mounted) return;
    setState(() { action = null; editingPosition = null; assignment = row.code; assignmentHistory = history; });
  }
  Future<void> openChild(Map<String, dynamic> child) async {
    if (!await leaveEditor() || !mounted) return;
    setState(() { action = null; assignment = null; });
    await _openOrganizationPage<void>(context, _OrgSheetTheme(child: _UnitDetails(
        unit: child, units: units, canManage: canManage)));
    if (mounted) await refresh();
  }
  Widget operation(_OrgEdit expected) {
    if (action != expected || unit == null) return const SizedBox.shrink();
    final tint = expected == _OrgEdit.addUnit ? 1 :
        (expected == _OrgEdit.addPosition || expected == _OrgEdit.editPosition ? 2 : 0);
    return Padding(padding: const EdgeInsets.only(top: 10), child: _OrganizationInlineEditor(
      key: editor, action: expected, unit: Map.of(unit!), units: units,
      position: editingPosition, detailsMode: true, background: _orgTints[tint].withValues(alpha: .55),
      onBusy: (v) { if (mounted) setState(() => busy = v); }, onCancel: closeEditor,
      onSaved: (_, fallback) async {
        if (mounted) setState(() { action = null; editingPosition = null; });
        await refresh();
        if (!mounted || expected != _OrgEdit.deleteUnit) return;
        widget.onDeleted?.call(fallback);
        if (nav.byId(fallback) != null) {
          setState(() => id = fallback!);
          if (scroll.hasClients) scroll.jumpTo(0);
        } else { Navigator.pop(context); }
      }));
  }
  Widget heading(String text, IconData icon, int tint, {Key? addKey, VoidCallback? add}) =>
      _OrgDetailSection(title: text, icon: icon, color: _orgAccents[tint],
        addKey: addKey, onAdd: locked ? null : add);
  Widget count(String label, int value, int tint) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _orgTints[tint], borderRadius: BorderRadius.circular(12)),
    child: Column(children: [Text(label, style: TextStyle(color: _orgAccents[tint], fontSize: 11)),
      const SizedBox(height: 4), Text(formatCount(value), style: TextStyle(color: _orgAccents[tint], fontWeight: FontWeight.bold))])));
  Widget managementCard(String title, String subtitle, IconData icon, int tint, _OrgEdit kind) =>
    Material(color: _orgTints[tint], borderRadius: BorderRadius.circular(14), child: InkWell(
      key: ValueKey(kind == _OrgEdit.moveUnit ? 'organization-unit-move-action' : 'organization-unit-delete-action'),
      borderRadius: BorderRadius.circular(14), onTap: locked ? null : () => open(kind),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        AsoudIconBox(icon: icon, color: _orgAccents[tint], size: 32), const SizedBox(height: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _orgAccents[tint])),
        const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: AsoudColors.muted, fontSize: 11)),
        Icon(Icons.chevron_left, size: 18, color: _orgAccents[tint]),
      ]))));
  Widget positionCard(OrgPosition row, List<OrgPosition> rows, int index) {
    final parent = rows.where((r) => r.code == row.parent).firstOrNull;
    final tint = index.isEven ? 0 : 2;
    return Padding(padding: const EdgeInsets.only(top: 10), child: Container(
      key: ValueKey('unit-position-${row.code}'), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _orgTints[tint].withValues(alpha: .5), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [AsoudIconBox(icon: Icons.work_outline, color: _orgAccents[tint], size: 32),
          const SizedBox(width: 8), Expanded(child: Text(row.displayTitle, style: const TextStyle(fontWeight: FontWeight.bold)))]),
        const SizedBox(height: 6),
        Text('بالادستی: ${parent?.displayTitle ?? (row.parent.isEmpty ? 'بدون بالادست' : 'جایگاه در دسترس نیست')}',
          style: const TextStyle(fontSize: 11, color: AsoudColors.muted)),
        Text('ظرفیت: ${formatCount(row.capacity)} نفر · منتسب: ${formatCount(row.activeEmployees.length)} نفر', style: const TextStyle(fontSize: 11)),
        Text(row.activeEmployees.length >= row.capacity ? 'ظرفیت تکمیل' : 'دارای ظرفیت خالی', style: TextStyle(fontSize: 11, color: _orgAccents[2])),
        if (row.duties.isNotEmpty) Text(row.duties, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 8), Row(children: [
          if (canManage) Expanded(child: OutlinedButton.icon(key: ValueKey('unit-position-edit-${row.code}'),
            onPressed: locked ? null : () => open(_OrgEdit.editPosition, row),
            icon: const Icon(Icons.edit_outlined, size: 14), label: const Text('ویرایش'))),
          if (canManage) const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(key: ValueKey('unit-position-assign-${row.code}'),
            onPressed: locked ? null : () => assign(row), icon: const Icon(Icons.person_add_alt, size: 14),
            label: Text(canManage ? 'انتساب پرسنل' : 'مشاهده پرسنل'))),
        ]),
        TextButton(key: ValueKey('unit-position-history-${row.code}'),
          onPressed: locked ? null : () => assign(row, history: true), child: const Text('سوابق انتساب')),
        if (action == _OrgEdit.editPosition && editingPosition?.code == row.code) operation(_OrgEdit.editPosition),
        if (assignment == row.code) _OrganizationAssignments(
          key: ValueKey('unit-assignment-${row.code}-$assignmentHistory'), code: row.code,
          canManage: canManage, embedded: true, initialHistory: assignmentHistory,
          onBusy: (v) { if (mounted) setState(() => busy = v); },
          onClose: () => setState(() => assignment = null)),
      ])));
  }
  @override
  Widget build(BuildContext context) => BlocBuilder<OrganizationCubit, OrganizationState>(builder: (context, state) {
    final current = unit;
    final children = nav.children(id);
    final positions = state.snapshot.rows.where((r) => r.departmentId == id).toList();
    final parent = nav.byId(current?['parent_department']?.toString());
    final parentLabel = parent == null ? ((current?['parent_department'] ?? '').toString().isEmpty
        ? 'ریشه ساختار سازمان' : 'نام بالادستی در دسترس نیست') : organizationUnitLabel(parent);
    return PopScope(canPop: !locked && action == null && assignment == null,
      onPopInvokedWithResult: (didPop, result) async { if (!didPop && !locked) await closeEditor(); },
      child: Scaffold(key: ValueKey('unit-details-$id'), backgroundColor: _orgCanvas,
        appBar: const _OrganizationReferenceHeader(title: 'جزئیات واحد سازمانی', form: true, compact: true),
        body: ListView(controller: scroll, key: const PageStorageKey('unit-details-scroll'),
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16), children: [
          Text(cubit.company, style: const TextStyle(fontSize: 11, color: AsoudColors.muted)),
          if (loading) const LinearProgressIndicator(),
          if (error != null) _OrgPanel(children: [Text(error!, style: const TextStyle(color: AsoudColors.danger)),
            TextButton(onPressed: locked ? null : refresh, child: const Text('دریافت دوباره اطلاعات واحد'))]),
          if (!loading && error == null && current == null) const _OrgPanel(children: [Text('این واحد حذف شده یا در دسترس شما نیست.')]),
          if (current != null && error == null) ...[
            _OrgPanel(children: [
              _OrgDetailIdentity(title: organizationUnitLabel(current), subtitle: 'بالادستی: $parentLabel'),
              Text('${current['description'] ?? ''}'.trim().isEmpty ? 'توضیحاتی ثبت نشده است.' : '${current['description']}',
                style: const TextStyle(fontSize: 12, color: AsoudColors.muted)),
              const SizedBox(height: 10), Row(children: [count('زیرواحدها', children.length, 0),
                const SizedBox(width: 8), count('جایگاه‌ها', positions.length, 2)]),
              if (canManage) ...[const SizedBox(height: 10),
                OutlinedButton.icon(key: const ValueKey('organization-unit-edit'),
                  onPressed: locked ? null : () => open(_OrgEdit.editUnit), icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('ویرایش مشخصات واحد')), operation(_OrgEdit.editUnit)],
            ]),
            if (canManage) ...[const SizedBox(height: 10), _OrgPanel(children: [
              heading('مدیریت واحد', Icons.tune, 1), const SizedBox(height: 10),
              managementCard('انتقال واحد', 'انتقال به واحد بالادستی جدید', Icons.swap_horiz, 0, _OrgEdit.moveUnit),
              operation(_OrgEdit.moveUnit), const SizedBox(height: 10),
              managementCard('حذف ایمن واحد', 'با بررسی وابستگی‌ها', Icons.delete_outline, 4, _OrgEdit.deleteUnit),
              operation(_OrgEdit.deleteUnit),
            ])],
            const SizedBox(height: 10), _OrgPanel(children: [
              heading('زیرواحدها', Icons.account_tree_outlined, 1, addKey: const ValueKey('organization-subunit-add'),
                add: canManage && current['is_group'] == 1 ? () => open(_OrgEdit.addUnit) : null),
              if (canManage && current['is_group'] != 1) const Text('این واحد امکان پذیرش زیرواحد ندارد.', style: TextStyle(fontSize: 11)),
              const SizedBox(height: 8),
              if (children.isEmpty) const _OrgNotice(icon: Icons.account_tree_outlined, color: Color(0xff8965af), text: 'هنوز زیرواحدی تعریف نشده است.'),
              for (final (index, child) in children.indexed) Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Material(color: _orgTints[index % 2], borderRadius: BorderRadius.circular(12), child: ListTile(
                  key: ValueKey('unit-child-${child['name']}'), leading: Icon(Icons.business_outlined, color: _orgAccents[index % 2]),
                  title: Text(organizationUnitLabel(child)),
                  subtitle: Text('${formatCount(nav.children('${child['name']}').length)} زیرواحد · ${formatCount(state.snapshot.rows.where((r) => r.departmentId == child['name']).length)} جایگاه', style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_left, size: 18), onTap: locked ? null : () => openChild(child)))),
              operation(_OrgEdit.addUnit),
            ]),
            const SizedBox(height: 10), _OrgPanel(children: [
              heading('جایگاه‌های شغلی', Icons.work_outline, 2, addKey: const ValueKey('organization-inline-position-open'),
                add: canManage ? () => open(_OrgEdit.addPosition) : null), operation(_OrgEdit.addPosition),
              if (positions.isEmpty) const _OrgNotice(icon: Icons.work_outline, color: AsoudColors.success, text: 'جایگاهی ثبت نشده است.'),
              for (final (index, row) in positions.indexed) positionCard(row, state.snapshot.rows, index),
              if (state.snapshot.pending) const Text('تغییرات محلی در انتظار تأیید سرور است.'),
              if (state.error != null) Text(state.error!, style: const TextStyle(color: AsoudColors.danger)),
            ]),
          ],
          const SizedBox(height: 10), OutlinedButton.icon(onPressed: locked ? null : () async {
            if (!await leaveEditor() || !context.mounted) return;
            setState(() { action = null; assignment = null; });
            await WidgetsBinding.instance.endOfFrame;
            if (context.mounted) Navigator.pop(context);
          }, icon: const Icon(Icons.arrow_forward, size: 16), label: const Text('بازگشت به چارت سازمانی')),
        ].map((child) => _UnitDetailsSection(
            active: action != null || assignment != null, child: child)).toList())),
    );
  });
}

// Keep the one operational form mounted when its section scrolls out of view.
// Inactive sections remain eligible for the normal ListView recycling.
class _UnitDetailsSection extends StatefulWidget {
  const _UnitDetailsSection({required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  State<_UnitDetailsSection> createState() => _UnitDetailsSectionState();
}

class _UnitDetailsSectionState extends State<_UnitDetailsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.active;
  @override
  void didUpdateWidget(covariant _UnitDetailsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) updateKeepAlive();
  }
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
