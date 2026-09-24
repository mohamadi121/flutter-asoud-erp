import 'dart:convert';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/generic_request_repository.dart';
import '../../domain/entities/workflow_definition.dart';
import '../widgets/request_link_fields.dart';

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
                              child: ListTile(
                                  title: Text('${row['subject']}'),
                                  subtitle: Text('${row['status']}'),
                                  trailing: const Icon(Icons.chevron_left),
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              GenericRequestDetailPage(
                                                  name: '${row['name']}',
                                                  repository: repository))))),
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
              final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          GenericRequestPage(repository: repository)));
              if (saved == true && mounted) await reload();
            }),
      ));
}

class GenericRequestPage extends StatefulWidget {
  const GenericRequestPage({required this.repository, super.key});
  final GenericRequestRepository repository;
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

  Future<void> submit() async {
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
      await widget.repository.create(payload, requestId);
      if (mounted) Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) => FutureBuilder<
          List<Map<String, dynamic>>>(
      future: options,
      builder: (context, snapshot) => AsoudFormPage(
            title: 'ثبت درخواست جدید',
            subtitle: 'ثبت و پیگیری',
            formKey: formKey,
            saving: saving,
            error: error,
            onSave: submit,
            children: [
              if (snapshot.hasError)
                TextButton(
                    onPressed: () =>
                        setState(() => options = widget.repository.options()),
                    child:
                        const Text('دریافت انواع درخواست ناموفق؛ تلاش دوباره')),
              if (!snapshot.hasData && !snapshot.hasError)
                const LinearProgressIndicator(),
              AsoudFormSection(title: 'اطلاعات اصلی', children: [
                DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(labelText: 'نوع درخواست *'),
                    initialValue: selected?['name'] as String?,
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
                        : (value) => setState(() {
                              selected = snapshot.data!
                                  .firstWhere((row) => row['name'] == value);
                              for (final controller in fields.values) {
                                controller.clear();
                              }
                              values.clear();
                              for (final field in selected!['fields'] as List) {
                                if (field['type'] == 'Checkbox') {
                                  values[field['key']] = false;
                                }
                                // Defaults set in the request type builder.
                                final initial =
                                    '${field['default_value'] ?? ''}';
                                if (initial.isEmpty) continue;
                                if (field['type'] == 'Multi Choice') {
                                  values[field['key']] = [initial];
                                } else {
                                  values[field['key']] = initial;
                                  fields[field['key']]?.text = initial;
                                }
                              }
                            })),
                if (snapshot.hasData && snapshot.data!.isEmpty)
                  const Text(
                      'گردش‌کار عمومی آماده‌ای برای این دفتر تعریف نشده است.'),
                AsoudFormField(
                    controller: subject,
                    label: 'عنوان درخواست *',
                    enabled: !saving,
                    validator: (value) => (value?.trim().length ?? 0) < 3 ||
                            (value?.length ?? 0) > 140
                        ? 'عنوان ۳ تا ۱۴۰ نویسه باشد.'
                        : null),
                AsoudFormDropdown(
                    controller: priority,
                    label: 'اولویت',
                    enabled: !saving,
                    options: const {
                      'Low': 'پایین',
                      'Normal': 'متوسط',
                      'High': 'بالا',
                      'Urgent': 'فوری'
                    }),
                AsoudFormField(
                    controller: project,
                    label: 'شناسه پروژه',
                    enabled: !saving),
                AsoudFormField(
                    controller: department,
                    label: 'شناسه واحد سازمانی',
                    enabled: !saving),
                AsoudFormDateField(
                    controller: requiredBy,
                    label: 'تاریخ نیاز',
                    enabled: !saving),
              ]),
              AsoudFormSection(title: 'پیوست‌ها', children: [
                for (final file in attachments)
                  ListTile(
                      title: Text(file['filename']!),
                      trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: saving
                              ? null
                              : () => setState(() {
                                    values.removeWhere((key, value) =>
                                        value ==
                                        'attachment:${file['filename']}');
                                    attachments.remove(file);
                                  }))),
                TextButton.icon(
                    onPressed: saving ? null : pickFiles,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('افزودن فایل خصوصی')),
              ]),
              if (selected != null)
                AsoudFormSection(title: 'اطلاعات درخواست', children: [
                  for (final raw in selected!['fields'] as List? ?? [])
                    dynamicField(raw as Map)
                ]),
            ],
          ));
}

class GenericRequestDetailPage extends StatefulWidget {
  const GenericRequestDetailPage(
      {required this.name, required this.repository, super.key});
  final String name;
  final GenericRequestRepository repository;
  @override
  State<GenericRequestDetailPage> createState() =>
      _GenericRequestDetailPageState();
}

class _GenericRequestDetailPageState extends State<GenericRequestDetailPage> {
  late Future<Map<String, dynamic>> future =
      widget.repository.detail(widget.name);
  Future<void> download(Map file) async {
    try {
      final result = file['content_base64'] != null
          ? file
          : await widget.repository
              .read('get_attachment', {'name': file['name']}) as Map;
      await FilePicker.platform.saveFile(
          fileName: '${result['filename']}',
          bytes: base64Decode('${result['content_base64']}'));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('دریافت فایل ممکن نشد.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: const AsoudHeader(
          title: 'جزئیات درخواست', subtitle: 'وضعیت ثبت و اجرا'),
      body: FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: TextButton(
                      onPressed: () => setState(() {
                            future = widget.repository.detail(widget.name);
                          }),
                      child: const Text('دریافت ناموفق؛ تلاش دوباره')));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return ListView(padding: const EdgeInsets.all(16), children: [
              ListTile(
                  title: Text('${data['subject']}'),
                  subtitle: Text('${data['status']}')),
              if (data['pending_sync'] == true)
                const Text(
                    'اطلاعات روی دستگاه محفوظ است؛ اجرای گردش‌کار پس از تأیید سرور انجام می‌شود.'),
              if (data['error'] != null)
                const Text(
                    'سرور درخواست را نپذیرفته است؛ مقادیر و مجوزهای درخواست نیازمند بررسی‌اند.'),
              for (final entry in {
                'اولویت': data['priority'],
                'تاریخ نیاز': data['required_by'],
                'پروژه': data['project'],
                'واحد': data['department'],
                'گردش‌کار': data['workflow_instance'],
                ...Map<String, dynamic>.from(data['values'] as Map? ?? {})
              }.entries)
                ListTile(
                    title: Text(entry.key),
                    subtitle: Text(formatRequestValue(entry.value))),
              for (final file in data['attachments'] as List? ?? [])
                ListTile(
                    title: Text('${file['filename']}'),
                    trailing: const Icon(Icons.download),
                    onTap: () => download(file as Map)),
            ]);
          }));
}
