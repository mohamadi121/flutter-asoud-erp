import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xls;

import '../../../../core/auth/access_denied.dart';
import '../../../../core/auth/capabilities.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/organization_labels.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/organization_repository.dart';
import '../../domain/organization_chart.dart';
import '../../domain/organization_unit_navigation.dart';
import '../../domain/organization_templates.dart';
import '../cubit/organization_cubit.dart';

part 'organization_chart_view.dart';
part 'organization_position_form.dart';
part 'organization_workspace.dart';
part 'organization_visual_report.dart';
part 'organization_style.dart';
part 'organization_create.dart';
part 'organization_assignments.dart';
part 'organization_unit_management.dart';
part 'organization_unit_details.dart';
part 'organization_focus.dart';
part 'organization_focus_editor.dart';
part 'organization_setup_flow.dart';

String _assignmentDate(dynamic value) => value == null
    ? 'نامشخص (سابقه قبلی)'
    : formatJalaliDateTimeIso(value.toString());

String? _nullableOrgUnitLabel(Map? unit) => unit == null ? null : organizationUnitLabel(unit);

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
    units = c.repository.units(c.company)..ignore();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<OrganizationCubit,
          OrganizationState>(
      listenWhen: (before, after) =>
          before.busy && !after.busy && after.error == null,
      listener: (context, state) {
        final c = context.read<OrganizationCubit>();
        final pendingUnits = c.repository.units(c.company)..ignore();
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
                            final pendingUnits = c.repository.units(c.company)..ignore();
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
  const _OrganizationSetup({this.canManage = true, this.returnToWorkspace = false});
  final bool returnToWorkspace;

  Future<void> _open(BuildContext context, Widget page) async {
    final saved = await _openOrganizationPage<bool>(context, _OrgSheetTheme(child: page));
    if (saved == true && returnToWorkspace && context.mounted) {
      Navigator.pop(context);
    }
  }

  /// Read-only roles (HR User) keep the chart but no create/import entry.
  final bool canManage;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _orgCanvas,
        appBar: const AsoudHeader(
            title: 'ایجاد ساختار سازمانی',
            subtitle: 'روش ایجاد ساختار سازمانی را انتخاب کنید'),
        body: SafeArea(
            child: BlocBuilder<OrganizationCubit, OrganizationState>(
          builder: (context, state) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const _OrganizationStatus(showWarnings: false),
              if (state.snapshot.rows.isNotEmpty)
                const _OrgNotice(
                  icon: Icons.info_outline,
                  color: AsoudColors.primary,
                  text:
                      'ساختار فعلی شما حفظ می‌شود. برای تکمیل آن از ورود اکسل یا ایجاد دستی استفاده کنید. قالب آماده فقط روی ساختار بدون جایگاه اعمال می‌شود و جایگزین اطلاعات موجود نیست.',
                ),
              if (canManage) const SizedBox(height: 18),
              if (canManage)
                Card(
                    child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: state.busy
                      ? null
                      : () => _open(context, const _OrganizationTemplates()),
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
                IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(
                      child: _OrgChoice(
                    icon: Icons.add_rounded,
                    color: AsoudColors.success,
                    title: 'ایجاد ساختار دستی',
                    subtitle: 'تعریف واحدها، زیرواحدها و جایگاه‌های شغلی',
                    action: 'شروع ایجاد ساختار',
                    onTap: state.busy
                        ? null
                        : () => _open(context, const _OrganizationManualSetup()),
                  )),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _OrgChoice(
                    icon: Icons.upload_file_rounded,
                    color: AsoudColors.warning,
                    title: 'ورود از اکسل',
                    subtitle: 'ساختار سازمانی را از فایل اکسل وارد کنید',
                    action: 'ورود به صفحه اکسل',
                    onTap: state.busy
                        ? null
                        : () => _open(context, const _OrganizationExcelImport()),
                  )),
                ])),
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
  const _OrganizationStatus({this.showWarnings = true});
  final bool showWarnings;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OrganizationCubit, OrganizationState>(
        builder: (context, state) => Column(children: [
          for (final warning in showWarnings ? state.snapshot.warnings : <String>[])
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
        : '${row.displayTitle} | بالادست: ${row.parent.isEmpty ? 'ریشه' : row.parent} | واحد: ${row.displayDepartment} (${row.departmentId}) | ظرفیت: ${row.capacity} | پرسنل: ${row.activeEmployees.join('، ')} | وظایف: ${row.duties}';
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
      this.onTap});
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
              Expanded(child: Text(subtitle,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xff526079)))),
              const SizedBox(height: 9),
              Text(action,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: color)),
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
                    'نام واحدها و جایگاه‌های این قالب‌ها فارسی است. قالب‌ها نقطه شروع پیشنهادی با جایگاه‌های خالی هستند و پس از ایجاد قابل ویرایش‌اند. برای حفظ اطلاعات، قالب فقط روی ساختار خالی اعمال می‌شود.'),
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
                  final c = context.read<OrganizationCubit>();
                  var existing = <Map<String, dynamic>>[];
                  try {
                    existing = ((await c.repository.units(c.company))['units']
                            as List)
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList();
                  } catch (_) {
                    // The server still reports a clash in the review step.
                  }
                  if (!context.mounted) return;
                  final saved = await _openOrganizationPage<bool>(
                      context,
                      _OrganizationImportReview(
                          payload: templateOrganizationPayload(template,
                              existingUnits: existing)));
                  if (saved == true && context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
              )),
          ])),
        ]),
      );
}
