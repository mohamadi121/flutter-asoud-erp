import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/workflow_automation_repository.dart';
import '../../domain/entities/document_template.dart';
import '../../domain/entities/workflow_definition.dart';
import '../../domain/repositories/workflow_repository.dart';
import '../widgets/document_template_visuals.dart';

/// Creates or edits a document template in four steps: base information,
/// fields, field mapping and settings. Pops (or replaces itself with the
/// success page) with the saved template.
class DocumentTemplateWizardPage extends StatefulWidget {
  const DocumentTemplateWizardPage({
    required this.company,
    this.repository,
    this.workflows,
    this.initial,
    this.module,
    this.documentType,
    this.sourceWorkflow,
    super.key,
  });
  final String company;
  final WorkflowAutomationRepository? repository;
  final WorkflowRepository? workflows;
  final DocumentTemplate? initial;

  /// Preselected module, type and request type (from a workflow stage).
  final String? module, documentType, sourceWorkflow;

  @override
  State<DocumentTemplateWizardPage> createState() => _WizardState();
}

const _stepTitles = [
  'اطلاعات پایه',
  'انتخاب فیلدها',
  'نگاشت فیلدها',
  'تنظیمات تکمیلی'
];

class _WizardState extends State<DocumentTemplateWizardPage> {
  late final WorkflowAutomationRepository repository = widget.repository ??
      WorkflowAutomationRepository(context.read<FrappeApiClient>());
  final formKey = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.initial?.title);
  late final description =
      TextEditingController(text: widget.initial?.description);
  late final note = TextEditingController(text: widget.initial?.managerNote);
  late String module = widget.initial?.module ?? widget.module ?? 'Finance';
  late String documentType =
      widget.initial?.documentType ?? widget.documentType ?? '';
  late String sourceWorkflow = (widget.initial?.sourceWorkflow ?? '').isEmpty
      ? widget.sourceWorkflow ?? ''
      : widget.initial!.sourceWorkflow;
  late Map<String, ValueSource> mapping = {...?widget.initial?.mapping};
  late Set<String> selected = {...mapping.keys};
  late bool draft = widget.initial?.createAsDraft ?? true;
  late bool autoSubmit = widget.initial?.autoSubmit ?? false;
  late bool reusable = widget.initial?.reusable ?? true;
  DocumentTemplateOptions? options;
  List<WorkflowDefinition> requestTypes = const [];
  String? error;
  String fieldQuery = '';
  int step = 0;
  bool saving = false;

  bool get editing =>
      widget.initial != null &&
      widget.initial!.name.isNotEmpty &&
      !widget.initial!.isReady;
  List<DocumentTargetField> get fields =>
      options?.fields[documentType] ?? const [];

  @override
  void initState() {
    super.initState();
    loadOptions();
    loadRequestTypes();
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> loadOptions() async {
    setState(() => error = null);
    try {
      final value = await repository.templateOptions(
          company: widget.company, workflow: sourceWorkflow);
      if (!mounted) return;
      setState(() {
        options = value;
        final types = value.module(module)?.types ?? const [];
        if (!types.any((type) => type.key == documentType && type.enabled)) {
          documentType = types
                  .where((type) => type.enabled)
                  .map((type) => type.key)
                  .firstOrNull ??
              '';
        }
        selected.addAll(_requiredKeys);
      });
    } catch (e) {
      if (mounted) {
        setState(() => error =
            e is ApiException ? e.message : 'دریافت اطلاعات الگو ممکن نشد.');
      }
    }
  }

  Future<void> loadRequestTypes() async {
    try {
      final workflows = widget.workflows ?? context.read<WorkflowRepository>();
      final rows = await workflows.getWorkflows(company: widget.company);
      if (mounted) {
        setState(() => requestTypes = rows
            .where((row) => row.targetDoctype == 'ASOUD Workflow Request')
            .toList());
      }
    } catch (_) {
      // The request type is optional; the base request fields still work.
    }
  }

  Iterable<String> get _requiredKeys =>
      fields.where((field) => field.required).map((field) => field.key);

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void next() {
    if (step == 0) {
      if (!(formKey.currentState?.validate() ?? false)) return;
      if (documentType.isEmpty) {
        return _message('نوع سند را انتخاب کنید.');
      }
      setState(() {
        selected
          ..retainAll(fields.map((field) => field.key))
          ..addAll(_requiredKeys);
        mapping.removeWhere((key, _) => !selected.contains(key));
      });
    }
    if (step == 2) {
      final missing = fields.where((field) =>
          selected.contains(field.key) && !mapping.containsKey(field.key));
      if (missing.isNotEmpty) {
        return _message('منبع مقدار «${missing.first.label}» را مشخص کنید.');
      }
    }
    if (step < 3) {
      setState(() => step++);
    } else {
      save();
    }
  }

  Future<void> save() async {
    setState(() => saving = true);
    final template = DocumentTemplate(
      name: widget.initial?.name ?? '',
      kind: widget.initial?.kind ?? 'custom',
      presetKey: widget.initial?.presetKey ?? '',
      title: title.text.trim(),
      description: description.text.trim(),
      module: module,
      documentType: documentType,
      mapping: {
        for (final key in selected)
          if (mapping[key] != null) key: mapping[key]!
      },
      createAsDraft: draft,
      autoSubmit: autoSubmit,
      reusable: reusable,
      managerNote: note.text.trim(),
    );
    try {
      final saved = await repository.saveTemplate(
          company: widget.company,
          template: template,
          sourceWorkflow: sourceWorkflow);
      if (!mounted) return;
      await Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
              builder: (_) => DocumentTemplateSuccessPage(
                  template: saved,
                  moduleLabel: options?.module(saved.module)?.label ?? '',
                  typeLabel: options?.typeLabel(saved.documentType) ?? '',
                  company: widget.company,
                  repository: repository)),
          result: saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      _message(e is ApiException ? e.message : 'ذخیره الگو انجام نشد.');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => step--);
        },
        child: Scaffold(
          appBar: AsoudHeader(
              title: editing ? 'ویرایش الگوی سند' : 'ایجاد الگوی سند',
              subtitle:
                  'مرحله ${toPersianDigits(step + 1)} از ۴ · ${_stepTitles[step]}'),
          body: options == null
              ? Center(
                  child: error == null
                      ? const CircularProgressIndicator()
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(error!, textAlign: TextAlign.center),
                          TextButton(
                              onPressed: loadOptions,
                              child: const Text('تلاش دوباره')),
                        ]))
              : switch (step) {
                  0 => _baseInfo(),
                  1 => _fieldsStep(),
                  2 => _mappingStep(),
                  _ => _settingsStep(),
                },
          bottomNavigationBar: options == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                      onPressed: saving ? null : next,
                      icon: Icon(step == 3
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded),
                      label: Text(step == 3
                          ? (saving ? 'در حال ذخیره...' : 'ذخیره')
                          : 'بعدی'),
                    ),
                  ),
                ),
        ),
      );

  Widget _baseInfo() {
    final moduleOption = options!.module(module);
    final moduleVisualData = moduleVisual(module);
    final typeVisualData = documentTypeVisual(documentType);
    return Form(
      key: formKey,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const AsoudSectionTitle(title: 'اطلاعات پایه'),
        TextFormField(
          controller: title,
          decoration: const InputDecoration(
              labelText: 'نام الگو *', hintText: 'مثلاً: سند هزینه خرید'),
          validator: (value) =>
              (value ?? '').trim().length < 2 ? 'نام الگو را وارد کنید.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: description,
          minLines: 2,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
              labelText: 'توضیحات', alignLabelWithHint: true),
        ),
        const SizedBox(height: 8),
        PickerField(
          label: 'ماژول',
          value: moduleOption?.label ?? '',
          icon: moduleVisualData.icon,
          iconColor: moduleVisualData.color,
          onTap: () async {
            final choice = await Navigator.push<DocumentModule>(
                context,
                MaterialPageRoute(
                    builder: (_) => ChoiceListPage<DocumentModule>(
                          title: 'انتخاب ماژول',
                          searchHint: 'جستجوی ماژول‌ها...',
                          items: options!.modules,
                          selected: moduleOption,
                          labelOf: (item) => item.label,
                          subtitleOf: (item) =>
                              item.available ? item.description : 'به‌زودی',
                          iconOf: (item) => moduleVisual(item.key),
                          enabledOf: (item) => item.available,
                        )));
            if (choice == null || choice.key == module) return;
            setState(() {
              module = choice.key;
              documentType = choice.types
                      .where((type) => type.enabled)
                      .map((type) => type.key)
                      .firstOrNull ??
                  '';
              mapping.clear();
              selected.clear();
            });
          },
        ),
        const SizedBox(height: 12),
        PickerField(
          label: 'نوع سند *',
          value: documentType.isEmpty ? '' : options!.typeLabel(documentType),
          icon: typeVisualData.icon,
          iconColor: typeVisualData.color,
          onTap: () async {
            final types = moduleOption?.types ?? const <DocumentTypeOption>[];
            final current =
                types.where((type) => type.key == documentType).firstOrNull;
            final choice = await Navigator.push<DocumentTypeOption>(
                context,
                MaterialPageRoute(
                    builder: (_) => ChoiceListPage<DocumentTypeOption>(
                          title: 'انتخاب نوع سند',
                          searchHint: 'جستجوی نوع سند...',
                          items: types,
                          selected: current,
                          labelOf: (item) => item.label,
                          subtitleOf: (item) => item.enabled ? '' : 'به‌زودی',
                          iconOf: (item) => documentTypeVisual(item.key),
                          enabledOf: (item) => item.enabled,
                        )));
            if (choice == null || choice.key == documentType) return;
            setState(() {
              documentType = choice.key;
              mapping.clear();
              selected.clear();
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: requestTypes.any((row) => row.id == sourceWorkflow)
              ? sourceWorkflow
              : '',
          decoration:
              const InputDecoration(labelText: 'درخواست مبنا (اختیاری)'),
          items: [
            const DropdownMenuItem(
                value: '', child: Text('فقط فیلدهای عمومی درخواست')),
            for (final row in requestTypes)
              DropdownMenuItem(
                  value: row.id,
                  child: Text(row.title, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (value) {
            sourceWorkflow = value ?? '';
            mapping.removeWhere((_, source) => source.source == 'request');
            loadOptions();
          },
        ),
      ]),
    );
  }

  Widget _fieldsStep() {
    final visible = fields
        .where(
            (field) => fieldQuery.isEmpty || field.label.contains(fieldQuery))
        .toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      const AsoudSectionTitle(title: 'انتخاب فیلدها'),
      TextField(
        decoration: const InputDecoration(
            hintText: 'جستجو در فیلدهای سند...',
            prefixIcon: Icon(Icons.search_rounded)),
        onChanged: (value) => setState(() => fieldQuery = value.trim()),
      ),
      const SizedBox(height: 12),
      Text('فیلدهای ${options!.typeLabel(documentType)}',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AsoudColors.muted)),
      const SizedBox(height: 6),
      Card(
        child: Column(children: [
          for (final field in visible)
            CheckboxListTile(
              value: selected.contains(field.key),
              // Required fields stay selected.
              onChanged: field.required
                  ? (_) {}
                  : (checked) => setState(() {
                        if (checked == true) {
                          selected.add(field.key);
                        } else {
                          selected.remove(field.key);
                          mapping.remove(field.key);
                        }
                      }),
              secondary: Icon(fieldTypeIcon(field.type),
                  color: AsoudColors.muted, size: 20),
              title: Text(field.label, style: const TextStyle(fontSize: 13)),
              subtitle: field.required
                  ? const Text('الزامی', style: TextStyle(fontSize: 10))
                  : null,
            ),
        ]),
      ),
    ]);
  }

  Widget _mappingStep() {
    final typeVisualData = documentTypeVisual(documentType);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        const Expanded(child: AsoudSectionTitle(title: 'نگاشت فیلدها')),
        TemplateChip(options!.typeLabel(documentType),
            color: typeVisualData.color),
      ]),
      for (final field in fields.where((field) => selected.contains(field.key)))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            AsoudPickerIcon(
                icon: fieldTypeIcon(field.type),
                color: AsoudColors.primary,
                size: 48),
            const SizedBox(width: 8),
            Expanded(
              child: PickerField(
                label: '${field.label}${field.required ? ' *' : ''}',
                value: _describe(field, mapping[field.key]),
                placeholder: 'منبع مقدار را انتخاب کنید',
                trailing: const Icon(Icons.link_rounded,
                    color: AsoudColors.primary, size: 20),
                onTap: () => pickSource(field),
              ),
            ),
          ]),
        ),
    ]);
  }

  String _describe(DocumentTargetField field, ValueSource? source) {
    if (source == null) return '';
    if (source.source == 'fixed') return source.value;
    final option = options!.sources[source.source]
        ?.where((item) => item.key == source.value)
        .firstOrNull;
    return '${valueSourceLabels[source.source]}: ${option?.label ?? source.value}';
  }

  Future<void> pickSource(DocumentTargetField field) async {
    final allowed = field.type == 'Item Table'
        ? const ['request']
        : valueSourceLabels.keys.toList();
    final source = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('منبع مقدار «${field.label}»',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  for (final key in allowed)
                    ListTile(
                      leading: AsoudPickerIcon(
                          icon: switch (key) {
                            'fixed' => Icons.info_outline_rounded,
                            'request' => Icons.check_rounded,
                            'user' => Icons.person_outline_rounded,
                            'organization' => Icons.apartment_rounded,
                            _ => Icons.view_in_ar_outlined,
                          },
                          color: AsoudColors.primary),
                      title: Text(valueSourceLabels[key]!,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(valueSourceHints[key]!,
                          style: const TextStyle(fontSize: 11)),
                      selected: mapping[field.key]?.source == key,
                      onTap: () => Navigator.pop(context, key),
                    ),
                  const SizedBox(height: 6),
                  OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('انصراف')),
                ]),
              ),
            ));
    if (source == null || !mounted) return;
    final value = source == 'fixed'
        ? await _fixedValue(field)
        : await _optionValue(field, source);
    if (value == null || value.isEmpty || !mounted) return;
    setState(
        () => mapping[field.key] = ValueSource(source: source, value: value));
  }

  Future<String?> _optionValue(DocumentTargetField field, String source) {
    final compatible = switch (field.type) {
      'Currency' => const {'Number', 'Currency'},
      'Date' => const {'Date'},
      'Item Table' => const {'Item Table'},
      _ => const <String>{},
    };
    final items = (options!.sources[source] ?? const [])
        .where((item) =>
            source != 'request' ||
            compatible.isEmpty ||
            compatible.contains(item.type))
        .toList();
    final current = mapping[field.key];
    return Navigator.push<String>(
        context,
        MaterialPageRoute(
            builder: (_) => ChoiceListPage<String>(
                  title: source == 'request'
                      ? 'انتخاب فیلد درخواست'
                      : valueSourceLabels[source]!,
                  searchHint: 'جستجو...',
                  sectionTitle: source == 'request' ? 'فیلدهای درخواست' : null,
                  items: [for (final item in items) item.key],
                  selected: current?.source == source ? current!.value : null,
                  labelOf: (key) =>
                      items.firstWhere((item) => item.key == key).label,
                  iconOf: (key) => (
                    icon: fieldTypeIcon(
                        items.firstWhere((item) => item.key == key).type),
                    color: AsoudColors.muted
                  ),
                  confirmLabel: 'انتخاب',
                )));
  }

  Future<String?> _fixedValue(DocumentTargetField field) async {
    if (field.isLink) {
      List<LinkOption> links;
      try {
        links = await repository.linkOptions(
            company: widget.company, targetType: field.type);
      } catch (e) {
        _message(e is ApiException ? e.message : 'دریافت فهرست ممکن نشد.');
        return null;
      }
      if (!mounted) return null;
      return Navigator.push<String>(
          context,
          MaterialPageRoute(
              builder: (_) => ChoiceListPage<String>(
                    title: field.label,
                    items: [for (final link in links) link.value],
                    selected: mapping[field.key]?.value,
                    labelOf: (value) =>
                        links.firstWhere((link) => link.value == value).label,
                    subtitleOf: (value) => value,
                    confirmLabel: 'انتخاب',
                  )));
    }
    final controller = TextEditingController(
        text: mapping[field.key]?.source == 'fixed'
            ? mapping[field.key]!.value
            : '');
    final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(field.label),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: field.type == 'Currency'
                      ? TextInputType.number
                      : TextInputType.text,
                  decoration: InputDecoration(
                      hintText: field.type == 'Date'
                          ? 'مثلاً 2026-09-25'
                          : 'مقدار ثابت'),
                ),
                if (field.type == 'Text') ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final placeholder in options!.placeholders)
                      ActionChip(
                          label: Text(placeholder,
                              textDirection: TextDirection.ltr),
                          onPressed: () => controller.text =
                              '${controller.text}$placeholder'),
                  ]),
                ],
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('انصراف')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('تأیید')),
              ],
            ));
    controller.dispose();
    return result;
  }

  Widget _settingsStep() =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const AsoudSectionTitle(title: 'تنظیمات تکمیلی'),
        Card(
          child: Column(children: [
            SwitchListTile(
              title: const Text('ایجاد به‌صورت پیش‌نویس'),
              subtitle: const Text('سند ایجاد شده در حالت پیش‌نویس ذخیره شود',
                  style: TextStyle(fontSize: 11)),
              value: draft && !autoSubmit,
              onChanged:
                  autoSubmit ? null : (value) => setState(() => draft = value),
            ),
            SwitchListTile(
              title: const Text('ثبت خودکار'),
              subtitle: const Text('پس از ایجاد، سند به‌صورت خودکار ثبت شود',
                  style: TextStyle(fontSize: 11)),
              value: autoSubmit,
              onChanged: (value) => setState(() {
                autoSubmit = value;
                if (value) draft = false;
              }),
            ),
            SwitchListTile(
              title: const Text('استفاده مجدد'),
              subtitle: const Text(
                  'این الگو برای سایر گردش‌های کار قابل استفاده باشد',
                  style: TextStyle(fontSize: 11)),
              value: reusable,
              onChanged: (value) => setState(() => reusable = value),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: note,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
              labelText: 'یادداشت مدیر (اختیاری)',
              hintText: 'توضیحات تکمیلی درباره الگو...',
              alignLabelWithHint: true),
        ),
      ]);
}

class DocumentTemplateSuccessPage extends StatelessWidget {
  const DocumentTemplateSuccessPage({
    required this.template,
    required this.moduleLabel,
    required this.typeLabel,
    required this.company,
    required this.repository,
    super.key,
  });
  final DocumentTemplate template;
  final String moduleLabel, typeLabel, company;
  final WorkflowAutomationRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                    color: AsoudColors.success.withValues(alpha: .12),
                    shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: AsoudColors.success, size: 56),
              ),
              const SizedBox(height: 20),
              const Text('الگو با موفقیت ایجاد شد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(
                  'الگوی «${template.title}» در ماژول $moduleLabel - $typeLabel '
                  'با موفقیت ذخیره شد.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, height: 1.7, color: AsoudColors.muted)),
              const SizedBox(height: 28),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => DocumentTemplateWizardPage(
                            company: company,
                            repository: repository,
                            initial: template))),
                icon: const Icon(Icons.description_outlined),
                label: const Text('مشاهده الگو'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.home_outlined),
                label: const Text('بازگشت به لیست الگوها'),
              ),
            ]),
          ),
        ),
      );
}
