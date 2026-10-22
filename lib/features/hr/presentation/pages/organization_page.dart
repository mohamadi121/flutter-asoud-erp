import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xls;

import '../../../../core/auth/access_denied.dart';
import '../../../../core/auth/capabilities.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/organization_repository.dart';
import '../../domain/organization_chart.dart';
import '../../domain/organization_templates.dart';
import '../cubit/organization_cubit.dart';

part 'organization_chart_view.dart';
part 'organization_position_form.dart';
part 'organization_workspace.dart';
part 'organization_visual_report.dart';

String _assignmentDate(dynamic value) => value == null
    ? 'نامشخص (سابقه قبلی)'
    : formatJalaliDateTimeIso(value.toString());

class OrganizationPage extends StatelessWidget {
  const OrganizationPage({required this.company, this.repository, super.key});
  final String company;
  final OrganizationRepository? repository;

  @override
  Widget build(BuildContext context) => FutureBuilder<Capabilities>(
        future: capabilitiesOf(context),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final capabilities = snapshot.data!;
          if (!capabilities.canReadOrganization) {
            return const AccessDeniedScaffold();
          }
          return BlocProvider(
            create: (_) => OrganizationCubit(
                repository ??
                    OrganizationRepository(context.read<FrappeApiClient>()),
                company)
              ..load(),
            child: Directionality(
                textDirection: TextDirection.rtl,
                child: _OrganizationSessionGuard(
                    child: _OrganizationEntry(
                        canManage: capabilities.canManageOrganization))),
          );
        },
      );
}

Future<T?> _openOrganizationPage<T>(BuildContext context, Widget page) {
  final cubit = context.read<OrganizationCubit>();
  return Navigator.of(context).push<T>(MaterialPageRoute<T>(
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: _OrganizationSessionGuard(child: page)),
    ),
  ));
}

class _OrganizationSessionGuard extends StatelessWidget {
  const _OrganizationSessionGuard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      BlocConsumer<OrganizationCubit, OrganizationState>(
        listenWhen: (before, after) =>
            !before.sessionChanged && after.sessionChanged,
        listener: (context, state) =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        builder: (context, state) => state.sessionChanged
            ? const Scaffold(
                body: Center(child: Text('نشست تغییر کرده؛ دوباره وارد شوید.')))
            : child,
      );
}

void _orgMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class _OrganizationEntry extends StatefulWidget {
  const _OrganizationEntry({required this.canManage});
  final bool canManage;
  @override
  State<_OrganizationEntry> createState() => _OrganizationEntryState();
}

class _OrganizationEntryState extends State<_OrganizationEntry> {
  late Future<Map<String, dynamic>> units;
  @override
  void initState() {
    super.initState();
    final c = context.read<OrganizationCubit>();
    units = c.repository.units(c.company);
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<OrganizationCubit,
          OrganizationState>(
      listenWhen: (before, after) =>
          before.busy && !after.busy && after.error == null,
      listener: (context, state) {
        final c = context.read<OrganizationCubit>();
        final pendingUnits = c.repository.units(c.company);
        setState(() {
          units = pendingUnits;
        });
      },
      builder: (context, state) => FutureBuilder<Map<String, dynamic>>(
          future: units,
          builder: (context, snapshot) {
            if (state.snapshot.rows.isNotEmpty ||
                (snapshot.data?['units'] as List? ?? []).isNotEmpty ||
                !widget.canManage) {
              return _OrganizationWorkspace(canManage: widget.canManage);
            }
            if (state.busy ||
                snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError || state.error != null) {
              if (state.error != null) {
                return const Scaffold(
                    appBar: AsoudHeader(title: 'ساختار سازمانی'),
                    body: SingleChildScrollView(child: _OrganizationStatus()));
              }
              return Scaffold(
                  appBar: const AsoudHeader(title: 'ساختار سازمانی'),
                  body: Center(
                      child: TextButton(
                          onPressed: () {
                            final c = context.read<OrganizationCubit>();
                            final pendingUnits = c.repository.units(c.company);
                            setState(() {
                              units = pendingUnits;
                            });
                            c.load();
                          },
                          child: const Text(
                              'دریافت ساختار ناموفق بود؛ تلاش دوباره'))));
            }
            return _OrganizationSetup(canManage: widget.canManage);
          }));
}

class _OrganizationSetup extends StatelessWidget {
  const _OrganizationSetup({this.canManage = true});

