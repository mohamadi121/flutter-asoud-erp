import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/theme/asoud_colors.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/widgets/asoud_ui.dart';
import '../data/access_management_repository.dart';

part 'access_catalog_editor.dart';

typedef AccessMap = Map<String, dynamic>;
List<AccessMap> accessRows(dynamic value) => (value as List? ?? [])
    .whereType<Map>()
    .map((r) => Map<String, dynamic>.from(r))
    .toList();
Map<String, List<String>> accessGrants(dynamic value) => (value as Map? ?? {})
    .map((k, v) => MapEntry('$k', (v as List).map((a) => '$a').toList()));

class AccessProfilesPage extends StatefulWidget {
  const AccessProfilesPage({required this.company, this.repository, super.key});
  final String company;
  final AccessManagementRepository? repository;
  @override
  State<AccessProfilesPage> createState() => _AccessProfilesState();
}

class _AccessProfilesState extends State<AccessProfilesPage> {
  late final repo = widget.repository ??
      AccessManagementRepository(context.read<FrappeApiClient>());
  List<AccessMap> profiles = [], catalog = [];
  AccessMap? catalogLayout;
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data =
          await repo.call('list_profiles', {'company': widget.company}) as Map;
      if (mounted) {
        setState(() {
          profiles = accessRows(data['profiles']);
          catalog = accessRows(data['catalog']);
          catalogLayout = accessRows([data['catalog_layout']]).firstOrNull;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([AccessMap? profile]) async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => AccessProfileEditor(
                company: widget.company,
                repository: repo,
                catalog: catalog,
                profile: profile,
                catalogLayout: catalogLayout,
                onCatalogSaved: (layout) {
                  if (mounted) setState(() => catalogLayout = layout);
                })));
    if (saved == true && mounted) {
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('پروفایل ذخیره شد.')));
      }
    }
  }

  Future<void> remove(AccessMap profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('حذف پروفایل دسترسی'),
        content: Text(
            'پروفایل «${profile['title']}» حذف شود؟ مجوزهای ذخیره‌شده برای کاربران تغییر نمی‌کنند.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('انصراف')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AsoudColors.danger),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || busy) return;
    setState(() => busy = true);
    try {
      await repo.call('delete_profile', {
        'company': widget.company,
        'name': profile['name'],
        'modified': profile['modified'],
      });
      if (!mounted) return;
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پروفایل حذف شد.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AsoudColors.background,
        appBar: const AsoudHeader(
            title: 'پروفایل‌های دسترسی',
            subtitle: 'الگوهای مجوز برای استفاده در تب دسترسی‌های هر حساب'),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                if (error != null) ...[
                  Text(error!),
                  TextButton(onPressed: load, child: const Text('تلاش دوباره'))
                ] else ...[
                  FilledButton.icon(
                      onPressed: () => edit(),
                      icon: const Icon(Icons.add),
                      style: FilledButton.styleFrom(
                          backgroundColor: AsoudColors.primary),
                      label: const Text('پروفایل جدید')),
                  const SizedBox(height: 12),
                  for (final (index, p) in profiles.indexed)
                    Card(
                        color: AsoudColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AsoudColors.border),
                        ),
                        child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  profileAccent(index).withValues(alpha: .12),
                              child: Icon(
                                  p['readonly'] == true
                                      ? Icons.lock_outline
                                      : Icons.badge_outlined,
                                  color: profileAccent(index)),
                            ),
                            title: Text('${p['title']}'),
                            subtitle: Text(p['readonly'] == true
                                ? 'پروفایل قدیمی بدون دفتر؛ فقط مشاهده'
                                : '${p['description'] ?? ''}'),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              tooltip: 'گزینه‌های پروفایل',
                              onSelected: (action) {
                                if (action == 'delete') {
                                  remove(p);
                                } else {
                                  edit(p);
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: 'open',
                                    child: Text(p['readonly'] == true
                                        ? 'مشاهده'
                                        : 'ویرایش')),
                                if (p['readonly'] != true)
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('حذف پروفایل')),
                              ],
                            ),
                            onTap: () => edit(p))),
                  if (profiles.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('هنوز پروفایلی در این دفتر ثبت نشده است.')),
                ],
              ]),
      ));
}

Color profileAccent(int index) => const [
      AsoudColors.primary,
      AsoudColors.success,
      AsoudColors.purple,
      AsoudColors.warning,
      AsoudColors.cyan,
    ][index % 5];

class AccessProfileEditor extends StatefulWidget {
  const AccessProfileEditor(
      {required this.company,
      required this.repository,
      required this.catalog,
      this.profile,
      this.example,
      this.catalogLayout,
      this.onCatalogSaved,
      super.key});
  final String company;
  final AccessManagementRepository repository;
  final List<AccessMap> catalog;
  final AccessMap? profile;
  final AccessMap? example;
  final AccessMap? catalogLayout;
  final ValueChanged<AccessMap>? onCatalogSaved;
  @override
  State<AccessProfileEditor> createState() => _AccessProfileEditorState();
}

