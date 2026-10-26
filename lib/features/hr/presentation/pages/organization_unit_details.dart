part of 'organization_page.dart';

class _UnitDetails extends StatefulWidget {
  const _UnitDetails(
      {required this.unit, required this.units, required this.canManage});
  final Map<String, dynamic> unit;
  final List<Map<String, dynamic>> units;
  final bool canManage;
  @override
  State<_UnitDetails> createState() => _UnitDetailsState();
}

class _UnitDetailsState extends State<_UnitDetails> {
  late Map<String, dynamic> unit = Map.of(widget.unit);
  late final title = TextEditingController(text: organizationUnitLabel(unit));
  bool management = true, editing = false, busy = false;
  String? error;
  bool get dirty => editing && title.text.trim() != organizationUnitLabel(unit);

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> rename() async {
    if (busy || !widget.canManage || title.text.trim().isEmpty) return;
    final c = context.read<OrganizationCubit>();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await c.repository.saveUnit(c.company, {
        'name': unit['name'],
        'modified': unit['modified'],
        'title': organizationEditedTitle(title.text, '${unit['department_name']}'),
        'parent': unit['parent_department'] ?? '',
        'is_group': unit['is_group'] == 1,
      });
      final result = await c.repository.units(c.company);
      final updated = (result['units'] as List)
          .cast<Map>()
          .firstWhere((u) => u['name'] == unit['name']);
      await c.load();
      if (mounted) {
        setState(() {
          unit = Map<String, dynamic>.from(updated);
          editing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> manage({bool delete = false}) async {
    if (busy || !widget.canManage) return;
    if (dirty && !await _confirmOrgDiscard(context)) return;
    if (!mounted) return;
    await _openOrganizationPage<void>(
        context,
        _OrganizationUnitManagement(
            unit: unit,
            units: widget.units,
            canManage: widget.canManage,
            initialDelete: delete));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final parent = widget.units
        .where((u) => u['name'] == unit['parent_department'])
        .firstOrNull;
    final parentLabel = parent != null ? organizationUnitLabel(parent) :
        ((unit['parent_department'] ?? '').toString().isEmpty
            ? 'مدیرعامل'
            : 'واحد بالادستی خارج از فهرست');
    return PopScope(
      canPop: !busy && !dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || busy) return;
        if (await _confirmOrgDiscard(context) && mounted) {
          setState(() => editing = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        backgroundColor: _orgCanvas,
        appBar: const _OrganizationReferenceHeader(
          title: 'جزئیات واحد سازمانی', form: true, compact: true),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            children: [
              Row(children: [
                TextButton(
                    onPressed: busy ? null : () => Navigator.maybePop(context),
                    child: const Text('چارت سازمانی',
                        style: TextStyle(fontSize: 11))),
                const Icon(Icons.chevron_left, size: 14),
                const Text('جزئیات واحد',
                    style: TextStyle(fontSize: 11, color: Color(0xff7d8089))),
              ]),
              _OrgPanel(children: [
                Row(children: [
                  AsoudIconBox(
                      icon: Icons.business_outlined,
                      color: _orgAccents[0],
                      size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(organizationUnitLabel(unit),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _orgInk)),
                        const SizedBox(height: 6),
                        Text('زیرمجموعه: $parentLabel',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xff7d8089))),
                      ])),
                ]),
                if (widget.canManage) ...[
                  const Divider(height: 30),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            key: const ValueKey('organization-unit-edit'),
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                      editing = !editing;
                                      title.text = organizationUnitLabel(unit);
                                    }),
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const Text('ویرایش مشخصات',
                                style: TextStyle(fontSize: 12)))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () =>
                                    setState(() => management = !management),
                            icon: const Icon(Icons.tune, size: 15),
                            label: const Text('مدیریت واحد',
                                style: TextStyle(fontSize: 12)))),
                  ]),
                  if (editing)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(children: [
                          AppTextField(
                              controller: title,
                              label: 'عنوان واحد',
                              enabled: !busy,
                              onChanged: (_) => setState(() {})),
                          if (error != null)
                            Text(error!,
                                style:
                                    const TextStyle(color: AsoudColors.danger)),
                          Row(children: [
                            Expanded(
                                child: FilledButton(
                                    onPressed: busy ||
                                            !dirty ||
                                            title.text.trim().isEmpty
                                        ? null
                                        : rename,
                                    child:
                                        Text(busy ? 'در حال ثبت…' : 'ذخیره'))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => setState(() => editing = false),
                                    child: const Text('انصراف')))
                          ]),
                        ])),
                  if (management)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: const Color(0xfff4f5fa),
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('مدیریت واحد',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 8),
                            _action('جابه‌جایی واحد', 'تغییر واحد بالادستی',
                                Icons.account_tree_outlined, false),
                            const SizedBox(height: 8),
                            _action('حذف واحد', 'با بررسی وابستگی‌ها',
                                Icons.delete_outline, true),
                          ]),
                    ),
                ],
              ]),
              const SizedBox(height: 10),
              _OrgPanel(children: [
                _OrgDetailSection(
                    title: 'زیرواحدها',
                    icon: Icons.account_tree_outlined,
                    color: _orgAccents[1],
                    addKey: const ValueKey('organization-subunit-add'),
                    onAdd: busy || !widget.canManage || unit['is_group'] != 1
                        ? null
                        : () async {
                            final saved = await _openOrganizationPage<bool>(
                                context,
                                _OrgSheetTheme(
                                    child: _UnitForm(
                                        units: widget.units,
                                        parent: '${unit['name']}')));
                            if (saved == true && context.mounted) {
                              Navigator.pop(context);
                            }
                          }),
                if (!widget.units
                    .any((u) => u['parent_department'] == unit['name']))
                  const _OrgNotice(
                      icon: Icons.account_tree_outlined,
                      color: Color(0xff8965af),
                      text: 'برای این واحد هنوز زیرواحدی تعریف نشده است.'),
                for (final child in widget.units
                    .where((u) => u['parent_department'] == unit['name']))
                  _OrgDetailRow(
                      title: organizationUnitLabel(child),
                      onTap: () => _openOrganizationPage<void>(
                          context,
                          _OrgSheetTheme(
                              child: _UnitDetails(
                                  unit: child,
                                  units: widget.units,
                                  canManage: widget.canManage)))),
              ]),
              const SizedBox(height: 10),
              _OrgPanel(children: [
                _UnitPositions(unit: unit, canManage: widget.canManage && !busy)
              ]),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                  onPressed: busy ? null : () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('بازگشت به چارت سازمانی')),
              const _OrgTabFooter(),
            ]),
      ),
    );
  }

  Widget _action(String title, String subtitle, IconData icon, bool delete) =>
      Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: delete
                    ? const Color(0xffffd5d1)
                    : const Color(0xffdce5f3))),
        child: ListTile(
            key: ValueKey(delete ? 'organization-unit-delete-action' : 'organization-unit-move-action'),
            dense: true,
            leading: AsoudIconBox(
                icon: icon,
                color: delete ? AsoudColors.danger : _orgAccents[0],
                size: 32),
            title: Text(title,
                style: TextStyle(
                    fontSize: 13,
                    color: delete ? AsoudColors.danger : _orgInk)),
            subtitle: Text(subtitle, style: const TextStyle(fontSize: 10)),
            trailing: const Icon(Icons.chevron_left, size: 18),
            onTap: busy ? null : () => manage(delete: delete)),
      );
}
