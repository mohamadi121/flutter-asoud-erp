import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../request_types/domain/request_type_catalog.dart';
import '../../data/generic_request_repository.dart';
import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import '../widgets/request_link_fields.dart';
import '../widgets/request_print.dart';
import 'generic_request_page.dart';
import 'workflow_instance_detail_page.dart';

/// Label and color of a request's status for chips and print.
(String, Color) requestStatus(Map<String, dynamic> data) {
  if (data['pending_sync'] == true) {
    return ('در انتظار همگام‌سازی', AsoudColors.primary);
  }
  final display = '${data['display_status'] ?? ''}';
  final status = '${data['status'] ?? ''}';
  final base = switch (status) {
    'Completed' => ('تکمیل شده', AsoudColors.success),
    'Rejected' => ('رد شده', AsoudColors.danger),
    'Cancelled' => ('لغو شده', AsoudColors.muted),
    'Failed' => ('نیازمند بررسی', AsoudColors.danger),
    _ => ('در انتظار تأیید', AsoudColors.warning),
  };
  return display.isNotEmpty && status == 'Running'
      ? (display, AsoudColors.primary)
      : base;
}

class RequestStatusChip extends StatelessWidget {
  const RequestStatusChip(this.data, {super.key});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final (label, color) = requestStatus(data);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w800)),
    );
  }
}

/// «انتخاب نوع درخواست»: a sheet listing the request types the user may submit.
Future<Map<String, dynamic>?> pickRequestType(
        BuildContext context, GenericRequestRepository repository) =>
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .75),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: repository.options(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('دریافت انواع درخواست ممکن نشد.',
                        textAlign: TextAlign.center));
              }
              if (!snapshot.hasData) {
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()));
              }
              final rows = snapshot.data!;
              return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    const Text('نوع درخواست را انتخاب کنید',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    if (rows.isEmpty)
                      const Text('نوع درخواستی برای این دفتر تعریف نشده است.',
                          textAlign: TextAlign.center),
                    for (final row in rows)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: AsoudIconBox(
                              icon: requestIconFor('${row['icon_key']}').icon,
                              color: requestIconFor('${row['icon_key']}').color,
                              size: 42),
                          title: Text('${row['workflow_title']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                              '${row['short_title'] ?? row['process_description'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_left_rounded),
                          onTap: () => Navigator.pop(context, row),
                        ),
                      ),
                  ]);
            },
          ),
        ),
      ),
    );

/// «درخواست شما با موفقیت ثبت شد» with the request summary.
class RequestSubmittedPage extends StatelessWidget {
  const RequestSubmittedPage({
    required this.request,
    required this.repository,
    required this.typeTitle,
    super.key,
  });

  /// The server's request, or the local payload while it waits to sync.
  final Map<String, dynamic> request;
  final GenericRequestRepository repository;
  final String typeTitle;

  bool get pending => request['pending_sync'] == true;

  @override
  Widget build(BuildContext context) {
    final values = Map<String, dynamic>.from(request['values'] as Map? ?? {});
    final number = pending ? '—' : '${request['name']}';
    final rows = {
      'شماره درخواست': number,
      'عنوان': '${request['subject'] ?? ''}',
      'نوع درخواست': typeTitle,
      'تعداد اقلام': '${toPersianDigits(requestItemRows(values).length)} قلم',
      'تاریخ ثبت': formatJalaliDateTimeIso(
          '${request['creation'] ?? DateTime.now().toIso8601String()}'),
    };
    void details() => Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
            builder: (_) => RequestDetailPage(
                name: '${request['name']}', repository: repository)));
    return Scaffold(
      appBar: AsoudHeader(title: typeTitle),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                    color: AsoudColors.success.withValues(alpha: .12),
                    shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: AsoudColors.success, size: 52),
              ),
              const SizedBox(height: 16),
              Text(
                  pending
                      ? 'درخواست شما روی گوشی ذخیره شد'
                      : 'درخواست شما با موفقیت ثبت شد',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                  pending
                      ? 'پس از اتصال به سرور ارسال و برای بررسی به مدیر مرتبط فرستاده می‌شود.'
                      : '$typeTitle با شماره $number ثبت و برای بررسی به مدیر مرتبط ارسال شد.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, height: 1.7, color: AsoudColors.muted)),
              const SizedBox(height: 18),
              if (!pending)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  onPressed: details,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('مشاهده جزئیات درخواست'),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                icon: const Icon(Icons.home_outlined),
                label: const Text('بازگشت به صفحه اصلی'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              const Row(children: [
                Expanded(
                    child: Text('خلاصه درخواست',
                        style: TextStyle(fontWeight: FontWeight.w900))),
                Icon(Icons.receipt_long_outlined, color: AsoudColors.primary),
              ]),
              const SizedBox(height: 8),
              for (final entry in rows.entries)
                _InfoRow(entry.key, entry.value),
              _InfoRowWidget('وضعیت', RequestStatusChip(request)),
              if (!pending)
                TextButton.icon(
                    onPressed: details,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('مشاهده جزئیات کامل')),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => _InfoRowWidget(
      label,
      Text(value.isEmpty ? '—' : value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)));
}

