import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../data/workflow_automation_repository.dart';
import '../../domain/entities/automatic_action.dart';
import '../../domain/entities/workflow_definition.dart';

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : [];
const _numeric = {'Number', 'Currency', 'Int', 'Float', 'Percent'};
const _textTypes = {
  'Text',
  'Data',
  'Short Text',
  'Long Text',
  'Small Text',
  'SmallText',
  'Select'
};

class AutomaticActionPage extends StatefulWidget {
  const AutomaticActionPage(
      {required this.stage,
      required this.design,
      required this.repository,
      required this.initialRoutes,
      required this.onSaved,
      super.key});
  final WorkflowStage stage;
  final WorkflowDesign design;
  final WorkflowAutomationRepository repository;
  final Map<String, String> initialRoutes;
  final Future<void> Function() onSaved;

  @override
  State<AutomaticActionPage> createState() => _AutomaticActionPageState();
}

class _AutomaticActionPageState extends State<AutomaticActionPage> {
  late final title = TextEditingController(text: widget.stage.title);
  late final description = TextEditingController(
      text: widget.stage.config['description']?.toString() ?? '');
  final message = TextEditingController();
  final formula = TextEditingController();
  final extra = TextEditingController(text: '0');
  final interval = TextEditingController(text: '60');
  final timeout = TextEditingController(text: '120');
  AutomaticActionType type = AutomaticActionType.createRequest;
  Map<String, dynamic>? metadata;
  String? error;
  bool loading = true,
      saving = false,
      linkOriginal = true,
      metadataFromCache = false;
  String destination = '', targetStage = '', field = '', transition = '';
  String method = 'sum',
      initialState = 'Draft',
      relationship = 'related',
      missing = 'error';
  String success = '', failure = '';
  Map<String, ActionMapping> mapping = {};
  Map<String, ActionMapping> inputs = {};
  ActionMapping? lookup;
  Set<String> recipients = {}, channels = {'in_app'};

  @override
  void initState() {
    super.initState();
    success = widget.initialRoutes['Success'] ?? '';
    failure = widget.initialRoutes['Error'] ?? '';
    _restoreConfig(widget.stage.config);
    for (final controller in _controllers) {
      controller.addListener(_changed);
    }
    _load();
  }

  void _restoreConfig(Map<String, dynamic> config,
      {Map<String, dynamic>? routes}) {
    title.text = (config['title'] ?? widget.stage.title).toString();
    description.text = (config['description'] ?? '').toString();
    final exits = routes ?? const <String, dynamic>{};
    success = (exits['Success'] ?? success).toString();
    failure = (exits['Error'] ?? failure).toString();
    if (config['schema_version'] == 2) {
      type = AutomaticActionType.parse(config['action_type'].toString());
      final op = _map(config['operation']);
      destination = (op['request_type'] ?? op['doctype'] ?? '').toString();
      targetStage = _map(op['target'])['stage']?.toString() ?? '';
      field = (op['field'] ?? op['lookup_field'] ?? '').toString();
      transition = op['transition']?.toString() ?? '';
      method = op['method']?.toString() ?? 'sum';
      initialState = op['initial_state']?.toString() ?? 'Draft';
      relationship = op['relationship']?.toString() ?? 'related';
      missing = op['missing']?.toString() ?? 'error';
      linkOriginal = op['link_original'] != false;
      message.text = op['message']?.toString() ?? '';
      formula.text = op['formula']?.toString() ?? '';
      mapping = _map(op['mapping']).map(
          (key, value) => MapEntry(key, ActionMapping.fromJson(_map(value))));
      inputs = _map(op['inputs']).map(
          (key, value) => MapEntry(key, ActionMapping.fromJson(_map(value))));
      if (op['lookup'] != null) {
        lookup = ActionMapping.fromJson(_map(op['lookup']));
      }
      recipients = ((op['recipients'] as List?) ?? []).map((e) => '$e').toSet();
      channels =
          ((op['channels'] as List?) ?? ['in_app']).map((e) => '$e').toSet();
      final policy = _map(config['execution']);
      extra.text = '${policy['extra_attempts'] ?? 0}';
      interval.text = '${policy['retry_seconds'] ?? 60}';
      timeout.text = '${policy['timeout_seconds'] ?? 120}';
    }
  }

