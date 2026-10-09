import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/offline/queued_offline_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/generic_request_repository.dart';
import '../../../request_types/domain/request_type_catalog.dart';
import '../../domain/entities/workflow_definition.dart';
import '../request_screen_registry.dart';
import '../widgets/request_status.dart';
import '../widgets/request_attachments.dart';
import '../widgets/request_field_widgets.dart';
import '../widgets/request_form_controller.dart';
import '../widgets/request_list_view.dart';
import 'request_flow_pages.dart';

/// «درخواست‌های من»: every request of the signed-in user, with a filter for
/// the system templates. Built on [RequestListView].
class GenericRequestsPage extends StatefulWidget {
  const GenericRequestsPage(
      {required this.company, this.repository, super.key});
  final String company;
  final GenericRequestRepository? repository;
  @override
  State<GenericRequestsPage> createState() => _GenericRequestsPageState();
}

class _GenericRequestsPageState extends State<GenericRequestsPage> {
  late final repository = widget.repository ??
      GenericRequestRepository(context.read<FrappeApiClient>(), widget.company);
  final listKey = GlobalKey<RequestListViewState>();
  late final Future<List<Map<String, dynamic>>> types = _types();
  String? templateKey;

  Future<List<Map<String, dynamic>>> _types() async {
    try {
      return [
        for (final row in await repository.options())
          if ('${row['template_key'] ?? ''}'.isNotEmpty) row
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  void dispose() {
    if (widget.repository == null) repository.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final type = await pickRequestType(context, repository);
    if (type == null || !mounted) return;
    final saved =
        await RequestScreenRegistry.openForm(context, repository, type);
    if (saved == true) await listKey.currentState?.reload();
  }

  Widget _templateFilter() => FutureBuilder<List<Map<String, dynamic>>>(
        future: types,
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) return const SizedBox.shrink();
          return Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(
                label: const Text('همه انواع'),
                selected: templateKey == null,
                onSelected: (_) => setState(() => templateKey = null)),
            for (final row in rows)
              ChoiceChip(
                  label: Text(
                      '${row['workflow_title'] ?? row['short_title'] ?? ''}'),
                  selected: templateKey == row['template_key'],
                  onSelected: (_) =>
                      setState(() => templateKey = '${row['template_key']}')),
          ]);
        },
      );

  @override
  Widget build(BuildContext context) => RequestListView(
        key: listKey,
        repository: repository,
        templateKey: templateKey,
        title: 'درخواست‌های من',
        subtitle: 'ثبت و پیگیری درخواست‌ها',
        header: _templateFilter(),
        createLabel: 'درخواست جدید',
        onCreate: _create,
      );
}

class GenericRequestPage extends StatefulWidget {
  const GenericRequestPage(
      {required this.repository, this.definition, this.existing, super.key});
  final GenericRequestRepository repository;

  /// The request type chosen beforehand; without it the form offers a choice.
  final Map<String, dynamic>? definition;

  /// A submitted request to edit before it is reviewed.
  final Map<String, dynamic>? existing;
  @override
  State<GenericRequestPage> createState() => _GenericRequestPageState();
}

class _GenericRequestPageState extends State<GenericRequestPage> {
  final formKey = GlobalKey<FormState>();
  final subject = TextEditingController(),
      project = TextEditingController(),
      department = TextEditingController(),
      requiredBy = TextEditingController(),
      priority = TextEditingController(text: 'Normal');
  late Future<List<Map<String, dynamic>>> options = widget.repository.options();
  Map<String, dynamic>? selected;
  RequestFormController? form;
  String? error;
  bool saving = false;
  final requestId = GenericRequestRepository.requestId();
  bool get editing => widget.existing != null;