class _InfoRowWidget extends StatelessWidget {
  const _InfoRowWidget(this.label, this.value);
  final String label;
  final Widget value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 104,
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: AsoudColors.muted))),
          Expanded(
              child: Align(
                  alignment: AlignmentDirectional.centerEnd, child: value)),
        ]),
      );
}

/// «جزئیات درخواست» with actions in the three-dot menu.
class RequestDetailPage extends StatefulWidget {
  const RequestDetailPage(
      {required this.name, required this.repository, this.tasks, super.key});
  final String name;
  final GenericRequestRepository repository;
  final WorkflowTaskRepository? tasks;
  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  Map<String, dynamic>? data;
  List<WorkflowTaskActivity> activities = const [];
  WorkflowInstanceSummary? summary;
  Map<String, dynamic>? definition;
  String? error;
  bool loading = true;

  bool get running =>
      data != null &&
      data!['pending_sync'] != true &&
      !const {'Completed', 'Rejected', 'Cancelled', 'Failed'}
          .contains(data!['status']);

  @override
  void initState() {
    super.initState();
    load();
  }

  WorkflowTaskRepository? _tasks() {
    try {
      return widget.tasks ?? context.read<WorkflowTaskRepository>();
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    final tasks = _tasks();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.repository.detail(widget.name);
      Map<String, dynamic>? type;
      try {
        type = (await widget.repository.options())
            .where((row) => row['name'] == value['workflow_definition'])
            .firstOrNull;
      } catch (_) {
        // Field labels are optional; keys are shown without them.
      }
      WorkflowInstanceDetail? instance;
      final id = '${value['workflow_instance'] ?? ''}';
      if (id.isNotEmpty && value['pending_sync'] != true) {
        try {
          instance = await tasks?.getInstance(id);
        } catch (_) {
          // The timeline is optional; the request itself is shown.
        }
      }
      if (!mounted) return;
      setState(() {
        data = value;
        definition = type;
        summary = instance?.summary;
        activities = instance?.activities ?? const [];
      });
    } catch (e) {
      if (mounted) {
        setState(() =>
            error = e is ApiException ? e.message : 'دریافت درخواست ممکن نشد.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Map<String, String> get labels => {
        for (final field in definition?['fields'] as List? ?? const [])
          if (field is Map) '${field['key']}': '${field['label']}',
      };

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<Uint8List> _pdf() => buildRequestPdf(
      request: data!,
      activities: activities,
      labels: labels,
      statusLabel: requestStatus(data!).$1);

  Future<void> menu(String action) async {
    switch (action) {
      case 'edit':
        if (definition == null) {
          return _message('فرم این نوع درخواست در دسترس نیست.');
        }
        final saved = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => GenericRequestPage(
                    repository: widget.repository,
                    definition: definition,
                    existing: data)));
        if (saved == true) await load();
      case 'print':
        await Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => RequestPrintPage(
                    title: '${data!['request_type'] ?? 'درخواست'}',
                    document: _pdf)));
      case 'pdf':
        try {
          await Printing.sharePdf(
              bytes: await _pdf(), filename: '${data!['name']}.pdf');
        } catch (_) {
          _message('ساخت فایل PDF ممکن نشد.');
        }
      case 'workflow':
        await Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => WorkflowInstanceDetailPage(
                    instance: '${data!['workflow_instance']}')));
      case 'cancel':
        await cancel();
    }
  }

  Future<void> cancel() async {
    final text = await showDialog<String>(
        context: context, builder: (_) => const _CancelDialog());
    if (text == null) return;
    try {
      await widget.repository.cancel(widget.name, reason: text);
      _message('درخواست لغو شد.');
      await load();
    } catch (e) {
      _message(e is ApiException ? e.message : 'لغو درخواست انجام نشد.');
    }
  }

  Future<void> download(Map file) async {
    try {
      final result = await widget.repository
          .read('get_attachment', {'name': file['name']}) as Map;
      await FilePicker.platform.saveFile(
          fileName: '${result['filename']}',
          bytes: base64Decode('${result['content_base64']}'));
    } catch (_) {
      _message('دریافت فایل ممکن نشد.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = data;
    return Scaffold(
      appBar: AsoudHeader(
        title: 'جزئیات درخواست',
        action: value == null || value['pending_sync'] == true
            ? null
            : PopupMenuButton<String>(
                tooltip: 'عملیات',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: menu,
                itemBuilder: (_) => [
                  if (running)
                    const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('ویرایش (قبل از تأیید)'))),
                  const PopupMenuItem(
                      value: 'print',
                      child: ListTile(
                          leading: Icon(Icons.print_outlined),
                          title: Text('چاپ درخواست'))),
                  const PopupMenuItem(
                      value: 'pdf',
                      child: ListTile(
                          leading: Icon(Icons.picture_as_pdf_outlined),
                          title: Text('خروجی PDF'))),
                  if ('${value['workflow_instance'] ?? ''}'.isNotEmpty)
                    const PopupMenuItem(
                        value: 'workflow',
                        child: ListTile(
                            leading: Icon(Icons.account_tree_outlined),
                            title: Text('مشاهده گردش کار'))),
                  if (running)
                    const PopupMenuItem(
                        value: 'cancel',
                        child: ListTile(
                            leading: Icon(Icons.delete_outline_rounded,
                                color: AsoudColors.danger),
                            title: Text('لغو درخواست',
                                style: TextStyle(color: AsoudColors.danger)))),
                ],
              ),
      ),
      body: loading && value == null
          ? const Center(child: CircularProgressIndicator())
          : error != null && value == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(error!),
                  TextButton(onPressed: load, child: const Text('تلاش دوباره')),
                ]))
              : RefreshIndicator(onRefresh: load, child: _body(value!)),
    );
  }

  Widget _card(List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children),
        ),
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      );

  Widget _body(Map<String, dynamic> value) {
    final values = Map<String, dynamic>.from(value['values'] as Map? ?? {});
    final items = requestItemRows(values);
    final plain = {
      for (final entry in values.entries)
        if (!(entry.value is List &&
            (entry.value as List).isNotEmpty &&
            (entry.value as List).first is Map))
          labels[entry.key] ?? entry.key: formatRequestValue(entry.value),
    };
    final attachments = value['attachments'] as List? ?? const [];
    return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (value['pending_sync'] == true)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                  'اطلاعات روی دستگاه محفوظ است؛ اجرای گردش‌کار پس از تأیید سرور انجام می‌شود.'),
            ),
          _card([
            Row(children: [
              Expanded(
                  child: Text(
                      value['pending_sync'] == true ? '—' : '${value['name']}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900))),
              RequestStatusChip(value),
            ]),
            const SizedBox(height: 6),
            Text('${value['subject'] ?? ''}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const Divider(height: 20),
            _InfoRow('درخواست‌کننده', '${value['requester_name'] ?? ''}'),
            _InfoRow('واحد', '${value['department'] ?? ''}'),
            _InfoRow('تاریخ ثبت',
                formatJalaliDateTimeIso('${value['creation'] ?? ''}')),
            _InfoRow('نوع درخواست', '${value['request_type'] ?? ''}'),
            for (final entry in plain.entries) _InfoRow(entry.key, entry.value),
          ]),
          if (items.isNotEmpty)
            _card([
              _section('اقلام درخواست'),
              Table(
                columnWidths: const {
                  0: FixedColumnWidth(28),
                  2: FixedColumnWidth(52),
                  3: FixedColumnWidth(56),
                },
                border: TableBorder(
                    horizontalInside: BorderSide(
                        color: AsoudColors.border.withValues(alpha: .8))),
                children: [
                  const TableRow(children: [
                    _Cell('#', header: true),
                    _Cell('کالا', header: true),
                    _Cell('تعداد', header: true),
                    _Cell('واحد', header: true),
                  ]),
                  for (final (index, row) in items.indexed)
                    TableRow(children: [
                      _Cell(toPersianDigits(index + 1)),
                      _Cell('${row['item_name'] ?? row['item_code']}'),
                      _Cell(toPersianDigits(formatRequestValue(row['qty']))),
                      _Cell('${row['uom'] ?? ''}'),
                    ]),
                ],
              ),
            ]),
          if (attachments.isNotEmpty)
            _card([
              _section('پیوست‌ها'),
              for (final file in attachments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const AsoudIconBox(
                      icon: Icons.insert_drive_file_outlined,
                      color: AsoudColors.warning,
                      size: 38),
                  title: Text('${(file as Map)['filename']}',
                      style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.download_rounded),
                  onTap: () => download(file),
                ),
            ]),
          if (activities.isNotEmpty || summary != null)
            _card([
              _section('گردش فرایند'),
              for (final activity in activities)
                _Step(
                    title: activity.stageTitle.isEmpty
                        ? requestActionLabel(activity.action)
                        : activity.stageTitle,
                    subtitle: [
                      requestActionLabel(activity.action),
                      activity.actor,
                      if (activity.createdOn != null)
                        formatJalaliDateTimeIso(
                            activity.createdOn!.toIso8601String()),
                    ].join(' · '),
                    done: !activity.action.contains('Failed') &&
                        activity.action != 'Reject'),
              if (summary != null &&
                  running &&
                  summary!.currentStageTitle.isNotEmpty)
                _Step(
                    title: summary!.currentStageTitle,
                    subtitle: 'در انتظار اقدام',
                    done: false,
                    current: true),
            ]),
        ]);
  }
}