class _AccessProfileEditorState extends State<AccessProfileEditor> {
  late final title = TextEditingController(
      text: (widget.profile?['title'] ?? widget.example?['title']) as String? ??
          '');
  late final description = TextEditingController(
      text: (widget.profile?['description'] ?? widget.example?['description'])
              as String? ??
          '');
  late final grants =
      accessGrants(widget.profile?['grants'] ?? widget.example?['grants']);
  final form = GlobalKey<FormState>();
  late AccessMap? layout = widget.catalogLayout;
  bool busy = false;
  String? error;
  bool get readonly => widget.profile?['readonly'] == true;
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || readonly || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.call('save_profile', {
        'company': widget.company,
        'title': title.text.trim(),
        'description': description.text.trim(),
        'grants': grants,
        if (widget.profile != null) ...{
          'name': widget.profile!['name'],
          'modified': widget.profile!['modified']
        }
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> manageCatalog() async {
    final result = await Navigator.push<AccessMap>(
      context,
      MaterialPageRoute(
          builder: (_) => _AccessCatalogEditor(
                layout: layout!,
                nativeCatalog: widget.catalog,
                save: (modules, version) async {
                  final result =
                      await widget.repository.call('save_catalog_layout', {
                    'company': widget.company,
                    'modules': modules,
                    'version': version,
                  });
                  return Map<String, dynamic>.from(result as Map);
                },
              )),
    );
    if (result == null || !mounted) return;
    setState(() => layout = result);
    widget.onCatalogSaved?.call(result);
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: widget.profile == null
            ? const Color(0xFFF2F6FC)
            : AsoudColors.background,
        appBar: AppBar(
          toolbarHeight: 52,
          titleSpacing: widget.profile == null ? 16 : null,
          automaticallyImplyLeading: false,
          centerTitle: false,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: widget.profile == null
              ? const _NewProfileBrand()
              : const Row(children: [
                  AsoudIconBox(
                      icon: Icons.layers_outlined, color: AsoudColors.primary),
                  SizedBox(width: 8),
                  Text('آسود ERP',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ]),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AsoudColors.border),
          ),
        ),
        body: Form(
            key: form,
            child: ListView(
                padding: EdgeInsets.fromLTRB(widget.profile == null ? 18 : 12,
                    7, widget.profile == null ? 18 : 12, 12),
                children: [
                  Row(children: [
                    IconButton.outlined(
                      tooltip: 'بازگشت',
                      onPressed:
                          busy ? null : () => Navigator.maybePop(context),
                      style: widget.profile == null
                          ? IconButton.styleFrom(
                              foregroundColor: AsoudColors.primary,
                              backgroundColor: Colors.white,
                              minimumSize: const Size.square(38),
                              padding: EdgeInsets.zero,
                              side: const BorderSide(color: Color(0xFFD4E1F5)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11)),
                            )
                          : null,
                      icon: Icon(Icons.arrow_forward,
                          size: widget.profile == null ? 14 : 17),
                    ),
                    const SizedBox(width: 8),
                    const Text('پروفایل‌های دسترسی',
                        style:
                            TextStyle(color: AsoudColors.muted, fontSize: 11)),
                  ]),
                  const SizedBox(height: 9),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: widget.profile == null ? 13 : 12),
                    decoration: BoxDecoration(
                      color: widget.profile == null
                          ? const Color(0xFFE8F0FE)
                          : AsoudColors.primary.withValues(alpha: .07),
                      border: Border.all(
                          color: AsoudColors.primary.withValues(alpha: .15)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              widget.profile == null
                                  ? 'پروفایل جدید'
                                  : readonly
                                      ? 'مشاهده پروفایل'
                                      : 'ویرایش پروفایل',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 17)),
                          if (widget.profile == null) const SizedBox(height: 3),
                          Text(
                              widget.profile == null
                                  ? 'یک الگوی مجوز برای استفاده در چند حساب بسازید.'
                                  : '${widget.profile!['title']}',
                              style: const TextStyle(
                                  color: AsoudColors.muted, fontSize: 11)),
                        ]),
                  ),
                  const SizedBox(height: 11),
                  _profilePanel(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ProfileSectionTitle(
                          'مشخصات پروفایل', Icons.badge_outlined),
                      const SizedBox(height: 8),
                      _ProfileField(
                          label: widget.profile == null
                              ? 'نام پروفایل'
                              : 'نام پروفایل *',
                          controller: title,
                          enabled: !readonly && !busy,
                          hint: widget.profile == null
                              ? 'مثلاً حسابدار'
                              : 'نام پروفایل را وارد کنید',
                          compact: widget.profile == null,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'نام پروفایل را وارد کنید.'
                              : null),
                      const SizedBox(height: 8),
                      _ProfileField(
                          label: 'توضیحات (اختیاری)',
                          controller: description,
                          enabled: !readonly && !busy,
                          hint: 'کاربرد این پروفایل',
                          compact: widget.profile == null,
                          minLines: 2,
                          maxLines: 4),
                    ],
                  )),
                  const SizedBox(height: 9),
                  if (readonly)
                    const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                            'دفتر این پروفایل قدیمی هنوز مشخص نشده است؛ هیچ مجوزی تغییر نمی‌کند.')),
                  if (widget.profile != null &&
                      layout?['editable'] == true) ...[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : manageCatalog,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('مدیریت کاتالوگ مشترک'),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  AccessPermissionMatrix(
                      catalog: widget.catalog,
                      catalogAction: widget.profile == null &&
                              layout?['editable'] == true
                          ? TextButton.icon(
                              onPressed: busy ? null : manageCatalog,
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              label: const Text('مدیریت کاتالوگ مشترک'),
                            )
                          : null,
                      layout: layout,
                      grants: grants,
                      enabled: !readonly && !busy,
                      onChanged: () => setState(() {})),
                  if (error != null)
                    Text(error!,
                        style: const TextStyle(color: AsoudColors.danger)),
                ])),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(children: [
                  Expanded(
                      child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AsoudColors.primary,
                              minimumSize: const Size(0, 46),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          onPressed: busy || readonly ? null : save,
                          child:
                              Text(busy ? 'در حال ذخیره…' : 'ذخیره پروفایل'))),
                  const SizedBox(width: 12),
                  OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(74, 46),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontSize: 12)),
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text('انصراف')),
                ]))),
      ));
}

