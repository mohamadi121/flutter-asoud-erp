import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';

import '../../../../core/offline/queued_offline_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/generic_request_repository.dart';
import '../../domain/entities/request_models.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/entities/workflow_task.dart';
import '../../domain/repositories/workflow_task_repository.dart';
import '../pages/workflow_instance_detail_page.dart';
import '../request_screen_registry.dart';
import 'request_attachments.dart';
import 'request_comments.dart';
import 'request_custom_table.dart';
import 'request_link_fields.dart';
import 'request_list_view.dart' show requestPriorityLabels;
import 'request_print.dart';
import 'request_status.dart';

/// What the slot builders of [RequestDetailScaffold] receive.
class RequestDetailView {
  const RequestDetailView(
      {required this.detail, required this.fields, this.type});

  /// The request.
  final RequestDetail detail;

  /// The form fields of its type: from `get_request`, else from the
  /// `request_options` row.
  final List<WorkflowFormFieldDefinition> fields;

  /// The `request_options` row of the type, when it could be loaded.
  final Map<String, dynamic>? type;

  /// The request type's title.
  String get typeTitle => detail.requestType.isNotEmpty
      ? detail.requestType
      : '${type?['workflow_title'] ?? 'درخواست'}';

  WorkflowFormFieldDefinition? field(String key) =>
      fields.where((field) => field.key == key).firstOrNull;

  /// The text to show for the stored [value] of field [key]: Jalali dates,
  /// Persian digits and Persian choice labels.
  String format(String key, Object? value) {
    final definition = field(key);
    if (value == null || value == '' || (value is List && value.isEmpty)) {
      return '—';
    }
    switch (definition?.type) {
      case 'Date':
        return value is String ? formatJalaliIso(value) : '$value';
      case 'Time' || 'Number' || 'Currency':
        return toPersianDigits('$value');
      case 'Choice':
        return definition!.optionLabel('$value');
      case 'Multi Choice':
        return value is List
            ? value.map((v) => definition!.optionLabel('$v')).join('، ')
            : '$value';
      case 'Attachment':
        final file = detail.attachments
            .where((file) => file.fileUrl == '$value')
            .firstOrNull;
        return file?.filename ?? '$value'.split('/').last;
    }
    return formatRequestValue(value);
  }
}

/// Builds a slot of the scaffold from the loaded request.
typedef RequestDetailSlot = Widget Function(
    BuildContext context, RequestDetailView view);

/// The shared detail page of a request: status chip (with the native-document
/// chip), the main-info card, the items table with thumbnails, the files with
/// download, the «نظرات» thread, the process timeline («گردش فرایند») and the
/// buttons «کپی لینک», «ویرایش» (when `can_edit`) and «انصراف درخواست» (when
/// `can_cancel`). Templates replace parts through the slots.
class RequestDetailScaffold extends StatefulWidget {
  const RequestDetailScaffold({
    required this.repository,
    required this.name,
    this.title = 'جزئیات درخواست',
    this.tasks,
    this.infoBuilder,
    this.itemsBuilder,
    this.extraSections,
    this.fileSaver = saveRequestFile,
    super.key,
  });
  final GenericRequestRepository repository;
  final String name;
  final String title;
  final WorkflowTaskRepository? tasks;

  /// Replaces the main-info card.
  final RequestDetailSlot? infoBuilder;

  /// Replaces the items card.
  final RequestDetailSlot? itemsBuilder;

  /// Extra cards shown after the items.
  final List<Widget> Function(BuildContext context, RequestDetailView view)?
      extraSections;
  final RequestFileSaver fileSaver;

  @override
  State<RequestDetailScaffold> createState() => _RequestDetailScaffoldState();
}

class _RequestDetailScaffoldState extends State<RequestDetailScaffold> {
  Map<String, dynamic>? data;
  RequestDetail? detail;
  List<WorkflowTaskActivity> activities = const [];
  WorkflowInstanceSummary? summary;
  Map<String, dynamic>? definition;
  String? error;
  bool loading = true;

  /// Legacy rows (no `can_edit`) are editable while the instance is running.
  bool get running =>
      data != null &&
      data!['pending_sync'] != true &&
      !const {'Completed', 'Rejected', 'Cancelled', 'Failed'}
          .contains(data!['status']) &&
      !const {'approved', 'rejected', 'cancelled'}
          .contains(data!['status_key']);

  bool get canEdit => data == null || data!['pending_sync'] == true
      ? false
      : data!.containsKey('can_edit')
          ? detail!.canEdit
          : running;

