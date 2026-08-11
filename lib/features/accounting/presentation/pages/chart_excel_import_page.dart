import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/repositories/chart_of_accounts_repository.dart';

class ChartExcelImportPage extends StatefulWidget {
  const ChartExcelImportPage({
    required this.company,
    required this.repository,
    super.key,
  });
  final String company;
  final ChartOfAccountsRepository repository;

  @override
  State<ChartExcelImportPage> createState() => _ChartExcelImportPageState();
}

class _ChartExcelImportPageState extends State<ChartExcelImportPage> {
  List<Map<String, dynamic>> rows = const [];
  String? fileName;
  String? message;
  bool saving = false;

  Future<void> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (result == null) return;
    try {
      final bytes = result.files.single.bytes;
      if (bytes == null) throw const FormatException('فایل قابل خواندن نیست.');
      final workbook = Excel.decodeBytes(bytes);
      final sheet = workbook.tables.values.firstOrNull;
      if (sheet == null || sheet.rows.length < 2) {
        throw const FormatException('فایل اکسل فاقد ردیف اطلاعات است.');
      }
      final parsed = <Map<String, dynamic>>[];
      for (final row in sheet.rows.skip(1)) {
        final values = row.map((cell) => _cellText(cell?.value)).toList();
        if (values.every((value) => value.isEmpty)) continue;
        if (values.length < 2 || values[0].isEmpty || values[1].isEmpty) {
          throw const FormatException('ستون‌های سطح و نام حساب اجباری هستند.');
        }
        parsed.add({
          'level': _apiLevel(values[0]),
          'account_name': values[1],
          'account_number':
              values.length > 2 && values[2].isNotEmpty ? values[2] : null,
          'parent_account':
              values.length > 3 && values[3].isNotEmpty ? values[3] : null,
          'root_type':
              values.length > 4 && values[4].isNotEmpty ? values[4] : 'Asset',
        });
      }
      if (parsed.isEmpty) throw const FormatException('ردیف معتبری پیدا نشد.');
      setState(() {
        rows = parsed;
        fileName = result.files.single.name;
        message = null;
      });
    } catch (error) {
      setState(() {
        rows = const [];
        message = error.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  Future<void> submit() async {
    setState(() => saving = true);
    try {
      await widget.repository.importAccounts(widget.company, rows);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      setState(() => message =
          'ورود حساب‌ها در ASOUD ERP انجام نشد؛ هیچ موفقیت ظاهری ثبت نشد.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
          title: 'ورود سرفصل‌ها از اکسل',
          subtitle: 'فایل را بررسی و سپس برای ASOUD ERP ارسال کنید',
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFE),
                  border: Border.all(color: AsoudColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  const AsoudIconBox(
                      icon: Icons.upload_file_rounded,
                      color: AsoudColors.warning),
                  const SizedBox(height: 10),
                  Text(fileName ?? 'فایل XLSX را انتخاب کنید',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                      'ترتیب ستون‌ها: سطح، نام حساب، کد، کد یا نام حساب والد، نوع ریشه',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9, color: AsoudColors.muted)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: pick,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('انتخاب فایل'),
                  ),
                ]),
              ),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(message!,
                    style: const TextStyle(color: Colors.red, fontSize: 10)),
              ],
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('پیش‌نمایش ${rows.length} حساب',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                for (final row in rows.take(20))
                  Card(
                    child: ListTile(
                      title: Text(row['account_name'] as String),
                      subtitle: Text(
                          '${row['level']} • ${row['account_number'] ?? 'کد خودکار'}'),
                    ),
                  ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: AsoudBottomActions(
          primaryLabel: saving ? 'در حال ارسال...' : 'ورود حساب‌ها',
          onPrimary: rows.isEmpty || saving ? null : submit,
          secondaryLabel: 'انصراف',
          onSecondary: () => Navigator.of(context).pop(),
        ),
      );
}

String _cellText(CellValue? value) => value?.toString().trim() ?? '';

String _apiLevel(String value) => switch (value.trim().toLowerCase()) {
      'گروه' || 'group' => 'Group',
      'کل' || 'general' => 'General',
      'معین' || 'ledger' => 'Ledger',
      _ => throw FormatException('سطح حساب «$value» معتبر نیست.'),
    };