/// Asks for an optional reason; pops with it, or null when dismissed.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog();
  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final reason = TextEditingController();

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('لغو درخواست'),
        content: TextField(
            controller: reason,
            decoration: const InputDecoration(labelText: 'دلیل لغو (اختیاری)')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف')),
          FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AsoudColors.danger),
              onPressed: () => Navigator.pop(context, reason.text.trim()),
              child: const Text('لغو درخواست')),
        ],
      );
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.header = false});
  final String text;
  final bool header;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                color: header ? AsoudColors.muted : AsoudColors.text,
                fontWeight: header ? FontWeight.w700 : FontWeight.w600)),
      );
}

class _Step extends StatelessWidget {
  const _Step(
      {required this.title,
      required this.subtitle,
      required this.done,
      this.current = false});
  final String title, subtitle;
  final bool done, current;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
              done
                  ? Icons.check_circle_rounded
                  : current
                      ? Icons.radio_button_checked_rounded
                      : Icons.cancel_rounded,
              color: done
                  ? AsoudColors.success
                  : current
                      ? AsoudColors.warning
                      : AsoudColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: done ? AsoudColors.success : AsoudColors.text)),
              Text(subtitle,
                  style:
                      const TextStyle(fontSize: 11, color: AsoudColors.muted)),
            ]),
          ),
        ]),
      );
}

/// Print preview of a request (print, share or save as PDF).
class RequestPrintPage extends StatelessWidget {
  const RequestPrintPage(
      {required this.title, required this.document, super.key});
  final String title;
  final Future<Uint8List> Function() document;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(title: 'چاپ درخواست'),
        body: PdfPreview(
          build: (_) => document(),
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          pdfFileName: '$title.pdf',
        ),
      );
}
