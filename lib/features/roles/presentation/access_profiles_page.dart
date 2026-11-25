import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/theme/asoud_colors.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/widgets/asoud_ui.dart';
import '../data/access_management_repository.dart';

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
  List<AccessMap> profiles = [], catalog = [], examples = [];
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
          examples = accessRows(data['examples']);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([AccessMap? profile, AccessMap? example]) async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => AccessProfileEditor(
                company: widget.company,
                repository: repo,
                catalog: catalog,
                profile: profile,
                example: example)));
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
                  for (final example in examples)
                    TextButton.icon(
                        onPressed: () => edit(null, example),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: Text('شروع با الگوی ${example['title']}')),
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
                            trailing: p['readonly'] == true
                                ? const Icon(Icons.chevron_left)
                                : PopupMenuButton<String>(
                                    tooltip: 'گزینه‌های پروفایل',
                                    onSelected: (_) => remove(p),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
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
      super.key});
  final String company;
  final AccessManagementRepository repository;
  final List<AccessMap> catalog;
  final AccessMap? profile;
  final AccessMap? example;
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

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AsoudColors.background,
        appBar: AsoudHeader(
            title: widget.profile == null ? 'پروفایل جدید' : 'ویرایش پروفایل'),
        body: Form(
            key: form,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  _ProfileFieldCard(
                      label: 'نام پروفایل *',
                      controller: title,
                      enabled: !readonly && !busy,
                      hint: 'نام پروفایل را وارد کنید',
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'نام پروفایل را وارد کنید.'
                          : null),
                  const SizedBox(height: 12),
                  _ProfileFieldCard(
                      label: 'توضیحات (اختیاری)',
                      controller: description,
                      enabled: !readonly && !busy,
                      hint: 'توضیحات (اختیاری)',
                      minLines: 3,
                      maxLines: 4),
                  if (readonly)
                    const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                            'دفتر این پروفایل قدیمی هنوز مشخص نشده است؛ هیچ مجوزی تغییر نمی‌کند.')),
                  AccessPermissionMatrix(
                      catalog: widget.catalog,
                      grants: grants,
                      enabled: !readonly && !busy,
                      onChanged: () => setState(() {})),
                  if (error != null)
                    Text(error!,
                        style: const TextStyle(color: AsoudColors.danger)),
                ])),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Row(children: [
                  Expanded(
                      child: FilledButton(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 60),
                              textStyle: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700)),
                          onPressed: busy || readonly ? null : save,
                          child:
                              Text(busy ? 'در حال ذخیره…' : 'ذخیره پروفایل'))),
                  const SizedBox(width: 12),
                  OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(112, 60),
                          textStyle: const TextStyle(fontSize: 16)),
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text('انصراف')),
                ]))),
      ));
}

class _ProfileFieldCard extends StatelessWidget {
  const _ProfileFieldCard({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.hint,
    this.validator,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String hint;
  final String? Function(String?)? validator;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(label,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              TextFormField(
                controller: controller,
                enabled: enabled,
                minLines: minLines,
                maxLines: maxLines,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(
                  hintText: hint,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 18, vertical: maxLines == 1 ? 22 : 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                validator: validator,
              ),
            ],
          ),
        ),
      );
}

class AccessPermissionMatrix extends StatelessWidget {
  const AccessPermissionMatrix(
      {required this.catalog,
      required this.grants,
      required this.onChanged,
      this.enabled = true,
      super.key});
  final List<AccessMap> catalog;
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
          constraints: const BoxConstraints(minHeight: 62),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AsoudColors.border))),
          child: Row(children: [
            Expanded(
                child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                        end: 8, top: 12, bottom: 12),
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14)))),
            for (final action in actions.keys)
              SizedBox(
                  width: 42,
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
                              const VisualDensity(horizontal: -1, vertical: -1),
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
  @override
  Widget build(BuildContext context) {
    final modules = <String, List<AccessMap>>{};
    for (final row in catalog) {
      modules.putIfAbsent('${row['module']}', () => []).add(row);
    }
    return Card(
        color: AsoudColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AsoudColors.border),
        ),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(children: [
              const Align(
                  alignment: Alignment.centerRight,
                  child: Text('مجوزها',
                      style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.bold))),
              const SizedBox(height: 14),
              Row(children: [
                const Expanded(
                    child: Text('ماژول / سند', style: TextStyle(fontSize: 13))),
                for (final title in actions.values)
                  SizedBox(
                      width: 42,
                      child: Center(
                          child: Text(title,
                              style: const TextStyle(fontSize: 11))))
              ]),
              const Divider(height: 24),
              for (final (index, module) in modules.entries.indexed)
                ExpansionTile(
                    collapsedBackgroundColor:
                        profileAccent(index).withValues(alpha: .08),
                    backgroundColor:
                        profileAccent(index).withValues(alpha: .04),
                    textColor: profileAccent(index),
                    iconColor: profileAccent(index),
                    collapsedIconColor: profileAccent(index),
                    key: PageStorageKey('module:${module.key}'),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    minTileHeight: 66,
                    title: Text(module.key,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    children: [
                      for (final group in module.value
                          .map((r) => '${r['group'] ?? ''}')
                          .toSet())
                        ExpansionTile(
                            key: PageStorageKey('${module.key}:$group'),
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            minTileHeight: 60,
                            title: Text(group.isEmpty ? module.key : group,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                            children: [
                              for (final row in module.value.where(
                                  (r) => '${r['group'] ?? ''}' == group)) ...[
                                permissionRow('${row['doctype']}',
                                    '${row['title']}', row['actions'] as List),
                                if (accessRows(row['details']).isNotEmpty)
                                  ExpansionTile(
                                      tilePadding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      minTileHeight: 56,
                                      title: const Text('جزئیات',
                                          style: TextStyle(fontSize: 14)),
                                      children: [
                                        for (final detail
                                            in accessRows(row['details']))
                                          permissionRow(
                                              '${row['doctype']}::${detail['level']}',
                                              '${detail['title']}',
                                              detail['actions'] as List),
                                      ]),
                              ],
                            ]),
                    ]),
            ])));
  }
}