  /// Read-only roles (HR User) keep the chart but no create/import entry.
  final bool canManage;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
            title: 'ایجاد ساختار سازمانی',
            subtitle: 'روش ایجاد ساختار سازمانی را انتخاب کنید'),
        body: SafeArea(
            child: BlocBuilder<OrganizationCubit, OrganizationState>(
          builder: (context, state) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const _OrganizationStatus(),
              if (canManage) const SizedBox(height: 18),
              if (canManage)
                Card(
                    child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: state.busy
                      ? null
                      : () => _openOrganizationPage<void>(
                          context, const _OrganizationTemplates()),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(children: [
                      AsoudIconBox(
                          icon: Icons.account_tree_outlined,
                          color: AsoudColors.primary,
                          size: 38),
                      SizedBox(width: 10),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('استفاده از قالب آماده',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                          SizedBox(height: 4),
                          Text(
                              'قالب‌های بازرگانی، تولیدی، خدماتی، پیمانکاری و فناوری',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xff526079))),
                        ],
                      )),
                      SizedBox(width: 6),
                      Icon(Icons.chevron_left_rounded,
                          color: AsoudColors.primary),
                    ]),
                  ),
                )),
              if (canManage) const SizedBox(height: 12),
              if (canManage)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: _OrgChoice(
                    icon: Icons.add_rounded,
                    color: AsoudColors.success,
                    title: 'ایجاد ساختار دستی',
                    subtitle: 'تعریف واحدها، زیرواحدها و جایگاه‌های شغلی',
                    action: 'شروع ایجاد ساختار',
                    onTap: state.busy
                        ? null
                        : () => _openOrganizationPage<void>(context,
                            const _OrganizationWorkspace(canManage: true)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _OrgChoice(
                    icon: Icons.upload_file_rounded,
                    color: AsoudColors.warning,
                    title: 'ورود از اکسل',
                    subtitle: 'ساختار سازمانی را از فایل اکسل وارد کنید',
                    action: 'انتخاب فایل اکسل',
                    secondary: TextButton.icon(
                        onPressed: state.busy
                            ? null
                            : () => _downloadOrganizationTemplate(context),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('دریافت الگوی اکسل',
                            style: TextStyle(fontSize: 10))),
                    onTap: state.busy ? null : () => _importExcel(context),
                  )),
                ]),
              const SizedBox(height: 28),
              const _OrgNotice(
                icon: Icons.visibility_outlined,
                title: 'پیش از ایجاد ساختار',
                color: AsoudColors.primary,
                text:
                    'قبل از ثبت نهایی، اطلاعات ساختار بررسی می‌شوند.\nجایگاه‌های شغلی می‌توانند بدون انتساب پرسنل ایجاد شوند. ایجاد ساختار به‌تنهایی دسترسی کاربری ایجاد نمی‌کند.',
              ),
            ],
          ),
        )),
      );

  Future<void> _importExcel(BuildContext context) async {
    final proceed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('ورود ساختار از اکسل'),
              content: const Text(
                  'فایل xlsx با ستون‌های code و title الزامی است. ستون‌های parent، department و employee اختیاری هستند. parent کد جایگاه بالادست و employee شناسه ثبت‌شده پرسنل است.\nردیف‌ها پس از پیش‌نمایش به ساختار فعلی اضافه می‌شوند؛ کد تکراری پذیرفته نمی‌شود.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('انصراف')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('انتخاب فایل')),
              ],
            ));
    if (proceed != true || !context.mounted) return;
    final cubit = context.read<OrganizationCubit>();
    List<OrgPosition> imported;
    List<Map<String, dynamic>> importedUnits = [];
    try {
      final file = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
      if (file == null || !context.mounted) return;
      final data = file.files.single.bytes;
      if (data == null) throw const FormatException('خواندن فایل ممکن نشد.');
      final workbook = xls.Excel.decodeBytes(data);
      final sheets =
          workbook.tables.values.where((sheet) => sheet.rows.isNotEmpty);
      if (sheets.isEmpty) throw const FormatException('فایل خالی است.');
      final table = (workbook.tables['positions'] ?? sheets.first).rows;
      final unitTable = workbook.tables['units']?.rows;
      if (unitTable != null && unitTable.length > 1) {
        final unitHeaders = unitTable.first
            .map((e) => e?.value.toString().trim().toLowerCase() ?? '')
            .toList();
        if (!unitHeaders.contains('code') ||
            !unitHeaders.contains('title') ||
            unitHeaders.where((h) => h.isNotEmpty).toSet().length !=
                unitHeaders.where((h) => h.isNotEmpty).length) {
          throw const FormatException(
              'ستون‌های واحدها باید code و title داشته باشند و تکراری نباشند.');
        }
        for (final cells in unitTable.skip(1)) {
          if (cells.every((c) => c?.value.toString().trim().isEmpty ?? true)) {
            continue;
          }
          importedUnits.add({
            for (var i = 0; i < unitHeaders.length; i++)
              if (unitHeaders[i].isNotEmpty)
                unitHeaders[i]: i < cells.length
                    ? cells[i]?.value.toString().trim() ?? ''
                    : ''
          });
        }
      }
      final headers = table.first
          .map((e) => e?.value.toString().trim().toLowerCase() ?? '')
          .toList();
      if (!headers.contains('code') || !headers.contains('title')) {
        throw const FormatException('ستون‌های code و title الزامی هستند.');
      }
      final names = headers.where((h) => h.isNotEmpty).toList();
      if (names.toSet().length != names.length) {
        throw const FormatException('نام ستون‌های فایل نباید تکراری باشد.');
      }
      imported = [];
      for (final row in table.skip(1)) {
        if (row
            .every((cell) => cell?.value.toString().trim().isEmpty ?? true)) {
          continue;
        }
        final record = <String, dynamic>{};
        for (var i = 0; i < headers.length; i++) {
          record[headers[i]] =
              i < row.length ? row[i]?.value.toString().trim() ?? '' : '';
        }
        if (record.containsKey('capacity')) {
          final capacity =
              int.tryParse(_normalizedOrgCode('${record['capacity']}'));
          if (capacity == null || capacity < 1) {
            throw const FormatException('ظرفیت اکسل باید عدد صحیح مثبت باشد.');
          }
          record['capacity'] = capacity;
          record['occupants'] = '${record['employee'] ?? ''}'.isEmpty
              ? <String>[]
              : ['${record['employee']}'];
        }
        imported.add(OrgPosition.fromJson(record));
      }
      if (imported.isEmpty && importedUnits.isEmpty) {
        throw const FormatException('فایل جایگاهی برای ورود ندارد.');
      }
      validateOrganization([...cubit.state.snapshot.rows, ...imported]);
    } catch (e) {
      if (context.mounted) {
        _orgMessage(context,
            e is FormatException ? e.message : 'فایل اکسل قابل پردازش نیست.');
      }
      return;
    }
    if (context.mounted) {
      if (importedUnits.isNotEmpty) {
        final saved = await _openOrganizationPage<bool>(
            context,
            _OrganizationImportReview(payload: {
              'units': importedUnits,
              'rows': imported.map((r) => r.toJson()).toList()
            }));
        if (saved == true && context.mounted) {
          _openOrganizationPage<void>(
              context, const _OrganizationWorkspace(canManage: true));
        }
        return;
      }
      final saved = await _openOrganizationPage<bool>(
          context,
          _OrganizationPreview(
              title: 'پیش‌نمایش ورود اکسل', additions: imported));
      if (saved == true && context.mounted) {
        _openOrganizationPage<void>(
            context, const _OrganizationWorkspace(canManage: true));
      }
    }
  }
}

