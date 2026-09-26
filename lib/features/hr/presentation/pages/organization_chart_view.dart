part of 'organization_page.dart';

String _normalizedOrgCode(String value) {
  const digits = '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩';
  return value.split('').map((char) {
    final index = digits.indexOf(char);
    return index < 0 ? char : '${index % 10}';
  }).join();
}

List<OrgPosition> _sortedPositions(Iterable<OrgPosition> rows) => rows.toList()
  ..sort((a, b) {
    final left = _normalizedOrgCode(a.code);
    final right = _normalizedOrgCode(b.code);
    final leftNumber = BigInt.tryParse(left);
    final rightNumber = BigInt.tryParse(right);
    final order = leftNumber != null && rightNumber != null
        ? leftNumber.compareTo(rightNumber)
        : left.compareTo(right);
    return order == 0 ? a.code.compareTo(b.code) : order;
  });

class _OrganizationChart extends StatefulWidget {
  const _OrganizationChart();
  @override
  State<_OrganizationChart> createState() => _OrganizationChartState();
}

class _OrganizationChartState extends State<_OrganizationChart> {
  int _view = 0;
  String _query = '';
  final List<String> _path = [];

  void _back() => setState(() {
        _path.removeLast();
        _query = '';
      });

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _view != 1 || _path.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _view == 1 && _path.isNotEmpty) _back();
        },
        child: Scaffold(
          appBar: const AsoudHeader(
              title: 'جایگاه‌های سازمانی',
              subtitle: 'ساختار بالادست، زیرمجموعه‌ها و انتصاب پرسنل'),
          body:
              SafeArea(child: BlocBuilder<OrganizationCubit, OrganizationState>(
            builder: (context, state) {
              final rows = state.snapshot.rows;
              final parents = rows
                  .where((row) => _path.isNotEmpty && row.code == _path.last);
              final parent = parents.isEmpty ? null : parents.first;
              final children = _sortedPositions(rows.where((row) =>
                  row.parent == (parent?.code ?? '') &&
                  (row.title.contains(_query) ||
                      row.code.contains(_query) ||
                      row.department.contains(_query))));
              return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                  children: [
                    const _OrganizationStatus(),
                    AsoudSegmentedControl<int>(
                      value: _view,
                      options: const [
                        AsoudSegmentedOption(
                            value: 0,
                            icon: Icons.account_tree_outlined,
                            label: 'نمای درختی'),
                        AsoudSegmentedOption(
                            value: 1,
                            icon: Icons.view_list_outlined,
                            label: 'نمای مرحله‌ای'),
                      ],
                      onChanged: (value) => setState(() {
                        _view = value;
                        _query = '';
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: ValueKey('org-search-$_view-${_path.join('/')}'),
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'جست‌وجوی کد یا عنوان جایگاه'),
                    ),
                    const SizedBox(height: 14),
                    if (_view == 1) ...[
                      Row(children: [
                        if (_path.isNotEmpty)
                          IconButton(
                              onPressed: _back,
                              tooltip: 'بازگشت به سطح قبل',
                              icon: const Icon(Icons.arrow_forward_rounded)),
                        Expanded(
                            child: Text(
                                parent == null
                                    ? 'جایگاه‌های اصلی'
                                    : 'زیرمجموعه‌های ${parent.title}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))),
                      ]),
                      if (parent != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: FilledButton.icon(
                            onPressed: state.busy
                                ? null
                                : () => _openOrganizationPage<bool>(context,
                                    _OrganizationPositionForm(parent: parent)),
                            icon: const Icon(Icons.add),
                            label: const Text('افزودن زیرمجموعه'),
                          ),
                        ),
                      if (children.isEmpty) const _OrgEmpty(),
                      for (final row in children)
                        Card(
                            child: ListTile(
                          contentPadding: const EdgeInsetsDirectional.only(
                              start: 12, end: 2),
                          leading: const Icon(Icons.folder_outlined,
                              color: AsoudColors.primary),
                          title: Text(row.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text([
                            if (row.department.isNotEmpty) row.department,
                            row.employee.isEmpty
                                ? 'جایگاه خالی'
                                : 'پرسنل: ${row.employee}'
                          ].join(' · ')),
                          trailing: SizedBox(
                              width: 104,
                              child: Row(children: [
                                Expanded(
                                    child: Text(row.code,
                                        textDirection: TextDirection.ltr,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700))),
                                _OrganizationMenu(position: row),
                              ])),
                          onTap: () => setState(() {
                            _path.add(row.code);
                            _query = '';
                          }),
                        )),
                    ] else
                      _OrganizationTree(rows: rows, query: _query),
                  ]);
            },
          )),
        ),
      );
}