  List<TextEditingController> get _controllers =>
      [title, description, message, formula, extra, interval, timeout];
  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.repository
          .automaticActionOptions(widget.design.workflow.id, widget.stage.id);
      if (result.data['schema_version'] != 2) {
        throw StateError('نسخه سرور از این فرم پشتیبانی نمی‌کند.');
      }
      if (mounted) {
        setState(() {
          metadata = result.data;
          metadataFromCache = result.fromCache;
          error = result.connectionError;
          final draft = result.pendingDraft;
          if (draft != null) {
            _restoreConfig(_map(draft['config']), routes: _map(draft['routes']));
          }
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is ApiException &&
                  e.kind != ApiFailureKind.network &&
                  e.kind != ApiFailureKind.timeout &&
                  e.kind != ApiFailureKind.server
              ? e.message
              : 'دریافت تنظیمات از سرور ناموفق بود؛ اتصال، دسترسی یا نسخهٔ API را بررسی کنید.';
          loading = false;
        });
      }
    }
  }

  Map<String, dynamic> get sources => _map(metadata?['sources']);
  List<Map<String, dynamic>> get prior => _rows(sources['stages']);
  ActionTarget get target => targetStage.isEmpty
      ? const ActionTarget.current()
      : ActionTarget.stage(targetStage);
  List<Map<String, dynamic>> get destinationOptions =>
      _rows(metadata?[switch (type) {
        AutomaticActionType.createRequest => 'requests',
        AutomaticActionType.createDocument => 'documents',
        _ => 'records',
      }]);
  List<Map<String, dynamic>> get writable => targetStage.isEmpty
      ? _rows(sources['writable'])
      : _rows(
          prior.where((s) => s['id'] == targetStage).firstOrNull?['writable']);
  String get targetDoctype => targetStage.isEmpty
      ? widget.design.workflow.targetDoctype
      : prior
              .where((s) => s['id'] == targetStage)
              .firstOrNull?['doctype']
              ?.toString() ??
          '';
  List<Map<String, dynamic>> get fields =>
      type == AutomaticActionType.updateFields ||
              type == AutomaticActionType.calculate
          ? writable
          : _rows(destinationOptions
              .where((d) => d['id'] == destination)
              .firstOrNull?['fields']);
  List<String> get transitions =>
      ((_map(metadata?['transitions'])[targetDoctype] as List?) ?? [])
          .map((e) => '$e')
          .toList();
  ActionExecutionPolicy get policy => ActionExecutionPolicy(
      extraAttempts: int.tryParse(toLatinDigits(extra.text)) ?? -1,
      retrySeconds: int.tryParse(toLatinDigits(interval.text)) ?? -1,
      timeoutSeconds: int.tryParse(toLatinDigits(timeout.text)) ?? -1);

  String? get problem {
    if (metadata == null) {
      return 'اطلاعات معتبر سرور لازم است.';
    }
    if (title.text.trim().length < 2) {
      return 'عنوان مرحله را وارد کنید.';
    }
    if (!policy.valid) {
      return 'بازهٔ تنظیمات تلاش مجدد یا مهلت فنی معتبر نیست.';
    }
    if (!widget.design.stages.any((s) =>
        s.id == success &&
        s.id != widget.stage.id &&
        s.type != WorkflowStageType.start)) {
      return 'مرحلهٔ مقصد موفقیت را انتخاب کنید.';
    }
    if (failure.isNotEmpty &&
        !widget.design.stages.any(
            (s) => s.id == failure && s.type == WorkflowStageType.userTask)) {
      return 'مسیر خطا باید یک وظیفهٔ کاربر موجود باشد.';
    }
    if (type == AutomaticActionType.createRequest ||
        type == AutomaticActionType.createDocument ||
        type == AutomaticActionType.link) {
      if (!destinationOptions.any((d) => d['id'] == destination)) {
        return 'نوع رکورد مقصد را انتخاب کنید.';
      }
    }
    if (type == AutomaticActionType.createRequest ||
        type == AutomaticActionType.createDocument ||
        type == AutomaticActionType.updateFields) {
      if (mapping.isEmpty) {
        return 'حداقل یک نگاشت فیلد اضافه کنید.';
      }
      if (mapping.keys.any((key) => !fields.any((f) => f['key'] == key))) {
        return 'یکی از فیلدهای نگاشت دیگر قابل استفاده نیست.';
      }
      if (type != AutomaticActionType.updateFields &&
          fields.any(
              (f) => f['required'] == true && !mapping.containsKey(f['key']))) {
        return 'نگاشت فیلدهای اجباری را تکمیل کنید.';
      }
    }
    if (type == AutomaticActionType.changeStatus &&
        !transitions.contains(transition)) {
      return 'انتقال معتبر را انتخاب کنید.';
    }
    if (type == AutomaticActionType.notify &&
        (recipients.isEmpty ||
            channels.isEmpty ||
            message.text.trim().isEmpty)) {
      return 'گیرندگان، کانال و متن اعلان را مشخص کنید.';
    }
    if (type == AutomaticActionType.notify) {
      final variables = RegExp(r'\{\{\s*([a-z][a-z0-9_]*)\s*\}\}');
      final allowed = _rows(sources['current'])
          .where((f) => !{'Table', 'Item Table'}.contains(f['type']))
          .map((f) => f['key'])
          .toSet();
      final remaining = message.text.replaceAll(variables, '');
      if (remaining.contains('{{') ||
          remaining.contains('}}') ||
          variables
              .allMatches(message.text)
              .any((m) => !allowed.contains(m.group(1)))) {
        return 'متغیر پیام معتبر نیست؛ از نام فیلدهای نمایش‌داده‌شده استفاده کنید.';
      }
    }
    if (type == AutomaticActionType.calculate &&
        (!fields.any(
                (f) => f['key'] == field && _numeric.contains(f['type'])) ||
            inputs.isEmpty ||
            method == 'formula' && formula.text.trim().isEmpty)) {
      return 'فیلد عددی، ورودی‌ها و روش محاسبه را تکمیل کنید.';
    }
    if (type == AutomaticActionType.calculate && method == 'formula') {
      final expression = toLatinDigits(formula.text.trim());
      if (!RegExp(r'^[a-z0-9_\s.()+*/\-]+$').hasMatch(expression) ||
          RegExp(r'[a-z][a-z0-9_]*')
              .allMatches(expression)
              .any((m) => !inputs.containsKey(m.group(0)))) {
        return 'فرمول فقط می‌تواند شامل ورودی‌های نگاشت‌شده و چهار عمل اصلی باشد.';
      }
    }
    if (type == AutomaticActionType.link &&
        (lookup == null || !fields.any((f) => f['key'] == field))) {
      return 'روش یافتن رکورد را تکمیل کنید.';
    }
    return null;
  }

  AutomaticOperation get operation => switch (type) {
        AutomaticActionType.createRequest => CreateRequestOperation(
            destination, mapping,
            linkOriginal: linkOriginal),
        AutomaticActionType.createDocument => CreateDocumentOperation(
            destination, mapping,
            initialState: initialState, linkOriginal: linkOriginal),
        AutomaticActionType.updateFields =>
          UpdateFieldsOperation(target, mapping),
        AutomaticActionType.changeStatus =>
          ChangeStatusOperation(target, transition),
        AutomaticActionType.notify =>
          NotifyOperation(recipients, channels, message.text.trim()),
        AutomaticActionType.calculate => CalculateOperation(
            target, field, method, inputs,
            formula: toLatinDigits(formula.text.trim())),
        AutomaticActionType.link => LinkRecordOperation(
            target, destination, field, lookup!,
            relationship: relationship, missing: missing),
      };

  Future<bool> _confirmReset() async =>
      await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('تغییر تنظیمات عملیات'),
                content: const Text(
                    'تنظیمات اختصاصی و نگاشت قبلی پاک می‌شوند. ادامه می‌دهید؟'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('تغییر و پاک‌کردن'))
                ],
              )) ??
      false;

  Future<void> _changeType(AutomaticActionType value) async {
    if (type == value || !await _confirmReset() || !mounted) {
      return;
    }
    setState(() {
      type = value;
      destination = '';
      targetStage = '';
      field = '';
      transition = '';
      mapping = {};
      inputs = {};
      lookup = null;
      recipients = {};
      channels = {'in_app'};
      message.clear();
      formula.clear();
      method = 'sum';
      initialState = 'Draft';
      relationship = 'related';
      missing = 'error';
      linkOriginal = true;
      error = null;
    });
  }

  Future<void> _changeDestination(String value, {bool isTarget = false}) async {
    if ((mapping.isNotEmpty ||
            inputs.isNotEmpty ||
            lookup != null ||
            transition.isNotEmpty) &&
        !await _confirmReset()) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      if (isTarget) {
        targetStage = value;
      } else {
        destination = value;
      }
      mapping = {};
      inputs = {};
      lookup = null;
      field = '';
      transition = '';
    });
  }

  Future<void> _save() async {
    if (problem != null || saving) {
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.saveAutomaticAction(
          definition: widget.design.workflow.id,
          stage: widget.stage.id,
          config: {
            'title': title.text.trim(),
            'description': description.text.trim(),
            'schema_version': 2,
            'action_type': type.key,
            'operation': operation.toJson(),
            'execution': policy.toJson()
          },
          routes: {
            'Success': success,
            'Error': failure
          });
      await widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is ApiException &&
                  (e.kind == ApiFailureKind.network ||
                      e.kind == ApiFailureKind.timeout ||
                      e.kind == ApiFailureKind.server)
              ? 'ارتباط با سرور برقرار نشد؛ تغییرات در صف محلی ذخیره شده و پس از اتصال دوباره همگام می‌شوند.'
              : e is ApiException
                  ? e.message
                  : 'ذخیره ناموفق بود؛ تنظیمات شما حفظ شده‌اند.';
          saving = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error!)));
      }
    }
  }

  Widget _select(String label, String value, Map<String, String> choices,
          ValueChanged<String> change) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
            key: ValueKey('$label:$value:${choices.keys.join(',')}'),
            initialValue: choices.containsKey(value) ? value : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: choices.entries
                .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: saving || choices.isEmpty
                ? null
                : (value) {
                    if (value != null) {
                      change(value);
                    }
                  },
          ));

  Widget _notice(String text, {bool warning = false}) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: warning ? const Color(0xfffff5e5) : const Color(0xffedf4ff),
          borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: const TextStyle(fontSize: 12, height: 1.7)));

  Future<void> _editMapping(Map<String, dynamic> destinationField,
      {bool input = false, bool forLookup = false}) async {
    final key = destinationField['key'] as String;
    final selected = await showModalBottomSheet<ActionMapping>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (context) => _MappingSheet(
            field: destinationField,
            sources: sources,
            initial: forLookup ? lookup : (input ? inputs : mapping)[key]));
    if (selected != null && mounted) {
      setState(() {
        if (forLookup) {
          lookup = selected;
        } else {
          (input ? inputs : mapping)[key] = selected;
        }
      });
    }
  }

  Widget _mappingRow(Map<String, dynamic> f,
      {bool input = false, bool forLookup = false}) {
    final value = forLookup ? lookup : (input ? inputs : mapping)[f['key']];
    var sourceTitle = value == null ? '' : _sourceLabel(value.source);
    if (value != null && value.source == ActionSource.stage) {
      final previous = prior.where((s) => s['id'] == value.stage).firstOrNull;
      sourceTitle = (previous?['label'] ?? value.stage ?? '').toString();
    }
    return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(
              '${f['label'] ?? f['key']}${f['required'] == true ? ' *' : ''}',
              style: const TextStyle(fontSize: 13)),
          subtitle: Text(
              value == null
                  ? 'انتخاب منبع مقدار'
                  : '$sourceTitle · ${f['type'] == 'Date' && value.source == ActionSource.constant ? formatJalaliIso(value.value.toString()) : value.value}\n'
                      '${value.transform == 'none' ? 'بدون تبدیل' : value.transform} · ${value.empty == 'error' ? 'خالی: خطا' : 'خالی: نادیده بگیر'}',
              style: const TextStyle(fontSize: 11)),
          onTap: saving
              ? null
              : () => _editMapping(f, input: input, forLookup: forLookup),
          trailing: value == null
              ? const Icon(Icons.chevron_left)
              : IconButton(
                  tooltip: 'حذف نگاشت',
                  icon: const Icon(Icons.close),
                  onPressed: saving
                      ? null
                      : () => setState(() {
                            if (forLookup) {
                              lookup = null;
                            } else {
                              (input ? inputs : mapping).remove(f['key']);
                            }
                          })),
        ));
  }

  Future<void> _pickRecipients() async {
    final picked = {...recipients};
    final users = [
      {'id': 'initiator', 'label': 'درخواست‌کننده'},
      ..._rows(metadata?['users'])
    ];
    final result = await showModalBottomSheet<Set<String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
            builder: (context, change) => Directionality(
                textDirection: TextDirection.rtl,
                child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * .7,
                    child: Column(children: [
                      const ListTile(title: Text('گیرندگان اعلان')),
                      Expanded(
                          child: ListView(children: [
                        for (final user in users)
                          CheckboxListTile(
                              title: Text('${user['label']}'),
                              value: picked.contains(user['id']),
                              onChanged: (value) => change(() {
                                    value == true
                                        ? picked.add('${user['id']}')
                                        : picked.remove(user['id']);
                                  }))
                      ])),
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: FilledButton(
                              onPressed: () =>
                                  Navigator.pop(sheetContext, picked),
                              child: const Text('تأیید گیرندگان'))),
                    ])))));
    if (result != null && mounted) {
      setState(() => recipients = result);
    }
  }

  List<Widget> _operationFields() {
    final targeted = {
      AutomaticActionType.updateFields,
      AutomaticActionType.changeStatus,
      AutomaticActionType.calculate,
      AutomaticActionType.link
    }.contains(type);
    return [
      if (targeted)
        _select(
            'رکورد هدف',
            targetStage,
            {
              '': 'موجودیت فعلی',
              for (final row in prior.where((s) => s['doctype'] != null))
                '${row['id']}': '${row['label']}'
            },
            (v) => _changeDestination(v, isTarget: true)),
      if (type == AutomaticActionType.createRequest ||
          type == AutomaticActionType.createDocument ||
          type == AutomaticActionType.link)
        _select(
            type == AutomaticActionType.createRequest
                ? 'نوع درخواست'
                : 'نوع سند / رکورد',
            destination,
            {for (final d in destinationOptions) '${d['id']}': '${d['label']}'},
            (v) => _changeDestination(v)),
      if (type == AutomaticActionType.createDocument)
        _select(
            'وضعیت اولیه',
            initialState,
            {'Draft': 'پیش‌نویس', 'Submitted': 'ثبت قطعی با مجوز سرور'},
            (v) => setState(() => initialState = v)),
      if ({
        AutomaticActionType.createRequest,
        AutomaticActionType.createDocument,
        AutomaticActionType.updateFields
      }.contains(type)) ...[
        for (final f in fields) _mappingRow(f),
        if (fields.isEmpty)
          _notice('پس از انتخاب مقصد، فیلدهای قابل نگاشت نمایش داده می‌شوند.'),
      ],
      if (type == AutomaticActionType.createRequest ||
          type == AutomaticActionType.createDocument)
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('اتصال به موجودیت اصلی'),
            subtitle:
                const Text('رکورد مستقل ساخته و پیوند آن در سوابق ثبت می‌شود.'),
            value: linkOriginal,
            onChanged: saving ? null : (v) => setState(() => linkOriginal = v)),
      if (type == AutomaticActionType.changeStatus) ...[
        _select('انتقال وضعیت', transition, {for (final t in transitions) t: t},
            (v) => setState(() => transition = v)),
        _notice(
            'این فهرست از گردش‌کار استاندارد سرور خوانده می‌شود. وضعیت رکورد، شرط انتقال و مجوز کاربر سیستمی هنگام اجرا دوباره بررسی می‌شوند.'),
      ],
      if (type == AutomaticActionType.notify) ...[
        Card(
            child: ListTile(
                title: const Text('انتخاب گیرندگان'),
                subtitle: Text('${recipients.length} گیرنده'),
                trailing: const Icon(Icons.people_outline),
                onTap: saving ? null : _pickRecipients)),
        Wrap(spacing: 8, children: [
          for (final c
              in const {'in_app': 'اعلان داخلی', 'email': 'ایمیل'}.entries)
            FilterChip(
                label: Text(c.value),
                selected: channels.contains(c.key),
                onSelected: saving
                    ? null
                    : (v) => setState(() {
                          v ? channels.add(c.key) : channels.remove(c.key);
                        }))
        ]),
        TextButton(
            onPressed: saving
                ? null
                : () {
                    message.text = 'درخواست {{subject}} بررسی شد.';
                  },
            child: const Text('استفاده از متن پیشنهادی')),
        TextField(
            controller: message,
            enabled: !saving,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'متن پیام')),
        _notice('متغیرها: ${_rows(sources['current']).where((f) => !{
              'Table',
              'Item Table'
            }.contains(f['type'])).map((f) => '{{${f['key']}}}').join('، ')}'),
        _notice(
            'خطای هر کانال جدا ثبت می‌شود. ایمیل ابتدا وارد صف ارسال سرور می‌شود.'),
      ],
      if (type == AutomaticActionType.calculate) ...[
        _select(
            'فیلد مقصد عددی',
            field,
            {
              for (final f in fields.where((f) => _numeric.contains(f['type'])))
                '${f['key']}': '${f['label']}'
            },
            (v) => setState(() {
                  field = v;
                  inputs = {};
                })),
        _select(
            'روش محاسبه',
            method,
            {'sum': 'جمع', 'average': 'میانگین', 'formula': 'فرمول محدود'},
            (v) => setState(() {
                  method = v;
                  formula.clear();
                })),
        if (field.isNotEmpty)
          for (final key in {'a', 'b', ...inputs.keys})
            _mappingRow({
              'key': key,
              'label': 'ورودی $key',
              'type':
                  fields.where((f) => f['key'] == field).firstOrNull?['type'] ??
                      'Number'
            }, input: true),
        if (method == 'formula')
          TextField(
              controller: formula,
              enabled: !saving,
              textDirection: TextDirection.ltr,
              maxLength: 300,
              decoration: const InputDecoration(
                  labelText: 'فرمول؛ مثال: (a + b) / 2',
                  helperText: 'فقط اعداد، ورودی‌ها و + − × ÷؛ بدون اجرای کد')),
      ],
      if (type == AutomaticActionType.link) ...[
        _select(
            'فیلد جست‌وجو',
            field,
            {for (final f in fields) '${f['key']}': '${f['label']}'},
            (v) => setState(() {
                  field = v;
                  lookup = null;
                })),
        if (fields.any((f) => f['key'] == field))
          _mappingRow(fields.firstWhere((f) => f['key'] == field),
              forLookup: true),
        _select(
            'نوع رابطه',
            relationship,
            {'related': 'مرتبط', 'supports': 'پشتیبان', 'follows': 'در ادامهٔ'},
            (v) => setState(() => relationship = v)),
        _select(
            'اگر رکورد پیدا نشد',
            missing,
            {'error': 'توقف و ثبت خطا', 'skip': 'ردکردن اتصال با ثبت نتیجه'},
            (v) => setState(() => missing = v)),
        _notice(
            'اگر چند رکورد پیدا شود، عملیات با خطا متوقف می‌شود؛ انتخاب تصادفی انجام نمی‌شود.'),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AsoudColors.background,
        appBar: AppBar(title: const Text('اقدام خودکار'), centerTitle: true),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
                child: FilledButton(
                    onPressed:
                        loading || saving || problem != null ? null : _save,
                    child: Text(
                        saving ? 'در حال ذخیره…' : 'اعتبارسنجی و ذخیره')))),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
                children: [
                    if (error != null) _notice(error!, warning: true),
                    if (metadataFromCache)
                      _notice(
                          'اطلاعات گزینه‌ها از آخرین دریافت موفق روی همین حساب و سرور خوانده شده است. سرور هنگام همگام‌سازی مجدداً مجوزها و اعتبار تنظیمات را بررسی می‌کند.',
                          warning: true),
                    if (metadata == null)
                      OutlinedButton(
                          onPressed: _load,
                          child: const Text('دریافت دوباره از سرور')),
                    if (metadata != null) ...[
                      if (metadata!['execution_ready'] != true)
                        _notice(
                            'اجرا متوقف است: مدیر باید کاربر سیستمی محدود و شرکت‌های مجاز را در سرور معرفی کند. ذخیرهٔ تنظیمات، به معنی اجرای عملیات نیست.',
                            warning: true),
                      TextField(
                          controller: title,
                          enabled: !saving,
                          decoration: const InputDecoration(
                              labelText: 'عنوان مرحله *')),
                      const SizedBox(height: 14),
                      TextField(
                          controller: description,
                          enabled: !saving,
                          maxLines: 2,
                          maxLength: 500,
                          decoration:
                              const InputDecoration(labelText: 'توضیحات')),
                      _select(
                          'نوع عملیات',
                          type.key,
                          {
                            for (final t in AutomaticActionType.values)
                              t.key: t.label
                          },
                          (v) => _changeType(AutomaticActionType.parse(v))),
                      ..._operationFields(),
                      const Divider(height: 30),
                      _select(
                          'در صورت موفقیت *',
                          success,
                          {
                            for (final s in widget.design.stages.where((s) =>
                                s.id != widget.stage.id &&
                                s.type != WorkflowStageType.start))
                              s.id: s.title
                          },
                          (v) => setState(() => success = v)),
                      _select(
                          'پس از شکست نهایی',
                          failure,
                          {
                            '': 'توقف و ثبت خطا',
                            for (final s in widget.design.stages.where(
                                (s) => s.type == WorkflowStageType.userTask))
                              s.id: s.title
                          },
                          (v) => setState(() => failure = v)),
                      ExpansionTile(
                          title: const Text('سیاست خطا و تنظیمات فنی'),
                          children: [
                            _number('تعداد تلاش اضافه بر اجرای اول (۰ تا ۵)',
                                extra),
                            _number(
                                'فاصلهٔ اولیه به ثانیه (۳۰ تا ۳۶۰۰)', interval),
                            _number('مهلت فنی هر اجرا به ثانیه (۱۰ تا ۳۰۰)',
                                timeout),
                            _notice(
                                'فاصلهٔ Retry دوبرابر می‌شود، تا سقف یک ساعت. فقط خطاهای موقت تکرار می‌شوند. زمان‌بندی با دقت چرخهٔ زمان‌بند سرور انجام می‌شود.'),
                          ]),
                      _notice(
                          'لاگ ممیزی همیشه فعال است. مسئول انسانی و مهلت انجام انسانی در این مرحله وجود ندارد.'),
                      if (problem != null)
                        Text(problem!,
                            style: const TextStyle(color: AsoudColors.danger)),
                    ],
                  ]),
      ));

  Widget _number(String label, TextEditingController controller) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
          controller: controller,
          enabled: !saving,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label)));
}