Future<void> _downloadOrganizationTemplate(BuildContext context) async {
  try {
    final book = xls.Excel.createExcel();
    book.rename('Sheet1', 'positions');
    book['positions'].appendRow([
      for (final name in [
        'code',
        'title',
        'parent',
        'department_id',
        'capacity',
        'duties',
        'employee'
      ])
        xls.TextCellValue(name),
    ]);
    book['units'].appendRow([
      for (final name in ['code', 'title', 'parent', 'name', 'parent_id'])
        xls.TextCellValue(name),
    ]);
    final bytes = book.encode();
    if (bytes == null) throw StateError('Excel encode failed');
    await FilePicker.platform.saveFile(
        fileName: 'organization-template.xlsx',
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: ['xlsx']);
  } catch (_) {
    if (context.mounted) _orgMessage(context, 'ذخیره الگوی اکسل انجام نشد.');
  }
}

class _OrganizationStatus extends StatelessWidget {
  const _OrganizationStatus();
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OrganizationCubit, OrganizationState>(
        builder: (context, state) => Column(children: [
          for (final warning in state.snapshot.warnings)
            _OrgNotice(
                icon: Icons.warning_amber,
                color: AsoudColors.warning,
                text: warning),
          if (state.busy)
            const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator()),
          if (state.error != null)
            ErrorState(
                failure: state.error!,
                onRetry:
                    state.busy ? null : context.read<OrganizationCubit>().load),
          if (state.snapshot.pending) ...[
            const _OrgNotice(
                icon: Icons.cloud_off_outlined,
                color: AsoudColors.warning,
                text:
                    'پیش‌نویس روی گوشی ذخیره شده و هنوز با سرور همگام نشده است.'),
            TextButton(
                onPressed:
                    state.busy ? null : context.read<OrganizationCubit>().load,
                child: const Text('دریافت نسخه سرور؛ حفظ پیش‌نویس')),
            if (state.snapshot.server != null)
              TextButton(
                  onPressed: state.busy
                      ? null
                      : () => _review(context, state.snapshot),
                  child: const Text('مقایسه و انتخاب نسخه')),
            TextButton(
                onPressed: state.busy
                    ? null
                    : () => context
                        .read<OrganizationCubit>()
                        .save(state.snapshot.rows),
                child: const Text('همگام‌سازی')),
          ],
        ]),
      );

  Future<void> _review(BuildContext context, OrganizationSnapshot draft) async {
    final server = draft.server!;
    final localRows = {for (final row in draft.rows) row.code: row};
    final remoteRows = {for (final row in server.rows) row.code: row};
    final codes = {...localRows.keys, ...remoteRows.keys}.toList()..sort();
    String describe(OrgPosition? row) => row == null
        ? 'وجود ندارد'
        : '${row.title} | بالادست: ${row.parent.isEmpty ? 'ریشه' : row.parent} | واحد: ${row.department} (${row.departmentId}) | ظرفیت: ${row.capacity} | پرسنل: ${row.activeEmployees.join('، ')} | وظایف: ${row.duties}';
    final differences = codes
        .where(
            (code) => describe(localRows[code]) != describe(remoteRows[code]))
        .toList();
    final cubit = context.read<OrganizationCubit>();
    final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('مقایسه نسخه سرور و گوشی'),
              content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Text(
                            'نسخه گوشی: ${draft.revision} — نسخه سرور: ${server.revision}'),
                        const Text(
                            'انتخاب پیش‌نویس، مبنای ذخیره بعدی را عوض می‌کند؛ هنوز چیزی به سرور ارسال نمی‌شود. نسخه پیش‌نویس قبلی روی گوشی بایگانی می‌شود.'),
                        if (differences.isEmpty)
                          const Text('محتوای دو نسخه یکسان است.'),
                        for (final code in differences)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                  'کد $code\nگوشی: ${describe(localRows[code])}\nسرور: ${describe(remoteRows[code])}')),
                      ]))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('انصراف')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('استفاده از سرور')),
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('نگه‌داشتن پیش‌نویس برای ذخیره')),
              ],
            ));
    if (choice != null && context.mounted) {
      await cubit.resolve(useServer: choice);
    }
  }
}