  /// A system template shown by the generic form: the server derives its
  /// priority, project and department.
  bool get isTemplate => '${selected?['template_key'] ?? ''}'.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) subject.text = '${existing['subject'] ?? ''}';
    final definition = widget.definition;
    if (definition != null) select(definition);
  }

  /// Switches to a request type: a new form controller with its defaults.
  void select(Map<String, dynamic> row) {
    selected = row;
    form?.dispose();
    form = RequestFormController.fromType(row,
        existing: editing ? widget.existing : null,
        loadOptions: RequestFormController.loaderFor(widget.repository),
        subject: subject);
  }

  @override
  void dispose() {
    form?.dispose();
    for (final c in [subject, project, department, requiredBy, priority]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _valid() {
    // Both run so that every error is shown.
    final fields = formKey.currentState!.validate();
    final values = form!.validate();
    return fields && values;
  }

  Future<void> save() async {
    if (saving || form == null || !_valid()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final name = '${widget.existing!['name']}';
      final uploads = form!.attachmentUploads();
      final removed = form!.removedAttachmentNames;
      final values = form!.payloadValues();
      final text = form!.subjectMode == 'input' ? subject.text.trim() : '';
      if (uploads.isEmpty && removed.isEmpty) {
        await widget.repository.update(name, text, values);
      } else {
        await widget.repository.update(name, text, values,
            attachments: uploads, removeAttachments: removed);
      }
      if (mounted) Navigator.pop(context, true);
    } on QueuedOfflineException catch (e) {
      // Safe on the device; the queue sends it when the connection returns.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => error = requestErrorMessage(e, 'ذخیره تغییرات انجام نشد.'));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> submit() async {
    if (editing) return save();
    if (saving || selected == null || form == null || !_valid()) return;
    final uploads = form!.attachmentUploads();
    final templateKey = '${selected!['template_key'] ?? ''}';
    final payload = <String, dynamic>{
      'workflow_definition': selected!['name'],
      if (templateKey.isNotEmpty) 'template_key': templateKey,
      'subject': form!.subjectMode == 'input' ? subject.text.trim() : '',
      // A system template derives these from its values on the server.
      if (!isTemplate) ...{
        'priority': priority.text,
        'project': project.text.trim(),
        'department': department.text.trim(),
        if (requiredBy.text.isNotEmpty) 'required_by': requiredBy.text,
      },
      'values': form!.payloadValues(),
      'attachments': uploads,
    };
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('بررسی درخواست'),
                content: Text(
                    '${subject.text}\n${selected!['workflow_title']}\nتعداد پیوست: ${uploads.length}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('بازگشت')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('ثبت درخواست'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.repository.create(payload, requestId);
      if (!mounted) return;
      await Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
              builder: (_) => RequestSubmittedPage(
                  request: result ??
                      {
                        ...payload,
                        'name': '',
                        'pending_sync': true,
                      },
                  repository: widget.repository,
                  typeTitle: '${selected!['workflow_title']}')),
          result: true);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'ثبت انجام نشد؛ اطلاعات فرم حفظ شده است. اتصال و نشست را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  List<WorkflowFormFieldDefinition> get _fields => form?.fields ?? const [];

  /// A section card; item tables carry their own title, so [title] may be empty.
  Widget _card(String title, List<Widget> children) =>
      RequestFormCard(title: title, children: children);

  Widget _banner(Map<String, dynamic> type) {
    final icon = requestIconFor('${type['icon_key']}');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: icon.color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        AsoudIconBox(icon: icon.icon, color: icon.color, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('فرم ${type['workflow_title']}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            Text(
                editing
                    ? 'تا پیش از بررسی می‌توانید درخواست را اصلاح کنید.'
                    : 'لطفاً موارد را تکمیل و ثبت کنید.',
                style: const TextStyle(fontSize: 11, color: AsoudColors.muted)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<
          List<Map<String, dynamic>>>(
      future: options,
      builder: (context, snapshot) {
        final type = selected;
        final chooseType = widget.definition == null;
        final all = _fields;
        final controller = form;
        return AsoudFormPage(
          title:
              type == null ? 'ثبت درخواست جدید' : '${type['workflow_title']}',
          subtitle: editing
              ? 'ویرایش درخواست'
              : '${type?['short_title'] ?? ''}'.isEmpty
                  ? 'ثبت و پیگیری'
                  : '${type!['short_title']}',
          formKey: formKey,
          saving: saving,
          error: error,
          onSave: submit,
          saveLabel: editing ? 'ذخیره تغییرات' : 'ثبت درخواست',
          children: [
            if (chooseType && snapshot.hasError)
              TextButton(
                  onPressed: () =>
                      setState(() => options = widget.repository.options()),
                  child:
                      const Text('دریافت انواع درخواست ناموفق؛ تلاش دوباره')),
            if (chooseType && !snapshot.hasData && !snapshot.hasError)
              const LinearProgressIndicator(),
            if (type != null) _banner(type),
            _card('اطلاعات درخواست', [
              if (chooseType) ...[
                DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(labelText: 'نوع درخواست *'),
                    initialValue: type?['name'] as String?,
                    items: [
                      for (final row in snapshot.data ?? [])
                        DropdownMenuItem(
                            value: '${row['name']}',
                            child: Text('${row['workflow_title']}'))
                    ],
                    validator: (value) =>
                        value == null ? 'نوع درخواست را انتخاب کنید.' : null,
                    onChanged: saving
                        ? null
                        : (value) => setState(() => select(snapshot.data!
                            .firstWhere((row) => row['name'] == value)))),
                if (snapshot.hasData && snapshot.data!.isEmpty)
                  const Text(
                      'گردش‌کار عمومی آماده‌ای برای این دفتر تعریف نشده است.'),
                const SizedBox(height: 12),
              ],
              if (controller == null || controller.subjectMode == 'input')
                AsoudFormField(
                    controller: subject,
                    label: 'عنوان درخواست *',
                    enabled: !saving,
                    validator: (value) => (value?.trim().length ?? 0) < 3 ||
                            (value?.length ?? 0) > 140
                        ? 'عنوان ۳ تا ۱۴۰ نویسه باشد.'
                        : null),
              if (controller != null)
                for (final field in all)
                  if (field.type != 'Item Table' && field.type != 'Attachment')
                    RequestFieldWidget(
                        controller: controller, field: field, enabled: !saving),
            ]),
            if (controller != null)
              for (final field in all)
                if (field.type == 'Item Table')
                  _card('', [
                    RequestFieldWidget(
                        controller: controller, field: field, enabled: !saving)
                  ]),
            if (controller != null && !editing)
              _card('پیوست‌ها', [
                RequestAttachmentsPicker(
                    controller: controller,
                    enabled: !saving,
                    onMessage: (text) => setState(() => error = text)),
                for (final field in all)
                  if (field.type == 'Attachment')
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: RequestFieldWidget(
                            controller: controller,
                            field: field,
                            enabled: !saving)),
              ]),
            if (controller != null && editing)
              for (final field in all)
                if (field.type == 'Attachment')
                  _card('فایل پیوست', [
                    RequestFieldWidget(
                        controller: controller, field: field, enabled: !saving)
                  ]),
            if (!isTemplate)
              Card(
                margin: AsoudFormStyle.sectionMargin,
                child: ExpansionTile(
                  initiallyExpanded: false,
                  maintainState: true,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: AsoudFormStyle.sectionPadding,
                  title: const Text('اطلاعات تکمیلی (اختیاری)',
                      style: AsoudFormStyle.sectionTitle),
                  children: [
                    AsoudFormDropdown(
                        controller: priority,
                        label: 'اولویت',
                        enabled: !saving && !editing,
                        options: const {
                          'Low': 'پایین',
                          'Normal': 'متوسط',
                          'High': 'بالا',
                          'Urgent': 'فوری'
                        }),
                    AsoudFormField(
                        controller: project,
                        label: 'شناسه پروژه',
                        enabled: !saving && !editing),
                    AsoudFormField(
                        controller: department,
                        label: 'شناسه واحد سازمانی',
                        enabled: !saving && !editing),
                    AsoudFormDateField(
                        controller: requiredBy,
                        label: 'تاریخ نیاز',
                        enabled: !saving && !editing),
                  ],
                ),
              ),
          ],
        );
      });
}