String _sourceLabel(ActionSource source) => switch (source) {
      ActionSource.current => 'موجودیت فعلی',
      ActionSource.stage => 'خروجی مرحلهٔ قبلی',
      ActionSource.constant => 'مقدار ثابت',
      ActionSource.system => 'سیستم',
    };

class _MappingSheet extends StatefulWidget {
  const _MappingSheet(
      {required this.field, required this.sources, this.initial});
  final Map<String, dynamic> field, sources;
  final ActionMapping? initial;
  @override
  State<_MappingSheet> createState() => _MappingSheetState();
}

class _MappingSheetState extends State<_MappingSheet> {
  late ActionSource source = widget.initial?.source ?? ActionSource.current;
  late String stage = widget.initial?.stage ?? '';
  late String value = widget.initial?.value.toString() ?? '';
  late String transform = widget.initial?.transform ?? 'none';
  late String empty = widget.initial?.empty ?? 'error';
  late final constant =
      TextEditingController(text: source == ActionSource.constant ? value : '');
  @override
  void initState() {
    super.initState();
    constant.addListener(_constantChanged);
  }

  void _constantChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<Map<String, dynamic>> get fields {
    final all = source == ActionSource.stage
        ? _rows(_rows(widget.sources['stages'])
            .where((s) => s['id'] == stage)
            .firstOrNull?['fields'])
        : _rows(widget.sources[source.name]);
    final type = widget.field['type'];
    return all
        .where((f) =>
            f['type'] == type ||
            _numeric.contains(type) && _numeric.contains(f['type']) ||
            _textTypes.contains(type) && _textTypes.contains(f['type']))
        .toList();
  }

