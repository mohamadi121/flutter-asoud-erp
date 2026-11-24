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
                profile: profile, example: example)));
    if (saved == true && mounted) {
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('پروفایل ذخیره شد.')));
      }
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
                      label: const Text('پروفایل جدید')),
                  const SizedBox(height: 12),
                  for (final example in examples) TextButton.icon(
                      onPressed: () => edit(null, example), icon: const Icon(Icons.auto_awesome_outlined),
                      label: Text('شروع با الگوی ${example['title']}')),
                  for (final p in profiles)
                    Card(
                        child: ListTile(
                            leading: Icon(
                                p['readonly'] == true
                                    ? Icons.lock_outline
                                    : Icons.badge_outlined,
                                color: AsoudColors.primary),
                            title: Text('${p['title']}'),
                            subtitle: Text(p['readonly'] == true
                                ? 'پروفایل قدیمی بدون دفتر؛ فقط مشاهده'
                                : '${p['description'] ?? ''}'),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => edit(p))),
                  if (profiles.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('هنوز پروفایلی در این دفتر ثبت نشده است.')),
                ],
              ]),
      ));
}

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
  late final title =
      TextEditingController(text: (widget.profile?['title'] ?? widget.example?['title']) as String? ?? '');
  late final description = TextEditingController(
      text: (widget.profile?['description'] ?? widget.example?['description']) as String? ?? '');
  late final grants = accessGrants(widget.profile?['grants'] ?? widget.example?['grants']);
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
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        TextFormField(
                            controller: title,
                            enabled: !readonly && !busy,
                            decoration: const InputDecoration(
                                labelText: 'نام پروفایل *'),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'نام پروفایل را وارد کنید.'
                                : null),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: description,
                            enabled: !readonly && !busy,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'توضیحات (اختیاری)')),
                      ]))),
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
                Text(error!, style: const TextStyle(color: AsoudColors.danger)),
            ])),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                      child: FilledButton(
                          onPressed: busy || readonly ? null : save,
                          child:
                              Text(busy ? 'در حال ذخیره…' : 'ذخیره پروفایل'))),
                  const SizedBox(width: 8),
                  OutlinedButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text('انصراف')),
                ]))),
      ));
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
      Row(children: [
        Expanded(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(title, style: const TextStyle(fontSize: 11)))),
        for (final action in actions.keys)
          SizedBox(
              width: 38,
              child: !allowed.contains(action)
                  ? const Center(child: Text('—'))
                  : Checkbox(
                      key: ValueKey('grant:$key:$action'),
                      value: grants[key]?.contains(action) == true,
                      visualDensity: VisualDensity.compact,
                      onChanged: !enabled
                          ? null
                          : (value) {
                              final selected = <String>{...grants[key] ?? []};
                              if (value == true) {
                                selected.add(action);
                              } else {
                                selected.remove(action);
                              }
                              grants[key] = selected.toList();
                              onChanged();
                            })),
      ]);
  @override
  Widget build(BuildContext context) {
    final modules = <String, List<AccessMap>>{};
    for (final row in catalog) {
      modules.putIfAbsent('${row['module']}', () => []).add(row);
    }
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              const Align(
                  alignment: Alignment.centerRight,
                  child: Text('مجوزها',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Row(children: [
                const Expanded(
                    child: Text('ماژول / سند', style: TextStyle(fontSize: 10))),
                for (final title in actions.values)
                  SizedBox(
                      width: 38,
                      child: Center(
                          child:
                              Text(title, style: const TextStyle(fontSize: 9))))
              ]),
              const Divider(),
              for (final module in modules.entries)
                ExpansionTile(
                    key: PageStorageKey('module:${module.key}'),
                    tilePadding: EdgeInsets.zero,
                    title:
                        Text(module.key, style: const TextStyle(fontSize: 13)),
                    children: [
                      for (final group in module.value
                          .map((r) => '${r['group'] ?? ''}')
                          .toSet())
                        ExpansionTile(
                            key: PageStorageKey('${module.key}:$group'),
                            tilePadding: EdgeInsets.zero,
                            title: Text(group.isEmpty ? module.key : group,
                                style: const TextStyle(fontSize: 12)),
                            children: [
                              for (final row in module.value.where(
                                  (r) => '${r['group'] ?? ''}' == group)) ...[
                                permissionRow('${row['doctype']}',
                                    '${row['title']}', row['actions'] as List),
                                if (accessRows(row['details']).isNotEmpty)
                                  ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      title: const Text('جزئیات',
                                          style: TextStyle(fontSize: 11)),
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
