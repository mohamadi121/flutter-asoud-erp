import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xls;
import '../../../../core/network/frappe_client.dart';
import '../../../../core/offline/local_database_store.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../parties/domain/repositories/party_repository.dart';
import '../../../parties/domain/entities/party_profile.dart';
import '../../data/organization_repository.dart';
import '../../domain/organization_chart.dart';
import '../cubit/organization_cubit.dart';

class OrganizationPage extends StatelessWidget {
  const OrganizationPage({required this.company, super.key});
  final String company;
  @override
  Widget build(BuildContext context) => BlocProvider(
      create: (_) => OrganizationCubit(
          OrganizationRepository(context.read<FrappeApiClient>()), company)
        ..load(),
      child: _OrganizationView(company: company));
}

class _OrganizationView extends StatelessWidget {
  const _OrganizationView({required this.company});
  final String company;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
            title: 'ساختار سازمانی',
            subtitle: 'جایگاه‌ها، بالادست و انتصاب پرسنل'),
        body: BlocBuilder<OrganizationCubit, OrganizationState>(
            builder: (context, state) {
          final cubit = context.read<OrganizationCubit>();
          final rows = state.snapshot.rows;
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (state.busy) const LinearProgressIndicator(),
            if (state.error != null)
              Text(state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (state.snapshot.pending)
              const Text(
                  'پیش‌نویس روی گوشی ذخیره شده؛ برای ارسال به سرور «همگام‌سازی» را بزنید.'),
            const Text(
                'هر جایگاه می‌تواند خالی باشد. بالادست سازمانی به‌تنهایی دسترسی کاربری ایجاد نمی‌کند.'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(
                  onPressed: state.busy
                      ? null
                      : () =>
                          _preview(context, [...rows, ...standardOrganization]),
                  child: const Text('قالب آماده')),
              OutlinedButton(
                  onPressed: state.busy ? null : () => _excel(context, rows),
                  child: const Text('ورود اکسل')),
              OutlinedButton(
                  onPressed: state.busy ? null : cubit.load,
                  child: const Text('بازخوانی')),
              if (state.snapshot.pending)
                OutlinedButton(
                    onPressed: state.busy ? null : () => cubit.save(rows),
                    child: const Text('همگام‌سازی')),
            ]),
            const Text(
                'ستون‌های اکسل: code، title، parent، department، employee. کد بالادست و شناسه پرسنل اختیاری هستند.'),
            const SizedBox(height: 16),
            if (rows.isEmpty && !state.busy)
              const Text('هنوز جایگاهی تعریف نشده است.'),
            ..._tree(context, rows, '', 0, state.busy),
            const SizedBox(height: 20),
            FilledButton.icon(
                onPressed: state.busy ? null : () => _edit(context, rows),
                icon: const Icon(Icons.add),
                label: const Text('افزودن جایگاه')),
          ]);
        }),
      );
  List<Widget> _tree(BuildContext context, List<OrgPosition> rows,
          String parent, int depth, bool busy) =>
      [
        for (final item in rows.where((e) => e.parent == parent)) ...[
          Padding(
              padding: EdgeInsetsDirectional.only(
                  start: (depth.clamp(0, 5) * 12).toDouble(), bottom: 8),
              child: Card(
                  child: ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: Text(item.title),
                subtitle: Text(
                    '${item.department}\n${item.employee.isEmpty ? 'جایگاه خالی' : 'پرسنل: ${item.employee}'}'),
                trailing: PopupMenuButton<String>(
                  enabled: !busy,
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _edit(context, rows, item);
                      return;
                    }
                    if (rows.any((e) => e.parent == item.code) ||
                        item.employee.isNotEmpty) {
                      _message(context,
                          'ابتدا زیرمجموعه‌ها و انتصاب پرسنل را تغییر دهید.');
                      return;
                    }
                    final yes = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                                title: const Text('حذف جایگاه'),
                                content:
                                    Text('جایگاه «${item.title}» حذف شود؟'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('انصراف')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('حذف'))
                                ]));
                    if (yes == true && context.mounted) {
                      await context.read<OrganizationCubit>().save(
                          rows.where((e) => e.code != item.code).toList());
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                    PopupMenuItem(value: 'delete', child: Text('حذف'))
                  ],
                ),
              ))),
          ..._tree(context, rows, item.code, depth + 1, busy),
        ],
      ];
  void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _preview(
      BuildContext context, List<OrgPosition> candidate) async {
    try {
      validateOrganization(candidate);
    } on FormatException catch (e) {
      _message(context, e.message);
      return;
    }
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('پیش‌نمایش ساختار'),
                content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final row in candidate)
                        ListTile(
                            title: Text(row.title),
                            subtitle: Text(
                                '${row.code} ← ${row.parent.isEmpty ? 'ریشه' : row.parent}')),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('انصراف')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('تأیید و ذخیره'))
                ]));
    if (confirmed == true && context.mounted) {
      await context.read<OrganizationCubit>().save(candidate);
    }
  }

  Future<void> _excel(BuildContext context, List<OrgPosition> rows) async {
    try {
      final file = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
      if (file == null || !context.mounted) return;
      final data = file.files.single.bytes;
      if (data == null) throw const FormatException('خواندن فایل ممکن نشد.');
      final workbook = xls.Excel.decodeBytes(data);
      final table = workbook.tables.values.first.rows;
      if (table.isEmpty) throw const FormatException('فایل خالی است.');
      final headers =
          table.first.map((e) => e?.value.toString().trim() ?? '').toList();
      if (!headers.contains('code') || !headers.contains('title')) {
        throw const FormatException('ستون‌های code و title الزامی هستند.');
      }
      final imported = <OrgPosition>[];
      for (final row in table.skip(1)) {
        if (row.every(
            (cell) => cell == null || cell.value.toString().trim().isEmpty)) {
          continue;
        }
        final record = <String, dynamic>{};
        for (var i = 0; i < headers.length; i++) {
          record[headers[i]] =
              i < row.length ? row[i]?.value.toString() ?? '' : '';
        }
        imported.add(OrgPosition.fromJson(record));
      }
      await _preview(context, [...rows, ...imported]);
    } catch (e) {
      if (context.mounted) {
        _message(context,
            e is FormatException ? e.message : 'فایل اکسل قابل پردازش نیست.');
      }
    }
  }

  Future<void> _edit(BuildContext context, List<OrgPosition> rows,
      [OrgPosition? item]) async {
    final code = TextEditingController(text: item?.code);
    final title = TextEditingController(text: item?.title);
    final department = TextEditingController(text: item?.department);
    var parent = item?.parent ?? '';
    var employee = item?.employee ?? '';
    List<PartyProfile> people = [];
    final cachedPeople =
        await LocalDatabaseStore.instance.list(entityType: 'party_profile');
    people = cachedPeople
        .where((record) =>
            record.payload['company'] == company &&
            record.payload['disabled'] != true &&
            (record.payload['roles'] as List? ?? []).contains('employee'))
        .map((record) => PartyProfile(
              id: record.payload['id']?.toString(),
              company: company,
              kind: PartyKind.individual,
              displayName: record.payload['display_name']?.toString() ?? '',
              roles: const {PartyRole.employee},
            ))
        .where((person) => person.id?.isNotEmpty == true)
        .toList();
    try {
      if (people.isEmpty && context.mounted) {
        people = await context
            .read<PartyRepository>()
            .list(company: company, role: PartyRole.employee)
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      if (context.mounted) {
        _message(context,
            'فهرست پرسنل در دسترس نیست؛ می‌توانید جایگاه خالی بسازید.');
      }
    }
    if (!context.mounted) {
      code.dispose();
      title.dispose();
      department.dispose();
      return;
    }
    final choice = await showDialog<OrgPosition>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, setState) => AlertDialog(
                  title: Text(item == null ? 'افزودن جایگاه' : 'ویرایش جایگاه'),
                  scrollable: true,
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: code,
                        enabled: item == null,
                        decoration:
                            const InputDecoration(labelText: 'کد جایگاه')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: title,
                        decoration:
                            const InputDecoration(labelText: 'عنوان جایگاه')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: department,
                        decoration:
                            const InputDecoration(labelText: 'واحد سازمانی')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        initialValue: parent,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'جایگاه بالادست'),
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('بدون بالادست')),
                          ...rows.where((e) => e.code != item?.code).map((e) =>
                              DropdownMenuItem(
                                  value: e.code, child: Text(e.title)))
                        ],
                        onChanged: (v) => parent = v ?? ''),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        initialValue: employee,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'پرسنل'),
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('جایگاه خالی')),
                          if (employee.isNotEmpty &&
                              !people.any((e) => e.id == employee))
                            DropdownMenuItem(
                                value: employee, child: Text(employee)),
                          ...people.map((e) => DropdownMenuItem(
                              value: e.id, child: Text(e.displayName)))
                        ],
                        onChanged: (v) => employee = v ?? ''),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('انصراف')),
                    TextButton(
                        onPressed: () {
                          final result = OrgPosition(
                              code: code.text.trim(),
                              title: title.text.trim(),
                              parent: parent,
                              department: department.text.trim(),
                              employee: employee);
                          try {
                            validateOrganization([
                              ...rows.where((e) => e.code != item?.code),
                              result
                            ]);
                          } on FormatException catch (e) {
                            _message(context, e.message);
                            return;
                          }
                          Navigator.pop(c, result);
                        },
                        child: const Text('ذخیره'))
                  ],
                )));
    code.dispose();
    title.dispose();
    department.dispose();
    if (choice != null && context.mounted) {
      await context
          .read<OrganizationCubit>()
          .save([...rows.where((e) => e.code != item?.code), choice]);
    }
  }
}
