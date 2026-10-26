part of 'organization_page.dart';

/// A view over the same Department and position records, not another chart store.
class _OrganizationVisualReport extends StatefulWidget {
  const _OrganizationVisualReport({required this.canManage});
  final bool canManage;
  @override
  State<_OrganizationVisualReport> createState() =>
      _OrganizationVisualReportState();
}

class _OrganizationVisualReportState extends State<_OrganizationVisualReport> {
  late Future<Map<String, dynamic>> units;
  late Future<List<OrganizationEmployee>> people;
  final List<String> unitPath = [], positionPath = [];
  int tab = 0;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final c = context.read<OrganizationCubit>();
    units = c.repository.units(c.company).catchError(
        (Object _) => <String, dynamic>{
              'units': <dynamic>[],
              'can_manage': false,
              'unavailable': true
            });
    people = c.repository.employees(c.company);
  }

  Future<void> _position(OrgPosition row) async {
    setState(() {
      final index = positionPath.indexOf(row.code);
      if (index >= 0) {
        positionPath.removeRange(index, positionPath.length);
      }
      positionPath.add(row.code);
    });
    await _orgSheet<void>(
        context, _PositionDetails(code: row.code, canManage: widget.canManage));
  }

  Widget _row<T>(String key, List<T> items, Widget Function(T) itemBuilder) =>
      LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth / 3).clamp(110.0, 180.0);
        return SizedBox(
            height: 174,
            child: ListView.builder(
                key: PageStorageKey(key),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    SizedBox(width: width, child: itemBuilder(items[index]))));
      });
  Widget _card(String title, String subtitle, String key, VoidCallback onTap,
          {Widget? menu, String? employee}) =>
      Card(
          color: _unitColor(key).withValues(alpha: .1),
          child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _OrganizationAvatar(employee: employee),
                      if (menu != null) SizedBox(width: 36, child: menu),
                    ]),
                    const SizedBox(height: 8),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11)),
                  ]))));
  Widget _positionCard(OrgPosition p, List<OrganizationEmployee> employees) =>
      _card(
          p.title,
          p.activeEmployees.isEmpty
              ? 'بدون متصدی'
              : p.activeEmployees
                  .map((id) =>
                      employees
                          .where((e) => e.id == id)
                          .map((e) => e.displayName)
                          .firstOrNull ??
                      'پرسنل منتسب')
                  .join('، '),
          p.departmentId.isEmpty ? p.department : p.departmentId,
          () => _position(p),
          menu: widget.canManage ? _OrganizationMenu(position: p) : null,
          employee: p.activeEmployees.firstOrNull);
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: const AsoudHeader(title: 'گزارش تصویری چارت'),
      body: FutureBuilder<Map<String, dynamic>>(
          future: units,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: TextButton(
                      onPressed: () => setState(_reload),
                      child: const Text(
                          'دریافت اطلاعات ناموفق بود؛ تلاش دوباره')));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final departments = (snapshot.data!['units'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            final ids = departments.map((d) => d['name']).toSet();
            final manageUnits =
                widget.canManage && snapshot.data!['can_manage'] == true;
            return FutureBuilder<List<OrganizationEmployee>>(
                future: people,
                builder: (context, employeeSnapshot) =>
                    BlocBuilder<OrganizationCubit, OrganizationState>(
                        builder: (context, state) {
                      final rows = state.snapshot.rows;
                      final knownPositions = rows.map((r) => r.code).toSet();
                      final validUnitPath =
                          unitPath.takeWhile(ids.contains).toList();
                      final validPositionPath = positionPath
                          .takeWhile(knownPositions.contains)
                          .toList();
                      final employees = employeeSnapshot.data ?? [];
                      return ListView(
                          key: const PageStorageKey('visual-chart'),
                          padding: const EdgeInsets.all(12),
                          children: [
                            if (snapshot.data!['unavailable'] == true)
                              const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text(
                                      'فهرست واحدها در دسترس نیست؛ جایگاه‌ها از آخرین اطلاعات ذخیره‌شده نمایش داده می‌شوند.',
                                      key: ValueKey('visual-units-unavailable'),
                                      style: TextStyle(fontSize: 11))),
                            const _OrganizationStatus(),
                            AsoudSegmentedControl<int>(
                                value: tab,
                                options: const [
                                  AsoudSegmentedOption(
                                      value: 0,
                                      label: 'نمای درختی',
                                      icon: Icons.account_tree_outlined),
                                  AsoudSegmentedOption(
                                      value: 1,
                                      label: 'نمای فهرستی',
                                      icon: Icons.view_list_outlined),
                                ],
                                onChanged: (v) => setState(() => tab = v)),
                            if (widget.canManage)
                              Row(children: [
                                Expanded(
                                    child: TextButton(
                                        onPressed: () async {
                                          await _openOrganizationPage<bool>(context, const _OrganizationExcelImport());
                                          if (mounted) setState(_reload);
                                        },
                                        child: const Text('ورود از اکسل'))),
                                Expanded(
                                    child: TextButton(
                                        onPressed: () =>
                                            _openOrganizationPage<bool>(
                                                context,
                                                const _OrganizationCreateForm(
                                                    position: true)),
                                        child: const Text('ایجاد دستی'))),
                              ]),
                            if (widget.canManage)
                              TextButton(
                                  onPressed: () =>
                                      _downloadOrganizationTemplate(context),
                                  child: const Text('دریافت الگوی اکسل')),
                            if (employeeSnapshot.hasError)
                              const Text(
                                  'مشخصات متصدیان دریافت نشد؛ اطلاعات جایگاه‌ها محفوظ است.'),
                            if (tab == 1) ...[
                              for (final d in departments)
                                ListTile(
                                    leading: Icon(Icons.business_outlined,
                                        color: _unitColor('${d['name']}')),
                                    title: Text(organizationUnitLabel(d)),
                                    onTap: () async {
                                      await _orgSheet<void>(
                                          context,
                                          _UnitDetails(
                                              unit: d,
                                              units: departments,
                                              canManage: manageUnits));
                                      if (mounted) setState(_reload);
                                    }),
                              for (final p in rows)
                                ListTile(
                                    title: Text(p.displayTitle),
                                    subtitle: Text(p.displayDepartment),
                                    onTap: () => _position(p)),
                            ] else ...[
                              if (rows.isEmpty && departments.isEmpty)
                                const Text(
                                    'هنوز ساختار سازمانی تعریف نشده است.'),
                              if (rows.any((p) => p.parent.isEmpty)) ...[
                                const Text('جایگاه‌های ریشه'),
                                _row(
                                    'position-roots',
                                    rows
                                        .where((p) => p.parent.isEmpty)
                                        .toList(),
                                    (p) => _positionCard(p, employees)),
                              ],
                              for (final parent in validPositionPath) ...[
                                const Center(
                                    child: Icon(Icons.south,
                                        color: AsoudColors.muted)),
                                _row(
                                    'positions-$parent',
                                    rows
                                        .where((p) => p.parent == parent)
                                        .toList(),
                                    (p) => _positionCard(p, employees)),
                                if (!rows.any((p) => p.parent == parent))
                                  const Text('این جایگاه زیرمجموعه ندارد.'),
                              ],
                              const Text(
                                  'واحدهای سازمانی — برای مشاهده شاخه، کارت را لمس کنید'),
                              for (final parent in ['', ...validUnitPath]) ...[
                                if (parent.isNotEmpty)
                                  const Center(
                                      child: Icon(Icons.south,
                                          color: AsoudColors.muted)),
                                _row(
                                    'units-$parent',
                                    departments
                                        .where((d) => parent.isEmpty
                                            ? !ids.contains(
                                                d['parent_department'])
                                            : d['parent_department'] == parent)
                                        .toList(),
                                    (d) => _card(
                                        organizationUnitLabel(d),
                                        'واحد سازمانی',
                                        '${d['name']}', () async {
                                      setState(() {
                                        final level = parent.isEmpty
                                            ? 0
                                            : validUnitPath.indexOf(parent) + 1;
                                        unitPath
                                          ..clear()
                                          ..addAll(validUnitPath.take(level))
                                          ..add('${d['name']}');
                                      });
                                      await _orgSheet<void>(
                                          context,
                                          _UnitDetails(
                                              unit: d,
                                              units: departments,
                                              canManage: manageUnits));
                                      if (mounted) setState(_reload);
                                    },
                                        menu: manageUnits
                                            ? IconButton(
                                                icon:
                                                    const Icon(Icons.more_vert),
                                                onPressed: () async {
                                                  await _orgSheet<void>(
                                                      context,
                                                      _UnitDetails(
                                                          unit: d,
                                                          units: departments,
                                                          canManage: true));
                                                  if (mounted) {
                                                    setState(_reload);
                                                  }
                                                })
                                            : null)),
                                if (parent.isNotEmpty)
                                  _row(
                                      'unit-positions-$parent',
                                      rows
                                          .where((p) =>
                                              p.departmentId == parent)
                                          .toList(),
                                      (p) => _positionCard(p, employees)),
                              ],
                            ],
                          ]);
                    }));
          }));
}

class _OrganizationAvatar extends StatefulWidget {
  const _OrganizationAvatar({this.employee});
  final String? employee;
  @override
  State<_OrganizationAvatar> createState() => _OrganizationAvatarState();
}

class _OrganizationAvatarState extends State<_OrganizationAvatar> {
  Future<Uint8List?>? photo;
  void _load() {
    final c = context.read<OrganizationCubit>();
    photo = widget.employee == null
        ? null
        : c.repository.employeePhoto(c.company, widget.employee!);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _OrganizationAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employee != widget.employee) _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
      future: photo,
      builder: (context, snapshot) => CircleAvatar(
          radius: 18,
          child: snapshot.hasData
              ? ClipOval(
                  child: Image.memory(snapshot.data!,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          const Icon(Icons.person_outline)))
              : const Icon(Icons.person_outline, size: 20)));
}