class _NewProfileBrand extends StatelessWidget {
  const _NewProfileBrand();

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF1855D7),
            borderRadius: BorderRadius.circular(9),
          ),
          child:
              const Icon(Icons.layers_outlined, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 6),
        const Text.rich(
            TextSpan(text: 'آسود ', children: [
              TextSpan(
                  text: 'ERP',
                  style: TextStyle(color: Color(0xFF1855D7), fontSize: 10)),
            ]),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AsoudColors.text)),
        const Spacer(),
        const DecoratedBox(
          decoration: ShapeDecoration(
            shape: StadiumBorder(side: BorderSide(color: Color(0xFFD4E1F5))),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text('مدیریت دسترسی',
                style: TextStyle(fontSize: 9, color: AsoudColors.muted)),
          ),
        ),
      ]);
}

Widget _profilePanel(Widget child) => Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AsoudColors.border)),
      child: Padding(padding: const EdgeInsets.all(10), child: child),
    );

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle(this.title, this.icon);
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
                color: AsoudColors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, size: 16, color: AsoudColors.primary)),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      ]);
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.hint,
    this.validator,
    this.minLines = 1,
    this.maxLines = 1,
    this.compact = false,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String hint;
  final String? Function(String?)? validator;
  final int minLines;
  final int maxLines;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label,
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          TextFormField(
            controller: controller,
            enabled: enabled,
            minLines: minLines,
            maxLines: maxLines,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: compact
                  ? const TextStyle(color: Color(0xFF7789A6), fontSize: 12)
                  : null,
              filled: compact ? true : null,
              fillColor: compact ? Colors.white : null,
              isDense: true,
              enabledBorder: compact
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFD4E1F5)),
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            validator: validator,
          ),
        ],
      );
}