  bool get valid => source == ActionSource.constant
      ? constant.text.trim().isNotEmpty &&
          (widget.field['type'] != 'Date' ||
              DateTime.tryParse(constant.text.trim()) != null) &&
          (!_numeric.contains(widget.field['type']) ||
              double.tryParse(toLatinDigits(constant.text.trim()))?.isFinite ==
                  true)
      : fields.any((f) => f['key'] == value);
  @override
  void dispose() {
    constant.dispose();
    super.dispose();
  }

  Widget select(String label, String selected, Map<String, String> items,
          ValueChanged<String> change) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
              key: ValueKey('$label:$selected:${items.keys.join(',')}'),
              isExpanded: true,
              initialValue: items.containsKey(selected) ? selected : null,
              decoration: InputDecoration(labelText: label),
              items: items.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                if (v != null) change(v);
              }));
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              contentPadding: EdgeInsets.zero,
              title:
                  Text('نگاشت ${widget.field['label'] ?? widget.field['key']}'),
              trailing: IconButton(
                  tooltip: 'بستن',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close))),
          select(
              'منبع مقدار',
              source.name,
              {
                for (final s in ActionSource.values)
                  if (s != ActionSource.constant ||
                      !{'Table', 'Item Table', 'Attachment', 'Multi Choice'}
                          .contains(widget.field['type']))
                    s.name: _sourceLabel(s)
              },
              (v) => setState(() {
                    source = ActionSource.values.byName(v);
                    value = '';
                    stage = '';
                    constant.clear();
                    transform = 'none';
                  })),
          if (source == ActionSource.stage)
            select(
                'مرحلهٔ قبلی',
                stage,
                {
                  for (final s in _rows(widget.sources['stages']))
                    '${s['id']}': '${s['label']}'
                },
                (v) => setState(() {
                      stage = v;
                      value = '';
                    })),
          if (source == ActionSource.constant)
            if (widget.field['type'] == 'Date')
              AsoudFormDateField(
                  controller: constant,
                  label: 'مقدار ثابت تاریخ',
                  required: true)
            else if (widget.field['type'] == 'Checkbox')
              select('مقدار ثابت', constant.text,
                  {'true': 'بله', 'false': 'خیر'}, (v) => constant.text = v)
            else if (widget.field['type'] == 'Choice')
              select(
                  'مقدار ثابت',
                  constant.text,
                  {
                    for (final v in (widget.field['options'] as List? ?? []))
                      '$v': '$v'
                  },
                  (v) => constant.text = v)
            else
              TextField(
                  controller: constant,
                  decoration: const InputDecoration(labelText: 'مقدار ثابت'))
          else
            select(
                'فیلد / مقدار',
                value,
                {
                  for (final f in fields)
                    '${f['key']}': '${f['label'] ?? f['key']}'
                },
                (v) => setState(() => value = v)),
          const SizedBox(height: 14),
          select(
              'تبدیل مجاز',
              transform,
              {
                'none': 'بدون تبدیل',
                if (_textTypes.contains(widget.field['type']))
                  'trim': 'حذف فاصلهٔ ابتدا و انتها',
                if (_numeric.contains(widget.field['type']))
                  'round2': 'گردکردن تا دو رقم'
              },
              (v) => setState(() => transform = v)),
          select(
              'اگر مقدار خالی بود',
              empty,
              {
                'error': 'توقف با خطای روشن',
                if (widget.field['required'] != true) 'skip': 'نگاشت اعمال نشود'
              },
              (v) => setState(() => empty = v)),
          FilledButton(
              onPressed: !valid
                  ? null
                  : () => Navigator.pop(
                      context,
                      ActionMapping(
                          source: source,
                          value: source == ActionSource.constant
                              ? (_numeric.contains(widget.field['type'])
                                  ? double.parse(
                                      toLatinDigits(constant.text.trim()))
                                  : widget.field['type'] == 'Checkbox'
                                      ? constant.text == 'true'
                                      : constant.text.trim())
                              : value,
                          stage: source == ActionSource.stage ? stage : null,
                          transform: transform,
                          empty: empty)),
              child: const Text('تأیید نگاشت')),
        ])),
      ));
}
