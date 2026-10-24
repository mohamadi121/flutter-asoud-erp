part of 'organization_page.dart';

/// A visual root is not a fabricated job or personnel assignment.
class _OrganizationRootCard extends StatelessWidget {
  const _OrganizationRootCard({this.title = 'مدیرعامل'});
  final String title;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xff283f70),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          const Icon(Icons.manage_accounts_outlined,
              color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
      );
}

class _OrganizationUnitManagement extends StatefulWidget {
  const _OrganizationUnitManagement(
      {required this.unit, required this.units, required this.canManage, this.initialDelete = false});
  final bool initialDelete;
  final Map<String, dynamic> unit;
  final List<Map<String, dynamic>> units;
  final bool canManage;
  @override
  State<_OrganizationUnitManagement> createState() =>
      _OrganizationUnitManagementState();
}

class _OrganizationUnitManagementState
    extends State<_OrganizationUnitManagement> {
  late Map<String, dynamic> unit = widget.unit;
  late String parent = '${unit['parent_department'] ?? ''}';
  bool busy = false;
  late bool deleting = widget.initialDelete;
  String? error;
  String get initialParent => '${unit['parent_department'] ?? ''}';
  String label(String id) => id.isEmpty
      ? 'مدیرعامل (سطح اصلی)'
      : widget.units
              .where((u) => u['name'] == id)
              .map((u) => '${u['department_name']}')
              .firstOrNull ??
          'واحد بالادستی خارج از فهرست';
  Set<String> get excluded {
    final result = <String>{'${unit['name']}'};
    var changed = true;
    while (changed) {
      final size = result.length;
      for (final u in widget.units) {
        if (result.contains(u['parent_department'])) result.add('${u['name']}');
      }
      changed = result.length != size;
    }
    return result;
  }

  Future<void> select(Map<String, dynamic> next) async {
    if (busy) return;
    if (parent != initialParent && !await _confirmOrgDiscard(context)) return;
    if (!mounted) return;
    setState(() {
      unit = next;
      parent = initialParent;
      error = null;
    });
  }

  Future<void> submit() async {
    if (busy || !widget.canManage) return;
    if (!deleting && parent == initialParent) return;
    final c = context.read<OrganizationCubit>();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (deleting) {
        final preview = await c.repository.previewDeleteUnit(
            c.company, '${unit['name']}', '${unit['modified']}');
        if (!mounted) return;
        if (preview['can_delete'] != true) {
          setState(() => error =
              (preview['blockers'] as List? ?? ['حذف این واحد مجاز نیست.'])
                  .join('\n'));
          return;
        }
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
                  title: const Text('تأیید حذف واحد'),
                  content: Text(
                      'واحد «${unit['department_name']}» حذف شود؟ وابستگی‌ها دوباره بررسی می‌شوند.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const Text('انصراف')),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const Text('تأیید حذف واحد')),
                  ],
                ));
        if (confirmed != true || !mounted) return;
        await c.repository
            .deleteUnit(c.company, '${unit['name']}', '${unit['modified']}');
      } else {
        await c.repository.saveUnit(c.company, {
          'name': unit['name'],
          'modified': unit['modified'],
          'title': unit['department_name'],
          'parent': parent,
          'is_group': unit['is_group'] == 1,
        });
      }
      await c.load();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OrganizationCubit>().state;
    final children = widget.units
        .where((u) => u['parent_department'] == unit['name'])
        .toList();
    final count = state.snapshot.rows
        .where((r) =>
            r.departmentId == unit['name'] ||
            (r.departmentId.isEmpty && r.department == unit['department_name']))
        .length;
    final roots = state.snapshot.rows.where((r) => r.parent.isEmpty).toList();
    final locked = busy || state.busy;
    return PopScope(
      canPop: !busy && parent == initialParent,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || busy) return;
        if (await _confirmOrgDiscard(context) && mounted) {
          setState(() => parent = initialParent);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        backgroundColor: _orgCanvas,
        appBar: const _OrganizationReferenceHeader(
            title: 'مدیریت ساختار سازمانی', form: true),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _OrgPanel(children: [
            Row(children: [
              const Expanded(
                  child: Text('ساختار فعلی سازمان',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: _orgInk))),
              Text(formatCount(widget.units.length, 'واحد'),
                  style: const TextStyle(fontSize: 11)),
            ]),
            const SizedBox(height: 12),
            _OrganizationRootCard(
                title: roots.firstOrNull?.title ?? 'مدیرعامل'),
            Center(
                child: Container(
                    width: 2, height: 14, color: const Color(0xffbac6d7))),
            Center(
                child: Container(
              width: 180,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xffe0eaff),
                  border: Border.all(color: const Color(0xff3679ff)),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Icon(Icons.business_outlined, color: _orgAccents[1], size: 22),
                const SizedBox(height: 6),
                Text('${unit['department_name']}', textAlign: TextAlign.center),
                Text(formatCount(children.length, 'زیرواحد'),
                    style: TextStyle(color: _orgAccents[1], fontSize: 11)),
              ]),
            )),
            const SizedBox(height: 10),
            const Text('زیرواحدها',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            if (children.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('این واحد زیرواحد ندارد.')),
            for (final child in children)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Material(
                    color: const Color(0xfff4f5fa),
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                    enabled: !locked,
                    dense: true,
                    leading: Icon(Icons.account_tree_outlined,
                        color: _orgAccents[1], size: 20),
                    title: Text('${child['department_name']}'),
                    subtitle: Text('زیرمجموعه: ${unit['department_name']}'),
                    trailing: const Icon(Icons.chevron_left, size: 18),
                    onTap: () => select(child),
                  ))),
          ]),
          const SizedBox(height: 12),
          _OrgPanel(children: [
            const Text('مدیریت واحد انتخاب‌شده',
                style: TextStyle(fontWeight: FontWeight.bold, color: _orgInk)),
            const SizedBox(height: 12),
            AppSelectField(
                value: '${unit['name']}',
                label: 'واحد انتخاب‌شده',
                displayValue: '${unit['department_name']}',
                enabled: !locked,
                onPick: () => showAppOptionSheet(context,
                    title: 'انتخاب واحد',
                    current: '${unit['name']}',
                    options: widget.units
                        .map((u) => AppOption(
                            '${u['name']}', '${u['department_name']}'))
                        .toList()),
                onChanged: (id) =>
                    select(widget.units.firstWhere((u) => u['name'] == id))),
            const SizedBox(height: 12),
            Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xfff2f5fa),
                    borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  _info('واحد بالادستی فعلی', label(initialParent)),
                  const Divider(height: 30),
                  _info(
                      'تعداد زیرواحد مستقیم', formatCount(children.length, '')),
                  const SizedBox(height: 10),
                  _info('جایگاه شغلی', formatCount(count, '')),
                ])),
            const SizedBox(height: 10),
            if (widget.canManage) ...[
              Row(children: [
                Expanded(
                    child: TextButton(
                        onPressed: locked
                            ? null
                            : () => setState(() => deleting = false),
                        style: TextButton.styleFrom(
                            backgroundColor: deleting
                                ? Colors.transparent
                                : const Color(0xfff1f1f1)),
                        child: const Text('جابه‌جایی واحد'))),
                Expanded(
                    child: TextButton(
                        onPressed: locked
                            ? null
                            : () => setState(() => deleting = true),
                        style: TextButton.styleFrom(
                            backgroundColor: deleting
                                ? const Color(0xfff1f1f1)
                                : Colors.transparent),
                        child: const Text('حذف واحد'))),
              ]),
              const SizedBox(height: 12),
              if (!deleting) ...[
                AppSelectField(
                    value: parent,
                    label: 'انتقال به کدام واحد؟',
                    displayValue: label(parent),
                    enabled: !locked,
                    onPick: () => showAppOptionSheet(context,
                            title: 'واحد بالادستی جدید',
                            current: parent,
                            options: [
                              const AppOption('', 'مدیرعامل (سطح اصلی)'),
                              ...widget.units
                                  .where((u) =>
                                      !excluded.contains(u['name']) &&
                                      u['disabled'] != 1 &&
                                      u['is_group'] == 1)
                                  .map((u) => AppOption('${u['name']}',
                                      '${u['department_name']}')),
                            ]),
                    onChanged: (v) => setState(() => parent = v)),
                const SizedBox(height: 12),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: _orgTints[0],
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      const Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text('پیش‌نمایش تغییر سلسله‌مراتب',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xff3679b5)))),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: Text('از\n${label(initialParent)}',
                                textAlign: TextAlign.center)),
                        const Icon(Icons.arrow_back, size: 18),
                        Expanded(
                            child: Text('به\n${label(parent)}',
                                textAlign: TextAlign.center))
                      ]),
                    ])),
              ] else
                const Text(
                    'حذف فقط پس از بررسی وابستگی‌ها و تأیید شما انجام می‌شود. واحد دارای زیرواحد، جایگاه یا سوابق مرتبط حذف نخواهد شد.'),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(error!,
                        style: const TextStyle(color: AsoudColors.danger))),
              const SizedBox(height: 10),
              FilledButton.icon(
                  key: const ValueKey('organization-management-submit'),
                  onPressed: locked || (!deleting && parent == initialParent)
                      ? null
                      : submit,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff191919),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder()),
                  icon: Icon(
                      deleting
                          ? Icons.delete_outline
                          : Icons.account_tree_outlined,
                      size: 18),
                  label: Text(busy
                      ? 'در حال بررسی…'
                      : deleting
                          ? 'بررسی امکان حذف'
                          : 'ثبت جابه‌جایی')),
            ] else
              const Text('فقط مشاهده؛ اجازهٔ تغییر ساختار ندارید.'),
          ]),
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                  'جابه‌جایی و حذف پس از بررسی وابستگی‌ها توسط سامانه ثبت می‌شوند. پیش‌نمایش به‌تنهایی اطلاعات را تغییر نمی‌دهد.',
                  style: TextStyle(fontSize: 11, color: Color(0xff7d8089)),
                  textAlign: TextAlign.center)),
        ]),
      ),
    );
  }

  Widget _info(String title, String value) => Row(children: [
        Expanded(
            child: Text(title,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xff7d8089)))),
        Flexible(
            child: Text(value,
                style: const TextStyle(fontSize: 12, color: _orgInk)))
      ]);
}