class AccessPermissionMatrix extends StatelessWidget {
  const AccessPermissionMatrix(
      {required this.catalog,
      required this.grants,
      required this.onChanged,
      this.enabled = true,
      this.layout,
      this.catalogAction,
      super.key});
  final List<AccessMap> catalog;
  final AccessMap? layout;
  final Widget? catalogAction;
  final Map<String, List<String>> grants;
  final VoidCallback onChanged;
  final bool enabled;
  static const actions = {
    'read': 'مشاهده',
    'create': 'ثبت',
    'write': 'ویرایش',
    'delete': 'حذف'
  };
  Widget permissionRow(String key, String title, List<dynamic> allowed) =>
      Container(
          constraints: const BoxConstraints(minHeight: 44),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AsoudColors.border))),
          child: Row(children: [
            Expanded(
                child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                        end: 4, top: 5, bottom: 5),
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)))),
            for (final action in actions.keys)
              SizedBox(
                  width: 38,
                  child: !allowed.contains(action)
                      ? const Center(
                          child: Text('—', style: TextStyle(fontSize: 15)))
                      : Checkbox(
                          key: ValueKey('grant:$key:$action'),
                          value: grants[key]?.contains(action) == true,
                          activeColor: AsoudColors.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity:
                              const VisualDensity(horizontal: -2, vertical: -2),
                          onChanged: !enabled
                              ? null
                              : (value) {
                                  final selected = <String>{
                                    ...grants[key] ?? []
                                  };
                                  if (value == true) {
                                    selected.add(action);
                                  } else {
                                    selected.remove(action);
                                  }
                                  grants[key] = selected.toList();
                                  onChanged();
                                })),
          ]));

  Widget _resource(AccessMap row) {
    final key = '${row['doctype']}';
    final details = accessRows(row['details']);
    final cells = permissionRow(key, '${row['title']}', row['actions'] as List);
    if (details.isEmpty) return cells;
    return ExpansionTile(
      key: PageStorageKey('permission-details:$key'),
      title: cells,
      tilePadding: const EdgeInsetsDirectional.only(end: 2),
      minTileHeight: 44,
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        for (final detail in details)
          permissionRow('$key::${detail['level']}', '${detail['title']}',
              detail['actions'] as List),
      ],
    );
  }

  Widget _configuredDocument(AccessMap doc, Map<String, AccessMap> native) {
    final id = '${doc['id']}';
    final row = native[id];
    final cells = permissionRow('${row?['doctype'] ?? id}', '${doc['title']}',
        (row?['actions'] as List?) ?? const []);
    final details = accessRows(doc['children']);
    if (details.isEmpty) return cells;
    return ExpansionTile(
      key: PageStorageKey('permission-details:$id'),
      title: cells,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      minTileHeight: 44,
      children: [
        for (final detail in details)
          permissionRow('${detail['id']}', '${detail['title']}', const []),
      ],
    );
  }

  Widget _configuredModule(
      AccessMap module, int index, Map<String, AccessMap> native) {
    final color = profileAccent(index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ExpansionTile(
        key: PageStorageKey('catalog-module:${module['id']}'),
        minTileHeight: 44,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        collapsedBackgroundColor: color.withValues(alpha: .09),
        backgroundColor: color.withValues(alpha: .05),
        textColor: color,
        collapsedTextColor: color,
        iconColor: color,
        collapsedIconColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        title: Text('${module['title']}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        children: [
          for (final doc in accessRows(module['children']))
            _configuredDocument(doc, native),
          if (accessRows(module['children']).isEmpty)
            const Padding(
                padding: EdgeInsets.all(8),
                child: Text('هنوز سندی اضافه نشده است.')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modules = <String, List<AccessMap>>{};
    final tree = accessRows(layout?['modules']);
    final native = {for (final row in catalog) 'native:${row['doctype']}': row};
    for (final row in catalog) {
      modules.putIfAbsent('${row['module']}', () => []).add(row);
    }
    return _profilePanel(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _ProfileSectionTitle('مجوزها', Icons.verified_user_outlined),
      if (catalogAction != null)
        Align(
            alignment: AlignmentDirectional.centerStart, child: catalogAction!),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 5),
        child: Text('ثبت یعنی ایجاد رکورد؛ نه تأیید نهایی.',
            style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
      ),
      Row(children: [
        const Expanded(
            child: Text('ماژول / سند', style: TextStyle(fontSize: 13))),
        for (final title in actions.values)
          SizedBox(
              width: 38,
              child: Center(
                  child: Text(title, style: const TextStyle(fontSize: 11))))
      ]),
      const Divider(height: 8, color: AsoudColors.border),
      if (layout != null) ...[
        for (final (index, module) in tree.indexed)
          _configuredModule(module, index, native),
        if (tree.isEmpty) const Text('هنوز ماژولی در کاتالوگ ثبت نشده است.'),
      ] else
        for (final (index, module) in modules.entries.indexed)
          Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ExpansionTile(
                  collapsedBackgroundColor:
                      profileAccent(index).withValues(alpha: .09),
                  backgroundColor: profileAccent(index).withValues(alpha: .06),
                  textColor: profileAccent(index),
                  iconColor: profileAccent(index),
                  collapsedIconColor: profileAccent(index),
                  key: PageStorageKey('module:${module.key}'),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  clipBehavior: Clip.antiAlias,
                  minTileHeight: 44,
                  title: Text(module.key,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  children: [
                    for (final row in module.value
                        .where((r) => '${r['group'] ?? ''}'.isEmpty))
                      _resource(row),
                    for (final group in module.value
                        .map((r) => '${r['group'] ?? ''}')
                        .where((group) => group.isNotEmpty)
                        .toSet())
                      ExpansionTile(
                          key: PageStorageKey('${module.key}:$group'),
                          tilePadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          backgroundColor: Colors.white,
                          minTileHeight: 42,
                          title: Text(group,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                          children: [
                            for (final row in module.value
                                .where((r) => '${r['group'] ?? ''}' == group))
                              _resource(row),
                          ]),
                  ])),
    ]));
  }
}