class _OrgNotice extends StatelessWidget {
  const _OrgNotice(
      {required this.icon,
      required this.color,
      required this.text,
      this.title});
  final IconData icon;
  final Color color;
  final String text;
  final String? title;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(14),
            border: title == null ? null : Border.all(color: color)),
        child: Row(children: [
          AsoudIconBox(icon: icon, color: color, size: 38),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (title != null) ...[
                  Text(title!,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                ],
                Text(text,
                    softWrap: true,
                    style: const TextStyle(
                        fontSize: 11, color: AsoudColors.muted)),
              ])),
        ]),
      );
}

class _OrgChoice extends StatelessWidget {
  const _OrgChoice(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.action,
      this.secondary,
      this.onTap});
  final Widget? secondary;
  final IconData icon;
  final Color color;
  final String title, subtitle, action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
          child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              AsoudIconBox(icon: icon, color: color, size: 38),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xff526079))),
              const SizedBox(height: 9),
              Text(action,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: color)),
              if (secondary != null) secondary!,
            ])),
      ));
}

class _OrganizationTemplates extends StatefulWidget {
  const _OrganizationTemplates();
  @override
  State<_OrganizationTemplates> createState() => _OrganizationTemplatesState();
}

class _OrganizationTemplatesState extends State<_OrganizationTemplates> {
  String query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
            title: 'قالب‌های ساختار سازمانی',
            subtitle: 'انتخاب ساختار متناسب با فعالیت شرکت'),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                  onChanged: (value) => setState(() => query = value.trim()),
                  decoration: const InputDecoration(
                      hintText: 'جست‌وجوی قالب سازمانی',
                      prefixIcon: Icon(Icons.search)))),
          Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
            const _OrgNotice(
                icon: Icons.info_outline,
                color: AsoudColors.primary,
                text:
                    'قالب‌ها نقطه شروع پیشنهادی با جایگاه‌های خالی هستند و پس از ایجاد قابل ویرایش‌اند. برای حفظ اطلاعات، قالب فقط روی ساختار خالی اعمال می‌شود.'),
            const SizedBox(height: 16),
            for (final template in organizationTemplates
                .where((t) => '${t.title} ${t.description}'.contains(query)))
              Card(
                  child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: AsoudIconBox(
                    icon: Icons.account_tree_outlined,
                    size: 52,
                    color: const [
                      AsoudColors.primary,
                      AsoudColors.warning,
                      Color(0xff805ad5),
                      Color(0xffd97770),
                      AsoudColors.success
                    ][organizationTemplates.indexOf(template)]),
                title: Text(template.title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                    '${template.description}\n${formatCount(template.positions.length, 'جایگاه')} پیشنهادی'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () async {
                  final saved = await _openOrganizationPage<bool>(
                      context,
                      _OrganizationImportReview(
                          payload: _templateOrganizationPayload(template)));
                  if (saved == true && context.mounted) {
                    _openOrganizationPage<void>(
                        context, const _OrganizationWorkspace(canManage: true));
                  }
                },
              )),
          ])),
        ]),
      );
}