class _OrgEmpty extends StatelessWidget {
  const _OrgEmpty();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Column(children: [
          AsoudIconBox(
              icon: Icons.account_tree_outlined,
              color: AsoudColors.primary,
              size: 48),
          SizedBox(height: 12),
          Text('جایگاهی برای نمایش وجود ندارد.', textAlign: TextAlign.center),
          SizedBox(height: 6),
          Text(
              'برای جایگاه اصلی از صفحه مدیریت و برای زیرمجموعه از منوی جایگاه استفاده کنید.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
        ]),
      );
}

class _OrganizationTree extends StatefulWidget {
  const _OrganizationTree(
      {required this.rows,
      this.query = '',
      this.preview = false,
      this.knownRows});
  final List<OrgPosition> rows;
  final List<OrgPosition>? knownRows;
  final String query;
  final bool preview;
  @override
  State<_OrganizationTree> createState() => _OrganizationTreeState();
}

class _OrganizationTreeState extends State<_OrganizationTree> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final byCode = {for (final row in widget.rows) row.code: row};
    final children = <String, List<OrgPosition>>{};
    for (final row in widget.rows) {
      children.putIfAbsent(row.parent, () => []).add(row);
    }
    final matches = <String>{};
    for (final row in widget.rows) {
      if (row.title.contains(widget.query) ||
          row.code.contains(widget.query) ||
          row.department.contains(widget.query)) {
        var cursor = row;
        final seen = <String>{};
        while (seen.add(cursor.code)) {
          matches.add(cursor.code);
          final parent = byCode[cursor.parent];
          if (parent == null) break;
          cursor = parent;
        }
      }
    }
    final widgets = <Widget>[];
    final visited = <String>{};
    void addRows(Iterable<OrgPosition> items, int depth) {
      for (final row in _sortedPositions(items)) {
        if (!visited.add(row.code) || !matches.contains(row.code)) continue;
        final descendants = children[row.code] ?? const <OrgPosition>[];
        final open = widget.preview ||
            widget.query.isNotEmpty ||
            _expanded.contains(row.code);
        final parentNames = (widget.knownRows ?? widget.rows)
            .where((e) => e.code == row.parent);
        widgets.add(Padding(
          key: ValueKey('org-tree-${row.code}'),
          padding: EdgeInsetsDirectional.only(
              start: (8 + depth.clamp(0, 5) * 10).toDouble(), end: 2),
          child: InkWell(
            onTap: descendants.isEmpty
                ? null
                : () => setState(() {
                      if (!_expanded.add(row.code)) _expanded.remove(row.code);
                    }),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Icon(
                      descendants.isEmpty
                          ? Icons.badge_outlined
                          : open
                              ? Icons.folder_open_outlined
                              : Icons.folder,
                      color: depth == 0
                          ? AsoudColors.primary
                          : AsoudColors.success,
                      size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(row.title,
                            style: TextStyle(
                                fontWeight: depth == 0
                                    ? FontWeight.w800
                                    : FontWeight.w500)),
                        if (widget.preview &&
                            row.parent.isNotEmpty &&
                            !byCode.containsKey(row.parent))
                          Text(
                              'زیرمجموعه: ${parentNames.isEmpty ? row.parent : parentNames.first.title}',
                              style: const TextStyle(
                                  fontSize: 10, color: AsoudColors.muted)),
                      ])),
                  if (descendants.isNotEmpty)
                    Icon(open ? Icons.expand_more : Icons.chevron_left,
                        size: 18, color: AsoudColors.muted),
                  const SizedBox(width: 6),
                  SizedBox(
                      width: widget.preview ? 70 : 58,
                      child: Text(row.code,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700))),
                  if (!widget.preview) _OrganizationMenu(position: row),
                ])),
          ),
        ));
        if (open) addRows(descendants, depth + 1);
      }
    }

    addRows(
        widget.rows.where(
            (row) => row.parent.isEmpty || !byCode.containsKey(row.parent)),
        0);
    if (widgets.isEmpty) return const _OrgEmpty();
    return Card(
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AsoudColors.border)),
      child: Column(children: widgets),
    );
  }
}

