part of 'access_profiles_page.dart';

typedef _SaveCatalog = Future<AccessMap> Function(
    List<AccessMap> modules, String version);

class _AccessCatalogEditor extends StatefulWidget {
  const _AccessCatalogEditor(
      {required this.layout, required this.save, required this.nativeCatalog});
  final AccessMap layout;
  final List<AccessMap> nativeCatalog;
  final _SaveCatalog save;

  @override
  State<_AccessCatalogEditor> createState() => _AccessCatalogEditorState();
}

class _AccessCatalogEditorState extends State<_AccessCatalogEditor> {
  late final modules = _copy(widget.layout['modules']);
  final random = Random.secure();
  bool busy = false, dirty = false;
  String? error;
  static const labels = ['ماژول', 'سند', 'جزئیات سند'];

  List<AccessMap> _copy(dynamic nodes) => [
        for (final node in accessRows(nodes))
          {
            'id': node['id'],
            'title': node['title'],
            'children': _copy(node['children'])
          },
      ];

  Future<void> edit(List<AccessMap> siblings, int level,
      [AccessMap? row]) async {
    final kind = labels[level];
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _CatalogNameDialog(
        title: row == null ? 'افزودن $kind' : 'ویرایش $kind',
        initial: row?['title'] as String? ?? '',
        existing: {
          for (final sibling in siblings)
            if (sibling != row) (sibling['title'] as String).toLowerCase()
        },
      ),
    );
    if (title == null || !mounted) return;
    setState(() {
      if (row == null) {
        final id = List.generate(16,
                (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join();
        siblings.add(
            {'id': 'custom-$id', 'title': title, 'children': <AccessMap>[]});
      } else {
        row['title'] = title;
      }
      dirty = true;
    });
  }

  Future<void> remove(List<AccessMap> siblings, AccessMap row) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: const Text('حذف از کاتالوگ مشترک'),
              content: Text(
                  '«${row['title']}» و ردیف‌های زیر آن از نمایش کاتالوگ حذف شوند؟ مجوزهای ذخیره‌شده و اسناد سیستم تغییر نمی‌کنند.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('انصراف')),
                TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('حذف')),
              ],
            ));
    if (yes != true || !mounted) return;
    setState(() {
      siblings.remove(row);
      dirty = true;
    });
  }

  Future<void> restore(List<AccessMap> target) async {
    final used = {
      for (final module in modules)
        for (final doc in module['children'] as List<AccessMap>) doc['id']
    };
    final titles = {
      for (final doc in target) (doc['title'] as String).toLowerCase()
    };
    final available = widget.nativeCatalog
        .where((doc) =>
            !used.contains('native:${doc['doctype']}') &&
            !titles.contains((doc['title'] as String).toLowerCase()))
        .toList();
    final doc = await showDialog<AccessMap>(
        context: context,
        builder: (dialog) => SimpleDialog(
              title: const Text('بازیابی سند موجود'),
              children: [
                if (available.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('سندی برای بازیابی در این ماژول نیست.')),
                for (final row in available)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(dialog, row),
                    child: Text('${row['title']}'),
                  ),
              ],
            ));
    if (doc == null || !mounted) return;
    setState(() {
      target.add({
        'id': 'native:${doc['doctype']}',
        'title': doc['title'],
        'children': <AccessMap>[]
      });
      dirty = true;
    });
  }

  Future<void> save() async {
    if (!dirty || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result =
          await widget.save(modules, widget.layout['version'] as String);
      if (!mounted) return;
      setState(() => busy = false);
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = failureMessage(e);
        busy = false;
      });
    }
  }

  Widget row(List<AccessMap> siblings, AccessMap node, int level, int index) {
    final children = node['children'] as List<AccessMap>;
    final color = profileAccent(index);
    final menu = PopupMenuButton<String>(
      enabled: !busy,
      tooltip: 'گزینه‌های ${node['title']}',
      icon: const Icon(Icons.more_vert, size: 17),
      onSelected: (action) {
        switch (action) {
          case 'add':
            edit(children, level + 1);
          case 'edit':
            edit(siblings, level, node);
          case 'remove':
            remove(siblings, node);
          case 'restore':
            restore(children);
        }
      },
      itemBuilder: (_) => [
        if (level < 2)
          PopupMenuItem(
              value: 'add', child: Text('افزودن ${labels[level + 1]}')),
        if (level == 0)
          const PopupMenuItem(
              value: 'restore', child: Text('بازیابی سند موجود')),
        const PopupMenuItem(value: 'edit', child: Text('ویرایش نام')),
        const PopupMenuItem(value: 'remove', child: Text('حذف ردیف')),
      ],
    );
    final title = Text('${node['title']}',
        style: TextStyle(
            fontSize: level == 0 ? 14 : 12, fontWeight: FontWeight.w700));
    if (level == 2) {
      return ListTile(
          title: title, dense: true, minTileHeight: 42, trailing: menu);
    }
    return ExpansionTile(
      key: PageStorageKey('edit-catalog:${node['id']}'),
      minTileHeight: 44,
      tilePadding: const EdgeInsetsDirectional.only(start: 4, end: 8),
      leading: menu,
      controlAffinity: ListTileControlAffinity.trailing,
      collapsedBackgroundColor: color.withValues(alpha: level == 0 ? .09 : .04),
      backgroundColor: color.withValues(alpha: .04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      collapsedShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: title,
      childrenPadding: const EdgeInsetsDirectional.only(start: 10),
      children: [
        for (final (i, child) in children.indexed)
          row(children, child, level + 1, i),
        if (children.isEmpty)
          TextButton(
              onPressed: busy ? null : () => edit(children, level + 1),
              child: Text('افزودن ${labels[level + 1]}')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: PopScope(
          canPop: !busy,
          child: Scaffold(
            backgroundColor: AsoudColors.background,
            appBar: const AsoudHeader(title: 'کاتالوگ مشترک دسترسی'),
            body: ListView(padding: const EdgeInsets.all(12), children: [
              _profilePanel(const Text(
                  'ترتیب ردیف‌ها: ماژول، سند و جزئیات سند. این تغییر برای همهٔ پروفایل‌هاست؛ ردیف تازه تا اتصال به مجوز معتبر، دسترسی ایجاد نمی‌کند.')),
              const SizedBox(height: 8),
              Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                      onPressed: busy ? null : () => edit(modules, 0),
                      icon: const Icon(Icons.add),
                      label: const Text('افزودن ماژول'))),
              const SizedBox(height: 8),
              _profilePanel(Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, module) in modules.indexed) ...[
                      row(modules, module, 0, i),
                      const SizedBox(height: 4),
                    ],
                    if (modules.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('هنوز ماژولی اضافه نشده است.')),
                  ])),
            ]),
            bottomNavigationBar: SafeArea(
                child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null)
                      Text(error!,
                          style: const TextStyle(color: AsoudColors.danger)),
                    Row(children: [
                      Expanded(
                          child: FilledButton(
                              onPressed: !dirty || busy ? null : save,
                              child: Text(
                                  busy ? 'در حال ذخیره…' : 'ذخیره کاتالوگ'))),
                      const SizedBox(width: 8),
                      OutlinedButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: const Text('انصراف')),
                    ]),
                  ]),
            )),
          ),
        ),
      );
}

class _CatalogNameDialog extends StatefulWidget {
  const _CatalogNameDialog(
      {required this.title, required this.initial, required this.existing});
  final String title, initial;
  final Set<String> existing;

  @override
  State<_CatalogNameDialog> createState() => _CatalogNameDialogState();
}

class _CatalogNameDialogState extends State<_CatalogNameDialog> {
  late final name = TextEditingController(text: widget.initial);
  final form = GlobalKey<FormState>();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Form(
            key: form,
            child: TextFormField(
              controller: name,
              autofocus: true,
              maxLength: 140,
              decoration: const InputDecoration(labelText: 'نام ردیف'),
              validator: (value) {
                final title = (value ?? '').trim();
                if (title.isEmpty) return 'نام را وارد کنید.';
                if (widget.existing.contains(title.toLowerCase())) {
                  return 'این نام در همین سطح وجود دارد.';
                }
                return null;
              },
            )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, name.text.trim());
                }
              },
              child: const Text('تأیید')),
        ],
      );
}