class _OrganizationPreview extends StatelessWidget {
  const _OrganizationPreview({required this.title, required this.additions});
  final String title;
  final List<OrgPosition> additions;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OrganizationCubit, OrganizationState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AsoudHeader(
                title: title, subtitle: 'پیش‌نمایش ساختار قبل از ثبت'),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              const _OrganizationStatus(),
              _OrgNotice(
                  icon: Icons.visibility_outlined,
                  color: AsoudColors.primary,
                  text:
                      'تا پیش از تأیید، هیچ جایگاهی ثبت نمی‌شود. تمام جایگاه‌ها پس از ذخیره قابل ویرایش هستند.'),
              const SizedBox(height: 16),
              _OrganizationTree(
                  rows: additions,
                  preview: true,
                  knownRows: [...state.snapshot.rows, ...additions]),
            ]),
            bottomNavigationBar: AsoudBottomActions(
              primaryLabel:
                  state.busy ? 'در حال ذخیره…' : 'تأیید و ایجاد ساختار',
              onPrimary: state.busy
                  ? null
                  : () async {
                      final cubit = context.read<OrganizationCubit>();
                      final saved = await cubit
                          .save([...cubit.state.snapshot.rows, ...additions]);
                      if (saved && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
              secondaryLabel: 'انصراف',
              onSecondary: state.busy ? null : () => Navigator.pop(context),
            ),
          );
        },
      );
}