  bool get canCancel => data == null || data!['pending_sync'] == true
      ? false
      : data!.containsKey('can_cancel')
          ? detail!.canCancel
          : running;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant RequestDetailScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name ||
        oldWidget.repository != widget.repository) {
      data = null;
      detail = null;
      load();
    }
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
        final key = '${value['template_key'] ?? ''}';
        type = (await widget.repository.options())
            .where((row) => key.isNotEmpty
                ? row['template_key'] == key
                : row['name'] == value['workflow_definition'])
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
        detail = RequestDetail.fromMap(value);
        definition = type;
        summary = instance?.summary;
        activities = instance?.activities ?? const [];
      });
    } catch (e) {
      if (mounted) {
        setState(
            () => error = requestErrorMessage(e, 'دریافت درخواست ممکن نشد.'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  RequestDetailView get view {
    final fields = detail!.fields.isNotEmpty
        ? detail!.fields
        : [
            for (final raw in definition?['fields'] as List? ?? const [])
              if (raw is Map) WorkflowFormFieldDefinition.fromMap(raw)
          ];
    return RequestDetailView(detail: detail!, fields: fields, type: definition);
  }

  Map<String, String> get labels => {
        for (final field in view.fields) field.key: field.label,
      };

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  bool get local => data?['local_preview'] == true;

  String get number => local
      ? '${data!['local_number'] ?? ''}'
      : data!['pending_sync'] == true
          ? '—'
          : detail!.number;

  String get typeTitle => view.typeTitle;

  Future<Uint8List> _pdf() => buildRequestPdf(
          request: {
            ...data!,
            'name': number,
            'request_type': typeTitle,
            if (local) 'requester_name': 'کاربر پیش‌نمایش',
          },
          activities: activities,
          labels: labels,
          statusLabel: requestStatus(data!).$1);

  Future<void> edit() async {
    final type = definition;
    if (type == null) {
      return _message('فرم این نوع درخواست در دسترس نیست.');
    }
    final saved = await RequestScreenRegistry.openForm(
        context, widget.repository, type,
        existing: data);
    if (saved == true) await load();
  }

  Future<void> menu(String action) async {
    switch (action) {
      case 'edit':
        await edit();
      case 'print':
        await Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) =>
                    RequestPrintPage(title: typeTitle, document: _pdf)));
      case 'pdf':
        try {
          await Printing.sharePdf(bytes: await _pdf(), filename: '$number.pdf');
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
      if (e is QueuedOfflineException) return _message(e.message);
      // A second cancel fails with "only a request in progress can be
      // changed": after a refresh a cancelled request counts as done.
      await load();
      if (!mounted) return;
      if (detail?.statusKey == RequestStatusKey.cancelled) {
        _message('درخواست لغو شده است.');
      } else {
        _message(requestErrorMessage(e, 'لغو درخواست انجام نشد.'));
      }
    }
  }

  Future<void> copyLink() async {
    await Clipboard.setData(ClipboardData(text: requestLink(detail!.name)));
    if (mounted) _message('لینک درخواست کپی شد.');
  }

  @override
  Widget build(BuildContext context) {
    final value = data;
    return Scaffold(
      appBar: AsoudHeader(
        title: widget.title,
        action: value == null
            ? null
            : PopupMenuButton<String>(
                tooltip: 'عملیات',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: menu,
                itemBuilder: (_) => [
                  if (canEdit)
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
                  if ('${value['workflow_instance'] ?? ''}'.isNotEmpty &&
                      value['pending_sync'] != true)
                    const PopupMenuItem(
                        value: 'workflow',
                        child: ListTile(
                            leading: Icon(Icons.account_tree_outlined),
                            title: Text('مشاهده گردش کار'))),
                  if (canCancel)
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
              : RefreshIndicator(onRefresh: load, child: _body()),
      bottomNavigationBar:
          value == null || value['pending_sync'] == true ? null : _actions(),
    );
  }

  /// One button of the bottom bar. The label never wraps: it shrinks to fit.
  Widget _barButton(Key key, String label, IconData icon, VoidCallback onTap,
          {Color? color}) =>
      Expanded(
          child: OutlinedButton.icon(
              key: key,
              style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: color == null ? null : BorderSide(color: color),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size.fromHeight(46)),
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, maxLines: 1, softWrap: false))));

  /// «کپی لینک» and «ویرایش» share a row (the mockups); «انصراف درخواست» sits
  /// beside «کپی لینک» when there is no edit button, and gets its own row
  /// below when all three show, so every label stays on one line.
  Widget _actions() {
    final copy = _barButton(const ValueKey('request-copy-link-button'),
        'کپی لینک', Icons.copy_rounded, copyLink);
    final edit = _barButton(const ValueKey('request-edit-button'), 'ویرایش',
        Icons.edit_outlined, this.edit);
    final cancel = _barButton(const ValueKey('request-cancel-button'),
        'انصراف درخواست', Icons.cancel_outlined, this.cancel,
        color: AsoudColors.danger);
    const gap = SizedBox(width: 8);
    final rows = <Widget>[
      if (canEdit && canCancel) ...[
        Row(children: [copy, gap, edit]),
        const SizedBox(height: 8),
        Row(children: [cancel]),
      ] else
        Row(children: [
          if (canCancel) ...[cancel, gap],
          copy,
          if (canEdit) ...[gap, edit],
        ]),
    ];
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AsoudColors.border))),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
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

  Widget _section(String title, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          if (icon != null) ...[
            AsoudIconBox(icon: icon, color: AsoudColors.primary, size: 28),
            const SizedBox(width: 8),
          ],
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900))),
        ]),
      );

  Widget _info(RequestDetailView view) {
    final detail = view.detail;
    final values = detail.values;
    final tableKeys = {
      for (final field in view.fields)
        if (field.type == 'Table' || field.type == 'Item Table') field.key
    };
    final plain = {
      for (final entry in values.entries)
        if (!tableKeys.contains(entry.key) &&
            !(entry.value is List &&
                (entry.value as List).isNotEmpty &&
                (entry.value as List).first is Map) &&
            view.field(entry.key)?.type != 'Auto')
          labels[entry.key] ?? entry.key: view.format(entry.key, entry.value),
    };
    return _card([
      RequestInfoRow(
          'درخواست‌کننده',
          detail.requesterName.isNotEmpty
              ? detail.requesterName
              : local
                  ? 'کاربر پیش‌نمایش'
                  : ''),
      RequestInfoRow('واحد', detail.department),
      RequestInfoRow('تاریخ ثبت', formatJalaliDateTimeIso(detail.creation)),
      RequestInfoRow('نوع درخواست', typeTitle),
      for (final entry in plain.entries) RequestInfoRow(entry.key, entry.value),
    ]);
  }

  Widget _items(RequestDetailView view) {
    final items = view.detail.items;
    final fileOf = {
      for (final file in view.detail.attachments) file.fileUrl: file,
    };
    final anyNote =
        items.any((row) => row.description.isNotEmpty || row.note.isNotEmpty);
    Widget cell(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: child);
    Widget text(String value, {bool header = false}) => cell(Text(value,
        style: TextStyle(
            fontSize: 12,
            color: header ? AsoudColors.muted : AsoudColors.text,
            fontWeight: header ? FontWeight.w700 : FontWeight.w600)));
    return _card([
      _section('اقلام درخواست (${toPersianDigits(items.length)} قلم)',
          icon: Icons.inventory_2_outlined),
      Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: {
          0: const FixedColumnWidth(28),
          1: const FlexColumnWidth(3),
          2: const FixedColumnWidth(48),
          3: const FixedColumnWidth(52),
          if (anyNote) 4: const FlexColumnWidth(2),
        },
        border: TableBorder(
            horizontalInside:
                BorderSide(color: AsoudColors.border.withValues(alpha: .8))),
        children: [
          TableRow(children: [
            text('#', header: true),
            text('کالا / خدمت', header: true),
            text('تعداد', header: true),
            text('واحد', header: true),
            if (anyNote) text('مشخصات', header: true),
          ]),
          for (final (index, row) in items.indexed)
            TableRow(children: [
              text(toPersianDigits(index + 1)),
              cell(Row(children: [
                if (row.attachmentRef != null ||
                    fileOf[row.attachmentUrl]?.isImage == true) ...[
                  RequestAttachmentThumbnail(
                      attachment:
                          row.attachmentRef ?? fileOf[row.attachmentUrl]!,
                      repository: widget.repository,
                      size: 38),
                  const SizedBox(width: 6),
                ],
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(row.title,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      if (row.itemName.isNotEmpty &&
                          row.itemCode.isNotEmpty &&
                          row.itemName != row.itemCode)
                        Text(row.itemCode,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                                fontSize: 10, color: AsoudColors.muted)),
                    ])),
              ])),
              text(row.qty == null
                  ? ''
                  : toPersianDigits(formatRequestValue(row.qty))),
              text(row.uom),
              if (anyNote)
                text([row.description, row.note]
                    .where((part) => part.isNotEmpty)
                    .join('\n')),
            ]),
        ],
      ),
    ]);
  }

  Widget _body() {
    final value = data!;
    final detail = this.detail!;
    final view = this.view;
    final generalFiles = [
      for (final file in detail.attachments)
        if (!file.isRowFile) file
    ];
    final tables = view.fields.where((field) => field.type == 'Table').toList();
    final values = detail.values;
    final onServer = value['pending_sync'] != true;
    // Every section is built at once: the page is short and each part must
    // be reachable without scrolling in tests and screen readers.
    return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (value['pending_sync'] == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(local
                  ? 'این درخواست فقط روی گوشی ذخیره شده است (پیش‌نمایش آفلاین) و به سرور ارسال نمی‌شود.'
                  : 'اطلاعات روی دستگاه محفوظ است؛ اجرای گردش‌کار پس از تأیید سرور انجام می‌شود.'),
            ),
          if (value['pending_sync'] == true &&
              '${value['error'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${value['error']}',
                  style: const TextStyle(color: AsoudColors.danger)),
            ),
          _card([
            Row(children: [
              Expanded(
                  child: Text(number,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900))),
              Flexible(
                  child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: [
                    RequestStatusChip(value),
                    if (detail.native.hasStatus)
                      RequestNativeChip(detail.native),
                  ])),
            ]),
            const SizedBox(height: 6),
            Text(detail.subject,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
          if (detail.statusKey == RequestStatusKey.rejected &&
              detail.rejectionReason.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AsoudColors.danger.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('دلیل رد: ${detail.rejectionReason}',
                  style: const TextStyle(
                      fontSize: 12, color: AsoudColors.danger, height: 1.7)),
            ),
          if (detail.native.failed && detail.native.error.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AsoudColors.danger.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(detail.native.error,
                  style: const TextStyle(
                      fontSize: 12, color: AsoudColors.danger, height: 1.7)),
            ),
          widget.infoBuilder?.call(context, view) ?? _info(view),
          if (detail.items.isNotEmpty)
            widget.itemsBuilder?.call(context, view) ?? _items(view),
          for (final field in tables)
            _card([
              RequestCustomTable(
                  field: field,
                  enabled: false,
                  initialValue: (values[field.key] as List?)
                          ?.whereType<Map>()
                          .map((row) => Map<String, dynamic>.from(row))
                          .toList() ??
                      [],
                  attachments: [
                    for (final file in detail.attachments)
                      if (file.fileUrl.isNotEmpty) file.fileUrl
                  ],
                  onChanged: (_) {})
            ]),
          ...?widget.extraSections?.call(context, view),
          if (generalFiles.isNotEmpty)
            _card([
              _section(
                  'پیوست‌ها (${toPersianDigits(generalFiles.length)} فایل)',
                  icon: Icons.attach_file_rounded),
              for (final file in generalFiles)
                RequestAttachmentTile(
                    attachment: file,
                    repository: widget.repository,
                    saver: widget.fileSaver,
                    onMessage: _message),
            ])
          else if (detail.templateKey.isNotEmpty)
            _card([
              _section('پیوست‌ها', icon: Icons.attach_file_rounded),
              const Text('فایلی وجود ندارد.',
                  style: TextStyle(fontSize: 12, color: AsoudColors.muted)),
            ]),
          _card([
            _section('نظرات', icon: Icons.chat_bubble_outline_rounded),
            RequestCommentsThread(
                repository: widget.repository,
                requestName: detail.name,
                enabled: onServer),
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
                    comment: activity.comment,
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
        ]));
  }
}

/// A label and its value (`درخواست‌کننده: علی محمدی`).
class RequestInfoRow extends StatelessWidget {
  const RequestInfoRow(this.label, this.value, {this.trailing, super.key});
  final String label, value;

  /// Shown instead of [value] (e.g. a priority chip).
  final Widget? trailing;
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
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing ??
                      Text(value.isEmpty ? '—' : value,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)))),
        ]),
      );
}

/// The Persian label of a priority value (`Normal` → «عادی»).
String requestPriorityLabel(String priority) =>
    requestPriorityLabels[priority] ?? priority;

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

class _Step extends StatelessWidget {
  const _Step(
      {required this.title,
      required this.subtitle,
      required this.done,
      this.comment = '',
      this.current = false});
  final String title, subtitle;
  final String comment;
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
              if (comment.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('«${comment.trim()}»',
                      style: const TextStyle(
                          fontSize: 11, height: 1.7, color: AsoudColors.text)),
                ),
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