class _OrganizationMenu extends StatelessWidget {
  const _OrganizationMenu({required this.position});
  final OrgPosition position;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OrganizationCubit, OrganizationState>(
        builder: (context, state) => SizedBox(
          width: 36,
          child: PopupMenuButton<String>(
            tooltip: 'عملیات جایگاه',
            padding: EdgeInsets.zero,
            enabled: !state.busy,
            icon: const Icon(Icons.more_vert, size: 21),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'add', child: Text('افزودن زیرمجموعه')),
              PopupMenuItem(value: 'edit', child: Text('ویرایش جایگاه')),
              PopupMenuItem(value: 'move', child: Text('انتقال جایگاه')),
              PopupMenuItem(value: 'delete', child: Text('حذف جایگاه')),
            ],
            onSelected: (action) async {
              if (action == 'move') {
                await _move(context);
                return;
              }
              if (action == 'add' || action == 'edit') {
                await _openOrganizationPage<bool>(
                    context,
                    _OrganizationPositionForm(
                        item: action == 'edit' ? position : null,
                        parent: action == 'add' ? position : null));
                return;
              }
              final cubit = context.read<OrganizationCubit>();
              if (cubit.state.snapshot.rows
                      .any((row) => row.parent == position.code) ||
                  position.employee.isNotEmpty) {
                _orgMessage(context,
                    'ابتدا زیرمجموعه‌ها و انتصاب پرسنل را تغییر دهید.');
                return;
              }
              final yes = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                        title: const Text('حذف جایگاه'),
                        content: Text('جایگاه «${position.title}» حذف شود؟'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('انصراف')),
                          FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('حذف')),
                        ],
                      ));
              if (yes == true && context.mounted && !cubit.state.busy) {
                final rows = cubit.state.snapshot.rows;
                if (rows.any((row) =>
                    row.parent == position.code ||
                    (row.code == position.code && row.employee.isNotEmpty))) {
                  return;
                }
                await cubit.save(
                    rows.where((row) => row.code != position.code).toList());
              }
            },
          ),
        ),
      );

  Future<void> _move(BuildContext context) async {
    final cubit = context.read<OrganizationCubit>();
    final rows = cubit.state.snapshot.rows;
    final blocked = <String>{position.code};
    var changed = true;
    while (changed) {
      changed = false;
      for (final row in rows) {
        if (blocked.contains(row.parent) && blocked.add(row.code))
          changed = true;
      }
    }
    final parent = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
              title: Text('انتقال «${position.title}» و زیرمجموعه‌هایش'),
              children: [
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'بالادست جدید را انتخاب کنید. مدیر مستقیم پرسنل این جایگاه نیز مطابق انتصاب بالادست تغییر می‌کند.')),
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, ''),
                    child: const Text('جایگاه اصلی؛ بدون بالادست')),
                for (final row in _sortedPositions(
                    rows.where((row) => !blocked.contains(row.code))))
                  SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, row.code),
                      child: Text('${row.code} — ${row.title}')),
              ],
            ));
    if (parent == null || !context.mounted || cubit.state.busy) return;
    final latest = cubit.state.snapshot.rows;
    final matches = latest.where((row) => row.code == position.code);
    if (matches.isEmpty) return;
    final current = matches.first;
    if (current.parent == parent) return;
    final candidate = latest
        .map((row) => row.code != current.code
            ? row
            : OrgPosition(
                code: row.code,
                title: row.title,
                parent: parent,
                department: row.department,
                employee: row.employee))
        .toList();
    try {
      validateOrganization(candidate);
    } on FormatException catch (e) {
      _orgMessage(context, e.message);
      return;
    }
    await cubit.save(candidate);
  }
}
