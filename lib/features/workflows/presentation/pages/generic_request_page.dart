import 'dart:convert';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/generic_request_repository.dart';
import '../../../request_types/domain/request_type_catalog.dart';
import '../../domain/entities/workflow_definition.dart';
import '../widgets/request_link_fields.dart';
import 'request_flow_pages.dart';

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
  late Future<List<Map<String, dynamic>>> future = repository.list();
  Timer? _retryTimer;
  bool _retrying = false;
  @override
  void initState() {
    super.initState();
    _retryTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (_retrying || !mounted) return;
      _retrying = true;
      try {
        if ((await repository.pending()).isNotEmpty) await reload();
      } catch (_) {
        // Keep durable pending requests; the next interval or manual refresh retries.
      } finally {
        _retrying = false;
      }
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    if (widget.repository == null) repository.dispose();
    super.dispose();
  }

  Future<void> reload({bool retry = false}) async {
    if (retry) await repository.sync(retry: true);
    if (mounted) {
      setState(() {
        future = repository.list();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AsoudHeader(
            title: 'درخواست‌های من', subtitle: 'ثبت و پیگیری درخواست‌ها'),
        body: FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: TextButton(
                        onPressed: reload,
                        child: const Text('دریافت ناموفق؛ تلاش دوباره')));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (snapshot.data!
                            .any((row) => row['pending_sync'] == true))
                          TextButton(
                              onPressed: () async {
                                try {
                                  await reload(retry: true);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'اتصال برقرار نشد؛ داده‌ها محفوظ‌اند.')));
                                  }
                                }
                              },
                              child: const Text('تلاش مجدد برای همگام‌سازی')),
                        for (final row in snapshot.data!)
                          Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                  title: Text('${row['subject']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  subtitle: Text([
                                    '${row['request_type'] ?? ''}',
                                    if ('${row['creation'] ?? ''}'.isNotEmpty)
                                      formatJalaliIso('${row['creation']}'),
                                  ]
                                      .where((part) => part.isNotEmpty)
                                      .join(' · ')),
                                  trailing: RequestStatusChip(row),
                                  onTap: () async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                            builder: (_) => RequestDetailPage(
                                                name: '${row['name']}',
                                                repository: repository)));
                                    await reload();
                                  })),
                        if (snapshot.data!.isEmpty)
                          const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('هنوز درخواستی ثبت نشده است.')),
                      ]));
            }),
        floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('درخواست جدید'),
            onPressed: () async {
              final type = await pickRequestType(context, repository);
              if (type == null || !context.mounted) return;
              final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => GenericRequestPage(
                          repository: repository, definition: type)));
              if (saved == true && mounted) await reload();
            }),
      ));
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
  final definition = TextEditingController();
  final fields = <String, TextEditingController>{};
  final values = <String, dynamic>{};
  final attachments = <Map<String, String>>[];
  late Future<List<Map<String, dynamic>>> options = widget.repository.options();
  Map<String, dynamic>? selected;
  String? error;
  bool saving = false;
  final requestId = GenericRequestRepository.requestId();
  bool get editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final definition = widget.definition;
    if (definition != null) select(definition);
    final existing = widget.existing;
    if (existing != null) {
      subject.text = '${existing['subject'] ?? ''}';
      values
        ..clear()
        ..addAll(Map<String, dynamic>.from(existing['values'] as Map? ?? {}));
    }
  }

  /// Switches to a request type and applies its field defaults.
  void select(Map<String, dynamic> row) {
    selected = row;
    for (final controller in fields.values) {
      controller.clear();
    }
    values.clear();
    for (final field in row['fields'] as List? ?? const []) {
      if (field['type'] == 'Checkbox') {
        values[field['key']] = false;
      }
      // Defaults set in the request type builder.
      final initial = '${field['default_value'] ?? ''}';
      if (initial.isEmpty) continue;
      if (field['type'] == 'Multi Choice') {
        values[field['key']] = [initial];
      } else {
        values[field['key']] = initial;
        fields[field['key']]?.text = initial;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      subject,
      project,
      department,
      requiredBy,
      priority,
      definition,
      ...fields.values
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository
          .update('${widget.existing!['name']}', subject.text.trim(), values);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() =>
            error = e is ApiException ? e.message : 'ذخیره تغییرات انجام نشد.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> submit() async {
    if (editing) return save();
    if (saving || !formKey.currentState!.validate() || selected == null) return;
    final payload = <String, dynamic>{
      'workflow_definition': selected!['name'],
      'subject': subject.text.trim(),
      'priority': priority.text,
      'project': project.text.trim(),
      'department': department.text.trim(),
      if (requiredBy.text.isNotEmpty) 'required_by': requiredBy.text,
      'values': values,
      'attachments': attachments,
    };
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('بررسی درخواست'),
                content: Text(
                    '${subject.text}\n${selected!['workflow_title']}\nتعداد پیوست: ${attachments.length}'),
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

  Future<void> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          withData: true,
          type: FileType.custom,
          allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'xlsx', 'docx']);
      if (result == null || !mounted) return;
      final total = attachments.fold<int>(
              0,
              (sum, file) =>
                  sum + base64Decode(file['content_base64']!).length) +
          result.files.fold<int>(0, (sum, file) => sum + file.size);
      if (attachments.length + result.files.length > 10 ||
          total > 25 * 1024 * 1024 ||
          result.files.any(
              (file) => file.bytes == null || file.size > 10 * 1024 * 1024)) {
        throw const FormatException();
      }
      if (result.files.any(
          (file) => attachments.any((old) => old['filename'] == file.name))) {
        throw const FormatException();
      }
      setState(() {
        for (final file in result.files) {
          attachments.add({
            'filename': file.name,
            'content_base64': base64Encode(file.bytes!)
          });
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'حداکثر ۱۰ فایل با نام متفاوت، هر فایل تا ۱۰ و مجموع تا ۲۵ مگابایت انتخاب کنید.');
      }
    }
  }

  Widget dynamicField(Map raw) {
    final field = WorkflowFormFieldDefinition.fromMap(raw);
    final controller = fields.putIfAbsent(field.key, () {
      final initial = values[field.key];
      final c = TextEditingController(text: initial is String ? initial : '');
      c.addListener(() => values[field.key] = c.text);
      return c;
    });
    String? validate(String? value) =>
        field.required && (value == null || value.trim().isEmpty)
            ? 'این فیلد الزامی است.'
            : null;
    if (field.type == 'Checkbox') {
      return SwitchListTile(
          title: Text(field.label),
          value: values[field.key] == true,
          onChanged: saving
              ? null
              : (value) => setState(() => values[field.key] = value));
    }
    if (field.type == 'Choice' || field.type == 'Attachment') {
      return DropdownButtonFormField<String>(
          key: ValueKey(
              '${selected!['name']}:${field.key}:${attachments.length}'),
          initialValue: values[field.key] as String?,
          decoration: InputDecoration(labelText: field.label),
          validator: validate,
          items: [
            for (final option in field.type == 'Choice'
                ? field.options
                : attachments
                    .map((file) => 'attachment:${file['filename']}')
                    .toList())
              DropdownMenuItem(
                  value: option,
                  child: Text(option.replaceFirst('attachment:', '')))
          ],
          onChanged: saving
              ? null
              : (value) => setState(() => values[field.key] = value));
    }
    final key = ValueKey('${selected!['name']}:${field.key}');
    if (field.type == 'Multi Choice') {
      return RequestMultiChoiceField(
          key: key,
          label: field.label,
          options: field.options,
          required: field.required,
          enabled: !saving,
          initialValue: (values[field.key] as List?)?.cast<String>(),
          onChanged: (value) => values[field.key] = value);
    }
    if (field.type == 'User' || field.type == 'Department') {
      return RequestLinkField(
          key: key,
          label: field.label,
          required: field.required,
          enabled: !saving,
          loader: (txt) => widget.repository.fieldOptions(field.type, txt: txt),
          onChanged: (value) => values[field.key] = value);
    }
    if (field.type == 'Item Table') {
      return RequestItemTableField(
          key: key,
          label: field.label,
          required: field.required,
          enabled: !saving,
          items: (txt) => widget.repository.fieldOptions('Item', txt: txt),
          uoms: (itemCode) =>
              widget.repository.fieldOptions('UOM', itemCode: itemCode),
          onChanged: (rows) => values[field.key] = rows);
    }
    if (field.type == 'Date') {
      return AsoudFormDateField(
          controller: controller,
          label: field.label,
          required: field.required,
          enabled: !saving);
    }
    return TextFormField(
        key: ValueKey('${selected!['name']}:${field.key}'),
        controller: controller,
        enabled: !saving,
        maxLines: field.type == 'Long Text' ? 4 : 1,
        decoration: InputDecoration(labelText: field.label),
        keyboardType: ['Number', 'Currency'].contains(field.type)
            ? TextInputType.number
            : null,
        onChanged: (value) => values[field.key] = value,
        validator: (value) {
          final missing = validate(value);
          if (missing != null) return missing;
          if (['Number', 'Currency'].contains(field.type) &&
              (value ?? '').isNotEmpty) {
            final number = num.tryParse(value!);
            if (number == null || !number.isFinite) {
              return 'عدد معتبر وارد کنید.';
            }
          }
          return null;
        });
  }

  List<Map> get _fieldDefs =>
      [for (final raw in selected?['fields'] as List? ?? const []) raw as Map];

  /// A section card; item tables carry their own title, so [title] may be empty.
  Widget _card(String title, List<Widget> children) => Card(
        margin: AsoudFormStyle.sectionMargin,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (title.isNotEmpty) ...[
              Text(title, style: AsoudFormStyle.sectionTitle),
              const SizedBox(height: 12),
            ],
            ...children,
          ]),
        ),
      );

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

  Widget _dropzone() => InkWell(
        onTap: saving ? null : pickFiles,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: AsoudColors.primary.withValues(alpha: .04),
              border:
                  Border.all(color: AsoudColors.primary.withValues(alpha: .35)),
              borderRadius: BorderRadius.circular(14)),
          child: const Column(children: [
            AsoudIconBox(
                icon: Icons.attach_file_rounded,
                color: AsoudColors.primary,
                size: 44),
            SizedBox(height: 8),
            Text('فایل یا فایل‌ها را انتخاب کنید',
                style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('فرمت‌های مجاز: PDF، JPG، PNG، XLSX، DOCX',
                style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
            Text('حداکثر حجم هر فایل: ۱۰ مگابایت',
                style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<
          List<Map<String, dynamic>>>(
      future: options,
      builder: (context, snapshot) {
        final type = selected;
        final chooseType = widget.definition == null;
        final all = _fieldDefs;
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
              AsoudFormField(
                  controller: subject,
                  label: 'عنوان درخواست *',
                  enabled: !saving,
                  validator: (value) => (value?.trim().length ?? 0) < 3 ||
                          (value?.length ?? 0) > 140
                      ? 'عنوان ۳ تا ۱۴۰ نویسه باشد.'
                      : null),
              for (final raw in all)
                if (raw['type'] != 'Item Table' && raw['type'] != 'Attachment')
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: dynamicField(raw)),
            ]),
            for (final raw in all)
              if (raw['type'] == 'Item Table') _card('', [dynamicField(raw)]),
            if (!editing)
              _card('پیوست‌ها', [
                _dropzone(),
                for (final file in attachments)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.insert_drive_file_outlined,
                          color: AsoudColors.warning),
                      title: Text(file['filename']!,
                          style: const TextStyle(fontSize: 12)),
                      subtitle: Text(
                          '${toPersianDigits((base64Decode(file['content_base64']!).length / 1024).ceil())} کیلوبایت',
                          style: const TextStyle(fontSize: 10)),
                      trailing: IconButton(
                          tooltip: 'حذف فایل',
                          icon: const Icon(Icons.close),
                          onPressed: saving
                              ? null
                              : () => setState(() {
                                    values.removeWhere((key, value) =>
                                        value ==
                                        'attachment:${file['filename']}');
                                    attachments.remove(file);
                                  }))),
                for (final raw in all)
                  if (raw['type'] == 'Attachment')
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: dynamicField(raw)),
              ]),
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
